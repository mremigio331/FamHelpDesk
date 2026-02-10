import Foundation

struct NotificationSettingsResponse: Codable {
    let settings: NotificationSettings
}

struct NotificationSettings: Codable {
    let userId: String
    let welcomeEnabled: Bool
    let membershipEnabled: Bool
    let ticketCreationEnabled: Bool
    let ticketAssignedEnabled: Bool
    let ticketCommentEnabled: Bool
    let ticketStatusChangedEnabled: Bool
    let groupInvitationEnabled: Bool
    let createdDate: Int
    let lastUpdated: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case welcomeEnabled = "welcome_enabled"
        case membershipEnabled = "membership_enabled"
        case ticketCreationEnabled = "ticket_creation_enabled"
        case ticketAssignedEnabled = "ticket_assigned_enabled"
        case ticketCommentEnabled = "ticket_comment_enabled"
        case ticketStatusChangedEnabled = "ticket_status_changed_enabled"
        case groupInvitationEnabled = "group_invitation_enabled"
        case createdDate = "created_date"
        case lastUpdated = "last_updated"
    }
}

struct UpdateNotificationSettingsRequest: Codable {
    let welcomeEnabled: Bool?
    let membershipEnabled: Bool?
    let ticketCreationEnabled: Bool?
    let ticketAssignedEnabled: Bool?
    let ticketCommentEnabled: Bool?
    let ticketStatusChangedEnabled: Bool?
    let groupInvitationEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case welcomeEnabled = "welcome_enabled"
        case membershipEnabled = "membership_enabled"
        case ticketCreationEnabled = "ticket_creation_enabled"
        case ticketAssignedEnabled = "ticket_assigned_enabled"
        case ticketCommentEnabled = "ticket_comment_enabled"
        case ticketStatusChangedEnabled = "ticket_status_changed_enabled"
        case groupInvitationEnabled = "group_invitation_enabled"
    }
}
