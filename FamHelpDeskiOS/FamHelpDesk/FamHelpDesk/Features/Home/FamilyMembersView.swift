import SwiftUI

struct FamilyMembersView: View {
    let family: Family
    @State private var membershipSession = MembershipSession.shared
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var members: [FamilyMember] {
        membershipSession.familyMembers[family.familyId] ?? []
    }

    var body: some View {
        List {
            if isLoading, members.isEmpty {
                Section {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading members...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                }
            } else if members.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No Members")
                            .font(.headline)
                        Text("This family doesn't have any members yet.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                Section(header: Text("Family Members (\(members.count))")) {
                    ForEach(members) { member in
                        MemberRowView(member: member)
                    }
                }
            }

            if let errorMessage {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(.orange)
                        Text("Error Loading Members")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            Task {
                                await loadMembers()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .refreshable {
            await loadMembers(forceRefresh: true)
        }
        .task {
            await loadMembers()
        }
    }

    private func loadMembers(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            // This will automatically check stale time and only fetch if needed
            try await membershipSession.fetchFamilyMembers(familyId: family.familyId, forceRefresh: forceRefresh)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct MemberRowView: View {
    let member: FamilyMember

    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(member.displayName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(member.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    // Admin badge
                    if member.isAdmin {
                        Text("Admin")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                }

                Text(member.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    // Status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor(for: member.status))
                            .frame(width: 8, height: 8)
                        Text(statusText(for: member.status))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Join date
                    if !member.joinedAt.isEmpty {
                        Text("Joined \(formatJoinDate(member.joinedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusColor(for status: MembershipStatus) -> Color {
        switch status {
        case .member:
            .green
        case .pending:
            .orange
        case .rejected:
            .red
        }
    }

    private func statusText(for status: MembershipStatus) -> String {
        switch status {
        case .member:
            "Active"
        case .pending:
            "Pending"
        case .rejected:
            "Rejected"
        }
    }

    private func formatJoinDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        FamilyMembersView(
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
