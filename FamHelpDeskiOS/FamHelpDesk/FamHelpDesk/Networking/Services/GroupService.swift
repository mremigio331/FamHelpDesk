import Foundation

final class GroupService {
    private let networkManager: NetworkManager

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    /// Fetches all groups in a family
    /// - Parameter familyId: The ID of the family
    /// - Returns: Array of Group objects
    /// - Throws: NetworkError if the request fails
    func getAllGroups(familyId: String) async throws -> [FamilyGroup] {
        let response: GetAllGroupsResponse = try await networkManager.get(
            endpoint: APIEndpoint.getAllGroups(familyId: familyId).path
        )
        print("📱 All Groups Response: \(response.groups.count) groups")
        return response.groups
    }

    /// Fetches groups for the current user
    /// - Returns: Dictionary of group items keyed by group ID
    /// - Throws: NetworkError if the request fails
    func getMyGroups() async throws -> [String: MyGroupItem] {
        let response: GetMyGroupsResponse = try await networkManager.get(
            endpoint: APIEndpoint.getMyGroups.path
        )
        print("📱 My Groups Response: \(response.groups.count) groups")
        return response.groups
    }

    /// Creates a new group
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - name: The name of the group
    ///   - description: Optional description
    /// - Returns: The created Group object
    /// - Throws: NetworkError if the request fails
    func createGroup(familyId: String, name: String, description: String?) async throws -> FamilyGroup {
        let request = CreateGroupRequest(
            familyId: familyId,
            groupName: name,
            groupDescription: description
        )
        let response: CreateGroupResponse = try await networkManager.post(
            endpoint: APIEndpoint.createGroup.path,
            body: request
        )
        print("📱 Created Group: \(response.group.groupName)")
        return response.group
    }
}
