import Foundation

@Observable
final class TicketSession {
    static let shared = TicketSession()

    private let ticketService = TicketService()

    var tickets: [Ticket] = []
    var nextToken: String?
    var hasMore = false
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?

    // Current filter state
    var currentFamilyId: String?
    var currentFilters: TicketFilters = .init()

    private init() {}

    // MARK: - Ticket Loading

    /// Loads initial tickets with pagination support
    /// - Parameters:
    ///   - familyId: The family ID to load tickets for
    ///   - filters: Optional filters to apply
    ///   - refresh: Whether this is a refresh operation (clears existing data)
    @MainActor
    func loadTickets(familyId: String, filters: TicketFilters = TicketFilters(), refresh: Bool = false) async {
        // Prevent multiple simultaneous loads
        guard !isLoading else { return }

        print("🎯 TicketSession.loadTickets called with:")
        print("   - familyId: \(familyId)")
        print("   - filters: queueId=\(filters.queueId ?? "nil"), groupId=\(filters.groupId ?? "nil"), assignedTo=\(filters.assignedTo ?? "nil"), status=\(filters.status?.rawValue ?? "nil"), severity=\(filters.severity?.rawValue.description ?? "nil")")
        print("   - refresh: \(refresh)")
        print("   - current tickets count: \(tickets.count)")
        print("   - current nextToken: \(nextToken ?? "nil")")

        isLoading = true
        errorMessage = nil

        // If refreshing or family changed, clear existing data
        if refresh || currentFamilyId != familyId {
            print("🔄 Clearing existing data (refresh=\(refresh), familyChanged=\(currentFamilyId != familyId))")
            tickets.removeAll()
            nextToken = nil
            hasMore = false
        }

        currentFamilyId = familyId
        currentFilters = filters

        do {
            print("🌐 Calling TicketService.getTickets...")
            let result = try await ticketService.getTickets(
                familyId: familyId,
                queueId: filters.queueId,
                groupId: filters.groupId,
                assignedTo: filters.assignedTo,
                status: filters.status?.rawValue,
                severity: filters.severity?.rawValue.description,
                limit: 25,
                nextToken: refresh ? nil : nextToken
            )

            if refresh {
                tickets = result.tickets
                print("🔄 Refreshed tickets: \(result.tickets.count) tickets loaded")
            } else {
                // Filter out duplicates before appending
                let existingTicketIds = Set(tickets.map(\.ticketId))
                let newTickets = result.tickets.filter { !existingTicketIds.contains($0.ticketId) }

                tickets.append(contentsOf: newTickets)
                print("➕ Appended tickets: \(newTickets.count) new tickets (filtered \(result.tickets.count - newTickets.count) duplicates), total now: \(tickets.count)")
            }

            nextToken = result.nextToken
            hasMore = result.hasMore

            print("✅ Loaded \(result.tickets.count) tickets for family \(familyId)")
            print("   - nextToken: \(result.nextToken ?? "nil")")
            print("   - hasMore: \(result.hasMore)")
            print("   - total tickets in session: \(tickets.count)")

        } catch {
            errorMessage = "Failed to load tickets: \(error.localizedDescription)"
            print("❌ Error loading tickets: \(error)")
            print("   - error type: \(type(of: error))")
            print("   - localized description: \(error.localizedDescription)")
            if let networkError = error as? NetworkError {
                print("   - network error details: \(networkError)")
            }
        }

        isLoading = false
        print("🏁 TicketSession.loadTickets completed (isLoading=\(isLoading))")
    }

    /// Loads more tickets (pagination)
    @MainActor
    func loadMoreTickets() async {
        // Only load more if we have more data and aren't already loading
        guard hasMore, !isLoadingMore, !isLoading, let familyId = currentFamilyId else { return }

        isLoadingMore = true

        do {
            let result = try await ticketService.getTickets(
                familyId: familyId,
                queueId: currentFilters.queueId,
                groupId: currentFilters.groupId,
                assignedTo: currentFilters.assignedTo,
                status: currentFilters.status?.rawValue,
                severity: currentFilters.severity?.rawValue.description,
                limit: 25,
                nextToken: nextToken
            )

            tickets.append(contentsOf: result.tickets)
            nextToken = result.nextToken
            hasMore = result.hasMore

            print("✅ Loaded \(result.tickets.count) more tickets")

        } catch {
            errorMessage = "Failed to load more tickets: \(error.localizedDescription)"
            print("❌ Error loading more tickets: \(error)")
        }

        isLoadingMore = false
    }

    /// Refreshes the current ticket list
    @MainActor
    func refreshTickets() async {
        guard let familyId = currentFamilyId else { return }
        await loadTickets(familyId: familyId, filters: currentFilters, refresh: true)
    }

    // MARK: - Ticket Operations

    /// Creates a new ticket and adds it to the list
    @MainActor
    func createTicket(request: CreateTicketRequest) async -> Bool {
        do {
            let newTicket = try await ticketService.createTicket(request: request)

            // Add to the beginning of the list (most recent first)
            tickets.insert(newTicket, at: 0)

            print("✅ Created ticket: \(newTicket.ticketId)")
            return true

        } catch {
            errorMessage = "Failed to create ticket: \(error.localizedDescription)"
            print("❌ Error creating ticket: \(error)")
            return false
        }
    }

    /// Updates a ticket and refreshes the list
    @MainActor
    func updateTicket(ticketId: String, request: UpdateTicketRequest) async -> Bool {
        do {
            let updatedTicket = try await ticketService.updateTicket(request: request)

            // Update the ticket in the list
            if let index = tickets.firstIndex(where: { $0.ticketId == ticketId }) {
                tickets[index] = updatedTicket
            }

            print("✅ Updated ticket: \(ticketId)")
            return true

        } catch {
            errorMessage = "Failed to update ticket: \(error.localizedDescription)"
            print("❌ Error updating ticket: \(error)")
            return false
        }
    }

    // MARK: - Helper Methods

    /// Checks if we should load more tickets when a ticket appears
    func shouldLoadMore(for ticket: Ticket) -> Bool {
        // Load more when we're near the end of the list
        guard hasMore, !isLoadingMore, !isLoading else { return false }

        // Find the index of the current ticket
        guard let index = tickets.firstIndex(where: { $0.ticketId == ticket.ticketId }) else { return false }

        // Load more when we're within 5 items of the end
        return index >= tickets.count - 5
    }

    /// Clears all data
    func clearData() {
        tickets.removeAll()
        nextToken = nil
        hasMore = false
        currentFamilyId = nil
        currentFilters = TicketFilters()
        errorMessage = nil
        print("🧹 TicketSession data cleared")
    }

    /// Clears error message
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Filter Model

struct TicketFilters {
    var queueId: String?
    var groupId: String?
    var assignedTo: String?
    var status: TicketStatus?
    var severity: TicketSeverity?

    init(
        queueId: String? = nil,
        groupId: String? = nil,
        assignedTo: String? = nil,
        status: TicketStatus? = nil,
        severity: TicketSeverity? = nil
    ) {
        self.queueId = queueId
        self.groupId = groupId
        self.assignedTo = assignedTo
        self.status = status
        self.severity = severity
    }
}
