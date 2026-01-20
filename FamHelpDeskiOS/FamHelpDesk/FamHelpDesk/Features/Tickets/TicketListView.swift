import SwiftUI

struct TicketListView: View {
    let familyId: String
    let filters: TicketFilters

    @State private var viewModel: TicketListViewModel
    @State private var showCreateTicket = false
    @State private var showFilterView = false

    init(familyId: String, filters: TicketFilters = TicketFilters()) {
        self.familyId = familyId
        self.filters = filters
        _viewModel = State(initialValue: TicketListViewModel(familyId: familyId, filters: filters))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation toolbar with create button
            HStack {
                HStack {
                    NavigationToolbar(title: "Tickets")
                }

                Spacer()

                // Filter button
                Button(action: {
                    showFilterView = true
                }) {
                    Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(hasActiveFilters ? .blue : .primary)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())

                // Create ticket button with plus icon
                Button(action: {
                    showCreateTicket = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .padding(.trailing)
            }
            .frame(height: 44) // Standard navigation bar height

            // Search bar
            searchBar

            // Main content
            if viewModel.showLoadingState {
                // Initial loading state
                loadingView
            } else if viewModel.hasError {
                // Error state
                errorView
            } else if viewModel.showSearchEmptyState {
                // Search empty state
                searchEmptyStateView
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
        .sheet(isPresented: $showCreateTicket) {
            TicketFormView(
                mode: .create(familyId: familyId),
                onSuccess: { _ in
                    // Add the new ticket to the list and refresh
                    Task {
                        await viewModel.refresh()
                    }
                }
            )
        }
        .sheet(isPresented: $showFilterView) {
            FilterView(
                currentFilters: viewModel.filters,
                familyId: familyId,
                onApplyFilters: { newFilters in
                    Task {
                        await viewModel.updateFilters(newFilters)
                    }
                },
                onClearFilters: {
                    Task {
                        await viewModel.updateFilters(TicketFilters())
                    }
                }
            )
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))

                TextField("Search tickets...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: viewModel.searchText) { _, newValue in
                        viewModel.updateSearchText(newValue)
                    }

                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
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

            if viewModel.isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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

                Text("There are no tickets to display. Create your first ticket to get started.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Action buttons
            HStack(spacing: 16) {
                Button("Create Ticket") {
                    showCreateTicket = true
                }
                .buttonStyle(.borderedProminent)

                Button("Refresh") {
                    Task {
                        await viewModel.refresh()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canRefresh)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Search Empty State View

    private var searchEmptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("No Results Found")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("No tickets match your search for \"\(viewModel.searchText)\". Try adjusting your search terms.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Action buttons
            HStack(spacing: 16) {
                Button("Clear Search") {
                    viewModel.clearSearch()
                }
                .buttonStyle(.borderedProminent)

                Button("Create Ticket") {
                    showCreateTicket = true
                }
                .buttonStyle(.bordered)
            }
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
                            isSelected: ticket.ticketId == viewModel.selectedTicketId,
                            searchQuery: viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : viewModel.searchText
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

                    // Plus button next to Tickets title
                    Button(action: {
                        showCreateTicket = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }

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

    private var hasActiveFilters: Bool {
        viewModel.filters.hasActiveFilters
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
                createdBy: EntityRef(id: "user123", name: "Test User"),
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
