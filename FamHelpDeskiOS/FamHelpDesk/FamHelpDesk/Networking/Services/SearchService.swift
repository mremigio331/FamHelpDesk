import Foundation

final class SearchService {
    private let networkManager: NetworkManager

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    /// Fetches all available families for discovery
    /// - Returns: Array of Family objects
    /// - Throws: NetworkError if the request fails
    func getAllFamilies() async throws -> [Family] {
        let response: GetAllFamiliesResponse = try await networkManager.get(
            endpoint: APIEndpoint.getAllFamilies.path
        )
        print("📱 Search All Families Response: \(response.families.count) families")
        return response.families
    }

    /// Searches for families based on a query string
    /// - Parameter query: The search query
    /// - Returns: Array of Family objects matching the query
    /// - Throws: NetworkError if the request fails
    func searchFamilies(query: String) async throws -> [Family] {
        let queryItems = [URLQueryItem(name: "q", value: query)]
        let response: GetAllFamiliesResponse = try await networkManager.get(
            endpoint: APIEndpoint.searchFamilies.path,
            queryItems: queryItems
        )
        print("📱 Search Families Response: \(response.families.count) families for query '\(query)'")
        return response.families
    }
}
