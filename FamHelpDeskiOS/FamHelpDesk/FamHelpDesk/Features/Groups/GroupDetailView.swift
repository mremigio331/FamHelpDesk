import SwiftUI

struct GroupDetailView: View {
    let group: FamilyGroup
    @State private var navigationContext = NavigationContext.shared
    @State private var userSession = UserSession.shared
    @State private var queueSession = QueueSession.shared
    @State private var selectedTab: GroupDetailTab = .overview

    @State private var members: [GroupMember] = []
    @State private var membershipRequests: [GroupMembershipRequestItem] = []
    @State private var isLoadingMembers = false
    @State private var isLoadingRequests = false
    @State private var membersError: String?
    @State private var showingMembershipRequest = false
    @State private var showingMembershipManagement = false

    private let membershipService = MembershipService()
    private let groupService = GroupService()

    enum GroupDetailTab: String, CaseIterable {
        case overview = "Overview"
        case queues = "Queues"
        case members = "Members"

        var systemImage: String {
            switch self {
            case .overview: "info.circle"
            case .queues: "tray.2"
            case .members: "person.2"
            }
        }
    }

    // Computed property to check if current user is already a member
    private var isCurrentUserMember: Bool {
        guard let currentUserId = userSession.currentUser?.userId else {
            return false
        }

        return members.contains { $0.userId == currentUserId }
    }

    // Computed property to check if current user is an admin of the group
    private var isCurrentUserAdmin: Bool {
        guard let currentUserId = userSession.currentUser?.userId else {
            return false
        }

        let currentMember = members.first { $0.userId == currentUserId }
        let isAdmin = currentMember?.isAdmin == true

        print("🔍 Admin check for user \(currentUserId): \(isAdmin)")
        if let member = currentMember {
            print("   - Found member record: isAdmin = \(member.isAdmin)")
        } else {
            print("   - No member record found")
        }

        return isAdmin
    }

