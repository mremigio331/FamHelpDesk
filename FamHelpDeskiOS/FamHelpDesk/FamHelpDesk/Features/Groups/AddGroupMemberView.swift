import SwiftUI

struct AddGroupMemberView: View {
    let group: FamilyGroup
    let onMemberAdded: (() -> Void)?
    @State private var groupSession = GroupSession.shared
    @State private var membershipService = MembershipService()
    @State private var searchText = ""
    @State private var isAdmin = false
    @State private var isAdding = false
    @State private var isLoadingMembers = false
    @State private var isRefreshing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var addSuccess = false

    @State private var allFamilyMembers: [FamilyMember] = []
    @State private var currentGroupMembers: [GroupMember] = []
    @State private var membershipRequests: [GroupMembershipRequestItem] = []
    @State private var selectedMember: FamilyMember?

    @Environment(\.dismiss) private var dismiss

    // Computed property to get available members (not in group and no pending requests)
    private var availableMembers: [FamilyMember] {
        let currentMemberIds = Set(currentGroupMembers.map(\.userId))
        let pendingRequestIds = Set(membershipRequests.filter { $0.status == "AWAITING" }.map(\.userId))

        return allFamilyMembers.filter { member in
            let isNotInGroup = !currentMemberIds.contains(member.userId)
            let hasNoPendingRequest = !pendingRequestIds.contains(member.userId)
            let matchesSearch = searchText.isEmpty ||
                member.displayName.localizedCaseInsensitiveContains(searchText) ||
                member.email.localizedCaseInsensitiveContains(searchText)

            return isNotInGroup && hasNoPendingRequest && matchesSearch
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Clean header with improved styling
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)

                    Spacer()

                    Text("Add Member")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button(isAdding ? "Adding..." : "Add") {
                        Task {
                            await performAddMember()
                        }
                    }
                    .foregroundColor(selectedMember != nil && !isAdding ? .blue : .gray)
                    .fontWeight(.semibold)
                    .disabled(selectedMember == nil || isAdding)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(uiColor: .systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color(uiColor: .separator)),
                    alignment: .bottom
                )

                VStack(spacing: 0) {
                    // Group Information Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "rectangle.3.group.fill")
                                .font(.title2)
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.groupName)
                                    .font(.headline)

                                if let description = group.groupDescription, !description.isEmpty {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))

                    // Search Bar
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search family members...", text: $searchText)
                                .textFieldStyle(.plain)
                        }
                        .padding()
                        .background(Color(uiColor: .systemBackground))
                        .overlay(
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(Color(uiColor: .separator)),
                            alignment: .bottom
                        )

                        // Admin Toggle
                        HStack {
                            Toggle("Make Admin", isOn: $isAdmin)
                                .toggleStyle(SwitchToggleStyle())

                            Spacer()
                        }
                        .padding()
                        .background(Color(uiColor: .systemBackground))

                        if isAdmin {
                            HStack {
                                Text("Admins can manage group members and settings.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                            .background(Color(uiColor: .systemBackground))
                        }

                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundColor(Color(uiColor: .separator))
                    }

                    // Members List
                    if isLoadingMembers {
                        VStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading family members...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(uiColor: .systemBackground))
                    } else if availableMembers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: searchText.isEmpty ? "person.2.slash" : "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)

                            Text(searchText.isEmpty ? "No Available Members" : "No Results")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text(searchText.isEmpty ?
                                "All family members are either already in this group or have pending requests." :
                                "No family members match your search.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(uiColor: .systemBackground))
                    } else {
                        List {
                            Section {
                                ForEach(availableMembers, id: \.userId) { member in
                                    MemberSelectionRow(
                                        member: member,
                                        isSelected: selectedMember?.userId == member.userId,
                                        onTap: {
                                            selectedMember = selectedMember?.userId == member.userId ? nil : member
                                        }
                                    )
                                }
                            } header: {
                                HStack {
                                    Text("Available Members")
                                    Spacer()
                                    Text("\(availableMembers.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .refreshable {
                            isRefreshing = true
                            await loadData()
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadData()
        }
        .alert(addSuccess ? "Member Added" : "Error", isPresented: $showingAlert) {
            Button("OK") {
                if addSuccess {
                    dismiss()
                }
            }
        } message: {
            if addSuccess {
                Text("\(alertMessage)\n\nThe member list has been updated.")
            } else {
                Text(alertMessage)
            }
        }
    }

    @MainActor
    private func loadData() async {
        // Don't show loading spinner if we're refreshing (pull-to-refresh has its own indicator)
        if !isRefreshing {
            isLoadingMembers = true
        }

        async let familyMembersTask = loadFamilyMembers()
        async let groupMembersTask = loadGroupMembers()
        async let membershipRequestsTask = loadMembershipRequests()

        await familyMembersTask
        await groupMembersTask
        await membershipRequestsTask

        isLoadingMembers = false
        isRefreshing = false
    }

    @MainActor
    private func loadFamilyMembers() async {
        do {
            allFamilyMembers = try await membershipService.getFamilyMembers(familyId: group.familyId)
            print("✅ Loaded \(allFamilyMembers.count) family members")
        } catch {
            print("❌ Error loading family members: \(error)")
            allFamilyMembers = []
        }
    }

    @MainActor
    private func loadGroupMembers() async {
        currentGroupMembers = await groupSession.fetchGroupMembers(familyId: group.familyId, groupId: group.groupId)
        print("✅ Loaded \(currentGroupMembers.count) group members")
    }

    @MainActor
    private func loadMembershipRequests() async {
        membershipRequests = await groupSession.fetchGroupMembershipRequests(familyId: group.familyId, groupId: group.groupId)
        print("✅ Loaded \(membershipRequests.count) membership requests")
    }

    @MainActor
    private func performAddMember() async {
        guard let member = selectedMember else { return }

        isAdding = true

        let success = await groupSession.addGroupMember(
            familyId: group.familyId,
            groupId: group.groupId,
            userId: member.userId,
            isAdmin: isAdmin
        )

        isAdding = false

        if success {
            addSuccess = true
            alertMessage = "\(member.displayName) has been added to the group."

            // Clear selection and refresh data after successful addition
            selectedMember = nil
            isAdmin = false

            // Refresh the member lists to reflect the changes
            await loadData()

            // Notify parent view that a member was added
            onMemberAdded?()
        } else {
            addSuccess = false
            alertMessage = groupSession.errorMessage ?? "Failed to add member to group."
        }

        showingAlert = true
    }
}

// MARK: - Member Selection Row

struct MemberSelectionRow: View {
    let member: FamilyMember
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile Circle
                Circle()
                    .fill(Color.blue) // Default color since profileColor is not available in FamilyMember
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(getInitials(from: member.displayName))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )

                // Member Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(member.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func getInitials(from displayName: String) -> String {
        let components = displayName.components(separatedBy: " ")
        let initials = components.compactMap(\.first).prefix(2)
        return String(initials).uppercased()
    }
}

#Preview {
    AddGroupMemberView(
        group: FamilyGroup(
            groupId: "group123",
            familyId: "family123",
            groupName: "Family Activities",
            groupDescription: "Planning and organizing family activities and events",
            createdBy: "user123",
            creationDate: Date().timeIntervalSince1970
        ),
        onMemberAdded: nil
    )
}
