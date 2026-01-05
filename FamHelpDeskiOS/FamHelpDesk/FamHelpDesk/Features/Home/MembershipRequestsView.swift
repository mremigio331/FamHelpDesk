import SwiftUI

struct MembershipRequestsView: View {
    let family: Family
    @State private var membershipSession = MembershipSession.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAlert = false

    private var membershipRequests: [MembershipRequest] {
        membershipSession.membershipRequests[family.familyId] ?? []
    }

    private var pendingRequests: [MembershipRequest] {
        membershipRequests.filter { $0.status == .pending || $0.status == .awaiting }
    }

    var body: some View {
        Group {
            if isLoading, membershipRequests.isEmpty {
                loadingView
            } else if pendingRequests.isEmpty {
                emptyStateView
            } else {
                requestsList
            }
        }
        .refreshable {
            await fetchMembershipRequests(forceRefresh: true)
        }
        .task {
            await fetchMembershipRequests()
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading membership requests...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Pending Requests")
                .font(.headline)
                .foregroundColor(.primary)

            Text("There are currently no pending membership requests for this family.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var requestsList: some View {
        List {
            Section {
                ForEach(pendingRequests) { request in
                    MembershipRequestRow(
                        request: request,
                        onApprove: { await handleApprove(request) },
                        onReject: { await handleReject(request) }
                    )
                }
            } header: {
                HStack {
                    Text("Pending Requests")
                    Spacer()
                    Text("\(pendingRequests.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func fetchMembershipRequests(forceRefresh: Bool = false) async {
        do {
            isLoading = true
            try await membershipSession.fetchMembershipRequests(
                familyId: family.familyId,
                forceRefresh: forceRefresh
            )
        } catch {
            errorMessage = error.localizedDescription
            showingAlert = true
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

            // Refresh the requests list to show updated state
            await fetchMembershipRequests(forceRefresh: true)

        } catch {
            errorMessage = error.localizedDescription
            showingAlert = true
        }
    }
}

struct MembershipRequestRow: View {
    let request: MembershipRequest
    let onApprove: () async -> Void
    let onReject: () async -> Void

    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(request.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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

                Text("Requested \(formatDate(request.requestDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }

            // Action Buttons
            if request.status == .pending || request.status == .awaiting, !isProcessing {
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
            } else if isProcessing {
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

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption)
            Text(request.status.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(6)
    }

    private var statusIcon: String {
        switch request.status {
        case .pending:
            "clock.circle.fill"
        case .approved:
            "checkmark.circle.fill"
        case .rejected:
            "xmark.circle.fill"
        case .awaiting:
            "clock.circle.fill" // Same as pending
        }
    }

    private var statusColor: Color {
        switch request.status {
        case .pending:
            .orange
        case .approved:
            .green
        case .rejected:
            .red
        case .awaiting:
            .orange // Same as pending
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

#Preview {
    NavigationStack {
        MembershipRequestsView(
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
