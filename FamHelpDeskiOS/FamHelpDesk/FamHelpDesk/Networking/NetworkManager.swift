import Foundation

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case decodingError
    case noData
    case unauthorized
}

final class NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession
    private var accessToken: String?
    var environment: APIEnvironment = .current

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        session = URLSession(configuration: configuration)
    }

    func setAccessToken(_ token: String) {
        print("🔑 NetworkManager: Setting access token (length: \(token.count))")
        accessToken = token
    }

    func clearAccessToken() {
        accessToken = nil
    }

    func setEnvironment(_ env: APIEnvironment) {
        environment = env
    }

    private func buildURL(endpoint: String) -> URL? {
        let baseURLString = environment.baseURL
        let fullPath = baseURLString + endpoint
        return URL(string: fullPath)
    }

    private func createRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            print("🔑 Adding Authorization header (token length: \(token.count))")

            // DEBUG: Decode and verify the token being sent
            if let claims = decodeTokenType(token) {
                print("🔍 Token being sent:")
                print("  - type: \(claims["token_use"] as? String ?? "unknown")")
                print("  - aud (client_id): \(claims["aud"] as? String ?? "unknown")")
                print("  - iss (issuer): \(claims["iss"] as? String ?? "unknown")")
                if let scope = claims["scope"] as? String {
                    print("  - scope: \(scope)")
                }
            }

            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("⚠️ No access token available!")
        }

        return request
    }

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

    func get<T: Decodable>(endpoint: String) async throws -> T {
        guard let url = buildURL(endpoint: endpoint) else {
            throw NetworkError.invalidURL
        }

        print("🌐 GET: \(url.absoluteString)")

        let request = createRequest(url: url, method: "GET")

        let (data, response) = try await session.data(for: request)

        try validateResponse(response: response, data: data)

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            throw NetworkError.decodingError
        }
    }

    func post<T: Decodable>(endpoint: String, body: Encodable) async throws -> T {
        guard let url = buildURL(endpoint: endpoint) else {
            throw NetworkError.invalidURL
        }

        print("🌐 POST: \(url.absoluteString)")

        var request = createRequest(url: url, method: "POST")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        try validateResponse(response: response, data: data)

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            throw NetworkError.decodingError
        }
    }

    private func validateResponse(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            return
        case 401:
            print("❌ Unauthorized (401)")
            throw NetworkError.unauthorized
        default:
            let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
            let message = errorMessage?["detail"] ?? errorMessage?["message"]
            print("❌ Server error: \(httpResponse.statusCode) - \(message ?? "No message")")
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }
    }
}
