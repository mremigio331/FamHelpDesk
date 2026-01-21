import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var userSession = UserSession.shared
    @State private var notificationSession = NotificationSession.shared
    @State private var navigationContext = NavigationContext.shared
    @State private var showProfile = false
    @State private var showNotifications = false
    @State private var showSearch = false

    var body: some View {
        NavigationStack(path: $navigationContext.navigationPath) {
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
                    .onAppear {
                        // Clear navigation context when back at home
                        navigationContext.selectedFamily = nil
                        navigationContext.selectedGroup = nil
                    }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: Family.self) { family in
                FamilyDetailView(family: family)
                    .onAppear {
                        // Just update the selected family - the back button should work with SwiftUI's navigation
                        navigationContext.selectedFamily = family
                    }
            }
            .navigationDestination(for: FamilyGroup.self) { group in
                GroupDetailView(group: group)
                    .onAppear {
                        navigationContext.selectedGroup = group
                    }
            }
            .sheet(isPresented: $showProfile) {
                UserProfileDetailView()
                    .onAppear {
                        navigationContext.navigateToProfile()
                    }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
                    .onAppear {
                        navigationContext.navigateToNotifications()
                    }
            }
            .sheet(isPresented: $showSearch) {
                FamilySearchView()
                    .onAppear {
                        navigationContext.navigateToSearch()
                    }
            }
        }
        .task {
            // Load notifications when app starts to get unread count
            await notificationSession.fetchNotifications(refresh: true)

            // Load user profile if not already loaded
            if userSession.currentUser == nil, !userSession.isFetching {
                await userSession.loadUserProfile()
            }

            // Mark navigation context as ready for deep links
            navigationContext.setReadyForDeepLinks()

            // Restore navigation state
            navigationContext.restoreNavigationState()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Save navigation state when app goes to background
            navigationContext.saveNavigationState()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Mark as ready for deep links when app becomes active
            navigationContext.setReadyForDeepLinks()
        }
        .onOpenURL { url in
            // Handle deep links
            navigationContext.processDeepLink(url)
        }
    }
}

struct CustomNavigationBar: View {
    @State private var userSession = UserSession.shared
    @State private var navigationContext = NavigationContext.shared
    @Binding var showProfile: Bool
    @Binding var showNotifications: Bool
    @Binding var showSearch: Bool
    let unreadCount: Int

    private var profileColor: Color {
        guard let user = userSession.currentUser else { return .blue }
        return ProfileColor(rawValue: user.profileColor)?.color ?? .blue
    }

    private var profileBackgroundColor: Color {
        profileColor
    }

    var body: some View {
        HStack(spacing: 12) {
            // Logo - Tappable to go home
            Button {
                // Navigate back to home (families list)
                navigationContext.popToRoot()
            } label: {
                HStack(spacing: 8) {
                    Image("FamHelpDeskTransparent")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)

                    Text("FamHelpDesk")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .buttonStyle(.plain) // Removes default button styling
            .scaleEffect(navigationContext.canNavigateBack ? 1.0 : 0.98) // Subtle visual feedback when navigable
            .opacity(navigationContext.canNavigateBack ? 1.0 : 0.8) // Slight opacity change when at root
            .layoutPriority(1)

            Spacer(minLength: 8)

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
                    .fill(profileBackgroundColor)
                    .frame(width: 36, height: 36)
                    .overlay {
                        if let user = userSession.currentUser {
                            Text(user.displayName.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
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
