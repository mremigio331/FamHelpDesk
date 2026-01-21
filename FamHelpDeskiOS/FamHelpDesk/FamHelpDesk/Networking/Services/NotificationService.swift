import Foundation

final class NotificationService {
    private let networkManager: NetworkManager
    private let retryHelper = RetryHelper()

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    /// Fetches notifications for the current user with enhanced error handling
    /// - Parameters:
    ///   - limit: Maximum number of notifications to fetch
    ///   - viewed: Filter by viewed status (nil for all)
    ///   - nextToken: Token for pagination
    /// - Returns: NotificationResponse containing notifications and pagination info
    /// - Throws: ServiceError with structured error information
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

        do {
            // Get the raw data for decoding
            let rawData = try await networkManager.getRawData(
                endpoint: APIEndpoint.getNotifications.path,
                queryItems: queryItems
            )

            // Decode the response
            let decoder = JSONDecoder()
            // Don't use convertFromSnakeCase since we have explicit CodingKeys
            let response: NotificationResponse = try decoder.decode(NotificationResponse.self, from: rawData)
            print("📱 Notifications Response: \(response.notifications.count) notifications, next_token: \(response.nextToken ?? "nil")")
            return response
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching notifications: \(serviceError)")
            throw serviceError
        }
    }

    /// Acknowledges a specific notification with enhanced error handling
    /// - Parameter notificationId: The ID of the notification to acknowledge
    /// - Returns: AcknowledgeResponse indicating success
    /// - Throws: ServiceError with structured error information
    func acknowledgeNotification(notificationId: String) async throws {
        let request = AcknowledgeNotificationRequest(notificationId: notificationId)

        do {
            _ = try await networkManager.putRawData(
                endpoint: APIEndpoint.acknowledgeNotification(notificationId: notificationId).path,
                body: request
            )
            print("📱 Acknowledged notification: \(notificationId)")
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error acknowledging notification: \(serviceError)")
            throw serviceError
        }
    }

    /// Acknowledges all notifications for the current user with enhanced error handling
    /// - Returns: AcknowledgeResponse indicating success
    /// - Throws: ServiceError with structured error information
    func acknowledgeAllNotifications() async throws {
        do {
            _ = try await networkManager.putRawData(
                endpoint: APIEndpoint.acknowledgeAllNotifications.path,
                body: EmptyRequest()
            )
            print("📱 Acknowledged all notifications")
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error acknowledging all notifications: \(serviceError)")
            throw serviceError
        }
    }
}

// MARK: - Helper Models

private struct EmptyRequest: Codable {}
