import SwiftUI

struct FamilyGroupsView: View {
    let family: Family
    @State private var groupSession = GroupSession.shared
    @State private var showingCreateGroup = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    private var groups: [FamilyGroup] {
        groupSession.getGroupsForFamily(family.familyId)
    }

    var body: some View {
        List {
            if groupSession.isFetching, groups.isEmpty {
                // Loading state
                Section {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading groups...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                }
            } else if groups.isEmpty {
                // Empty state
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.3.group")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        Text("No Groups Yet")
                            .font(.headline)
                        Text("Create the first group for this family to get started.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                // Groups list
                Section("Groups (\(groups.count))") {
                    ForEach(groups) { group in
                        NavigationLink(destination: GroupDetailView(group: group)) {
                            GroupRowView(group: group)
                        }
                    }
                }
            }

            // Create group section
            Section {
                Button(action: {
                    showingCreateGroup = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Create New Group")
                            .foregroundColor(.blue)
                    }
                }
                .disabled(groupSession.isFetching)
            }
        }
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await groupSession.refreshFamilyGroups(familyId: family.familyId)
        }
        .task {
            // Load groups when view appears
            if groups.isEmpty {
                await groupSession.fetchFamilyGroups(familyId: family.familyId)
            }
        }
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupView(family: family)
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") {
                groupSession.clearError()
            }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: groupSession.errorMessage) { _, newValue in
            if let errorMessage = newValue {
                alertMessage = errorMessage
                showingAlert = true
            }
        }
    }
}

// MARK: - Group Row View

struct GroupRowView: View {
    let group: FamilyGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.groupName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let description = group.groupDescription, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Created \(formatDate(group.createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding(.vertical, 4)
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

// MARK: - Create Group View

struct CreateGroupView: View {
    let family: Family
    @Environment(\.dismiss) private var dismiss
    @State private var groupSession = GroupSession.shared

    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var isCreating = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    private var isFormValid: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Group Name", text: $groupName)
                        .textInputAutocapitalization(.words)

                    TextField("Description (Optional)", text: $groupDescription, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text("Group Information")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Group name must be 2-50 characters long.")
                        if !groupDescription.isEmpty {
                            Text("Description can be up to 200 characters.")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Section {
                    Text("Family: \(family.familyName)")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await createGroup()
                        }
                    }
                    .disabled(!isFormValid || isCreating)
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    @MainActor
    private func createGroup() async {
        isCreating = true

        let trimmedDescription = groupDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDescription = trimmedDescription.isEmpty ? nil : trimmedDescription

        let result = await groupSession.createGroup(
            familyId: family.familyId,
            name: groupName,
            description: finalDescription
        )

        isCreating = false

        if result != nil {
            // Success - dismiss the sheet
            dismiss()
        } else if let errorMessage = groupSession.errorMessage {
            // Show error
            alertMessage = errorMessage
            showingAlert = true
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FamilyGroupsView(
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

#Preview("Create Group") {
    CreateGroupView(
        family: Family(
            familyId: "123",
            familyName: "Smith Family",
            familyDescription: "Our family group",
            createdBy: "user123",
            creationDate: Date().timeIntervalSince1970
        )
    )
}
