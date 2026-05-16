import SwiftUI

struct GrabRequestListView: View {
    @Bindable var viewModel: FamGrabViewModel
    let familyId: String
    let filterStatus: GrabRequestStatus?
    let userRole: String?

    @State private var selectedStatusFilter: GrabRequestStatus?
    @State private var hasAppeared = false

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.requests.isEmpty {
                loadingView
            } else if viewModel.requests.isEmpty {
                emptyView
            } else {
                requestList
            }
        }
        .task {
            guard !hasAppeared else { return }
            hasAppeared = true
            await viewModel.loadRequests(
                familyId: familyId,
                status: filterStatus,
                userRole: userRole,
                refresh: true
            )
        }
    }

    private var requestList: some View {
        List {
            // Filter bar for "My Requests" tab
            if userRole != nil {
                statusFilterSection
            }

            ForEach(viewModel.requests) { request in
                NavigationLink(destination: GrabRequestDetailView(
                    viewModel: viewModel,
                    familyId: familyId,
                    requestId: request.requestId
                )) {
                    GrabRequestRow(request: request)
                }
                .onAppear {
                    if viewModel.shouldLoadMore(for: request) {
                        Task {
                            await viewModel.loadMoreRequests()
                        }
                    }
                }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.loadRequests(
                familyId: familyId,
                status: selectedStatusFilter ?? filterStatus,
                userRole: userRole,
                refresh: true
            )
        }
    }

    private var statusFilterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    GrabFilterChip(title: "All", isSelected: selectedStatusFilter == nil) {
                        selectedStatusFilter = nil
                        Task {
                            await viewModel.loadRequests(familyId: familyId, status: nil, userRole: userRole, refresh: true)
                        }
                    }

                    ForEach(GrabRequestStatus.allCases, id: \.self) { status in
                        GrabFilterChip(title: status.displayName, isSelected: selectedStatusFilter == status) {
                            selectedStatusFilter = status
                            Task {
                                await viewModel.loadRequests(familyId: familyId, status: status, userRole: userRole, refresh: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .listRowSeparator(.hidden)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading requests...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Requests")
                .font(.headline)

            Text(emptyMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyMessage: String {
        if filterStatus == .open {
            "No open requests right now. Create one to get started!"
        } else if userRole == "requestor" {
            "You haven't created any requests yet."
        } else {
            "No requests found."
        }
    }
}

// MARK: - Grab Request Row

struct GrabRequestRow: View {
    let request: GrabRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(request.requestorId.name ?? request.requestorId.id)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                StatusBadge(status: request.status)
            }

            HStack(spacing: 12) {
                Label("\(request.embolecCost.embolecFormatted) E", systemImage: "dollarsign.circle")
                    .font(.subheadline)
                    .foregroundColor(.orange)

                if let items = request.items, !items.isEmpty {
                    Label("\(items.count) item\(items.count == 1 ? "" : "s")", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(formatDate(request.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: GrabRequestStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.systemImage)
                .font(.caption2)
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .foregroundColor(statusColor)
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .open: .blue
        case .partiallyClaimed: .orange.opacity(0.7)
        case .claimed: .orange
        case .partiallyCompleted: .purple.opacity(0.7)
        case .completed: .purple
        case .confirmed: .green
        case .cancelled: .red
        }
    }
}

// MARK: - Grab Filter Chip

struct GrabFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        GrabRequestListView(
            viewModel: FamGrabViewModel(),
            familyId: "family-123",
            filterStatus: .open,
            userRole: nil
        )
    }
}
