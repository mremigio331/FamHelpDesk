import SwiftUI

struct FilterView: View {
    @Environment(\.dismiss) private var dismiss

    // Filter state
    @State private var selectedStatuses: Set<TicketStatus> = []
    @State private var selectedSeverities: Set<TicketSeverity> = []
    @State private var selectedGroups: Set<String> = []
    @State private var selectedAssignedUsers: Set<String> = []
    @State private var searchQuery: String = ""

    // UI state
    @State private var availableGroups: [FamilyGroup] = []
    @State private var availableUsers: [FamilyMember] = []
    @State private var isLoadingGroups = false
    @State private var isLoadingUsers = false

    // Services
    private let groupSession = GroupSession.shared

    // Callbacks
    let currentFilters: TicketFilters
    let familyId: String
    let onApplyFilters: (TicketFilters) -> Void
    let onClearFilters: () -> Void

    init(currentFilters: TicketFilters, familyId: String, onApplyFilters: @escaping (TicketFilters) -> Void, onClearFilters: @escaping () -> Void) {
        self.currentFilters = currentFilters
        self.familyId = familyId
        self.onApplyFilters = onApplyFilters
        self.onClearFilters = onClearFilters

        // Initialize state from current filters
        // If no statuses are set, default to open only
        let initialStatuses = currentFilters.statuses ?? (currentFilters.status != nil ? Set([currentFilters.status!]) : [.open])
        _selectedStatuses = State(initialValue: initialStatuses)
        _selectedSeverities = State(initialValue: currentFilters.severities ?? (currentFilters.severity != nil ? Set([currentFilters.severity!]) : []))

        // Initialize groups - support both single and multiple
        let groupIds: Set<String> = {
            if let groupIds = currentFilters.groupIds, !groupIds.isEmpty {
                return groupIds
            } else if let groupId = currentFilters.groupId {
                return Set([groupId])
            }
            return []
        }()
        _selectedGroups = State(initialValue: groupIds)

        // Initialize assigned users - support both single and multiple
        let assignedUserIds: Set<String> = {
            if let assignedToUsers = currentFilters.assignedToUsers, !assignedToUsers.isEmpty {
                return assignedToUsers
            } else if let assignedTo = currentFilters.assignedTo {
                return Set([assignedTo])
            }
            return []
        }()
        _selectedAssignedUsers = State(initialValue: assignedUserIds)

        _searchQuery = State(initialValue: currentFilters.searchQuery ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with active filter indicators
                if hasActiveFilters {
                    activeFiltersHeader
                }

                // Filter options
                ScrollView {
                    VStack(spacing: 24) {
                        // Search section
                        searchFilterSection

                        // Status filters
                        statusFilterSection

                        // Severity filters
                        severityFilterSection

                        // Group filters
                        groupFilterSection

                        // Assigned Users filters
                        assignedUsersFilterSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Filter Tickets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if hasActiveFilters {
                            Button("Clear All") {
                                clearAllFilters()
                            }
                            .foregroundColor(.red)
                        }

                        Button("Apply") {
                            applyFilters()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await loadGroups()
            await loadUsers()
        }
    }

    // MARK: - Active Filters Header

    private var activeFiltersHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Filters")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Clear All") {
                    clearAllFilters()
                }
                .font(.caption)
                .foregroundColor(.red)
            }

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(activeFilterChips, id: \.id) { chip in
                        FilterChip(
                            title: chip.title,
                            onRemove: chip.onRemove
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
    }

    // MARK: - Filter Sections

    private var searchFilterSection: some View {
        FilterSection(title: "Search") {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))

                TextField("Search tickets...", text: $searchQuery)
                    .textFieldStyle(.plain)

                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(10)
        }
    }

