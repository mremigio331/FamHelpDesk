import SwiftUI

struct TicketListView: View {
    let familyId: String
    let filters: TicketFilters

    @State private var viewModel: TicketListViewModel

    init(familyId: String, filters: TicketFilters = TicketFilters()) {
        self.familyId = familyId
        self.filters = filters
        _viewModel = State(initialValue: TicketListViewModel(familyId: familyId, filters: filters))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation toolbar
            NavigationToolbar(title: "Tickets")

            // Main content
            if viewModel.showLoadingState {
                // Initial loading state
                loadingView
            } else if viewModel.hasError {
                // Error state
                errorView
            } else if viewModel.showEmptyState {
                // Empty state
                emptyStateView
            } else {
                // Tickets list
                ticketsList
            }
        }
        .task {
            // Load tickets when view appears - only if not already loaded
            if viewModel.tickets.isEmpty, !viewModel.isLoading {
                await viewModel.loadTickets()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading tickets...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text(viewModel.errorType?.title ?? "Error")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(viewModel.errorType?.message ?? "An error occurred")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Action buttons
            HStack(spacing: 16) {
                if viewModel.errorType?.canRetry == true {
                    Button("Retry") {
                        Task {
                            await viewModel.retryLastOperation()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)
                }

                Button("Refresh") {
                    Task {
                        await viewModel.refresh()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "ticket")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("No Tickets")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("There are no tickets to display.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Refresh button
            Button("Refresh") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canRefresh)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Tickets List

    private var ticketsList: some View {
        List {
            // Tickets section
            Section {
                ForEach(viewModel.tickets) { ticket in
                    NavigationLink(destination: TicketDetailView(ticket: ticket)) {
                        TicketRowView(
                            ticket: ticket,
                            isSelected: ticket.ticketId == viewModel.selectedTicketId
                        )
                    }
                    .onAppear {
                        // Load more tickets when approaching the end
                        Task {
                            await viewModel.loadMoreIfNeeded(ticket)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Tickets (\(viewModel.tickets.count))")

                    Spacer()

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .scaleEffect(0.8)
                    }

                    // Show last refresh time if available
                    if let lastRefresh = viewModel.lastRefreshDate {
                        Text("Updated \(formatRelativeTime(lastRefresh))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Loading more indicator
            if viewModel.isLoadingMore {
                Section {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more tickets...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                }
            }

            // End of list indicator
            if !viewModel.hasMore, !viewModel.tickets.isEmpty {
                Section {
                    Text("No more tickets to load")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            }
        }
        .refreshable {
            // Pull-to-refresh
            await viewModel.refresh()
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Helper Methods

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Ticket Detail View Placeholder

struct TicketDetailView: View {
    let ticket: Ticket

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(ticket.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                if let description = ticket.description {
                    Text(description)
                        .font(.body)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Details")
                        .font(.headline)

                    DetailRow(label: "Status", value: ticket.status.rawValue)
                    DetailRow(label: "Severity", value: ticket.severity.displayName)
                    DetailRow(label: "Created", value: formatDate(ticket.creationDate))

                    if let assignedTo = ticket.assignedTo {
                        DetailRow(label: "Assigned To", value: assignedTo.name ?? assignedTo.id)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Ticket Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TicketListView(familyId: "family123")
    }
}

#Preview("Empty State") {
    NavigationStack {
        TicketListView(familyId: "empty-family")
    }
}

#Preview("Ticket Detail") {
    NavigationStack {
        TicketDetailView(
            ticket: Ticket(
                familyId: EntityRef(id: "family123", name: "Test Family"),
                groupId: EntityRef(id: "group123", name: "Support"),
                queueId: EntityRef(id: "queue123", name: "General"),
                ticketId: "ticket123",
                title: "Sample Ticket Title",
                description: "This is a detailed description of the ticket that explains the issue or request in detail.",
                severity: .sev2,
                status: .open,
                creationDate: Date().timeIntervalSince1970 - 3600,
                createdBy: "user123",
                lastUpdateTime: Date().timeIntervalSince1970,
                resolvedDate: nil,
                closedDate: nil,
                reopenUntil: nil,
                assignedTo: EntityRef(id: "user456", name: "John Doe"),
                isPrivate: false
            )
        )
    }
}
