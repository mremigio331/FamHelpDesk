import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var userSession = UserSession.shared
    @State private var notificationSession = NotificationSession.shared
    @State private var showProfile = false
    @State private var showNotifications = false
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Top Bar
                CustomNavigationBar(
                    showProfile: $showProfile,
                    showNotifications: $showNotifications,
                    showSearch: $showSearch,
                    unreadCount: notificationSession.unreadCount
                )

                // Main Content
                HomeView()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showProfile) {
                UserProfileDetailView()
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
            .sheet(isPresented: $showSearch) {
                FamilySearchView()
            }
        }
        .task {
            // Load notifications when app starts to get unread count
            await notificationSession.fetchNotifications(refresh: true)
        }
    }
}

struct CustomNavigationBar: View {
    @State private var userSession = UserSession.shared
    @Binding var showProfile: Bool
    @Binding var showNotifications: Bool
    @Binding var showSearch: Bool
    let unreadCount: Int

    var body: some View {
        HStack(spacing: 12) {
            // Logo placeholder (you can replace with actual logo image)
            Image(systemName: "ticket.fill")
                .font(.title2)
                .foregroundColor(.blue)

            Text("Fam Help Desk")
                .font(.headline)

            Spacer()

            // Search button
            Button {
                showSearch = true
            } label: {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                    }
            }

            // Notifications button with badge
            Button {
                showNotifications = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "bell")
                                .foregroundColor(.blue)
                        }

                    // Badge for unread count
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 12, y: -12)
                    }
                }
            }

            // Profile button
            Button {
                showProfile = true
            } label: {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay {
                        if let user = userSession.currentUser {
                            Text(user.displayName.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "person.fill")
                                .foregroundColor(.blue)
                        }
                    }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
}
