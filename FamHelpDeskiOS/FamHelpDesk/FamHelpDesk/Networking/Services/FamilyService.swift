import Foundation

final class FamilyService {
    private let networkManager: NetworkManager

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    /// Fetches all families
    /// - Returns: Array of Family objects
    /// - Throws: NetworkError if the request fails
    func getAllFamilies() async throws -> [Family] {
        let response: GetAllFamiliesResponse = try await networkManager.get(
            endpoint: APIEndpoint.getAllFamilies.path
        )
        print("📱 All Families Response: \(response.families.count) families")
        return response.families
    }

    /// Fetches families for the current user
    /// - Returns: Dictionary of family items keyed by family ID
    /// - Throws: NetworkError if the request fails
    func getMyFamilies() async throws -> [String: MyFamilyItem] {
        let response: GetMyFamiliesResponse = try await networkManager.get(
            endpoint: APIEndpoint.getMyFamilies.path
        )
        print("📱 My Families Response: \(response.families.count) families")
        return response.families
    }

    /// Creates a new family
    /// - Parameters:
    ///   - name: The name of the family
    ///   - description: Optional description
    /// - Returns: The created Family object
    /// - Throws: NetworkError if the request fails
    func createFamily(name: String, description: String?) async throws -> Family {
        let request = CreateFamilyRequest(
            familyName: name,
            familyDescription: description
        )
        let response: CreateFamilyResponse = try await networkManager.post(
            endpoint: APIEndpoint.createFamily.path,
            body: request
        )
        print("📱 Created Family: \(response.family.familyName)")
        return response.family
    }
}
