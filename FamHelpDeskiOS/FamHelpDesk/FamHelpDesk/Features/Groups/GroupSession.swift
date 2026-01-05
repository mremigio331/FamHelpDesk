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

    /// Clears error message
    func clearError() {
        errorMessage = nil
    }
}
