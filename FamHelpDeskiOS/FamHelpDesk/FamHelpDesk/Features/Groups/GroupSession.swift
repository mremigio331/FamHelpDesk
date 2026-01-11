import Foundation

@Observable
final class GroupSession {
    static let shared = GroupSession()

    private let groupService = GroupService()

    var myGroups: [String: MyGroupItem] = [:]
    var familyGroups: [String: [FamilyGroup]] = [:]
    var isFetching = false
    var errorMessage: String?

    private init() {}

    /// Fetches groups for the current user across all families
    /// - Requirements: 2.5 - Support viewing user's groups across all families
    @MainActor
    func fetchMyGroups() async {
        isFetching = true
        errorMessage = nil

        do {
            myGroups = try await groupService.getMyGroups()
            print("✅ Fetched \(myGroups.count) user groups")
        } catch {
            errorMessage = "Failed to load your groups: \(error.localizedDescription)"
            print("❌ Error fetching user groups: \(error)")
        }

        isFetching = false
    }

    /// Fetches all groups within a specific family
    /// - Parameter familyId: The ID of the family
    /// - Requirements: 2.1 - Display all groups within a family
    @MainActor
    func fetchFamilyGroups(familyId: String) async {
        isFetching = true
        errorMessage = nil

        do {
            let groups = try await groupService.getAllGroups(familyId: familyId)
            familyGroups[familyId] = groups
            print("✅ Fetched \(groups.count) groups for family \(familyId)")
        } catch {
            errorMessage = "Failed to load family groups: \(error.localizedDescription)"
            print("❌ Error fetching family groups: \(error)")
        }

        isFetching = false
    }

    /// Creates a new group and updates local state
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - name: The name of the group
    ///   - description: Optional description
    /// - Returns: The created FamilyGroup if successful, nil otherwise
    /// - Requirements: 2.2 - Allow creating new groups with appropriate permissions
    @MainActor
    func createGroup(familyId: String, name: String, description: String?) async -> FamilyGroup? {
        isFetching = true
        errorMessage = nil

        do {
            let newGroup = try await groupService.createGroup(
                familyId: familyId,
                name: name,
                description: description
            )

            // Update local state - add the new group to family groups
            if familyGroups[familyId] != nil {
                familyGroups[familyId]?.append(newGroup)
            } else {
                familyGroups[familyId] = [newGroup]
            }

            print("✅ Created group: \(newGroup.groupName)")
            isFetching = false
            return newGroup

        } catch {
            if let validationError = error as? ValidationError {
                errorMessage = validationError.localizedDescription
            } else {
                errorMessage = "Failed to create group: \(error.localizedDescription)"
            }
            print("❌ Error creating group: \(error)")
            isFetching = false
            return nil
        }
    }

    /// Gets groups for a specific family from local cache
    /// - Parameter familyId: The ID of the family
    /// - Returns: Array of FamilyGroup objects for the family
    func getGroupsForFamily(_ familyId: String) -> [FamilyGroup] {
        familyGroups[familyId] ?? []
    }

    /// Gets user's groups as an array sorted by group name
    /// - Returns: Array of MyGroupItem objects sorted by group name
    func getMyGroupsArray() -> [MyGroupItem] {
        Array(myGroups.values).sorted { $0.group.groupName < $1.group.groupName }
    }

    /// Refreshes all group data
    @MainActor
    func refresh() async {
        await fetchMyGroups()
    }

    /// Refreshes groups for a specific family
    /// - Parameter familyId: The ID of the family to refresh
    @MainActor
    func refreshFamilyGroups(familyId: String) async {
        await fetchFamilyGroups(familyId: familyId)
    }

