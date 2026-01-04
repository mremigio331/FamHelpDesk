import SwiftUI

struct NotificationsView: View {
    @State private var notificationSession = NotificationSession.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Close") {
                        dismiss()
                    }

                    Spacer()

                    Text("Notifications")
                        .font(.headline)

                    Spacer()

                    if !notificationSession.notifications.isEmpty {
                        Button("Mark All Read") {
                            Task {
                                await notificationSession.acknowledgeAllNotifications()
                            }
                        }
                        .font(.caption)
                    } else {
                        // Invisible button for spacing
                        Button("") {}
                            .opacity(0)
                    }
                }
                .padding()
                .background(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 2)

                // Content
                if notificationSession.isFetching, notificationSession.notifications.isEmpty {
                    // Initial loading state
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading notifications...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if notificationSession.notifications.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("No Notifications")
                            .font(.title2)
                            .fontWeight(.medium)

                        Text("You're all caught up! New notifications will appear here.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Notifications list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(notificationSession.notifications) { notification in
                                NotificationItemView(notification: notification)
                                    .onTapGesture {
                                        if !notification.viewed {
                                            Task {
                                                await notificationSession.acknowledgeNotification(notification.notificationId)
                                            }
                                        }
                                    }

                                Divider()
                                    .padding(.leading, 16)
                            }

                            // Load more indicator
                            if notificationSession.hasNextPage {
                                HStack {
                                    if notificationSession.isFetching {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Loading more...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Button("Load More") {
                                            Task {
                                                await notificationSession.loadMoreNotifications()
                                            }
                                        }
                                        .font(.caption)
                                    }
                                }
                                .padding()
                                .onAppear {
                                    // Auto-load when scrolled to bottom
                                    Task {
                                        await notificationSession.loadMoreNotifications()
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        await notificationSession.refresh()
                    }
                }

                // Error message
                if let errorMessage = notificationSession.errorMessage {
                    VStack {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            // Load notifications when view appears
            if notificationSession.notifications.isEmpty {
                await notificationSession.fetchNotifications(refresh: true)
            }
        }
    }
}

struct NotificationItemView: View {
    let notification: Notification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Notification icon
            Circle()
                .fill(notification.viewed ? Color.gray.opacity(0.3) : Color.blue)
                .frame(width: 8, height: 8)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(notification.title)
                    .font(.headline)
                    .fontWeight(notification.viewed ? .regular : .semibold)
                    .foregroundColor(notification.viewed ? .secondary : .primary)

                // Message
                Text(notification.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Timestamp
                HStack {
                    Text(formatNotificationDate(notification.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Notification type badge
                    Text(notification.type.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(notification.type.color.opacity(0.2))
                        .foregroundColor(notification.type.color)
                        .cornerRadius(8)
                }
            }

            Spacer()
        }
        .padding()
        .background(notification.viewed ? Color.clear : Color.blue.opacity(0.05))
    }

    private func formatNotificationDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let now = Date()
        let timeInterval = now.timeIntervalSince(date)

        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            if days == 1 {
                return "1 day ago"
            } else if days < 7 {
                return "\(days) days ago"
            } else {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none
                return dateFormatter.string(from: date)
            }
        }
    }
}

// Extension to provide display names and colors for notification types
extension NotificationType {
    var displayName: String {
        switch self {
        case .welcome:
            "Welcome"
        case .welcomeToFamily:
            "Welcome to Family"
        case .membershipRequest:
            "Membership Request"
        case .membershipApproved:
            "Membership Approved"
        case .membershipDenied:
            "Membership Denied"
        case .ticketAssigned:
            "Ticket Assigned"
        case .ticketComment:
            "Ticket Comment"
        case .ticketStatusChanged:
            "Ticket Status Changed"
        case .groupInvitation:
            "Group Invitation"
        case .unknown:
            "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .welcome, .welcomeToFamily:
            .blue
        case .membershipRequest:
            .orange
        case .membershipApproved:
            .green
        case .membershipDenied:
            .red
        case .ticketAssigned, .ticketComment, .ticketStatusChanged:
            .purple
        case .groupInvitation:
            .blue
        case .unknown:
            .gray
        }
    }
}

#Preview {
    NotificationsView()
}
