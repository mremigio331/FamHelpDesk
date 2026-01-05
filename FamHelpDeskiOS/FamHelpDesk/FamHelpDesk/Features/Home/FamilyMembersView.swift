import SwiftUI

struct FamilyMembersView: View {
    let family: Family
    @State private var membershipSession = MembershipSession.shared
    @State private var familySession = FamilySession.shared
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var members: [FamilyMember] {
        membershipSession.familyMembers[family.familyId] ?? []
    }

    private var membershipRequests: [MembershipRequest] {
        membershipSession.membershipRequests[family.familyId] ?? []
    }

    private var pendingRequests: [MembershipRequest] {
        membershipRequests.filter { $0.status == .pending || $0.status == .awaiting }
    }

    private var familyItem: MyFamilyItem? {
        familySession.myFamilies[family.familyId]
    }

    private var isAdmin: Bool {
        familyItem?.membership.isAdmin ?? false
    }

    var body: some View {
        List {
            // Pending Membership Requests Section (only for admins)
            if isAdmin, !pendingRequests.isEmpty {
                Section(header: Text("Pending Requests (\(pendingRequests.count))")) {
                    ForEach(pendingRequests) { request in
                        MembershipRequestRowView(
                            request: request,
                            onApprove: { await handleApprove(request) },
                            onReject: { await handleReject(request) }
                        )
                    }
                }
            }

            // Family Members Section
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
            // Load both members and requests
            try await membershipSession.fetchFamilyMembers(familyId: family.familyId, forceRefresh: forceRefresh)

            // Only load requests if user is admin
            if isAdmin {
                try await membershipSession.fetchMembershipRequests(familyId: family.familyId, forceRefresh: forceRefresh)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func handleApprove(_ request: MembershipRequest) async {
        await handleMembershipAction(request, action: .approve)
    }

    private func handleReject(_ request: MembershipRequest) async {
        await handleMembershipAction(request, action: .reject)
    }

    private func handleMembershipAction(_ request: MembershipRequest, action: MembershipAction) async {
        do {
            try await membershipSession.reviewRequest(familyId: family.familyId, userId: request.userId, action: action)

            // Refresh both members and requests to show updated state
            await loadMembers(forceRefresh: true)

        } catch {
            errorMessage = error.localizedDescription
        }
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

struct MembershipRequestRowView: View {
    let request: MembershipRequest
    let onApprove: () async -> Void
    let onReject: () async -> Void

    @State private var isProcessing = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(Color.orange.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.badge.plus")
                        .font(.title3)
                        .foregroundColor(.orange)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(request.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    // Request badge
                    Text("Request")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                }

                Text(request.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    // Request date
                    Text("Requested \(formatRequestDate(request.requestDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }

                // Action Buttons
                if !isProcessing {
                    HStack(spacing: 8) {
                        Button(action: {
                            Task {
                                isProcessing = true
                                await onApprove()
                                isProcessing = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Approve")
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            Task {
                                isProcessing = true
                                await onReject()
                                isProcessing = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Reject")
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                } else {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Processing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatRequestDate(_ dateString: String) -> String {
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
