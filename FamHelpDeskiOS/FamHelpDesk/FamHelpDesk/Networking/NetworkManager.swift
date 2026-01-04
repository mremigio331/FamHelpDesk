import Amplify
import AWSCognitoAuthPlugin
import Foundation

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
}

final class NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession
    private var accessToken: String?
    var environment: APIEnvironment = .current
    private let logger = AuthLogger.shared

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        session = URLSession(configuration: configuration)
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
        guard let url = buildURL(endpoint: endpoint, queryItems: queryItems) else {
            logger.logNetworkOperation(.requestFailure(method: "GET", endpoint: endpoint, error: NetworkError.invalidURL))
            throw NetworkError.invalidURL
        }

        logger.logNetworkOperation(.requestStarted(method: "GET", endpoint: endpoint, hasAuth: accessToken != nil))

        return try await performRequestWithRetry(url: url, method: "GET", body: nil)
    }

    func getRawData(endpoint: String, queryItems: [URLQueryItem]? = nil) async throws -> Data {
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
        guard let url = buildURL(endpoint: endpoint) else {
            logger.logNetworkOperation(.requestFailure(method: "POST", endpoint: endpoint, error: NetworkError.invalidURL))
            throw NetworkError.invalidURL
        }

        logger.logNetworkOperation(.requestStarted(method: "POST", endpoint: endpoint, hasAuth: accessToken != nil))

        return try await performRequestWithRetry(url: url, method: "POST", body: body)
    }

    func postRawData(endpoint: String, body: Encodable) async throws -> Data {
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
        guard let url = buildURL(endpoint: endpoint) else {
            logger.logNetworkOperation(.requestFailure(method: "PUT", endpoint: endpoint, error: NetworkError.invalidURL))
            throw NetworkError.invalidURL
        }

        logger.logNetworkOperation(.requestStarted(method: "PUT", endpoint: endpoint, hasAuth: accessToken != nil))

        return try await performRequestWithRetry(url: url, method: "PUT", body: body)
    }

    func putRawData(endpoint: String, body: Encodable) async throws -> Data {
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

    // MARK: - Request Execution with 401 Retry Logic

    /// Perform request with automatic 401 response handling and token refresh retry
    private func performRequestWithRetry<T: Decodable>(
        url: URL,
        method: String,
        body: Encodable?,
        retryCount: Int = 0
    ) async throws -> T {
        let maxRetries = 1 // Only retry once for 401 errors

        do {
            var request = try await createRequest(url: url, method: method)

            // Add body for POST/PUT requests
            if let body {
                let encoder = JSONEncoder()
                encoder.keyEncodingStrategy = .convertToSnakeCase
                request.httpBody = try encoder.encode(body)
            }

            let (data, response) = try await session.data(for: request)

            // Validate response and handle 401 with retry
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

        } catch NetworkError.unauthorized where retryCount < maxRetries {
            // Handle 401 response with token refresh retry
            logger.logNetworkOperation(.unauthorizedResponse(endpoint: url.absoluteString))
            logger.logNetworkOperation(.retryAttempt(attempt: retryCount + 1, maxRetries: maxRetries, endpoint: url.absoluteString))

            do {
                // Clear any cached tokens and force refresh
                await AuthSessionManager.shared.clearTokens()

                // Wait a moment before retry
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

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