    /// Updates an existing group and updates local state
    /// - Parameters:
    ///   - groupId: The ID of the group to update
    ///   - name: The new name of the group (optional)
    ///   - description: The new description (optional)
    /// - Returns: The updated FamilyGroup if successful, nil otherwise
    /// - Requirements: 2.2 - Allow updating groups with appropriate permissions
    @MainActor
    func updateGroup(groupId: String, name: String?, description: String?) async -> FamilyGroup? {
        isFetching = true
        errorMessage = nil

        do {
            let updatedGroup = try await groupService.updateGroup(
                groupId: groupId,
                name: name,
                description: description
            )

            // Update local state - find and replace the group in all relevant caches
            updateGroupInLocalState(updatedGroup)

            print("✅ Updated group: \(updatedGroup.groupName)")
            isFetching = false
            return updatedGroup

        } catch {
            if let validationError = error as? ValidationError {
                errorMessage = validationError.localizedDescription
            } else {
                errorMessage = "Failed to update group: \(error.localizedDescription)"
            }
            print("❌ Error updating group: \(error)")
            isFetching = false
            return nil
        }
    }

    /// Deletes a group and updates local state
    /// - Parameter groupId: The ID of the group to delete
    /// - Returns: True if successful, false otherwise
    /// - Requirements: 2.2 - Allow deleting groups with appropriate permissions
    @MainActor
    func deleteGroup(groupId: String) async -> Bool {
        isFetching = true
        errorMessage = nil

        do {
            _ = try await groupService.deleteGroup(groupId: groupId)

            // Update local state - remove the group from all caches
            removeGroupFromLocalState(groupId)

            print("✅ Deleted group: \(groupId)")
            isFetching = false
            return true

        } catch {
            errorMessage = "Failed to delete group: \(error.localizedDescription)"
            print("❌ Error deleting group: \(error)")
            isFetching = false
            return false
        }
    }

    /// Fetches group members for a specific group
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    /// - Returns: Array of GroupMember objects if successful, empty array otherwise
    /// - Requirements: 2.1 - Display group membership information
    @MainActor
    func fetchGroupMembers(familyId: String, groupId: String) async -> [GroupMember] {
        isFetching = true
        errorMessage = nil

        do {
            let members = try await groupService.getGroupMembers(familyId: familyId, groupId: groupId)
            print("✅ Fetched \(members.count) members for group \(groupId)")
            isFetching = false
            return members
        } catch {
            errorMessage = "Failed to load group members: \(error.localizedDescription)"
            print("❌ Error fetching group members: \(error)")
            isFetching = false
            return []
        }
    }

    /// Requests membership for a group
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    /// - Returns: True if successful, false otherwise
    /// - Requirements: 2.2 - Allow requesting group membership
    @MainActor
    func requestGroupMembership(familyId: String, groupId: String) async -> Bool {
        isFetching = true
        errorMessage = nil

        do {
            _ = try await groupService.requestGroupMembership(familyId: familyId, groupId: groupId)
            print("✅ Requested membership for group \(groupId)")
            isFetching = false
            return true
        } catch {
            errorMessage = "Failed to request group membership: \(error.localizedDescription)"
            print("❌ Error requesting group membership: \(error)")
            isFetching = false
            return false
        }
    }

    /// Adds a member to a group
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    ///   - userId: The ID of the user to add
    ///   - isAdmin: Whether the user should be an admin
    /// - Returns: True if successful, false otherwise
    /// - Requirements: 2.2 - Allow adding group members with appropriate permissions
    @MainActor
    func addGroupMember(familyId: String, groupId: String, userId: String, isAdmin: Bool = false) async -> Bool {
        isFetching = true
        errorMessage = nil

        do {
            _ = try await groupService.addGroupMember(familyId: familyId, groupId: groupId, userId: userId, isAdmin: isAdmin)
            print("✅ Added member \(userId) to group \(groupId)")
            isFetching = false
            return true
        } catch {
            errorMessage = "Failed to add group member: \(error.localizedDescription)"
            print("❌ Error adding group member: \(error)")
            isFetching = false
            return false
        }
    }

