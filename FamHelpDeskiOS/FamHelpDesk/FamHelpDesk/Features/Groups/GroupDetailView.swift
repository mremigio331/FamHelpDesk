import SwiftUI

struct GroupDetailView: View {
    let group: FamilyGroup
    @State private var navigationContext = NavigationContext.shared

    @State private var members: [GroupMember] = []
    @State private var isLoadingMembers = false
    @State private var membersError: String?

    private let membershipService = MembershipService()

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
                                await loadGroupMembers()
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
            }
        }
        .navigationTitle(group.groupName)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadGroupMembers()
        }
        .task {
            await loadGroupMembers()
        }
        .onAppear {
            // Update navigation context when this view appears
            navigationContext.selectedGroup = group
        }
    }

    private func loadGroupMembers() async {
        isLoadingMembers = true
        membersError = nil

        do {
            members = try await membershipService.getGroupMembers(
                familyId: group.familyId,
                groupId: group.groupId
            )
        } catch {
            membersError = "Failed to load group members: \(error.localizedDescription)"
        }

        isLoadingMembers = false
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
