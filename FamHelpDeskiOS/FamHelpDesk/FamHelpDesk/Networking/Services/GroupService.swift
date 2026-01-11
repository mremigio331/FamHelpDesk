import Foundation

final class GroupService {
    private let networkManager: NetworkManager
    private let retryHelper = RetryHelper()

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    /// Fetches all groups in a family with enhanced error handling
    /// - Parameter familyId: The ID of the family
    /// - Returns: Array of Group objects
    /// - Throws: ServiceError with structured error information
    func getAllGroups(familyId: String) async throws -> [FamilyGroup] {
        do {
            // Use custom decoder without convertFromSnakeCase since we have manual CodingKeys
            let rawData = try await networkManager.getRawData(
                endpoint: APIEndpoint.getAllGroups(familyId: familyId).path
            )

            let decoder = JSONDecoder()
            let response = try decoder.decode(GetAllGroupsResponse.self, from: rawData)

            print("📱 All Groups Response: \(response.groups.count) groups")
            return response.groups
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching all groups: \(serviceError)")
            throw serviceError
        }
    }

    /// Fetches groups for the current user with enhanced error handling
    /// - Returns: Dictionary of group items keyed by group ID
    /// - Throws: ServiceError with structured error information
    func getMyGroups() async throws -> [String: MyGroupItem] {
        do {
            let response: GetMyGroupsResponse = try await networkManager.get(
                endpoint: APIEndpoint.getMyGroups.path
            )
            print("📱 My Groups Response: \(response.groups.count) groups")
            return response.groups
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching my groups: \(serviceError)")
            throw serviceError
        }
    }

    /// Creates a new group with enhanced validation and error handling
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - name: The name of the group
    ///   - description: Optional description
    /// - Returns: The created Group object
    /// - Throws: ServiceError for validation errors or network failures
    func createGroup(familyId: String, name: String, description: String?) async throws -> FamilyGroup {
        // Validate group name requirements
        try validateGroupInput(name: name, description: description)

        do {
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
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error creating group: \(serviceError)")
            throw serviceError
        }
    }

    /// Updates an existing group with enhanced validation and error handling
    /// - Parameters:
    ///   - groupId: The ID of the group to update
    ///   - name: The new name of the group (optional)
    ///   - description: The new description (optional)
    /// - Returns: The updated Group object
    /// - Throws: ServiceError for validation errors or network failures
    func updateGroup(groupId: String, name: String?, description: String?) async throws -> FamilyGroup {
        // Validate group input if provided
        if let name = name {
            try validateGroupInput(name: name, description: description)
        } else if let description = description {
            try validateGroupInput(name: "temp", description: description) // Just validate description
        }

        do {
            let request = UpdateGroupRequest(
                groupName: name,
                groupDescription: description
            )
            let response: UpdateGroupResponse = try await networkManager.put(
                endpoint: APIEndpoint.updateGroup(groupId: groupId).path,
                body: request
            )
            print("📱 Updated Group: \(response.group.groupName)")
            return response.group
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error updating group: \(serviceError)")
            throw serviceError
        }
    }

