import Foundation

final class APIClient {
    static let shared = APIClient()

    private var baseURL: URL {
        URL(string: APIEnvironment.current.baseURL)!
    }

    private var accessToken: String?

    func setAccessToken(_ token: String) {
        accessToken = token
    }

    func clearAccessToken() {
        accessToken = nil
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        print("🌐 GET (APIClient): \(url.absoluteString)")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if let token = accessToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        print("🌐 POST (APIClient): \(url.absoluteString)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validate(resp: URLResponse, data _: Data) throws {
        guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw APIError.server
        }
    }
}

enum APIError: Error {
    case server
}
