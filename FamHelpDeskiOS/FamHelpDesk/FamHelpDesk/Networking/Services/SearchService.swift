import Foundation

final class SearchService {
    private let networkManager: NetworkManager
    private let retryHelper = RetryHelper()

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    /// Fetches all available families for discovery with enhanced error handling
    /// - Returns: Array of Family objects
    /// - Throws: ServiceError with structured error information
    func getAllFamilies() async throws -> [Family] {
        do {
            let response: GetAllFamiliesResponse = try await networkManager.get(
                endpoint: APIEndpoint.getAllFamilies.path
            )
            print("📱 Search All Families Response: \(response.families.count) families")
            return response.families
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching all families for search: \(serviceError)")
            throw serviceError
        }
    }

    /// Searches for families based on a query string with validation and enhanced error handling
    /// - Parameter query: The search query
    /// - Returns: Array of Family objects matching the query
    /// - Throws: ServiceError for validation errors or network failures
    func searchFamilies(query: String) async throws -> [Family] {
        // Validate search query
        try validateSearchQuery(query)
        
        do {
            let queryItems = [URLQueryItem(name: "q", value: query)]
            let response: GetAllFamiliesResponse = try await networkManager.get(
                endpoint: APIEndpoint.searchFamilies.path,
                queryItems: queryItems
            )
            print("📱 Search Families Response: \(response.families.count) families for query '\(query)'")
            return response.families
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error searching families: \(serviceError)")
            throw serviceError
        }
    }
    
    // MARK: - Private Validation Methods
    
    /// Validates search query according to business rules
    /// - Parameter query: The search query to validate
    /// - Throws: ValidationError if query is invalid
    private func validateSearchQuery(_ query: String) throws {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedQuery.isEmpty {
            throw ValidationError.emptySearchQuery
        }
        
        if trimmedQuery.count < 2 {
            throw ValidationError.searchQueryTooShort
        }
    }
}
