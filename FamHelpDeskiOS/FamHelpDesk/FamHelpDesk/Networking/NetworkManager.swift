import Amplify
import AWSCognitoAuthPlugin
import Foundation
import Network

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case decodingError
    case noData
    case unauthorized
    case tokenRefreshFailed(Error)
    case authenticationFailure(Error)
    case networkTimeout
    case malformedResponse
    case noConnection
}

final class NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession
    private var accessToken: String?
    var environment: APIEnvironment = .current
    private let logger = AuthLogger.shared
    private let retryHelper = RetryHelper()

    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var isConnected = true

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        session = URLSession(configuration: configuration)

        // Start network monitoring
        startNetworkMonitoring()
    }

    deinit {
        networkMonitor.cancel()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                if path.status == .satisfied {
                    self?.logger.logNetworkOperation(.connectionRestored)
                } else {
                    self?.logger.logNetworkOperation(.connectionLost)
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    var hasNetworkConnection: Bool {
        isConnected
    }

    func setAccessToken(_ token: String) {
        logger.logNetworkOperation(.authHeaderAdded)
        accessToken = token
    }

    func clearAccessToken() {
        accessToken = nil
    }

    func setEnvironment(_ env: APIEnvironment) {
        environment = env
    }

    // Fetch fresh token from Amplify (auto-refreshes if needed)
    // Enhanced with proper error handling for token refresh failures
    private func getFreshToken() async throws -> String? {
        // If we have a manually set token, use it
        if let token = accessToken {
            return token
        }

        do {
            // Fetch token from AuthSessionManager with error handling
            let token = try await AuthSessionManager.shared.getIDToken()
            return token
        } catch {
            // Handle different types of token failures with structured error classification
            if let tokenError = error as? TokenError {
                switch tokenError {
                case .userNotSignedIn:
                    logger.logNetworkOperation(.authHeaderMissing(reason: "user_not_signed_in"))
                    throw NetworkError.unauthorized
                case .tokenProviderUnavailable, .tokenExpired, .tokenValidationFailed:
                    logger.logNetworkOperation(.authHeaderMissing(reason: "token_refresh_failed"))
                    throw NetworkError.tokenRefreshFailed(error)
                case let .authenticationFailure(authError):
                    logger.logNetworkOperation(.authHeaderMissing(reason: "authentication_failure"))
                    throw NetworkError.authenticationFailure(authError)
                case let .tokenRetrievalFailed(retrievalError):
                    logger.logNetworkOperation(.authHeaderMissing(reason: "token_retrieval_failed"))
                    throw NetworkError.tokenRefreshFailed(retrievalError)
                }
            } else {
                logger.logNetworkOperation(.authHeaderMissing(reason: "unknown_token_error"))
                throw NetworkError.tokenRefreshFailed(error)
            }
        }
    }

    private func buildURL(endpoint: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        let baseURLString = environment.baseURL
        let fullPath = baseURLString + endpoint

        guard var urlComponents = URLComponents(string: fullPath) else {
            return nil
        }

        if let queryItems, !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        return urlComponents.url
    }

    private func createRequest(url: URL, method: String) async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Ensure Bearer token headers are always included when tokens available
        do {
            if let token = try await getFreshToken() {
                logger.logNetworkOperation(.authHeaderAdded)
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else {
                logger.logNetworkOperation(.authHeaderMissing(reason: "no_token_available"))
            }
        } catch {
            logger.logNetworkOperation(.authHeaderMissing(reason: "token_retrieval_failed"))
            // Don't throw here - allow request to proceed without token
            // The server will return 401 if authentication is required
        }

        return request
    }

    // MARK: - Token Management

    private func decodeTokenType(_ token: String) -> [String: Any]? {
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }
        var base64 = segments[1]
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        base64 = base64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    func get<T: Decodable>(endpoint: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        // Check network connection first
        guard hasNetworkConnection else {
            logger.logNetworkOperation(.requestFailure(method: "GET", endpoint: endpoint, error: NetworkError.noConnection))
            throw NetworkError.noConnection
        }

        guard let url = buildURL(endpoint: endpoint, queryItems: queryItems) else {
            logger.logNetworkOperation(.requestFailure(method: "GET", endpoint: endpoint, error: NetworkError.invalidURL))
            throw NetworkError.invalidURL
        }

        logger.logNetworkOperation(.requestStarted(method: "GET", endpoint: endpoint, hasAuth: accessToken != nil))

        return try await performRequestWithRetry(url: url, method: "GET", body: nil)
    }

    func getRawData(endpoint: String, queryItems: [URLQueryItem]? = nil) async throws -> Data {
        // Check network connection first
        guard hasNetworkConnection else {
            logger.logNetworkOperation(.requestFailure(method: "GET", endpoint: endpoint, error: NetworkError.noConnection))
            throw NetworkError.noConnection
        }

        guard let url = buildURL(endpoint: endpoint, queryItems: queryItems) else {
            logger.logNetworkOperation(.requestFailure(method: "GET", endpoint: endpoint, error: NetworkError.invalidURL))
            throw NetworkError.invalidURL
        }

        logger.logNetworkOperation(.requestStarted(method: "GET", endpoint: endpoint, hasAuth: accessToken != nil))

        var request = try await createRequest(url: url, method: "GET")
        let (data, response) = try await session.data(for: request)

        // Validate response
        try await validateResponseWithRetry(response: response, data: data, url: url, method: "GET", body: nil, retryCount: 0)

        return data
    }

    func post<T: Decodable>(endpoint: String, body: Encodable) async throws -> T {
        // Check network connection first
        guard hasNetworkConnection else {
            logger.logNetworkOperation(.requestFailure(method: "POST", endpoint: endpoint, error: NetworkError.noConnection))
            throw NetworkError.noConnection
        }

        guard let url = buildURL(endpoint: endpoint) else {
            logger.logNetworkOperation(.requestFailure(method: "POST", endpoint: endpoint, error: NetworkError.invalidURL))
            throw NetworkError.invalidURL
        }

        logger.logNetworkOperation(.requestStarted(method: "POST", endpoint: endpoint, hasAuth: accessToken != nil))

        return try await performRequestWithRetry(url: url, method: "POST", body: body)
    }

    func postRawData(endpoint: String, body: Encodable) async throws -> Data {
        // Check network connection first
        guard hasNetworkConnection else {
            logger.logNetworkOperation(.requestFailure(method: "POST", endpoint: endpoint, error: NetworkError.noConnection))
            throw NetworkError.noConnection
        }

        guard let url = buildURL(endpoint: endpoint) else {
            logger.logNetworkOperation(.requestFailure(method: "POST", endpoint: endpoint, error: NetworkError.invalidURL))
            throw NetworkError.invalidURL
        }

        logger.logNetworkOperation(.requestStarted(method: "POST", endpoint: endpoint, hasAuth: accessToken != nil))

        var request = try await createRequest(url: url, method: "POST")

        // Add body for POST request
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        // Validate response
        try await validateResponseWithRetry(response: response, data: data, url: url, method: "POST", body: body, retryCount: 0)

        return data
    }

    func put<T: Decodable>(endpoint: String, body: Encodable) async throws -> T {
        // Check network connection first
        guard hasNetworkConnection else {
            logger.logNetworkOperation(.requestFailure(method: "PUT", endpoint: endpoint, error: NetworkError.noConnection))
            throw NetworkError.noConnection
        }

        guard let url = buildURL(endpoint: endpoint) else {
            logger.logNetworkOperation(.requestFailure(method: "PUT", endpoint: endpoint, error: NetworkError.invalidURL))
            throw NetworkError.invalidURL
        }

        logger.logNetworkOperation(.requestStarted(method: "PUT", endpoint: endpoint, hasAuth: accessToken != nil))

        return try await performRequestWithRetry(url: url, method: "PUT", body: body)
    }

    func putRawData(endpoint: String, body: Encodable) async throws -> Data {
        // Check network connection first
        guard hasNetworkConnection else {
            logger.logNetworkOperation(.requestFailure(method: "PUT", endpoint: endpoint, error: NetworkError.noConnection))
            throw NetworkError.noConnection
        }

        guard let url = buildURL(endpoint: endpoint) else {
            logger.logNetworkOperation(.requestFailure(method: "PUT", endpoint: endpoint, error: NetworkError.invalidURL))
            throw NetworkError.invalidURL
        }

        logger.logNetworkOperation(.requestStarted(method: "PUT", endpoint: endpoint, hasAuth: accessToken != nil))

        var request = try await createRequest(url: url, method: "PUT")

        // Add body for PUT request
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        // Validate response
        try await validateResponseWithRetry(response: response, data: data, url: url, method: "PUT", body: body, retryCount: 0)

        return data
    }

    func delete<T: Decodable>(endpoint: String) async throws -> T {
        // Check network connection first
        guard hasNetworkConnection else {
            logger.logNetworkOperation(.requestFailure(method: "DELETE", endpoint: endpoint, error: NetworkError.noConnection))
            throw NetworkError.noConnection
        }

        guard let url = buildURL(endpoint: endpoint) else {
            logger.logNetworkOperation(.requestFailure(method: "DELETE", endpoint: endpoint, error: NetworkError.invalidURL))
            throw NetworkError.invalidURL
        }

        logger.logNetworkOperation(.requestStarted(method: "DELETE", endpoint: endpoint, hasAuth: accessToken != nil))

        return try await performRequestWithRetry(url: url, method: "DELETE", body: nil)
    }

    func deleteRawData(endpoint: String) async throws -> Data {
        // Check network connection first
        guard hasNetworkConnection else {
            logger.logNetworkOperation(.requestFailure(method: "DELETE", endpoint: endpoint, error: NetworkError.noConnection))
            throw NetworkError.noConnection
        }

        guard let url = buildURL(endpoint: endpoint) else {
            logger.logNetworkOperation(.requestFailure(method: "DELETE", endpoint: endpoint, error: NetworkError.invalidURL))
            throw NetworkError.invalidURL
        }

        logger.logNetworkOperation(.requestStarted(method: "DELETE", endpoint: endpoint, hasAuth: accessToken != nil))

        var request = try await createRequest(url: url, method: "DELETE")
        let (data, response) = try await session.data(for: request)

        // Validate response
        try await validateResponseWithRetry(response: response, data: data, url: url, method: "DELETE", body: nil, retryCount: 0)

        return data
    }

    // MARK: - Request Execution with 401 Retry Logic

    /// Perform request with enhanced retry logic for multiple error types
    private func performRequestWithRetry<T: Decodable>(
        url: URL,
        method: String,
        body: Encodable?,
        retryCount: Int = 0
    ) async throws -> T {
        let maxRetries = 3 // Increased from 1 to 3 for better resilience

        do {
            var request = try await createRequest(url: url, method: method)

            // Add body for POST/PUT requests
            if let body, method != "DELETE" {
                let encoder = JSONEncoder()
                encoder.keyEncodingStrategy = .convertToSnakeCase
                request.httpBody = try encoder.encode(body)
            }

            let (data, response) = try await session.data(for: request)

            // Validate response and handle retryable errors
            try await validateResponseWithRetry(response: response, data: data, url: url, method: method, body: body, retryCount: retryCount)

            // Decode successful response
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(T.self, from: data)
            } catch {
                logger.logNetworkOperation(.requestFailure(method: method, endpoint: url.absoluteString, error: NetworkError.decodingError))
                throw NetworkError.decodingError
            }

        } catch let networkError as NetworkError where networkError.canRetry && retryCount < maxRetries {
            // Enhanced retry logic for multiple error types
            logger.logNetworkOperation(.retryAttempt(attempt: retryCount + 1, maxRetries: maxRetries, endpoint: url.absoluteString))

            // Calculate exponential backoff delay
            let baseDelay = networkError.retryDelay
            let backoffDelay = baseDelay * pow(2.0, Double(retryCount))
            let jitteredDelay = backoffDelay + Double.random(in: 0 ... 0.5) // Add jitter to prevent thundering herd

            do {
                // Handle specific error types before retry
                switch networkError {
                case .unauthorized:
                    // Clear any cached tokens and force refresh
                    await AuthSessionManager.shared.clearTokens()
                case .networkTimeout, .noConnection:
                    // Check if connection is restored before retry
                    if !hasNetworkConnection {
                        // Wait for connection to be restored or timeout
                        let connectionTimeout = 10.0 // 10 seconds
                        let startTime = Date()
                        while !hasNetworkConnection, Date().timeIntervalSince(startTime) < connectionTimeout {
                            try await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5 seconds
                        }

                        if !hasNetworkConnection {
                            throw NetworkError.noConnection
                        }
                    }
                case let .serverError(statusCode, _) where statusCode >= 500:
                    // Server errors - use exponential backoff
                    break
                default:
                    break
                }

                // Wait before retry
                try await Task.sleep(nanoseconds: UInt64(jitteredDelay * 1_000_000_000))

                // Retry the request
                return try await performRequestWithRetry(url: url, method: method, body: body, retryCount: retryCount + 1)

            } catch {
                logger.logNetworkOperation(.requestFailure(method: method, endpoint: url.absoluteString, error: error))
                throw NetworkError.authenticationFailure(error)
            }
        }
    }

    // MARK: - Response Validation

    /// Enhanced response validation with structured error handling for different failure types
    private func validateResponseWithRetry(
        response: URLResponse,
        data: Data,
        url: URL,
        method: String,
        body _: Encodable?,
        retryCount _: Int
    ) async throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.logNetworkOperation(.requestFailure(method: method, endpoint: url.absoluteString, error: NetworkError.invalidResponse))
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            logger.logNetworkOperation(.requestSuccess(method: method, endpoint: url.absoluteString, statusCode: httpResponse.statusCode))
            return
        case 401:
            logger.logNetworkOperation(.unauthorizedResponse(endpoint: url.absoluteString))
            throw NetworkError.unauthorized
        case 408, 504:
            logger.logNetworkOperation(.requestFailure(method: method, endpoint: url.absoluteString, error: NetworkError.networkTimeout))
            throw NetworkError.networkTimeout
        case 502, 503, 504:
            // Additional server errors that should be retried
            let errorMessage = parseErrorResponse(data: data)
            let message = errorMessage ?? "Server temporarily unavailable"
            let serverError = NetworkError.serverError(statusCode: httpResponse.statusCode, message: message)
            logger.logNetworkOperation(.requestFailure(method: method, endpoint: url.absoluteString, error: serverError))
            throw serverError
        default:
            // Implement structured error handling for different failure types
            let errorMessage = parseErrorResponse(data: data)
            let message = errorMessage ?? "Unknown server error"

            let serverError = NetworkError.serverError(statusCode: httpResponse.statusCode, message: message)
            logger.logNetworkOperation(.requestFailure(method: method, endpoint: url.absoluteString, error: serverError))

            throw serverError
        }
    }

    /// Legacy validation method for backward compatibility
    private func validateResponse(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.logNetworkOperation(.requestFailure(method: "LEGACY", endpoint: "legacy_validation", error: NetworkError.invalidResponse))
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            return
        case 401:
            logger.logNetworkOperation(.unauthorizedResponse(endpoint: "legacy_validation"))
            throw NetworkError.unauthorized
        default:
            let errorMessage = parseErrorResponse(data: data)
            let message = errorMessage ?? "Unknown server error"
            let serverError = NetworkError.serverError(statusCode: httpResponse.statusCode, message: message)
            logger.logNetworkOperation(.requestFailure(method: "LEGACY", endpoint: "legacy_validation", error: serverError))
            throw serverError
        }
    }

    /// Parse error response with structured error handling
    private func parseErrorResponse(data: Data) -> String? {
        do {
            // Try to parse as JSON error response
            if let errorDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Try common error message keys
                if let detail = errorDict["detail"] as? String {
                    return detail
                } else if let message = errorDict["message"] as? String {
                    return message
                } else if let error = errorDict["error"] as? String {
                    return error
                } else if let errors = errorDict["errors"] as? [String], !errors.isEmpty {
                    return errors.joined(separator: ", ")
                }
            }

            // Try to parse as simple string
            if let errorString = String(data: data, encoding: .utf8), !errorString.isEmpty {
                return errorString
            }

        } catch {
            // Production-safe logging for error parsing failures
            #if DEBUG
                logger.logNetworkOperation(.requestFailure(method: "PARSE", endpoint: "error_response", error: error))
            #endif
        }

        return nil
    }
}
