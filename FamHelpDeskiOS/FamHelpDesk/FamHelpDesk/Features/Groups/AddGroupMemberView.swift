import SwiftUI

struct AddGroupMemberView: View {
    let group: FamilyGroup
    @State private var groupSession = GroupSession.shared
    @State private var userId = ""
    @State private var isAdmin = false
    @State private var isAdding = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var addSuccess = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                    .padding(.vertical, 8)
                } header: {
                    Text("Group Information")
                }

                Section {
                    TextField("User ID", text: $userId)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Toggle("Make Admin", isOn: $isAdmin)
                        .toggleStyle(SwitchToggleStyle())

                    if isAdmin {
                        Text("Admins can manage group members and settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Member Details")
                } footer: {
                    Text("Enter the User ID of the person you want to add to this group.")
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addMember()
                    }
                    .disabled(userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAdding)
                }
            }
        }
        .alert(addSuccess ? "Member Added" : "Error", isPresented: $showingAlert) {
            Button("OK") {
                if addSuccess {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }

    private func addMember() {
        Task {
            await performAddMember()
        }
    }

    @MainActor
    private func performAddMember() async {
        isAdding = true

        let trimmedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)

        let success = await groupSession.addGroupMember(
            familyId: group.familyId,
            groupId: group.groupId,
            userId: trimmedUserId,
            isAdmin: isAdmin
        )

        isAdding = false

        if success {
            addSuccess = true
            alertMessage = "Successfully added \(trimmedUserId) to the group\(isAdmin ? " as an admin" : "")."
        } else {
            addSuccess = false
            alertMessage = groupSession.errorMessage ?? "Failed to add member to group. Please try again."
        }

        showingAlert = true
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
        )
    )
}
