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
    
    // Task management for cancellation
    private var currentLoadTask: Task<Void, Never>?
    private var currentLoadMoreTask: Task<Void, Never>?
    
    // Debounce mechanism to prevent rapid successive calls
    private var lastLoadTime: Date = .distantPast
    private let minimumLoadInterval: TimeInterval = 0.5 // 500ms minimum between loads

    private init() {}

    // MARK: - Ticket Loading

    /// Loads initial tickets with pagination support
    /// - Parameters:
    ///   - familyId: The family ID to load tickets for
    ///   - filters: Optional filters to apply
    ///   - refresh: Whether this is a refresh operation (clears existing data)
    @MainActor
    func loadTickets(familyId: String, filters: TicketFilters = TicketFilters(), refresh: Bool = false) async {
        // Cancel any existing load task
        currentLoadTask?.cancel()
        
        // Create new task for this load operation
        currentLoadTask = Task {
            await performLoadTickets(familyId: familyId, filters: filters, refresh: refresh)
        }
        
        await currentLoadTask?.value
    }
    
    /// Internal method that performs the actual loading
    @MainActor
    private func performLoadTickets(familyId: String, filters: TicketFilters, refresh: Bool) async {
        // Check if task was cancelled before starting
        guard !Task.isCancelled else {
            print("🚫 Load tickets task was cancelled before starting")
            return
        }
        
        // Debounce: prevent rapid successive calls unless it's a refresh
        let now = Date()
        if !refresh && now.timeIntervalSince(lastLoadTime) < minimumLoadInterval {
            print("🚫 Load tickets debounced - too soon since last call")
            return
        }
        lastLoadTime = now
        
        // Prevent multiple simultaneous loads
        guard !isLoading else { 
            print("🚫 Already loading tickets, skipping")
            return 
        }

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
            // Check if task was cancelled before making network request
            guard !Task.isCancelled else {
                print("🚫 Load tickets task was cancelled before network request")
                isLoading = false
                return
            }
            
            print("🌐 Calling TicketService.searchTickets...")

            // Convert filter sets to arrays of values
            let queueIds: [String]? = filters.queueId != nil ? [filters.queueId!] : nil

            let groupIds: [String]? = {
                if let groupIds = filters.groupIds, !groupIds.isEmpty {
                    return Array(groupIds)
                } else if let groupId = filters.groupId {
                    return [groupId]
                }
                return nil
            }()

            let assignedToUsers: [String]? = {
                if let assignedToUsers = filters.assignedToUsers, !assignedToUsers.isEmpty {
                    return Array(assignedToUsers)
                } else if let assignedTo = filters.assignedTo {
                    return [assignedTo]
                }
                return nil
            }()

            let statusValues: [String]? = {
                if let statuses = filters.statuses, !statuses.isEmpty {
                    return Array(statuses).map(\.rawValue)
                } else if let status = filters.status {
                    return [status.rawValue]
                }
                return nil
            }()

            let severityValues: [Double]? = {
                if let severities = filters.severities, !severities.isEmpty {
                    return Array(severities).map(\.rawValue)
                } else if let severity = filters.severity {
                    return [severity.rawValue]
                }
                return nil
            }()

            let result = try await ticketService.searchTickets(
                familyId: familyId,
                queueIds: queueIds,
                groupIds: groupIds,
                assignedToUsers: assignedToUsers,
                statuses: statusValues,
                severities: severityValues,
                limit: 25,
                nextToken: refresh ? nil : nextToken
            )

            // Check if task was cancelled after network request
            guard !Task.isCancelled else {
                print("🚫 Load tickets task was cancelled after network request")
                isLoading = false
                return
            }

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
            // Don't show cancellation errors to the user
            if Task.isCancelled {
                print("🚫 Load tickets task was cancelled during execution")
            } else {
                errorMessage = "Failed to load tickets: \(error.localizedDescription)"
                print("❌ Error loading tickets: \(error)")
                print("   - error type: \(type(of: error))")
                print("   - localized description: \(error.localizedDescription)")
                if let networkError = error as? NetworkError {
                    print("   - network error details: \(networkError)")
                }
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

        // Cancel any existing load more task
        currentLoadMoreTask?.cancel()
        
        // Create new task for this load more operation
        currentLoadMoreTask = Task {
            await performLoadMoreTickets(familyId: familyId)
        }
        
        await currentLoadMoreTask?.value
    }
    
    /// Internal method that performs the actual load more operation
    @MainActor
    private func performLoadMoreTickets(familyId: String) async {
        // Check if task was cancelled before starting
        guard !Task.isCancelled else {
            print("🚫 Load more tickets task was cancelled before starting")
            return
        }

        isLoadingMore = true

        do {
            // Check if task was cancelled before making network request
            guard !Task.isCancelled else {
                print("🚫 Load more tickets task was cancelled before network request")
                isLoadingMore = false
                return
            }
            
            // Convert filter sets to arrays of values
            let queueIds: [String]? = currentFilters.queueId != nil ? [currentFilters.queueId!] : nil

            let groupIds: [String]? = {
                if let groupIds = currentFilters.groupIds, !groupIds.isEmpty {
                    return Array(groupIds)
                } else if let groupId = currentFilters.groupId {
                    return [groupId]
                }
                return nil
            }()

            let assignedToUsers: [String]? = {
                if let assignedToUsers = currentFilters.assignedToUsers, !assignedToUsers.isEmpty {
                    return Array(assignedToUsers)
                } else if let assignedTo = currentFilters.assignedTo {
                    return [assignedTo]
                }
                return nil
            }()

            let statusValues: [String]? = {
                if let statuses = currentFilters.statuses, !statuses.isEmpty {
                    return Array(statuses).map(\.rawValue)
                } else if let status = currentFilters.status {
                    return [status.rawValue]
                }
                return nil
            }()

            let severityValues: [Double]? = {
                if let severities = currentFilters.severities, !severities.isEmpty {
                    return Array(severities).map(\.rawValue)
                } else if let severity = currentFilters.severity {
                    return [severity.rawValue]
                }
                return nil
            }()

            let result = try await ticketService.searchTickets(
                familyId: familyId,
                queueIds: queueIds,
                groupIds: groupIds,
                assignedToUsers: assignedToUsers,
                statuses: statusValues,
                severities: severityValues,
                limit: 25,
                nextToken: nextToken
            )

            // Check if task was cancelled after network request
            guard !Task.isCancelled else {
                print("🚫 Load more tickets task was cancelled after network request")
                isLoadingMore = false
                return
            }

            tickets.append(contentsOf: result.tickets)
            nextToken = result.nextToken
            hasMore = result.hasMore

            print("✅ Loaded \(result.tickets.count) more tickets")

        } catch {
            // Don't show cancellation errors to the user
            if Task.isCancelled {
                print("🚫 Load more tickets task was cancelled during execution")
            } else {
                errorMessage = "Failed to load more tickets: \(error.localizedDescription)"
                print("❌ Error loading more tickets: \(error)")
            }
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

            // Optimistic update - add to the beginning of the list (most recent first)
            addTicketToCache(newTicket, at: 0)

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

            // Optimistic update - update the ticket in cache
            updateTicketInCache(updatedTicket)
            
            // Also invalidate the cache to ensure fresh data (like last_update_time)
            // This ensures the ticket list is fully up-to-date when navigating back
            await invalidateTickets()

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
        // Cancel any ongoing tasks
        currentLoadTask?.cancel()
        currentLoadMoreTask?.cancel()
        
        tickets.removeAll()
        nextToken = nil
        hasMore = false
        currentFamilyId = nil
        currentFilters = TicketFilters()
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        print("🧹 TicketSession data cleared")
    }

    /// Clears error message
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Cache Invalidation (React Query Style)
    
    /// Invalidates and refetches tickets for the current family/filters
    @MainActor
    func invalidateTickets() async {
        guard let familyId = currentFamilyId else { return }
        await loadTickets(familyId: familyId, filters: currentFilters, refresh: true)
    }
    
    /// Invalidates tickets for a specific family (useful when switching contexts)
    @MainActor
    func invalidateTickets(for familyId: String, filters: TicketFilters = TicketFilters()) async {
        await loadTickets(familyId: familyId, filters: filters, refresh: true)
    }
    
    /// Invalidates all ticket data and clears cache
    @MainActor
    func invalidateAllTickets() async {
        clearData()
        if let familyId = currentFamilyId {
            await loadTickets(familyId: familyId, filters: currentFilters, refresh: true)
        }
    }
    
    /// Optimistically updates a ticket in the cache (like React Query's setQueryData)
    @MainActor
    func updateTicketInCache(_ updatedTicket: Ticket) {
        if let index = tickets.firstIndex(where: { $0.ticketId == updatedTicket.ticketId }) {
            tickets[index] = updatedTicket
            print("🔄 Optimistically updated ticket in cache: \(updatedTicket.ticketId)")
        }
    }
    
    /// Adds a new ticket to the cache optimistically
    @MainActor
    func addTicketToCache(_ newTicket: Ticket, at position: Int = 0) {
        tickets.insert(newTicket, at: position)
        print("➕ Optimistically added ticket to cache: \(newTicket.ticketId)")
    }
    
    /// Removes a ticket from the cache optimistically
    @MainActor
    func removeTicketFromCache(ticketId: String) {
        tickets.removeAll { $0.ticketId == ticketId }
        print("🗑️ Optimistically removed ticket from cache: \(ticketId)")
    }
}

// MARK: - Filter Model

struct TicketFilters {
    var queueId: String?
    var groupId: String?
    var assignedTo: String?
    var status: TicketStatus?
    var severity: TicketSeverity?
    var statuses: Set<TicketStatus>?
    var severities: Set<TicketSeverity>?
    var groupIds: Set<String>?
    var assignedToUsers: Set<String>?
    var searchQuery: String?

    init(
        queueId: String? = nil,
        groupId: String? = nil,
        assignedTo: String? = nil,
        status: TicketStatus? = nil,
        severity: TicketSeverity? = nil,
        statuses: Set<TicketStatus>? = [.open], // Default to open tickets only
        severities: Set<TicketSeverity>? = nil,
        groupIds: Set<String>? = nil,
        assignedToUsers: Set<String>? = nil,
        searchQuery: String? = nil
    ) {
        self.queueId = queueId
        self.groupId = groupId
        self.assignedTo = assignedTo
        self.status = status
        self.severity = severity
        self.statuses = statuses
        self.severities = severities
        self.groupIds = groupIds
        self.assignedToUsers = assignedToUsers
        self.searchQuery = searchQuery
    }

    // Computed properties for backward compatibility
    var hasActiveFilters: Bool {
        // Don't count "open only" as an active filter since it's the default
        let hasNonDefaultStatuses = statuses != [.open]
        
        return queueId != nil ||
            groupId != nil ||
            assignedTo != nil ||
            status != nil ||
            severity != nil ||
            hasNonDefaultStatuses ||
            !(severities?.isEmpty ?? true) ||
            !(groupIds?.isEmpty ?? true) ||
            !(assignedToUsers?.isEmpty ?? true) ||
            !isSearchQueryEmpty
    }

    var isSearchQueryEmpty: Bool {
        searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }
    
    /// Returns true if this is the default filter (only open tickets)
    var isDefaultFilter: Bool {
        queueId == nil &&
        groupId == nil &&
        assignedTo == nil &&
        status == nil &&
        severity == nil &&
        statuses == [.open] &&
        severities == nil &&
        groupIds == nil &&
        assignedToUsers == nil &&
        isSearchQueryEmpty
    }
}
