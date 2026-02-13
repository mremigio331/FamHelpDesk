import SwiftUI

struct ManageMembersSheet: View {
    let family: Family
    let members: [FamilyMember]
    let onDismiss: () -> Void

    @State private var membershipSession = MembershipSession.shared
    @State private var familySession = FamilySession.shared
    @State private var isProcessing = false
    @State private var processingUserId: String?
    @State private var errorMessage: String?
    @State private var showRemoveConfirmation = false
    @State private var memberToRemove: FamilyMember?

    private var currentUserId: String? {
        familySession.myFamilies[family.familyId]?.membership.userId
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Manage member roles and remove members. You cannot modify your own role.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Members")) {
                    ForEach(members) { member in
                        ManageMemberRow(
                            member: member,
                            isCurrentUser: member.userId == currentUserId,
                            isProcessing: processingUserId == member.userId,
                            onMakeAdmin: {
                                await handleMakeAdmin(member)
                            },
                            onRemoveAdmin: {
                                await handleRemoveAdmin(member)
                            },
                            onRemove: {
                                memberToRemove = member
                                showRemoveConfirmation = true
                            }
                        )
                    }
                }

                if let errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Manage Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
            .confirmationDialog(
                "Remove Member",
                isPresented: $showRemoveConfirmation,
                titleVisibility: .visible,
                presenting: memberToRemove
            ) { member in
                Button("Remove", role: .destructive) {
                    Task {
                        await handleRemoveMember(member)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { member in
                Text("Are you sure you want to remove \(member.displayName) from this family? This action cannot be undone.")
            }
        }
    }

    private func handleMakeAdmin(_ member: FamilyMember) async {
        processingUserId = member.userId
        errorMessage = nil

        do {
            try await membershipSession.updateMemberRole(
                familyId: family.familyId,
                targetUserId: member.userId,
                isAdmin: true
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        processingUserId = nil
    }

    private func handleRemoveAdmin(_ member: FamilyMember) async {
        processingUserId = member.userId
        errorMessage = nil

        do {
            try await membershipSession.updateMemberRole(
                familyId: family.familyId,
                targetUserId: member.userId,
                isAdmin: false
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        processingUserId = nil
    }

    private func handleRemoveMember(_ member: FamilyMember) async {
        processingUserId = member.userId
        errorMessage = nil

        do {
            try await membershipSession.removeMember(
                familyId: family.familyId,
                targetUserId: member.userId
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        processingUserId = nil
        memberToRemove = nil
    }
}

struct ManageMemberRow: View {
    let member: FamilyMember
    let isCurrentUser: Bool
    let isProcessing: Bool
    let onMakeAdmin: () async -> Void
    let onRemoveAdmin: () async -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(member.displayName.prefix(1).uppercased())
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(member.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if member.isAdmin {
                            Text("Admin")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }

                        if isCurrentUser {
                            Text("You")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }

                    Text(member.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            if !isCurrentUser {
                HStack(spacing: 8) {
                    if member.isAdmin {
                        Button(action: {
                            Task {
                                await onRemoveAdmin()
                            }
                        }) {
                            Text("Remove Admin")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isProcessing)
                    } else {
                        Button(action: {
                            Task {
                                await onMakeAdmin()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "crown")
                                Text("Make Admin")
                            }
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isProcessing)
                    }

                    Button(action: onRemove) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Remove")
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isProcessing)
                }
            }

            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    // Preview disabled - FamilyMember requires Codable initialization
    Text("ManageMembersSheet Preview")
}
