import SwiftUI

struct FamilyDetailView: View {
    let family: Family
    @State private var familySession = FamilySession.shared
    @State private var navigationContext = NavigationContext.shared
    @State private var notificationSession = NotificationSession.shared
    @State private var showProfile = false
    @State private var showNotifications = false
    @State private var showSearch = false
    @State private var navigationBarVisible = true

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case members = "Members"
        case groups = "Groups"

        var systemImage: String {
            switch self {
            case .overview:
                "info.circle"
            case .members:
                "person.2"
            case .groups:
                "rectangle.3.group"
            }
        }
    }

    private var familyItem: MyFamilyItem? {
        familySession.myFamilies[family.familyId]
    }

    private var isAdmin: Bool {
        familyItem?.membership.isAdmin ?? false
    }

    private var selectedTab: Tab {
        get { navigationContext.selectedFamilyTab }
        set { navigationContext.selectedFamilyTab = newValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Collapsible Navigation Bar
            CollapsibleNavigationBar(
                showProfile: $showProfile,
                showNotifications: $showNotifications,
                showSearch: $showSearch,
                unreadCount: notificationSession.unreadCount,
                isVisible: $navigationBarVisible,
                isInFamilyContext: true
            )

            // Family Content
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Tab", selection: Binding(
                    get: { selectedTab },
                    set: { navigationContext.selectedFamilyTab = $0 }
                )) {
                    ForEach(availableTabs, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                // Tab Content with Collapsible Scroll
                CollapsibleScrollView(navigationBarVisible: $navigationBarVisible) {
                    TabView(selection: Binding(
                        get: { selectedTab },
                        set: { navigationContext.selectedFamilyTab = $0 }
                    )) {
                        ForEach(availableTabs, id: \.self) { tab in
                            Group {
                                switch tab {
                                case .overview:
                                    overviewContent
                                case .members:
                                    FamilyMembersView(family: family)
                                case .groups:
                                    FamilyGroupsView(family: family)
                                }
                            }
                            .tag(tab)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(minHeight: UIScreen.main.bounds.height - 200) // Ensure scrollable content
                }
            }
        }
        .navigationBarHidden(true)
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
        .onAppear {
            // Update navigation context when this view appears
            navigationContext.selectedFamily = family

            // Load notifications to get unread count
            Task {
                await notificationSession.fetchNotifications(refresh: false)
            }
        }
    }

    private var availableTabs: [Tab] {
        var tabs: [Tab] = [.overview]

        // Only show members and groups tabs if user is a member
        if let familyItem, familyItem.membership.status == "MEMBER" {
            tabs.append(.members)
            tabs.append(.groups)
        }

        return tabs
    }

    private var overviewContent: some View {
        VStack(spacing: 0) {
            // Family Title Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .font(.title)
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(family.familyName)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let description = family.familyDescription, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding()
                .background(Color(uiColor: .systemBackground))
            }

            // Family Details List
            List {
                Section {
                    if let item = familyItem {
                        // User has some relationship with this family
                        HStack {
                            Text("Your Status")
                                .foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 4) {
                                switch item.membership.status {
                                case "MEMBER":
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Member")
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                case "AWAITING":
                                    Image(systemName: "clock.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("Request Pending")
                                        .fontWeight(.medium)
                                        .foregroundColor(.orange)
                                default:
                                    Image(systemName: "person.badge.plus")
                                        .foregroundColor(.blue)
                                    Text(item.membership.status)
                                        .fontWeight(.medium)
                                }
                            }
                        }

                        if item.membership.isAdmin {
                            HStack {
                                Text("Role")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Admin")
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }

                        if item.membership.status != "MEMBER" {
                            // Show message about limited access
                            VStack(alignment: .leading, spacing: 8) {
                                Divider()
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("Limited Access")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                                Text("You can only view basic family information until your membership is approved.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        // User is not a member and hasn't requested membership
                        HStack {
                            Text("Your Status")
                                .foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.gray)
                                Text("Not a member")
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Divider()
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("Limited Access")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                            Text("You can only view basic family information. Request membership to access members and groups.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Created")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(family.createdAt))
                    }

                    HStack {
                        Text("Family ID")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(family.familyId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                // Add some extra content to make scrolling more apparent
                Section("Additional Information") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Family Management")
                            .font(.headline)

                        Text("This family provides a centralized way to organize and manage help desk tickets. Members can create groups, manage queues, and collaborate on resolving issues.")
                            .font(.body)
                            .foregroundColor(.secondary)

                        if let item = familyItem, item.membership.status == "MEMBER" {
                            Text("As a member, you have access to:")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            VStack(alignment: .leading, spacing: 4) {
                                Label("View and manage family members", systemImage: "person.2")
                                Label("Create and join groups", systemImage: "rectangle.3.group")
                                Label("Manage tickets and queues", systemImage: "ticket")
                                Label("Receive notifications", systemImage: "bell")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await refreshFamilyData()
            }
        }
    }

    private func refreshFamilyData() async {
        // Refresh family session to update membership status
        await familySession.refresh()
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        FamilyDetailView(
            family: Family(
                familyId: "123",
                familyName: "Smith Family",
                familyDescription: "Our family group",
                createdBy: "user123",
                creationDate: Date().timeIntervalSince1970
            )
        )
    }
}
