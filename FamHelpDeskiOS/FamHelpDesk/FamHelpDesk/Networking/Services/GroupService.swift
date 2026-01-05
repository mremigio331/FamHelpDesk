import Foundation

// MARK: - Validation Error Types

enum ValidationError: Error, LocalizedError {
    case emptyGroupName
    case groupNameTooShort
    case groupNameTooLong
    case groupDescriptionTooLong

    var errorDescription: String? {
        switch self {
        case .emptyGroupName:
            "Group name cannot be empty"
        case .groupNameTooShort:
            "Group name must be at least 2 characters long"
        case .groupNameTooLong:
            "Group name cannot exceed 50 characters"
        case .groupDescriptionTooLong:
            "Group description cannot exceed 200 characters"
        }
    }
}

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
        // Use custom decoder without convertFromSnakeCase since we have manual CodingKeys
        let rawData = try await networkManager.getRawData(
            endpoint: APIEndpoint.getAllGroups(familyId: familyId).path
        )

        let decoder = JSONDecoder()
        let response = try decoder.decode(GetAllGroupsResponse.self, from: rawData)

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
    /// - Throws: NetworkError if the request fails, ValidationError for invalid inputs
    func createGroup(familyId: String, name: String, description: String?) async throws -> FamilyGroup {
        // Validate group name requirements
        try validateGroupInput(name: name, description: description)

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

    /// Validates group input according to requirements
    /// - Parameters:
    ///   - name: The group name to validate
    ///   - description: The optional description to validate
    /// - Throws: ValidationError if inputs are invalid
    private func validateGroupInput(name: String, description: String?) throws {
        // Validate group name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            throw ValidationError.emptyGroupName
        }

        if trimmedName.count < 2 {
            throw ValidationError.groupNameTooShort
        }

        if trimmedName.count > 50 {
            throw ValidationError.groupNameTooLong
        }

        // Validate description if provided
        if let description {
            let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedDescription.count > 200 {
                throw ValidationError.groupDescriptionTooLong
            }
        }
    }
}
