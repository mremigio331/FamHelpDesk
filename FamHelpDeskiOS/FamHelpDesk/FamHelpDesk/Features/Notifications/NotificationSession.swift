import Foundation

@Observable
final class NotificationSession {
    static let shared = NotificationSession()

    private let notificationService = NotificationService()

    var notifications: [Notification] = []
    var unreadCount: Int = 0
    var isFetching = false
    var hasNextPage = false
    var nextToken: String?
    var errorMessage: String?

    private init() {}

    /// Fetches notifications for the current user
    /// - Parameter refresh: If true, clears existing notifications and starts fresh
    @MainActor
    func fetchNotifications(refresh: Bool = false) async {
        isFetching = true
        errorMessage = nil

        // If refreshing, clear existing data
        if refresh {
            notifications = []
            nextToken = nil
            hasNextPage = false
        }

        do {
            let response = try await notificationService.getNotifications(
                limit: 20,
                viewed: nil,
                nextToken: refresh ? nil : nextToken
            )

            if refresh {
                notifications = response.notifications
            } else {
                notifications.append(contentsOf: response.notifications)
            }

            nextToken = response.nextToken
            hasNextPage = response.hasMore

            print("✅ Fetched \(response.notifications.count) notifications (total: \(notifications.count))")

            // Calculate unread count from fetched notifications
            updateUnreadCount()

        } catch {
            errorMessage = "Failed to load notifications: \(error.localizedDescription)"
            print("❌ Error fetching notifications: \(error)")
        }

        isFetching = false
    }

    /// Acknowledges a specific notification and updates local state
    /// - Parameter notificationId: The ID of the notification to acknowledge
    @MainActor
    func acknowledgeNotification(_ notificationId: String) async {
        do {
            _ = try await notificationService.acknowledgeNotification(notificationId: notificationId)

            // Update local state - mark notification as viewed
            if let index = notifications.firstIndex(where: { $0.notificationId == notificationId }) {
                let currentNotification = notifications[index]
                // Create a new notification with viewed = true
                let viewedNotification = Notification(
                    notificationId: currentNotification.notificationId,
                    userId: currentNotification.userId,
                    notificationType: currentNotification.notificationType,
                    message: currentNotification.message,
                    timestamp: currentNotification.timestamp,
                    viewed: true,
                    familyId: currentNotification.familyId,
                    ticketId: currentNotification.ticketId
                )
                notifications[index] = viewedNotification
            }

            // Update unread count
            updateUnreadCount()

            print("✅ Acknowledged notification: \(notificationId)")

        } catch {
            errorMessage = "Failed to acknowledge notification: \(error.localizedDescription)"
            print("❌ Error acknowledging notification: \(error)")
        }
    }

    /// Acknowledges all notifications and updates local state
    @MainActor
    func acknowledgeAllNotifications() async {
        do {
            _ = try await notificationService.acknowledgeAllNotifications()

            // Update local state - mark all notifications as viewed
            notifications = notifications.map { notification in
                Notification(
                    notificationId: notification.notificationId,
                    userId: notification.userId,
                    notificationType: notification.notificationType,
                    message: notification.message,
                    timestamp: notification.timestamp,
                    viewed: true,
                    familyId: notification.familyId,
                    ticketId: notification.ticketId
                )
            }

            // Reset unread count
            unreadCount = 0

            print("✅ Acknowledged all notifications")

        } catch {
            errorMessage = "Failed to acknowledge all notifications: \(error.localizedDescription)"
            print("❌ Error acknowledging all notifications: \(error)")
        }
    }

    /// Loads more notifications if available (for infinite scrolling)
    @MainActor
    func loadMoreNotifications() async {
        guard hasNextPage, !isFetching else { return }
        await fetchNotifications(refresh: false)
    }

    /// Fetches the current unread notification count
    @MainActor
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.viewed }.count
        print("✅ Updated unread count: \(unreadCount)")
    }

    /// Refreshes all notification data
    @MainActor
    func refresh() async {
        await fetchNotifications(refresh: true)
    }
}
