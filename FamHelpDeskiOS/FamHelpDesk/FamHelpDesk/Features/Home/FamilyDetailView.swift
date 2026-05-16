import SwiftUI

struct FamilyDetailView: View {
    let family: Family
    @State private var familySession = FamilySession.shared
    @State private var navigationContext = NavigationContext.shared
    @State private var notificationSession = NotificationSession.shared
    @State private var groupSession = GroupSession.shared
    @State private var membershipSession = MembershipSession.shared
    @State private var ticketSession = TicketSession.shared
    @State private var showProfile = false
    @State private var showNotifications = false
    @State private var showSearch = false
    @State private var showCreateTicket = false
    @State private var showEditFamily = false
    @State private var navigationBarVisible = true
    @State private var currentFamilyId: String?
    @State private var appMode: AppMode = .helpDesk

    enum AppMode: String, CaseIterable {
        case helpDesk = "Help Desk"
        case famGrab = "FamGrab"
    }

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case members = "Members"
        case groups = "Groups"
        case tickets = "Tickets"

        var systemImage: String {
            switch self {
            case .overview:
                "info.circle"
            case .members:
                "person.2"
            case .groups:
                "rectangle.3.group"
            case .tickets:
                "ticket"
            }
        }
    }

    private var familyItem: MyFamilyItem? {
        familySession.myFamilies[family.familyId]
    }

    private var isAdmin: Bool {
        familyItem?.membership.isAdmin ?? false
    }

    private var canCreateTickets: Bool {
        familyItem?.membership.status == "MEMBER"
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
                isInFamilyContext: true,
                onCreateTicket: canCreateTickets ? {
                    showCreateTicket = true
                } : nil,
                onCreateGroup: isAdmin ? {
                    print("Create Group action triggered")
                } : nil
            )

            // Family Content
            VStack(spacing: 0) {
                // Top-level mode picker: Help Desk vs FamGrab
                Picker("Mode", selection: $appMode) {
                    ForEach(AppMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if appMode == .famGrab {
                    // FamGrab mode
                    FamGrabView(familyId: family.familyId)
                } else {
                    // Help Desk mode — show sub-tabs
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
                                    case .tickets:
                                        TicketListView(familyId: family.familyId)
                                    }
                                }
                                .tag(tab)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(minHeight: UIScreen.main.bounds.height - 200)
                    }
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
        .sheet(isPresented: $showCreateTicket) {
            TicketFormView(
                mode: .create(familyId: family.familyId),
                onSuccess: { newTicket in
                    // Ticket created successfully - could refresh ticket list if needed
                    print("✅ Created ticket: \(newTicket.ticketId)")
                }
            )
        }
        .sheet(isPresented: $showEditFamily) {
            EditFamilyView(family: family)
        }
        .onAppear {
            // Preload all family data when view appears
            Task {
                await preloadFamilyData()
            }
        }
        .onChange(of: family.familyId) { oldValue, newValue in
            // Clear and reload data when family changes
            Task {
                await handleFamilyChange(from: oldValue, to: newValue)
            }
        }
    }

    private var availableTabs: [Tab] {
        var tabs: [Tab] = [.overview]

        // Only show members, groups, tickets tabs if user is a member
        if let familyItem, familyItem.membership.status == "MEMBER" {
            tabs.append(.members)
            tabs.append(.groups)
            tabs.append(.tickets)
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

                    // Edit button for family admins
                    if isAdmin {
                        Button(action: {
                            showEditFamily = true
                        }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
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

                        Button(action: {
                            UIPasteboard.general.string = family.familyId
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                // Severity Levels Guide Section
                Section("Severity Levels Guide") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(SeverityInfo.allSeverities) { severity in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(severity.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                Text(severity.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text(severity.scope)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }

                            if severity.id != SeverityInfo.allSeverities.last?.id {
                                Divider()
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                // Family Settings Section (only for members)
                if let item = familyItem, item.membership.status == "MEMBER" {
                    Section("Family Settings") {
                        NavigationLink(destination: FamilyNotificationSettingsView(
                            familyId: family.familyId,
                            familyName: family.familyName
                        )) {
                            Label("Notification Settings", systemImage: "bell.badge")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

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

    // MARK: - Data Preloading

    /// Handles family context change by clearing old data and loading new data
    @MainActor
    private func handleFamilyChange(from oldFamilyId: String?, to newFamilyId: String) async {
        guard oldFamilyId != newFamilyId else { return }

        print("🔄 Family changed from \(oldFamilyId ?? "nil") to \(newFamilyId)")

        // Clear old family data
        if let oldId = oldFamilyId {
            membershipSession.clearFamilyData(familyId: oldId)
            print("🧹 Cleared data for old family: \(oldId)")
        }

        // Clear ticket session completely since it tracks current family
        ticketSession.clearData()

        // Load new family data
        await preloadFamilyData()
    }

    /// Preloads all family data (members, groups, tickets) when family is selected
    /// This ensures data is ready when users navigate to different tabs
    @MainActor
    private func preloadFamilyData() async {
        print("🚀 Preloading data for family: \(family.familyId)")

        // Track current family
        currentFamilyId = family.familyId

        // Only preload if user is a member
        guard let familyItem, familyItem.membership.status == "MEMBER" else {
            print("⏭️ Skipping preload - user is not a member")
            return
        }

        // Preload all data concurrently
        async let membersTask: () = preloadMembers()
        async let groupsTask: () = preloadGroups()
        async let ticketsTask: () = preloadTickets()
        async let notificationsTask: () = preloadNotifications()

        // Wait for all tasks to complete
        _ = await (membersTask, groupsTask, ticketsTask, notificationsTask)

        print("✅ Preload complete for family: \(family.familyId)")
    }

    @MainActor
    private func preloadMembers() async {
        do {
            try await membershipSession.fetchFamilyMembers(familyId: family.familyId)
            print("✅ Preloaded family members")
        } catch {
            print("⚠️ Failed to preload members: \(error)")
        }
    }

    @MainActor
    private func preloadGroups() async {
        await groupSession.fetchFamilyGroups(familyId: family.familyId)
        print("✅ Preloaded family groups")
    }

    @MainActor
    private func preloadTickets() async {
        // Load tickets with default filters (open tickets)
        await ticketSession.loadTickets(
            familyId: family.familyId,
            filters: TicketFilters(statuses: [.open]),
            refresh: true
        )
        print("✅ Preloaded family tickets")
    }

    @MainActor
    private func preloadNotifications() async {
        await notificationSession.fetchNotifications(refresh: false)
        print("✅ Preloaded notifications")
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
                creationDate: Date().timeIntervalSince1970,
                isPrivate: false
            )
        )
    }
}