    /// Removes a member from a group
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    ///   - userId: The ID of the user to remove
    /// - Returns: True if successful, false otherwise
    /// - Requirements: 2.2 - Allow removing group members with appropriate permissions
    @MainActor
    func removeGroupMember(familyId: String, groupId: String, userId: String) async -> Bool {
        isFetching = true
        errorMessage = nil

        do {
            _ = try await groupService.removeGroupMember(familyId: familyId, groupId: groupId, userId: userId)
            print("✅ Removed member \(userId) from group \(groupId)")
            isFetching = false
            return true
        } catch {
            errorMessage = "Failed to remove group member: \(error.localizedDescription)"
            print("❌ Error removing group member: \(error)")
            isFetching = false
            return false
        }
    }

    /// Fetches group membership requests for a specific group
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    /// - Returns: Array of GroupMembershipRequestItem objects if successful, empty array otherwise
    /// - Requirements: 2.1 - Display group membership requests for admins
    @MainActor
    func fetchGroupMembershipRequests(familyId: String, groupId: String) async -> [GroupMembershipRequestItem] {
        isFetching = true
        errorMessage = nil

        do {
            let requests = try await groupService.getGroupMembershipRequests(familyId: familyId, groupId: groupId)
            print("✅ Fetched \(requests.count) membership requests for group \(groupId)")
            isFetching = false
            return requests
        } catch {
            errorMessage = "Failed to load membership requests: \(error.localizedDescription)"
            print("❌ Error fetching membership requests: \(error)")
            isFetching = false
            return []
        }
    }

    /// Updates a group member's role
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    ///   - userId: The ID of the user
    ///   - isAdmin: Whether the user should be an admin
    /// - Returns: True if successful, false otherwise
    /// - Requirements: 2.2 - Allow updating member roles with appropriate permissions
    @MainActor
    func updateGroupMemberRole(familyId: String, groupId: String, userId: String, isAdmin: Bool) async -> Bool {
        isFetching = true
        errorMessage = nil

        do {
            _ = try await groupService.updateGroupMemberRole(familyId: familyId, groupId: groupId, userId: userId, isAdmin: isAdmin)
            print("✅ Updated role for member \(userId) in group \(groupId)")
            isFetching = false
            return true
        } catch {
            errorMessage = "Failed to update member role: \(error.localizedDescription)"
            print("❌ Error updating member role: \(error)")
            isFetching = false
            return false
        }
    }

    /// Fetches group members with their roles
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    /// - Returns: Array of GroupMemberWithRole objects if successful, empty array otherwise
    /// - Requirements: 2.1 - Display group members with their roles
    @MainActor
    func fetchGroupMembersWithRoles(familyId: String, groupId: String) async -> [GroupMemberWithRole] {
        isFetching = true
        errorMessage = nil

        do {
            let members = try await groupService.getGroupMembersWithRoles(familyId: familyId, groupId: groupId)
            print("✅ Fetched \(members.count) members with roles for group \(groupId)")
            isFetching = false
            return members
        } catch {
            errorMessage = "Failed to load group members with roles: \(error.localizedDescription)"
            print("❌ Error fetching group members with roles: \(error)")
            isFetching = false
            return []
        }
    }

    // MARK: - Private Helper Methods

    /// Updates a group in all local state caches
    /// - Parameter updatedGroup: The updated group to replace in caches
    private func updateGroupInLocalState(_ updatedGroup: FamilyGroup) {
        // Update in familyGroups cache
        for (familyId, groups) in familyGroups {
            if let index = groups.firstIndex(where: { $0.groupId == updatedGroup.groupId }) {
                familyGroups[familyId]?[index] = updatedGroup
            }
        }

        // Update in myGroups cache if present
        if let myGroupItem = myGroups[updatedGroup.groupId] {
            myGroups[updatedGroup.groupId] = MyGroupItem(
                group: updatedGroup,
                membership: myGroupItem.membership
            )
        }
    }

    /// Removes a group from all local state caches
    /// - Parameter groupId: The ID of the group to remove
    private func removeGroupFromLocalState(_ groupId: String) {
        // Remove from familyGroups cache
        for (familyId, groups) in familyGroups {
            familyGroups[familyId] = groups.filter { $0.groupId != groupId }
        }

        // Remove from myGroups cache
        myGroups.removeValue(forKey: groupId)
    }

    /// Clears error message
    func clearError() {
        errorMessage = nil
    }
}