    private var statusFilterSection: some View {
        FilterSection(title: "Status") {
            VStack(alignment: .leading, spacing: 12) {
                // Default indicator
                if selectedStatuses == [.open] {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Showing open tickets by default")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(TicketStatus.allCases, id: \.self) { status in
                        FilterToggleButton(
                            title: status.rawValue.capitalized,
                            isSelected: selectedStatuses.contains(status)
                        ) {
                            toggleStatus(status)
                        }
                    }
                }
            }
        }
    }

    private var severityFilterSection: some View {
        FilterSection(title: "Severity") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(TicketSeverity.allCases, id: \.self) { severity in
                    FilterToggleButton(
                        title: severity.displayName,
                        isSelected: selectedSeverities.contains(severity),
                        color: colorForSeverity(severity)
                    ) {
                        toggleSeverity(severity)
                    }
                }
            }
        }
    }

    private var groupFilterSection: some View {
        FilterSection(title: "Groups") {
            VStack(spacing: 12) {
                if isLoadingGroups {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading groups...")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(availableGroups, id: \.id) { group in
                            FilterToggleButton(
                                title: group.groupName,
                                isSelected: selectedGroups.contains(group.groupId)
                            ) {
                                toggleGroup(group.groupId)
                            }
                        }
                    }
                }
            }
        }
    }

    private var assignedUsersFilterSection: some View {
        FilterSection(title: "Assigned Users") {
            VStack(spacing: 12) {
                if isLoadingUsers {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading users...")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(availableUsers, id: \.userId) { user in
                            FilterToggleButton(
                                title: user.displayName,
                                isSelected: selectedAssignedUsers.contains(user.userId)
                            ) {
                                toggleAssignedUser(user.userId)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private var hasActiveFilters: Bool {
        // Don't count "open only" as an active filter since it's the default
        let hasNonDefaultStatuses = selectedStatuses != [.open]

        return hasNonDefaultStatuses ||
            !selectedSeverities.isEmpty ||
            !selectedGroups.isEmpty ||
            !selectedAssignedUsers.isEmpty ||
            !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var activeFilterChips: [FilterChipData] {
        var chips: [FilterChipData] = []

        // Search chip
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chips.append(FilterChipData(
                id: "search",
                title: "Search: \"\(searchQuery)\"",
                onRemove: { searchQuery = "" }
            ))
        }

        // Status chips
        for status in selectedStatuses {
            chips.append(FilterChipData(
                id: "status-\(status.rawValue)",
                title: status.rawValue.capitalized,
                onRemove: { toggleStatus(status) }
            ))
        }

        // Severity chips
        for severity in selectedSeverities {
            chips.append(FilterChipData(
                id: "severity-\(severity.rawValue)",
                title: severity.displayName,
                onRemove: { toggleSeverity(severity) }
            ))
        }

        // Group chips
        for groupId in selectedGroups {
            let title = availableGroups.first { $0.groupId == groupId }?.groupName ?? "Unknown Group"
            chips.append(FilterChipData(
                id: "group-\(groupId)",
                title: title,
                onRemove: { toggleGroup(groupId) }
            ))
        }

        // Assigned user chips
        for userId in selectedAssignedUsers {
            let title = availableUsers.first { $0.userId == userId }?.displayName ?? "Unknown User"
            chips.append(FilterChipData(
                id: "user-\(userId)",
                title: title,
                onRemove: { toggleAssignedUser(userId) }
            ))
        }

        return chips
    }

    private func toggleStatus(_ status: TicketStatus) {
        if selectedStatuses.contains(status) {
            selectedStatuses.remove(status)
        } else {
            selectedStatuses.insert(status)
        }
    }

    private func toggleSeverity(_ severity: TicketSeverity) {
        if selectedSeverities.contains(severity) {
            selectedSeverities.remove(severity)
        } else {
            selectedSeverities.insert(severity)
        }
    }

    private func toggleGroup(_ groupId: String) {
        if selectedGroups.contains(groupId) {
            selectedGroups.remove(groupId)
        } else {
            selectedGroups.insert(groupId)
        }
    }

    private func toggleAssignedUser(_ userId: String) {
        if selectedAssignedUsers.contains(userId) {
            selectedAssignedUsers.remove(userId)
        } else {
            selectedAssignedUsers.insert(userId)
        }
    }

    private func colorForSeverity(_ severity: TicketSeverity) -> Color {
        switch severity.colorCategory {
        case .critical:
            .red
        case .high:
            .orange
        case .medium:
            .yellow
        case .low:
            .green
        }
    }

    private func clearAllFilters() {
        selectedStatuses = [.open] // Reset to default (open only)
        selectedSeverities.removeAll()
        selectedGroups.removeAll()
        selectedAssignedUsers.removeAll()
        searchQuery = ""

        onClearFilters()
    }

    private func applyFilters() {
        let filters = TicketFilters(
            queueId: nil, // Not used in simplified version
            groupId: selectedGroups.first, // Keep backward compatibility
            assignedTo: selectedAssignedUsers.first, // Keep backward compatibility
            status: selectedStatuses.first, // Keep backward compatibility
            severity: selectedSeverities.first, // Keep backward compatibility
            statuses: selectedStatuses.isEmpty ? nil : selectedStatuses,
            severities: selectedSeverities.isEmpty ? nil : selectedSeverities,
            groupIds: selectedGroups.isEmpty ? nil : selectedGroups,
            assignedToUsers: selectedAssignedUsers.isEmpty ? nil : selectedAssignedUsers,
            searchQuery: searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : searchQuery
        )

        onApplyFilters(filters)
        dismiss()
    }

    private func loadGroups() async {
        isLoadingGroups = true

        // First try to get cached groups
        let cachedGroups = groupSession.getGroupsForFamily(familyId)
        if !cachedGroups.isEmpty {
            availableGroups = cachedGroups
            isLoadingGroups = false
            return
        }

        // If no cached groups, fetch from API
        await groupSession.fetchFamilyGroups(familyId: familyId)
        availableGroups = groupSession.getGroupsForFamily(familyId)
        isLoadingGroups = false
    }

    private func loadUsers() async {
        isLoadingUsers = true

        // TODO: Implement user loading from family members
        // For now, we'll use a placeholder implementation
        // In a real implementation, you'd fetch family members from an API
        availableUsers = []
        isLoadingUsers = false
    }
}

// MARK: - Supporting Views

struct FilterSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FilterToggleButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    init(title: String, isSelected: Bool, color: Color = .blue, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? color : color.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct FilterChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(16)
    }
}

// MARK: - Supporting Types

struct FilterChipData {
    let id: String
    let title: String
    let onRemove: () -> Void
}

// MARK: - Preview

#Preview {
    FilterView(
        currentFilters: TicketFilters(),
        familyId: "family123",
        onApplyFilters: { _ in },
        onClearFilters: {}
    )
}
