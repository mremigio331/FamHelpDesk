import Combine
import Foundation
import SwiftUI

@MainActor
final class NotificationSettingsViewModel: ObservableObject {
    @Published var welcomeEnabled = true
    @Published var membershipEnabled = true
    @Published var ticketCreationEnabled = true
    @Published var ticketAssignedEnabled = true
    @Published var ticketCommentEnabled = false
    @Published var ticketStatusChangedEnabled = false
    @Published var groupInvitationEnabled = false

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let notificationSettingsService = NotificationSettingsService.shared

    func loadSettings() async {
        isLoading = true
        errorMessage = nil

        do {
            let settings = try await notificationSettingsService.getNotificationSettings()

            // Update published properties
            welcomeEnabled = settings.welcomeEnabled
            membershipEnabled = settings.membershipEnabled
            ticketCreationEnabled = settings.ticketCreationEnabled
            ticketAssignedEnabled = settings.ticketAssignedEnabled
            ticketCommentEnabled = settings.ticketCommentEnabled
            ticketStatusChangedEnabled = settings.ticketStatusChangedEnabled
            groupInvitationEnabled = settings.groupInvitationEnabled

            isLoading = false
        } catch {
            errorMessage = "Failed to load notification settings: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func saveSettings() async {
        do {
            let updatedSettings = try await notificationSettingsService.updateNotificationSettings(
                welcomeEnabled: welcomeEnabled,
                membershipEnabled: membershipEnabled,
                ticketCreationEnabled: ticketCreationEnabled,
                ticketAssignedEnabled: ticketAssignedEnabled,
                ticketCommentEnabled: ticketCommentEnabled,
                ticketStatusChangedEnabled: ticketStatusChangedEnabled,
                groupInvitationEnabled: groupInvitationEnabled
            )

            // Update with server response to ensure consistency
            welcomeEnabled = updatedSettings.welcomeEnabled
            membershipEnabled = updatedSettings.membershipEnabled
            ticketCreationEnabled = updatedSettings.ticketCreationEnabled
            ticketAssignedEnabled = updatedSettings.ticketAssignedEnabled
            ticketCommentEnabled = updatedSettings.ticketCommentEnabled
            ticketStatusChangedEnabled = updatedSettings.ticketStatusChangedEnabled
            groupInvitationEnabled = updatedSettings.groupInvitationEnabled

            errorMessage = nil
        } catch {
            errorMessage = "Failed to save notification settings: \(error.localizedDescription)"
        }
    }
}