    /// Deletes a group with proper error handling
    /// - Parameter groupId: The ID of the group to delete
    /// - Returns: Success response
    /// - Throws: ServiceError for network failures or business logic errors
    func deleteGroup(groupId: String) async throws -> DeleteGroupResponse {
        do {
            let response: DeleteGroupResponse = try await networkManager.delete(
                endpoint: APIEndpoint.deleteGroup(groupId: groupId).path
            )
            print("📱 Deleted Group: \(groupId)")
            return response
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error deleting group: \(serviceError)")
            throw serviceError
        }
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

    // MARK: - Group Membership Management

    /// Fetches group members with enhanced error handling
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    /// - Returns: Array of GroupMember objects
    /// - Throws: ServiceError with structured error information
    func getGroupMembers(familyId: String, groupId: String) async throws -> [GroupMember] {
        do {
            let response: GetGroupMembersResponse = try await networkManager.get(
                endpoint: APIEndpoint.getGroupMembers(familyId: familyId, groupId: groupId).path
            )
            print("📱 Group Members Response: \(response.members.count) members")
            return response.members
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching group members: \(serviceError)")
            throw serviceError
        }
    }

    /// Requests group membership with enhanced error handling
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    /// - Returns: Success response
    /// - Throws: ServiceError for network failures or business logic errors
    func requestGroupMembership(familyId: String, groupId: String) async throws -> GroupMembershipResponse {
        do {
            let request = GroupMembershipRequest(familyId: familyId, groupId: groupId)
            let response: GroupMembershipResponse = try await networkManager.post(
                endpoint: APIEndpoint.requestGroupMembership(familyId: familyId, groupId: groupId).path,
                body: request
            )
            print("📱 Requested Group Membership: \(groupId)")
            return response
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error requesting group membership: \(serviceError)")
            throw serviceError
        }
    }

    /// Adds a group member with enhanced error handling
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    ///   - userId: The ID of the user to add
    ///   - isAdmin: Whether the user should be an admin
    /// - Returns: Success response
    /// - Throws: ServiceError for network failures or business logic errors
    func addGroupMember(familyId: String, groupId: String, userId: String, isAdmin: Bool = false) async throws -> GroupMembershipResponse {
        do {
            let request = AddGroupMemberRequest(familyId: familyId, groupId: groupId, userId: userId, isAdmin: isAdmin)
            let response: GroupMembershipResponse = try await networkManager.post(
                endpoint: APIEndpoint.addGroupMember(familyId: familyId, groupId: groupId).path,
                body: request
            )
            print("📱 Added Group Member: \(userId) to \(groupId)")
            return response
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error adding group member: \(serviceError)")
            throw serviceError
        }
    }

    /// Removes a group member with enhanced error handling
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    ///   - userId: The ID of the user to remove
    /// - Returns: Success response
    /// - Throws: ServiceError for network failures or business logic errors
    func removeGroupMember(familyId: String, groupId: String, userId: String) async throws -> GroupMembershipResponse {
        do {
            let response: GroupMembershipResponse = try await networkManager.delete(
                endpoint: APIEndpoint.removeGroupMember(familyId: familyId, groupId: groupId, userId: userId).path
            )
            print("📱 Removed Group Member: \(userId) from \(groupId)")
            return response
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error removing group member: \(serviceError)")
            throw serviceError
        }
    }

    /// Fetches group membership requests with enhanced error handling
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    /// - Returns: Array of GroupMembershipRequest objects
    /// - Throws: ServiceError with structured error information
    func getGroupMembershipRequests(familyId: String, groupId: String) async throws -> [GroupMembershipRequestItem] {
        do {
            let response: GetGroupMembershipRequestsResponse = try await networkManager.get(
                endpoint: APIEndpoint.getGroupMembershipRequests(familyId: familyId, groupId: groupId).path
            )
            print("📱 Group Membership Requests Response: \(response.requests.count) requests")
            return response.requests
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching group membership requests: \(serviceError)")
            throw serviceError
        }
    }

    /// Updates a group member's role with enhanced error handling
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    ///   - userId: The ID of the user
    ///   - isAdmin: Whether the user should be an admin
    /// - Returns: Success response
    /// - Throws: ServiceError for network failures or business logic errors
    func updateGroupMemberRole(familyId: String, groupId: String, userId: String, isAdmin: Bool) async throws -> GroupMembershipResponse {
        do {
            let request = UpdateGroupMemberRoleRequest(isAdmin: isAdmin)
            let response: GroupMembershipResponse = try await networkManager.put(
                endpoint: APIEndpoint.updateGroupMemberRole(familyId: familyId, groupId: groupId, userId: userId).path,
                body: request
            )
            print("📱 Updated Group Member Role: \(userId) in \(groupId)")
            return response
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error updating group member role: \(serviceError)")
            throw serviceError
        }
    }

    /// Fetches group members with roles with enhanced error handling
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    /// - Returns: Array of GroupMemberWithRole objects
    /// - Throws: ServiceError with structured error information
    func getGroupMembersWithRoles(familyId: String, groupId: String) async throws -> [GroupMemberWithRole] {
        do {
            let response: GetGroupMembersWithRolesResponse = try await networkManager.get(
                endpoint: APIEndpoint.getGroupMembersWithRoles(familyId: familyId, groupId: groupId).path
            )
            print("📱 Group Members With Roles Response: \(response.members.count) members")
            return response.members
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching group members with roles: \(serviceError)")
            throw serviceError
        }
    }
}
