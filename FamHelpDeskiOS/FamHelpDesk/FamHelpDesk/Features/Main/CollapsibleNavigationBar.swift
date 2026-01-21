import SwiftUI

/// A collapsible navigation bar that hides when scrolling down and shows when scrolling up
struct CollapsibleNavigationBar: View {
    @State private var userSession = UserSession.shared
    @State private var navigationContext = NavigationContext.shared
    @Environment(\.dismiss) private var dismiss
    @Binding var showProfile: Bool
    @Binding var showNotifications: Bool
    @Binding var showSearch: Bool
    let unreadCount: Int

    /// Whether the navigation bar should be visible
    @Binding var isVisible: Bool

    /// Whether we're in a family context (hides search button, shows ticket creation)
    let isInFamilyContext: Bool

    /// Optional callback for ticket creation when in family context
    let onCreateTicket: (() -> Void)?

    /// Optional callback for group creation when in family context
    let onCreateGroup: (() -> Void)?

    /// Animation duration for show/hide
    private let animationDuration: Double = 0.2

    private var profileColor: Color {
        guard let user = userSession.currentUser else { return .blue }
        return ProfileColor(rawValue: user.profileColor)?.color ?? .blue
    }

    private var profileBackgroundColor: Color {
        profileColor
    }

    @State private var showCreateGroupSheet = false

    var body: some View {
        VStack(spacing: 0) {
            if isVisible {
                HStack(spacing: 12) {
                    // Logo with text - acts as back button when in family context, otherwise goes to root
                    Button {
                        if navigationContext.selectedFamily != nil || navigationContext.selectedGroup != nil {
                            // Inside family/group - go back
                            dismiss()
                        } else {
                            // At root - go to root (no-op but keeps consistent behavior)
                            navigationContext.popToRoot()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            // Show back chevron when in family/group context
                            if navigationContext.selectedFamily != nil || navigationContext.selectedGroup != nil {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                            }

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
                    .buttonStyle(.plain)
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    // Action buttons
                    HStack(spacing: 12) {
                        // Plus button with options for creating ticket or group
                        if isInFamilyContext {
                            Menu {
                                Button("Create Ticket") {
                                    onCreateTicket?()
                                }
                                Button("Create Group") {
                                    if let family = navigationContext.selectedFamily {
                                        showCreateGroupSheet = true
                                    }
                                }
                            } label: {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Image(systemName: "plus")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.blue)
                                    }
                            }
                            .sheet(isPresented: $showCreateGroupSheet) {
                                if let family = navigationContext.selectedFamily {
                                    CreateGroupView(family: family)
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }

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
    private let scrollThreshold: CGFloat = 80

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
            if abs(offsetDifference) > 10 { // Minimum scroll distance to trigger change
                withAnimation(.easeInOut(duration: 0.2)) {
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
            isInFamilyContext: false,
            onCreateTicket: nil,
            onCreateGroup: nil
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
