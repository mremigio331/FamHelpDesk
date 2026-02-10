import Foundation

final class NotificationSettingsService {
    static let shared = NotificationSettingsService()

    private let networkManager = NetworkManager.shared

    private init() {}

    func getNotificationSettings() async throws -> NotificationSettings {
        let response: NotificationSettingsResponse = try await networkManager.get(
            endpoint: APIEndpoint.getNotificationSettings.path
        )
        return response.settings
    }

    func updateNotificationSettings(
        welcomeEnabled: Bool? = nil,
        membershipEnabled: Bool? = nil,
        ticketCreationEnabled: Bool? = nil,
        ticketAssignedEnabled: Bool? = nil,
        ticketCommentEnabled: Bool? = nil,
        ticketStatusChangedEnabled: Bool? = nil,
        groupInvitationEnabled: Bool? = nil
    ) async throws -> NotificationSettings {
        let request = UpdateNotificationSettingsRequest(
            welcomeEnabled: welcomeEnabled,
            membershipEnabled: membershipEnabled,
            ticketCreationEnabled: ticketCreationEnabled,
            ticketAssignedEnabled: ticketAssignedEnabled,
            ticketCommentEnabled: ticketCommentEnabled,
            ticketStatusChangedEnabled: ticketStatusChangedEnabled,
            groupInvitationEnabled: groupInvitationEnabled
        )

        let response: NotificationSettingsResponse = try await networkManager.put(
            endpoint: APIEndpoint.updateNotificationSettings.path,
            body: request
        )
        return response.settings
    }
}
