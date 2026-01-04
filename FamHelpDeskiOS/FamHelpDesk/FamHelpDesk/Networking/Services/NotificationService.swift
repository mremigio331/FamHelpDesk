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
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        if let viewed {
            queryItems.append(URLQueryItem(name: "viewed", value: String(viewed)))
        }

        if let nextToken {
            queryItems.append(URLQueryItem(name: "next_token", value: nextToken))
        }

        // First get the raw data to debug
        let rawData = try await networkManager.getRawData(
            endpoint: APIEndpoint.getNotifications.path,
            queryItems: queryItems
        )

        // Print the raw JSON response for debugging
        if let jsonString = String(data: rawData, encoding: .utf8) {
            print("🔍 Raw API Response JSON:")
            print(jsonString)
        }

        // Now try to decode it
        let decoder = JSONDecoder()
        // Don't use convertFromSnakeCase since we have explicit CodingKeys
        let response: NotificationResponse = try decoder.decode(NotificationResponse.self, from: rawData)
        print("📱 Notifications Response: \(response.notifications.count) notifications, next_token: \(response.nextToken ?? "nil")")
        return response
    }

    /// Acknowledges a specific notification
    /// - Parameter notificationId: The ID of the notification to acknowledge
    /// - Returns: AcknowledgeResponse indicating success
    /// - Throws: NetworkError if the request fails
    func acknowledgeNotification(notificationId: String) async throws -> AcknowledgeResponse {
        let request = AcknowledgeNotificationRequest(notificationId: notificationId)

        // Get raw data to debug the response
        let rawData = try await networkManager.putRawData(
            endpoint: APIEndpoint.acknowledgeNotification(notificationId: notificationId).path,
            body: request
        )

        // Print the raw JSON response for debugging
        if let jsonString = String(data: rawData, encoding: .utf8) {
            print("🔍 Raw Acknowledge Response JSON:")
            print(jsonString)
        }

        // Now try to decode it
        let decoder = JSONDecoder()
        let response: AcknowledgeResponse = try decoder.decode(AcknowledgeResponse.self, from: rawData)
        print("📱 Acknowledged notification: \(notificationId)")
        return response
    }

    /// Acknowledges all notifications for the current user
    /// - Returns: AcknowledgeResponse indicating success
    /// - Throws: NetworkError if the request fails
    func acknowledgeAllNotifications() async throws -> AcknowledgeResponse {
        // Get raw data to debug the response
        let rawData = try await networkManager.putRawData(
            endpoint: APIEndpoint.acknowledgeAllNotifications.path,
            body: EmptyRequest()
        )

        // Print the raw JSON response for debugging
        if let jsonString = String(data: rawData, encoding: .utf8) {
            print("🔍 Raw Acknowledge All Response JSON:")
            print(jsonString)
        }

        // Now try to decode it
        let decoder = JSONDecoder()
        let response: AcknowledgeResponse = try decoder.decode(AcknowledgeResponse.self, from: rawData)
        print("📱 Acknowledged all notifications")
        return response
    }
}

// MARK: - Helper Models

private struct EmptyRequest: Codable {}
