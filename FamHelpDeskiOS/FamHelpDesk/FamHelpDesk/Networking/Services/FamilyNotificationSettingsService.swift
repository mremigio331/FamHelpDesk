import Foundation

final class FamilyNotificationSettingsService {
    private let networkManager: NetworkManager

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    /// Fetches family notification settings for the current user for a specific family
    /// - Parameter familyId: The ID of the family to fetch settings for
    /// - Returns: FamilyNotificationSettings object
    /// - Throws: ServiceError with structured error information
    func getFamilyNotificationSettings(familyId: String) async throws -> FamilyNotificationSettings {
        do {
            let response: FamilyNotificationSettingsResponse = try await networkManager.get(
                endpoint: APIEndpoint.getFamilyNotificationSettings(familyId: familyId).path
            )
            print("📱 Family Notification Settings Response for family \(familyId)")
            return response.settings
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching family notification settings: \(serviceError)")
            throw serviceError
        }
    }

    /// Updates family notification settings for the current user for a specific family
    /// - Parameters:
    ///   - familyId: The ID of the family to update settings for
    ///   - settings: Dictionary of setting keys and boolean values to update
    /// - Returns: Updated FamilyNotificationSettings object
    /// - Throws: ServiceError with structured error information
    func updateFamilyNotificationSettings(
        familyId: String,
        settings: [String: Bool]
    ) async throws -> FamilyNotificationSettings {
        do {
            // Convert dictionary to UpdateFamilyNotificationSettingsRequest
            let request = createUpdateRequest(from: settings)

            let response: FamilyNotificationSettingsResponse = try await networkManager.put(
                endpoint: APIEndpoint.updateFamilyNotificationSettings(familyId: familyId).path,
                body: request
            )
            print("📱 Updated Family Notification Settings for family \(familyId)")
            return response.settings
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error updating family notification settings: \(serviceError)")
            throw serviceError
        }
    }

    // MARK: - Private Helper Methods

    /// Creates an UpdateFamilyNotificationSettingsRequest from a dictionary of settings
    /// - Parameter settings: Dictionary of setting keys and boolean values
    /// - Returns: UpdateFamilyNotificationSettingsRequest with appropriate fields set
    private func createUpdateRequest(from settings: [String: Bool]) -> UpdateFamilyNotificationSettingsRequest {
        UpdateFamilyNotificationSettingsRequest(
            // Family
            newFamilyCreationEnabled: settings["new_family_creation_enabled"],
            welcomeEnabled: settings["welcome_enabled"],

            // Family Membership
            welcomeToFamilyEnabled: settings["welcome_to_family_enabled"],
            newFamilyMemberEnabled: settings["new_family_member_enabled"],
            familyMembershipApproved: settings["family_membership_approved"],
            familyMembershipDenied: settings["family_membership_denied"],
            familyMembershipInvitation: settings["family_membership_invitation"],
            familyMembershipJoined: settings["family_membership_joined"],
            familyMembershipLeft: settings["family_membership_left"],
            familyMembershipRequest: settings["family_membership_request"],

            // Group Membership
            groupMembershipApproved: settings["group_membership_approved"],
            groupMembershipDenied: settings["group_membership_denied"],
            groupMembershipAdded: settings["group_membership_added"],
            groupMembershipJoined: settings["group_membership_joined"],
            groupMembershipLeft: settings["group_membership_left"],
            groupMembershipRequest: settings["group_membership_request"],
            newGroupCreation: settings["new_group_creation"],

            // Tickets
            ticketCreationFamily: settings["ticket_creation_family"],
            ticketCreationGroup: settings["ticket_creation_group"],
            ticketAssigned: settings["ticket_assigned"],
            ticketComment: settings["ticket_comment"],
            ticketStatusChange: settings["ticket_status_change"],
            ticketResolved: settings["ticket_resolved"]
        )
    }
}
