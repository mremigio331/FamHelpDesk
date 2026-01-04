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
    case welcome = "Welcome"
    case welcomeToFamily = "Welcome to Family"
    case membershipRequest = "Membership Request"
    case membershipApproved = "Membership Approved"
    case membershipDenied = "Membership Denied"
    case ticketAssigned = "Ticket Assigned"
    case ticketComment = "Ticket Comment"
    case ticketStatusChanged = "Ticket Status Changed"
    case groupInvitation = "Group Invitation"
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
