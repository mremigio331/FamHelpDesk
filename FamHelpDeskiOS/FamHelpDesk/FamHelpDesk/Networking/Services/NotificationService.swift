import Foundation

/// Service for fetching and managing in-app notifications
/// Note: This is separate from NotificationSettingsService which handles notification preferences
final class NotificationService {
    static let shared = NotificationService()

    private let networkManager = NetworkManager.shared

    private init() {}

    // TODO: Implement these methods when notification fetching is added
    func getNotifications(limit: Int, viewed _: Bool?, nextToken: String?) async throws -> NotificationListResponse {
        // Build query parameters
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        if let nextToken {
            queryItems.append(URLQueryItem(name: "next_token", value: nextToken))
        }

        // Note: The backend endpoint doesn't support filtering by viewed status yet
        // This parameter is kept for future compatibility

        print("📱 [NotificationService] Fetching notifications (limit: \(limit))")

        // Make API request
        let response: NotificationAPIResponse = try await networkManager.get(
            endpoint: APIEndpoint.getNotifications.path,
            queryItems: queryItems
        )

        print("✅ [NotificationService] Fetched \(response.count) notifications")

        return NotificationListResponse(
            notifications: response.notifications,
            nextToken: response.nextToken,
            hasMore: response.nextToken != nil
        )
    }

    func acknowledgeNotification(notificationId: String) async throws -> AcknowledgeResponse {
        print("📱 [NotificationService] Acknowledging notification: \(notificationId)")

        // Make API request - PUT /notifications/{notification_id}/acknowledge
        // Create empty request body
        struct EmptyRequest: Codable {}

        let response: AcknowledgeAPIResponse = try await networkManager.put(
            endpoint: APIEndpoint.acknowledgeNotification(notificationId: notificationId).path,
            body: EmptyRequest()
        )

        print("✅ [NotificationService] Notification acknowledged: \(response.message)")

        return AcknowledgeResponse(
            success: true,
            message: response.message
        )
    }

    func acknowledgeAllNotifications() async throws -> AcknowledgeResponse {
        print("📱 [NotificationService] Acknowledging all notifications")

        // Make API request - PUT /notifications/acknowledge-all
        // Create empty request body
        struct EmptyRequest: Codable {}

        let response: AcknowledgeAllAPIResponse = try await networkManager.put(
            endpoint: APIEndpoint.acknowledgeAllNotifications.path,
            body: EmptyRequest()
        )

        print("✅ [NotificationService] Acknowledged \(response.acknowledgedCount) notifications")

        return AcknowledgeResponse(
            success: true,
            message: response.message
        )
    }
}

// MARK: - Response Models (Stubs)

struct NotificationListResponse: Codable {
    let notifications: [Notification]
    let nextToken: String?
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case notifications
        case nextToken = "next_token"
        case hasMore = "has_more"
    }
}

// MARK: - API Response Models

struct NotificationAPIResponse: Codable {
    let notifications: [Notification]
    let count: Int
    let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case notifications
        case count
        case nextToken = "next_token"
    }
}

struct AcknowledgeAPIResponse: Codable {
    let message: String
    let notificationId: String

    enum CodingKeys: String, CodingKey {
        case message
        case notificationId = "notification_id"
    }
}

struct AcknowledgeAllAPIResponse: Codable {
    let message: String
    let acknowledgedCount: Int

    enum CodingKeys: String, CodingKey {
        case message
        case acknowledgedCount = "acknowledged_count"
    }
}
