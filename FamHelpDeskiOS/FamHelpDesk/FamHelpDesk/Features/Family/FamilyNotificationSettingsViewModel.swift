import Combine
import Foundation
import SwiftUI

@MainActor
final class FamilyNotificationSettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    // Family
    @Published var newFamilyCreationEnabled = true
    @Published var welcomeEnabled = true

    // Family Membership
    @Published var welcomeToFamilyEnabled = true
    @Published var newFamilyMemberEnabled = true
    @Published var familyMembershipApproved = true
    @Published var familyMembershipDenied = true
    @Published var familyMembershipInvitation = true
    @Published var familyMembershipJoined = true
    @Published var familyMembershipLeft = true
    @Published var familyMembershipRequest = true

    // Group Membership
    @Published var groupMembershipApproved = true
    @Published var groupMembershipDenied = true
    @Published var groupMembershipAdded = true
    @Published var groupMembershipJoined = true
    @Published var groupMembershipLeft = true
    @Published var groupMembershipRequest = true
    @Published var newGroupCreation = true

    // Tickets
    @Published var ticketCreationFamily = true
    @Published var ticketCreationGroup = true
    @Published var ticketAssigned = true
    @Published var ticketComment = false
    @Published var ticketStatusChange = false
    @Published var ticketResolved = false

    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Properties

    var familyId: String?

    private let familyNotificationSettingsService: FamilyNotificationSettingsService
    private var originalSettings: FamilyNotificationSettings?

    // MARK: - Initialization

    init(familyNotificationSettingsService: FamilyNotificationSettingsService = FamilyNotificationSettingsService()) {
        self.familyNotificationSettingsService = familyNotificationSettingsService
    }

    // MARK: - Public Methods

    /// Load notification settings for a specific family
    /// - Parameter familyId: The ID of the family to load settings for
    func loadSettings(familyId: String) async {
        self.familyId = familyId
        isLoading = true
        errorMessage = nil

        do {
            let settings = try await familyNotificationSettingsService.getFamilyNotificationSettings(familyId: familyId)
            originalSettings = settings

            // Update published properties with loaded settings
            updatePublishedProperties(from: settings)

            isLoading = false
        } catch {
            errorMessage = "Failed to load notification settings: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Save changed notification settings to the backend
    func saveSettings() async {
        guard let familyId else {
            errorMessage = "No family ID set"
            return
        }

        // Build dictionary of only changed settings
        let changedSettings = buildChangedSettingsDictionary()

        // If nothing changed, skip the API call
        guard !changedSettings.isEmpty else {
            return
        }

        do {
            let updatedSettings = try await familyNotificationSettingsService.updateFamilyNotificationSettings(
                familyId: familyId,
                settings: changedSettings
            )

            // Update original settings to reflect server state
            originalSettings = updatedSettings

            // Update published properties with server response to ensure consistency
            updatePublishedProperties(from: updatedSettings)

            errorMessage = nil
        } catch {
            errorMessage = "Failed to save notification settings: \(error.localizedDescription)"
        }
    }

    /// Set all membership notification settings to the specified value
    /// - Parameter enabled: Whether to enable or disable all membership notifications
    func setAllMembershipNotifications(enabled: Bool) async {
        welcomeToFamilyEnabled = enabled
        newFamilyMemberEnabled = enabled
        familyMembershipApproved = enabled
        familyMembershipDenied = enabled
        familyMembershipInvitation = enabled
        familyMembershipJoined = enabled
        familyMembershipLeft = enabled
        familyMembershipRequest = enabled

        await saveSettings()
    }

    /// Set all group notification settings to the specified value
    /// - Parameter enabled: Whether to enable or disable all group notifications
    func setAllGroupNotifications(enabled: Bool) async {
        groupMembershipApproved = enabled
        groupMembershipDenied = enabled
        groupMembershipAdded = enabled
        groupMembershipJoined = enabled
        groupMembershipLeft = enabled
        groupMembershipRequest = enabled
        newGroupCreation = enabled

        await saveSettings()
    }

    /// Set all ticket notification settings to the specified value
    /// - Parameter enabled: Whether to enable or disable all ticket notifications
    func setAllTicketNotifications(enabled: Bool) async {
        ticketCreationFamily = enabled
        ticketCreationGroup = enabled
        ticketAssigned = enabled
        ticketComment = enabled
        ticketStatusChange = enabled
        ticketResolved = enabled

        await saveSettings()
    }

    // MARK: - Private Methods

    /// Update all published properties from a FamilyNotificationSettings object
    /// - Parameter settings: The settings object to read from
    private func updatePublishedProperties(from settings: FamilyNotificationSettings) {
        // Family
        newFamilyCreationEnabled = settings.newFamilyCreationEnabled
        welcomeEnabled = settings.welcomeEnabled

        // Family Membership
        welcomeToFamilyEnabled = settings.welcomeToFamilyEnabled
        newFamilyMemberEnabled = settings.newFamilyMemberEnabled
        familyMembershipApproved = settings.familyMembershipApproved
        familyMembershipDenied = settings.familyMembershipDenied
        familyMembershipInvitation = settings.familyMembershipInvitation
        familyMembershipJoined = settings.familyMembershipJoined
        familyMembershipLeft = settings.familyMembershipLeft
        familyMembershipRequest = settings.familyMembershipRequest

        // Group Membership
        groupMembershipApproved = settings.groupMembershipApproved
        groupMembershipDenied = settings.groupMembershipDenied
        groupMembershipAdded = settings.groupMembershipAdded
        groupMembershipJoined = settings.groupMembershipJoined
        groupMembershipLeft = settings.groupMembershipLeft
        groupMembershipRequest = settings.groupMembershipRequest
        newGroupCreation = settings.newGroupCreation

        // Tickets
        ticketCreationFamily = settings.ticketCreationFamily
        ticketCreationGroup = settings.ticketCreationGroup
        ticketAssigned = settings.ticketAssigned
        ticketComment = settings.ticketComment
        ticketStatusChange = settings.ticketStatusChange
        ticketResolved = settings.ticketResolved
    }

    /// Build a dictionary of only the settings that have changed from the original
    /// - Returns: Dictionary with snake_case keys and boolean values for changed settings
    private func buildChangedSettingsDictionary() -> [String: Bool] {
        guard let original = originalSettings else {
            return [:]
        }

        var changes: [String: Bool] = [:]

        // Family
        if newFamilyCreationEnabled != original.newFamilyCreationEnabled {
            changes["new_family_creation_enabled"] = newFamilyCreationEnabled
        }
        if welcomeEnabled != original.welcomeEnabled {
            changes["welcome_enabled"] = welcomeEnabled
        }

        // Family Membership
        if welcomeToFamilyEnabled != original.welcomeToFamilyEnabled {
            changes["welcome_to_family_enabled"] = welcomeToFamilyEnabled
        }
        if newFamilyMemberEnabled != original.newFamilyMemberEnabled {
            changes["new_family_member_enabled"] = newFamilyMemberEnabled
        }
        if familyMembershipApproved != original.familyMembershipApproved {
            changes["family_membership_approved"] = familyMembershipApproved
        }
        if familyMembershipDenied != original.familyMembershipDenied {
            changes["family_membership_denied"] = familyMembershipDenied
        }
        if familyMembershipInvitation != original.familyMembershipInvitation {
            changes["family_membership_invitation"] = familyMembershipInvitation
        }
        if familyMembershipJoined != original.familyMembershipJoined {
            changes["family_membership_joined"] = familyMembershipJoined
        }
        if familyMembershipLeft != original.familyMembershipLeft {
            changes["family_membership_left"] = familyMembershipLeft
        }
        if familyMembershipRequest != original.familyMembershipRequest {
            changes["family_membership_request"] = familyMembershipRequest
        }

        // Group Membership
        if groupMembershipApproved != original.groupMembershipApproved {
            changes["group_membership_approved"] = groupMembershipApproved
        }
        if groupMembershipDenied != original.groupMembershipDenied {
            changes["group_membership_denied"] = groupMembershipDenied
        }
        if groupMembershipAdded != original.groupMembershipAdded {
            changes["group_membership_added"] = groupMembershipAdded
        }
        if groupMembershipJoined != original.groupMembershipJoined {
            changes["group_membership_joined"] = groupMembershipJoined
        }
        if groupMembershipLeft != original.groupMembershipLeft {
            changes["group_membership_left"] = groupMembershipLeft
        }
        if groupMembershipRequest != original.groupMembershipRequest {
            changes["group_membership_request"] = groupMembershipRequest
        }
        if newGroupCreation != original.newGroupCreation {
            changes["new_group_creation"] = newGroupCreation
        }

        // Tickets
        if ticketCreationFamily != original.ticketCreationFamily {
            changes["ticket_creation_family"] = ticketCreationFamily
        }
        if ticketCreationGroup != original.ticketCreationGroup {
            changes["ticket_creation_group"] = ticketCreationGroup
        }
        if ticketAssigned != original.ticketAssigned {
            changes["ticket_assigned"] = ticketAssigned
        }
        if ticketComment != original.ticketComment {
            changes["ticket_comment"] = ticketComment
        }
        if ticketStatusChange != original.ticketStatusChange {
            changes["ticket_status_change"] = ticketStatusChange
        }
        if ticketResolved != original.ticketResolved {
            changes["ticket_resolved"] = ticketResolved
        }

        return changes
    }
}
