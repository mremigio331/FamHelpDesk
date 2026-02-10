import Foundation

// MARK: - Notification Models

struct Notification: Codable, Identifiable {
    let notificationId: String
    let userId: String
    let notificationType: String
    let message: String
    let timestamp: Int
    let viewed: Bool
    let familyId: String?
    let ticketId: String?

    var id: String { notificationId }

    // Computed properties for UI
    var type: NotificationType {
        NotificationType(rawValue: notificationType) ?? .unknown
    }

    var title: String {
        type.displayName
    }

    var createdAt: String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    // Custom coding keys to match backend API
    enum CodingKeys: String, CodingKey {
        case notificationId = "notification_id"
        case userId = "user_id"
        case notificationType = "notification_type"
        case message
        case timestamp
        case viewed
        case familyId = "family_id"
        case ticketId = "ticket_id"
    }
}

enum NotificationType: String, Codable, CaseIterable {
    // Welcome
    case welcome = "Welcome"

    // Family
    case newFamilyCreation = "New Family Created"

    // Family Membership
    case familyMembershipApproved = "Family Membership Approved"
    case familyMembershipDenied = "Family Membership Denied"
    case familyMembershipInvitation = "Family Membership Invitation"
    case familyMemberJoined = "Family Membership Accepted"
    case familyMembershipLeft = "Family Member left"
    case familyMembershipRequest = "Family Membership Request"
    case newFamilyMember = "New Family Member"
    case welcomeToFamily = "Welcome to Family"

    // Group Membership
    case groupMembershipApproved = "Group Membership Approved"
    case groupMembershipDenied = "Group Membership Denied"
    case groupMembershipAdded = "Group Membership Added"
    case groupMemberJoined = "Group Membership Accepted"
    case groupMembershipLeft = "Group Member left"
    case groupMembershipRequest = "Group Membership Request"
    case newGroupCreation = "New Group Creation"

    // Tickets
    case ticketCreationFamily = "Family Ticket Creation"
    case ticketCreationGroup = "Group Ticket Creation"
    case ticketAssigned = "Ticket Assigned"
    case ticketComment = "Ticket Comment"
    case ticketStatusChanged = "Ticket Status Changed"
    case ticketResolved = "Ticket Resolved"

    case unknown = "Unknown"
}

// MARK: - Notification Response Models

struct NotificationResponse: Codable {
    let notifications: [Notification]
    let count: Int
    let nextToken: String?

    // Computed property for compatibility
    var hasMore: Bool {
        nextToken != nil
    }

    enum CodingKeys: String, CodingKey {
        case notifications
        case count
        case nextToken = "next_token"
    }
}

struct UnreadCountResponse: Codable {
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case unreadCount = "unread_count"
    }
}

struct AcknowledgeResponse: Codable {
    let success: Bool
    let message: String?
}

// MARK: - Notification Request Models

struct GetNotificationsRequest: Codable {
    let limit: Int?
    let viewed: Bool?
    let nextToken: String?
}

struct AcknowledgeNotificationRequest: Codable {
    let notificationId: String
}
