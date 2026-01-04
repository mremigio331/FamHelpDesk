import Foundation

// MARK: - Notification Models

struct Notification: Codable, Identifiable {
    let notificationId: String
    let userId: String
    let type: NotificationType
    let title: String
    let message: String
    let data: NotificationData?
    let viewed: Bool
    let createdAt: String
    
    var id: String { notificationId }
}

enum NotificationType: String, Codable {
    case membershipRequest = "membership_request"
    case membershipApproved = "membership_approved"
    case membershipRejected = "membership_rejected"
    case groupInvitation = "group_invitation"
    case familyUpdate = "family_update"
}

struct NotificationData: Codable {
    let familyId: String?
    let groupId: String?
    let requestId: String?
}

// MARK: - Notification Response Models

struct NotificationResponse: Codable {
    let notifications: [Notification]
    let nextToken: String?
    let hasMore: Bool
}

struct UnreadCountResponse: Codable {
    let unreadCount: Int
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