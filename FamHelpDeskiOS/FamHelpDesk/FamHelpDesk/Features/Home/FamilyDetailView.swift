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

    enum Tab: String, CaseIterable {
        case helpDesk = "Help Desk"
        case grab = "Grab"
        case settings = "Settings"

        var systemImage: String {
            switch self {
            case .helpDesk: "ticket"
            case .grab: "bag.fill"
            case .settings: "gearshape"
            }
        }
    }

    /// Sub-tabs within the Help Desk tab
    enum HelpDeskTab: String, CaseIterable {
        case groups = "Groups"
        case tickets = "Tickets"

        var systemImage: String {
            switch self {
            case .groups: "rectangle.3.group"
            case .tickets: "ticket"
            }
        }
    }

    /// Sub-tabs within the Family Settings tab
    enum SettingsTab: String, CaseIterable {
        case overview = "Overview"
        case members = "Members"

        var systemImage: String {
            switch self {
            case .overview: "info.circle"
            case .members: "person.2"
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

    @State private var selectedHelpDeskTab: HelpDeskTab = .tickets
    @State private var selectedSettingsTab: SettingsTab = .overview

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
                // Top-level 3-tab picker
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

                // Tab content
                switch selectedTab {
                case .helpDesk:
                    helpDeskContent
                case .grab:
                    FamGrabView(familyId: family.familyId)
                case .settings:
                    settingsContent
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
                    print("✅ Created ticket: \(newTicket.ticketId)")
                }
            )
        }
        .sheet(isPresented: $showEditFamily) {
            EditFamilyView(family: family)
        }
        .onAppear {
            Task {
                await preloadFamilyData()
            }
        }
        .onChange(of: family.familyId) { oldValue, newValue in
            Task {
                await handleFamilyChange(from: oldValue, to: newValue)
            }
        }
    }

    // MARK: - Available Tabs

    private var availableTabs: [Tab] {
        if let familyItem, familyItem.membership.status == "MEMBER" {
            return Tab.allCases
        }
        // Non-members only see Settings (overview)
        return [.settings]
    }

    // MARK: - Help Desk Content

    @ViewBuilder
    private var helpDeskContent: some View {
        VStack(spacing: 0) {
            // Sub-tab picker for Help Desk
            Picker("Help Desk Tab", selection: $selectedHelpDeskTab) {
                ForEach(HelpDeskTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            // Help Desk tab content
            CollapsibleScrollView(navigationBarVisible: $navigationBarVisible) {
                TabView(selection: $selectedHelpDeskTab) {
                    FamilyGroupsView(family: family)
                        .tag(HelpDeskTab.groups)

                    TicketListView(familyId: family.familyId)
                        .tag(HelpDeskTab.tickets)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(minHeight: UIScreen.main.bounds.height - 200)
            }
        }
    }

    // MARK: - Settings Content

    @ViewBuilder
    private var settingsContent: some View {
        VStack(spacing: 0) {
            // Sub-tab picker for Settings (only show if member)
            if let familyItem, familyItem.membership.status == "MEMBER" {
                Picker("Settings Tab", selection: $selectedSettingsTab) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
            }

            // Settings tab content
            CollapsibleScrollView(navigationBarVisible: $navigationBarVisible) {
                TabView(selection: $selectedSettingsTab) {
                    overviewContent
                        .tag(SettingsTab.overview)

                    FamilyMembersView(family: family)
                        .tag(SettingsTab.members)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(minHeight: UIScreen.main.bounds.height - 200)
            }
        }
    }

    // MARK: - Overview Content

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

                // Notification Settings (only for members)
                if let item = familyItem, item.membership.status == "MEMBER" {
                    Section("Notifications") {
                        NavigationLink(destination: FamilyNotificationSettingsView(
                            familyId: family.familyId,
                            familyName: family.familyName
                        )) {
                            Label("Notification Settings", systemImage: "bell.badge")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

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

                // Additional Information
                Section("About This Family") {
                    VStack(alignment: .leading, spacing: 12) {
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

    // MARK: - Helpers

    private func refreshFamilyData() async {
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

    @MainActor
    private func handleFamilyChange(from oldFamilyId: String?, to newFamilyId: String) async {
        guard oldFamilyId != newFamilyId else { return }

        print("🔄 Family changed from \(oldFamilyId ?? "nil") to \(newFamilyId)")

        if let oldId = oldFamilyId {
            membershipSession.clearFamilyData(familyId: oldId)
            print("🧹 Cleared data for old family: \(oldId)")
        }

        ticketSession.clearData()
        await preloadFamilyData()
    }

    @MainActor
    private func preloadFamilyData() async {
        print("🚀 Preloading data for family: \(family.familyId)")

        currentFamilyId = family.familyId

        guard let familyItem, familyItem.membership.status == "MEMBER" else {
            print("⏭️ Skipping preload - user is not a member")
            return
        }

        async let membersTask: () = preloadMembers()
        async let groupsTask: () = preloadGroups()
        async let ticketsTask: () = preloadTickets()
        async let notificationsTask: () = preloadNotifications()

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
