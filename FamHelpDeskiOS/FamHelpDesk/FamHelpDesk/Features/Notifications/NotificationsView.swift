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
        // Welcome
        case .welcome:
            "Welcome"
        // Family
        case .newFamilyCreation:
            "New Family"
        // Family Membership
        case .familyMembershipApproved:
            "Membership Approved"
        case .familyMembershipDenied:
            "Membership Denied"
        case .familyMembershipInvitation:
            "Family Invitation"
        case .familyMemberJoined:
            "Member Joined"
        case .familyMembershipLeft:
            "Member Left"
        case .familyMembershipRequest:
            "Membership Request"
        case .newFamilyMember:
            "New Member"
        case .welcomeToFamily:
            "Welcome to Family"
        // Group Membership
        case .groupMembershipApproved:
            "Group Approved"
        case .groupMembershipDenied:
            "Group Denied"
        case .groupMembershipAdded:
            "Added to Group"
        case .groupMemberJoined:
            "Group Member Joined"
        case .groupMembershipLeft:
            "Group Member Left"
        case .groupMembershipRequest:
            "Group Request"
        case .newGroupCreation:
            "New Group"
        // Tickets
        case .ticketCreationFamily:
            "Family Ticket"
        case .ticketCreationGroup:
            "Group Ticket"
        case .ticketAssigned:
            "Ticket Assigned"
        case .ticketComment:
            "Ticket Comment"
        case .ticketStatusChanged:
            "Ticket Updated"
        case .ticketResolved:
            "Ticket Resolved"
        case .unknown:
            "Unknown"
        }
    }

    var color: Color {
        switch self {
        // Welcome
        case .welcome, .welcomeToFamily:
            .blue

        // Family
        case .newFamilyCreation:
            .green

        // Family Membership - Positive
        case .familyMembershipApproved, .familyMemberJoined, .newFamilyMember:
            .green

        // Family Membership - Neutral/Info
        case .familyMembershipInvitation, .familyMembershipRequest:
            .orange

        // Family Membership - Negative
        case .familyMembershipDenied, .familyMembershipLeft:
            .red

        // Group Membership - Positive
        case .groupMembershipApproved, .groupMemberJoined, .groupMembershipAdded, .newGroupCreation:
            .green

        // Group Membership - Neutral/Info
        case .groupMembershipRequest:
            .orange

        // Group Membership - Negative
        case .groupMembershipDenied, .groupMembershipLeft:
            .red

        // Tickets
        case .ticketCreationFamily, .ticketCreationGroup:
            .blue

        case .ticketAssigned:
            .purple

        case .ticketComment:
            .indigo

        case .ticketStatusChanged:
            .teal

        case .ticketResolved:
            .green

        case .unknown:
            .gray
        }
    }
}

#Preview {
    NotificationsView()
}
