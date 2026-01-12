import SwiftUI

/// A collapsible navigation bar that hides when scrolling down and shows when scrolling up
struct CollapsibleNavigationBar: View {
    @State private var userSession = UserSession.shared
    @State private var navigationContext = NavigationContext.shared
    @Binding var showProfile: Bool
    @Binding var showNotifications: Bool
    @Binding var showSearch: Bool
    let unreadCount: Int

    /// Whether the navigation bar should be visible
    @Binding var isVisible: Bool

    /// Whether we're in a family context (hides search button)
    let isInFamilyContext: Bool

    /// Animation duration for show/hide
    private let animationDuration: Double = 0.3

    private var profileColor: Color {
        guard let user = userSession.currentUser else { return .blue }
        return ProfileColor(rawValue: user.profileColor)?.color ?? .blue
    }

    private var profileBackgroundColor: Color {
        profileColor
    }

    var body: some View {
        VStack(spacing: 0) {
            if isVisible {
                HStack(spacing: 12) {
                    // Logo and title
                    HStack(spacing: 8) {
                        Image(systemName: "ticket.fill")
                            .font(.title2)
                            .foregroundColor(.blue)

                        Text("Fam Help Desk")
                            .font(.headline)
                    }

                    Spacer()

                    // Action buttons
                    HStack(spacing: 12) {
                        // Search button - only show when not in family context
                        if !isInFamilyContext {
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
                            .transition(.scale.combined(with: .opacity))
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
                                .fill(profileBackgroundColor.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if let user = userSession.currentUser {
                                        Text(user.displayName.prefix(1).uppercased())
                                            .font(.headline)
                                            .foregroundColor(profileColor)
                                    } else {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: animationDuration), value: isVisible)
        .clipped()
    }
}

/// A scroll view that automatically manages the collapsible navigation bar
struct CollapsibleScrollView<Content: View>: View {
    let content: Content
    @Binding var navigationBarVisible: Bool

    @State private var lastScrollOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0

    /// Threshold for hiding/showing the navigation bar
    private let scrollThreshold: CGFloat = 50

    init(navigationBarVisible: Binding<Bool>, @ViewBuilder content: () -> Content) {
        _navigationBarVisible = navigationBarVisible
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                    }
                )
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            let currentOffset = value
            let offsetDifference = currentOffset - lastScrollOffset

            // Update scroll offset
            scrollOffset = currentOffset

            // Determine if we should show or hide the navigation bar
            if abs(offsetDifference) > 5 { // Minimum scroll distance to trigger change
                withAnimation(.easeInOut(duration: 0.3)) {
                    if offsetDifference > scrollThreshold {
                        // Scrolling up - show navigation bar
                        navigationBarVisible = true
                    } else if offsetDifference < -scrollThreshold {
                        // Scrolling down - hide navigation bar
                        navigationBarVisible = false
                    }
                }

                lastScrollOffset = currentOffset
            }
        }
    }
}

/// Preference key for tracking scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    @State var isVisible = true
    @State var showProfile = false
    @State var showNotifications = false
    @State var showSearch = false

    return VStack {
        CollapsibleNavigationBar(
            showProfile: $showProfile,
            showNotifications: $showNotifications,
            showSearch: $showSearch,
            unreadCount: 3,
            isVisible: $isVisible,
            isInFamilyContext: false
        )

        Spacer()

        Button("Toggle Visibility") {
            withAnimation {
                isVisible.toggle()
            }
        }

        Spacer()
    }
}
