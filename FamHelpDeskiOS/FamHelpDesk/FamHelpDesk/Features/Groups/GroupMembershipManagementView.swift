import SwiftUI

struct GroupMembershipManagementView: View {
    let group: FamilyGroup
    @State private var groupSession = GroupSession.shared
    @State private var membershipRequests: [GroupMembershipRequestItem] = []
    @State private var groupMembers: [GroupMemberWithRole] = []
    @State private var isLoadingRequests = false
    @State private var isLoadingMembers = false
    @State private var errorMessage: String?
    @State private var showingAlert = false
    @State private var selectedTab: Tab = .requests
    @State private var showingAddMember = false

    enum Tab: String, CaseIterable {
        case requests = "Requests"
        case members = "Members"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            // Content
            switch selectedTab {
            case .requests:
                membershipRequestsView
            case .members:
                membersView
            }
        }
        .navigationTitle("Manage Membership")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddMember = true
                }) {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .refreshable {
            await loadData()
        }
        .task {
            await loadData()
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showingAddMember) {
            AddGroupMemberView(group: group)
        }
    }

    // MARK: - Membership Requests View

    private var membershipRequestsView: some View {
        Group {
            if isLoadingRequests, membershipRequests.isEmpty {
                loadingView
            } else if membershipRequests.isEmpty {
                emptyRequestsView
            } else {
                requestsList
            }
        }
    }

    private var requestsList: some View {
        List {
            Section {
                ForEach(membershipRequests) { request in
                    GroupMembershipRequestRow(
                        request: request,
                        group: group,
                        onApprove: { await handleApproveRequest(request) },
                        onReject: { await handleRejectRequest(request) }
                    )
                }
            } header: {
                HStack {
                    Text("Pending Requests")
                    Spacer()
                    Text("\(membershipRequests.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyRequestsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Pending Requests")
                .font(.headline)
                .foregroundColor(.primary)

            Text("There are currently no pending membership requests for this group.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Members View

    private var membersView: some View {
        Group {
            if isLoadingMembers, groupMembers.isEmpty {
                loadingView
            } else if groupMembers.isEmpty {
                emptyMembersView
            } else {
                membersList
            }
        }
    }

    private var membersList: some View {
        List {
            Section {
                ForEach(groupMembers) { member in
                    GroupMemberManagementRow(
                        member: member,
                        group: group,
                        onRemove: { await handleRemoveMember(member) },
                        onToggleAdmin: { await handleToggleAdminRole(member) }
                    )
                }
            } header: {
                HStack {
                    Text("Group Members")
                    Spacer()
                    Text("\(groupMembers.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyMembersView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Members")
                .font(.headline)
                .foregroundColor(.primary)

            Text("This group doesn't have any members yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await loadMembershipRequests()
            }
            group.addTask {
                await loadGroupMembers()
            }
        }
    }

    @MainActor
    private func loadMembershipRequests() async {
        isLoadingRequests = true
        membershipRequests = await groupSession.fetchGroupMembershipRequests(
            familyId: group.familyId,
            groupId: group.groupId
        )
        isLoadingRequests = false
    }

    @MainActor
    private func loadGroupMembers() async {
        isLoadingMembers = true
        groupMembers = await groupSession.fetchGroupMembersWithRoles(
            familyId: group.familyId,
            groupId: group.groupId
        )
        isLoadingMembers = false
    }

    private func handleApproveRequest(_ request: GroupMembershipRequestItem) async {
        let success = await groupSession.addGroupMember(
            familyId: group.familyId,
            groupId: group.groupId,
            userId: request.userId,
            isAdmin: false
        )

        if success {
            await loadData() // Refresh both lists
        } else {
            await showError(groupSession.errorMessage ?? "Failed to approve membership request")
        }
    }

    private func handleRejectRequest(_: GroupMembershipRequestItem) async {
        // Note: The current API doesn't have a reject endpoint, so we'll just remove from requests
        // In a real implementation, you'd call a reject endpoint
        await loadMembershipRequests()
    }

    private func handleRemoveMember(_ member: GroupMemberWithRole) async {
        let success = await groupSession.removeGroupMember(
            familyId: group.familyId,
            groupId: group.groupId,
            userId: member.userId
        )

        if success {
            await loadGroupMembers()
        } else {
            await showError(groupSession.errorMessage ?? "Failed to remove member")
        }
    }

    private func handleToggleAdminRole(_ member: GroupMemberWithRole) async {
        let newAdminStatus = !member.isAdmin
        let success = await groupSession.updateGroupMemberRole(
            familyId: group.familyId,
            groupId: group.groupId,
            userId: member.userId,
            isAdmin: newAdminStatus
        )

        if success {
            await loadGroupMembers()
        } else {
            await showError(groupSession.errorMessage ?? "Failed to update member role")
        }
    }

    @MainActor
    private func showError(_ message: String) async {
        errorMessage = message
        showingAlert = true
    }
}

// MARK: - Group Membership Request Row

struct GroupMembershipRequestRow: View {
    let request: GroupMembershipRequestItem
    let group: FamilyGroup
    let onApprove: () async -> Void
    let onReject: () async -> Void

    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Info
            HStack {
                // Avatar
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(userInitials)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.userDisplayName ?? "Unknown User")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let email = request.userEmail {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Status Badge
                statusBadge
            }

            // Request Date
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Requested \(formatDate())")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }

            // Action Buttons
            if !isProcessing {
                HStack(spacing: 12) {
                    Button(action: {
                        Task {
                            isProcessing = true
                            await onApprove()
                            isProcessing = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Approve")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        Task {
                            isProcessing = true
                            await onReject()
                            isProcessing = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Reject")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var userInitials: String {
        let name = request.userDisplayName ?? "Unknown User"
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.circle.fill")
                .font(.caption)
            Text("Pending")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }

    private func formatDate() -> String {
        let date = Date(timeIntervalSince1970: request.requestDate)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Group Member Management Row

struct GroupMemberManagementRow: View {
    let member: GroupMemberWithRole
    let group: FamilyGroup
    let onRemove: () async -> Void
    let onToggleAdmin: () async -> Void

    @State private var isProcessing = false
    @State private var showingRemoveAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Info
            HStack {
                // Avatar
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(userInitials)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.userDisplayName ?? "Unknown User")
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
                    }

                    if let email = member.userEmail {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let joinedAt = member.joinedAt {
                        Text("Joined \(formatJoinDate(joinedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            // Action Buttons
            if !isProcessing {
                HStack(spacing: 12) {
                    Button(action: {
                        Task {
                            isProcessing = true
                            await onToggleAdmin()
                            isProcessing = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: member.isAdmin ? "person.crop.circle.badge.minus" : "person.crop.circle.badge.plus")
                            Text(member.isAdmin ? "Remove Admin" : "Make Admin")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(member.isAdmin ? Color.orange : Color.blue)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        showingRemoveAlert = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.crop.circle.badge.minus")
                            Text("Remove")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
        .alert("Remove Member", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task {
                    isProcessing = true
                    await onRemove()
                    isProcessing = false
                }
            }
        } message: {
            Text("Are you sure you want to remove \(member.userDisplayName ?? "this user") from the group?")
        }
    }

    private var userInitials: String {
        let name = member.userDisplayName ?? "Unknown User"
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    private func formatJoinDate(_ dateString: String) -> String {
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
        GroupMembershipManagementView(
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