    // Computed property to check if current user has a pending membership request
    private var hasCurrentUserPendingRequest: Bool {
        guard let currentUserId = userSession.currentUser?.userId else { return false }

        let hasPendingRequest = membershipRequests.contains { request in
            request.userId == currentUserId && request.status == "AWAITING"
        }

        print("🔍 Checking pending requests for user \(currentUserId): \(hasPendingRequest)")
        return hasPendingRequest
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(GroupDetailTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top, 8)

            // Tab Content
            switch selectedTab {
            case .overview:
                GroupOverviewView(
                    group: group,
                    members: members,
                    membershipRequests: membershipRequests,
                    isLoadingMembers: isLoadingMembers,
                    isLoadingRequests: isLoadingRequests,
                    membersError: membersError,
                    isCurrentUserMember: isCurrentUserMember,
                    isCurrentUserAdmin: isCurrentUserAdmin,
                    hasCurrentUserPendingRequest: hasCurrentUserPendingRequest,
                    showingMembershipRequest: $showingMembershipRequest,
                    showingMembershipManagement: $showingMembershipManagement,
                    refreshMembershipData: refreshMembershipData
                )
            case .queues:
                QueueListView(group: group)
            case .members:
                GroupMembersView(
                    group: group,
                    members: members,
                    membershipRequests: membershipRequests,
                    isLoadingMembers: isLoadingMembers,
                    isLoadingRequests: isLoadingRequests,
                    membersError: membersError,
                    isCurrentUserMember: isCurrentUserMember,
                    isCurrentUserAdmin: isCurrentUserAdmin,
                    hasCurrentUserPendingRequest: hasCurrentUserPendingRequest,
                    showingMembershipRequest: $showingMembershipRequest,
                    showingMembershipManagement: $showingMembershipManagement,
                    refreshMembershipData: refreshMembershipData
                )
            }
        }
        .navigationTitle(group.groupName)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await refreshMembershipData()
        }
        .task {
            // Load group members when view appears
            await loadGroupMembers()
            await loadMembershipRequests()

            // Load queues for this group
            await loadGroupQueues()

            // Ensure user session is loaded for membership check
            if userSession.currentUser == nil, !userSession.isFetching, !userSession.isLoading {
                print("🔄 Loading user profile for membership check...")
                await userSession.loadUserProfile()
            }
        }
        .onAppear {
            // Update navigation context when this view appears
            navigationContext.selectedGroup = group
        }
        .sheet(isPresented: $showingMembershipRequest) {
            GroupMembershipRequestView(group: group) {
                // Refresh membership data when request is successful
                Task {
                    await refreshMembershipData()
                }
            }
        }
        .sheet(isPresented: $showingMembershipManagement) {
            NavigationStack {
                GroupMembershipManagementView(group: group)
            }
        }
    }

    private func refreshMembershipData() async {
        await loadGroupMembers()
        await loadMembershipRequests()
        await loadGroupQueues()
    }

    private func loadGroupMembers() async {
        isLoadingMembers = true
        membersError = nil

        do {
            members = try await membershipService.getGroupMembers(
                familyId: group.familyId,
                groupId: group.groupId
            )
            print("🔍 Group members API response:")
            print("🔍 Members count: \(members.count)")
            for (index, member) in members.enumerated() {
                print("🔍 Member \(index + 1):")
                print("   - userId: \(member.userId)")
                print("   - displayName: \(member.userDisplayName ?? "nil")")
                print("   - email: \(member.userEmail ?? "nil")")
                print("   - status: \(member.status)")
                print("   - isAdmin: \(member.isAdmin)")
            }
        } catch {
            membersError = "Failed to load group members: \(error.localizedDescription)"
            print("❌ Error loading group members: \(error)")
        }

        isLoadingMembers = false
    }

    private func loadMembershipRequests() async {
        isLoadingRequests = true

        do {
            membershipRequests = try await groupService.getGroupMembershipRequests(
                familyId: group.familyId,
                groupId: group.groupId
            )
            print("🔍 Membership requests loaded: \(membershipRequests.count)")
            for request in membershipRequests {
                print("   - User: \(request.userId), Status: \(request.status), Name: \(request.userDisplayName ?? "nil")")
            }
        } catch {
            print("❌ Error loading membership requests: \(error)")
            // Don't set error state for requests - just log it
        }

        isLoadingRequests = false
    }

    private func loadGroupQueues() async {
        await queueSession.fetchGroupQueues(familyId: group.familyId, groupId: group.groupId)
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

// MARK: - Group Overview View

struct GroupOverviewView: View {
    let group: FamilyGroup
    let members: [GroupMember]
    let membershipRequests: [GroupMembershipRequestItem]
    let isLoadingMembers: Bool
    let isLoadingRequests: Bool
    let membersError: String?
    let isCurrentUserMember: Bool
    let isCurrentUserAdmin: Bool
    let hasCurrentUserPendingRequest: Bool
    @Binding var showingMembershipRequest: Bool
    @Binding var showingMembershipManagement: Bool
    let refreshMembershipData: () async -> Void

    @State private var queueSession = QueueSession.shared

    private var queues: [Queue] {
        queueSession.getQueuesForGroup(group.groupId)
    }

    var body: some View {
        List {
            // Group Information Section
            Section("Group Information") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "rectangle.3.group.fill")
                            .font(.title)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.groupName)
                                .font(.title2)
                                .fontWeight(.bold)

                            if let description = group.groupDescription, !description.isEmpty {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Divider()

                    HStack {
                        Text("Created")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(group.createdAt))
                    }

                    HStack {
                        Text("Group ID")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(group.groupId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 8)
            }

            // Quick Stats Section
            Section("Quick Stats") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(members.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    VStack(alignment: .center, spacing: 4) {
                        Text("Queues")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(queues.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Pending Requests")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(membershipRequests.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .refreshable {
            await refreshMembershipData()
        }
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

// MARK: - Group Members View

struct GroupMembersView: View {
    let group: FamilyGroup
    let members: [GroupMember]
    let membershipRequests: [GroupMembershipRequestItem]
    let isLoadingMembers: Bool
    let isLoadingRequests: Bool
    let membersError: String?
    let isCurrentUserMember: Bool
    let isCurrentUserAdmin: Bool
    let hasCurrentUserPendingRequest: Bool
    @Binding var showingMembershipRequest: Bool
    @Binding var showingMembershipManagement: Bool
    let refreshMembershipData: () async -> Void

    var body: some View {
        List {
            // Members Section
            Section("Members") {
                if isLoadingMembers {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else if let error = membersError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Error Loading Members")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await refreshMembershipData()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else if members.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        Text("No Members")
                            .font(.headline)
                        Text("This group doesn't have any members yet.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(members) { member in
                        GroupMemberRow(member: member)
                    }
                }

                // Pending Membership Requests - Show for all users (no section header since PENDING tag is clear)
                if !membershipRequests.isEmpty {
                    ForEach(membershipRequests) { request in
                        PendingMembershipRequestRow(request: request)
                    }
                }

                // Membership Actions - only show if user has available actions
                if !isLoadingMembers, !isLoadingRequests, membersError == nil {
                    let hasRequestAction = !isCurrentUserMember && !hasCurrentUserPendingRequest
                    let hasManageAction = isCurrentUserAdmin

                    if hasRequestAction || hasManageAction {
                        VStack(spacing: 12) {
                            // Only show "Request to Join" if user is not already a member and doesn't have a pending request
                            if hasRequestAction {
                                Button(action: {
                                    showingMembershipRequest = true
                                }) {
                                    HStack {
                                        Image(systemName: "person.badge.plus")
                                        Text("Request to Join Group")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }

                            // Only show "Manage Membership" for group admins
                            if hasManageAction {
                                Button(action: {
                                    showingMembershipManagement = true
                                }) {
                                    HStack {
                                        Image(systemName: "person.2.badge.gearshape")
                                        Text("Manage Membership")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .refreshable {
            await refreshMembershipData()
        }
    }
}

// MARK: - Pending Membership Request Row

struct PendingMembershipRequestRow: View {
    let request: GroupMembershipRequestItem

    var body: some View {
        HStack(spacing: 12) {
            // Request Avatar
            Circle()
                .fill(Color.orange.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(requestInitials)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.orange)
                )

            // Request Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(requestDisplayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("PENDING")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)

                    Spacer()
                }

                if let email = request.userEmail {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("Requested \(formatRequestDate())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var requestDisplayName: String {
        request.userDisplayName ?? "Unknown User"
    }

    private var requestInitials: String {
        let name = requestDisplayName
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    private func formatRequestDate() -> String {
        let date = Date(timeIntervalSince1970: request.requestDate)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Group Member Row

struct GroupMemberRow: View {
    let member: GroupMember

    var body: some View {
        HStack(spacing: 12) {
            // Member Avatar
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(memberInitials)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                )

            // Member Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(memberDisplayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if member.isAdmin {
                        Text("ADMIN")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }

                    Spacer()
                }

                if let email = member.userEmail {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("Joined \(formatJoinDate())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var memberDisplayName: String {
        member.userDisplayName ?? "Unknown User"
    }

    private var memberInitials: String {
        let name = memberDisplayName
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    private func formatJoinDate() -> String {
        let date = Date(timeIntervalSince1970: member.requestDate)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GroupDetailView(
            group: FamilyGroup(
                groupId: "group123",
                familyId: "family123",
                groupName: "Family Activities",
                groupDescription: "Planning and organizing family activities and events",
                createdBy: "user123",
                creationDate: Date().timeIntervalSince1970
            )
        )
    }
}
