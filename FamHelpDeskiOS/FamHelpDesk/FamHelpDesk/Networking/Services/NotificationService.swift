import Foundation

final class NotificationService {
    private let networkManager: NetworkManager

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    /// Fetches notifications for the current user
    /// - Parameters:
    ///   - limit: Maximum number of notifications to fetch
    ///   - viewed: Filter by viewed status (nil for all)
    ///   - nextToken: Token for pagination
    /// - Returns: NotificationResponse containing notifications and pagination info
    /// - Throws: NetworkError if the request fails
    func getNotifications(limit: Int = 20, viewed: Bool? = nil, nextToken: String? = nil) async throws -> NotificationResponse {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        if let viewed = viewed {
            queryItems.append(URLQueryItem(name: "viewed", value: String(viewed)))
        }
        
        if let nextToken = nextToken {
            queryItems.append(URLQueryItem(name: "nextToken", value: nextToken))
        }
        
        let response: NotificationResponse = try await networkManager.get(
            endpoint: APIEndpoint.getNotifications.path,
            queryItems: queryItems
        )
        print("📱 Notifications Response: \(response.notifications.count) notifications")
        return response
    }

    /// Acknowledges a specific notification
    /// - Parameter notificationId: The ID of the notification to acknowledge
    /// - Returns: AcknowledgeResponse indicating success
    /// - Throws: NetworkError if the request fails
    func acknowledgeNotification(notificationId: String) async throws -> AcknowledgeResponse {
        let request = AcknowledgeNotificationRequest(notificationId: notificationId)
        let response: AcknowledgeResponse = try await networkManager.post(
            endpoint: APIEndpoint.acknowledgeNotification(notificationId: notificationId).path,
            body: request
        )
        print("📱 Acknowledged notification: \(notificationId)")
        return response
    }

    /// Acknowledges all notifications for the current user
    /// - Returns: AcknowledgeResponse indicating success
    /// - Throws: NetworkError if the request fails
    func acknowledgeAllNotifications() async throws -> AcknowledgeResponse {
        let response: AcknowledgeResponse = try await networkManager.post(
            endpoint: APIEndpoint.acknowledgeAllNotifications.path,
            body: EmptyRequest()
        )
        print("📱 Acknowledged all notifications")
        return response
    }

    /// Gets the unread notification count for the current user
    /// - Returns: UnreadCountResponse containing the count
    /// - Throws: NetworkError if the request fails
    func getUnreadCount() async throws -> UnreadCountResponse {
        let response: UnreadCountResponse = try await networkManager.get(
            endpoint: APIEndpoint.getUnreadCount.path
        )
        print("📱 Unread count: \(response.unreadCount)")
        return response
    }
}

// MARK: - Helper Models

private struct EmptyRequest: Codable {}