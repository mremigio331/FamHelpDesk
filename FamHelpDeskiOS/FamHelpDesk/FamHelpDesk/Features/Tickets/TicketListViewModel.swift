import Foundation
import Observation
import SwiftUI

@Observable
final class TicketListViewModel {
    private let ticketSession = TicketSession.shared

    var familyId: String
    var filters: TicketFilters

    // Selection and navigation state
    var selectedTicketId: String?
    var isNavigatingToDetail = false

    // Enhanced loading states
    var isInitialLoading = false
    var isRefreshing = false
    var lastRefreshDate: Date?

    // Error handling state
    var hasError = false
    var errorType: TicketListError?

    // Search state
    var searchText = ""
    var isSearching = false
    private var searchTask: Task<Void, Never>?

    // Computed properties from session
    var tickets: [Ticket] {
        var filteredTickets = ticketSession.tickets

        // Apply client-side status filtering
        if let statuses = filters.statuses, !statuses.isEmpty {
            filteredTickets = filteredTickets.filter { ticket in
                statuses.contains(ticket.status)
            }
        } else if let status = filters.status {
            filteredTickets = filteredTickets.filter { ticket in
                ticket.status == status
            }
        }

        // Apply client-side severity filtering
        if let severities = filters.severities, !severities.isEmpty {
            filteredTickets = filteredTickets.filter { ticket in
                severities.contains(ticket.severity)
            }
        } else if let severity = filters.severity {
            filteredTickets = filteredTickets.filter { ticket in
                ticket.severity == severity
            }
        }

        // Apply client-side group filtering
        if let groupId = filters.groupId {
            filteredTickets = filteredTickets.filter { ticket in
                ticket.groupId.id == groupId
            }
        }

        // Apply client-side search filtering
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filteredTickets = filteredTickets.filter { ticket in
                searchMatches(ticket: ticket, query: searchText)
            }
        }

        return filteredTickets
    }

    var isLoading: Bool { ticketSession.isLoading }
    var isLoadingMore: Bool { ticketSession.isLoadingMore }
    var hasMore: Bool { ticketSession.hasMore }
    var errorMessage: String? { ticketSession.errorMessage }

    // Computed properties for UI state
    var isEmpty: Bool { tickets.isEmpty && !isLoading }
    var showEmptyState: Bool { isEmpty && !hasError }
    var showLoadingState: Bool { isLoading && tickets.isEmpty }
    var canRefresh: Bool { !isLoading && !isLoadingMore }
    var canLoadMore: Bool { hasMore && !isLoading && !isLoadingMore }
    var showSearchEmptyState: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            tickets.isEmpty &&
            !isLoading &&
            !hasError
    }

    init(familyId: String, filters: TicketFilters = TicketFilters()) {
        self.familyId = familyId
        self.filters = filters
    }

    // MARK: - Public Methods

    /// Loads initial tickets with enhanced state management
    @MainActor
    func loadTickets() async {
        guard !isLoading else {
            print("🚫 TicketListViewModel.loadTickets: Already loading, skipping")
            return
        }

        // Check if we already have data for this family and filters
        if ticketSession.currentFamilyId == familyId,
           ticketSession.currentFilters.queueId == filters.queueId,
           ticketSession.currentFilters.groupId == filters.groupId,
           !tickets.isEmpty
        {
            print("📋 TicketListViewModel.loadTickets: Data already loaded for this context, skipping")
            return
        }

        print("🎯 TicketListViewModel.loadTickets: Starting load for familyId=\(familyId)")
        isInitialLoading = true
        clearError()

        await ticketSession.loadTickets(familyId: familyId, filters: filters)

        isInitialLoading = false
        handleLoadingResult()
    }

    /// Refreshes the ticket list (pull-to-refresh) with enhanced state management
    @MainActor
    func refresh() async {
        guard canRefresh else { return }

        isRefreshing = true
        clearError()

        await ticketSession.loadTickets(familyId: familyId, filters: filters, refresh: true)

        isRefreshing = false
        lastRefreshDate = Date()
        handleLoadingResult()
    }

    /// Loads more tickets if needed (infinite scroll) with enhanced logic
    @MainActor
    func loadMoreIfNeeded(_ ticket: Ticket) async {
        guard canLoadMore else { return }

        // Enhanced logic: load more when we're within 3 items of the end
        guard let index = tickets.firstIndex(where: { $0.ticketId == ticket.ticketId }),
              index >= tickets.count - 3 else { return }

        await ticketSession.loadMoreTickets()
        handleLoadingResult()
    }

    /// Updates filters and reloads tickets with state management
    @MainActor
    func updateFilters(_ newFilters: TicketFilters) async {
        guard !isLoading else { return }

        filters = newFilters
        clearError()
        clearSelection()

        await ticketSession.loadTickets(familyId: familyId, filters: filters, refresh: true)
        handleLoadingResult()
    }

    // MARK: - Selection and Navigation

    /// Selects a ticket and manages navigation state
    func selectTicket(_ ticket: Ticket) {
        selectedTicketId = ticket.ticketId
        isNavigatingToDetail = true
    }

    /// Clears ticket selection
    func clearSelection() {
        selectedTicketId = nil
        isNavigatingToDetail = false
    }

    /// Called when navigation to detail completes
    func didNavigateToDetail() {
        isNavigatingToDetail = false
    }

    /// Gets the currently selected ticket
    var selectedTicket: Ticket? {
        guard let selectedTicketId else { return nil }
        return tickets.first { $0.ticketId == selectedTicketId }
    }

    // MARK: - Error Handling

    /// Enhanced error handling with specific error types
    private func handleLoadingResult() {
        if let errorMessage = ticketSession.errorMessage {
            hasError = true
            errorType = determineErrorType(from: errorMessage)
        } else {
            hasError = false
            errorType = nil
        }
    }

    /// Determines the type of error for better user experience
    private func determineErrorType(from message: String) -> TicketListError {
        let lowercaseMessage = message.lowercased()

        if lowercaseMessage.contains("network") || lowercaseMessage.contains("connection") {
            return .networkError
        } else if lowercaseMessage.contains("unauthorized") || lowercaseMessage.contains("authentication") {
            return .authenticationError
        } else if lowercaseMessage.contains("timeout") {
            return .timeoutError
        } else {
            return .genericError(message)
        }
    }

    /// Clears error state
    func clearError() {
        hasError = false
        errorType = nil
        ticketSession.clearError()
    }

    /// Retries the last failed operation
    @MainActor
    func retryLastOperation() async {
        clearError()

        if tickets.isEmpty {
            await loadTickets()
        } else {
            await refresh()
        }
    }

    // MARK: - Ticket Operations

    /// Creates a new ticket with enhanced state management
    @MainActor
    func createTicket(_ request: CreateTicketRequest) async -> Bool {
        let success = await ticketSession.createTicket(request: request)

        if success {
            // Select the newly created ticket (it should be at index 0)
            if let newTicket = tickets.first {
                selectTicket(newTicket)
            }
        } else {
            handleLoadingResult()
        }

        return success
    }

    /// Updates an existing ticket with enhanced state management
    @MainActor
    func updateTicket(ticketId: String, request: UpdateTicketRequest) async -> Bool {
        let success = await ticketSession.updateTicket(ticketId: ticketId, request: request)

        if !success {
            handleLoadingResult()
        }

        return success
    }

    // MARK: - Utility Methods

    /// Gets the index of a ticket in the list
    func index(of ticket: Ticket) -> Int? {
        tickets.firstIndex { $0.ticketId == ticket.ticketId }
    }

    /// Checks if a ticket is the last in the list
    func isLastTicket(_ ticket: Ticket) -> Bool {
        guard let index = index(of: ticket) else { return false }
        return index == tickets.count - 1
    }

    /// Gets tickets by status for filtering
    func tickets(with status: TicketStatus) -> [Ticket] {
        tickets.filter { $0.status == status }
    }

    /// Gets tickets by severity for filtering
    func tickets(with severity: TicketSeverity) -> [Ticket] {
        tickets.filter { $0.severity == severity }
    }

    // MARK: - Search Methods

    /// Updates search text with debouncing
    @MainActor
    func updateSearchText(_ newText: String) {
        searchText = newText

        // Cancel previous search task
        searchTask?.cancel()

        // If search is empty, clear immediately
        if newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            isSearching = false
            return
        }

        // Debounce search with 300ms delay
        searchTask = Task {
            isSearching = true

            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            if !Task.isCancelled {
                isSearching = false
            }
        }
    }

    /// Clears search text and results
    @MainActor
    func clearSearch() {
        searchTask?.cancel()
        searchText = ""
        isSearching = false
    }

    /// Checks if a ticket matches the search query
    private func searchMatches(ticket: Ticket, query: String) -> Bool {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !searchQuery.isEmpty else { return true }

        // Search in title
        if ticket.title.lowercased().contains(searchQuery) {
            return true
        }

        // Search in description
        if let description = ticket.description,
           description.lowercased().contains(searchQuery)
        {
            return true
        }

        return false
    }

    /// Gets highlighted text for search results
    func highlightedText(for text: String, query: String) -> AttributedString {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !searchQuery.isEmpty else {
            return AttributedString(text)
        }

        var attributedString = AttributedString(text)

        // Find all occurrences of the search query (case-insensitive)
        let lowercaseText = text.lowercased()
        let lowercaseQuery = searchQuery.lowercased()

        var searchRange = lowercaseText.startIndex

        while let range = lowercaseText.range(of: lowercaseQuery, range: searchRange ..< lowercaseText.endIndex) {
            // Convert String.Index to AttributedString.Index
            let startIndex = AttributedString.Index(range.lowerBound, within: attributedString)
            let endIndex = AttributedString.Index(range.upperBound, within: attributedString)

            if let startIndex, let endIndex {
                attributedString[startIndex ..< endIndex].backgroundColor = Color.yellow
                attributedString[startIndex ..< endIndex].foregroundColor = Color.black
            }

            searchRange = range.upperBound
        }

        return attributedString
    }
}

// MARK: - Error Types

enum TicketListError: Identifiable, Equatable {
    case networkError
    case authenticationError
    case timeoutError
    case genericError(String)

    var id: String {
        switch self {
        case .networkError: "network"
        case .authenticationError: "auth"
        case .timeoutError: "timeout"
        case let .genericError(message): "generic-\(message.hashValue)"
        }
    }

    var title: String {
        switch self {
        case .networkError: "Network Error"
        case .authenticationError: "Authentication Error"
        case .timeoutError: "Request Timeout"
        case .genericError: "Error"
        }
    }

    var message: String {
        switch self {
        case .networkError:
            "Please check your internet connection and try again."
        case .authenticationError:
            "Your session has expired. Please log in again."
        case .timeoutError:
            "The request took too long to complete. Please try again."
        case let .genericError(message):
            message
        }
    }

    var canRetry: Bool {
        switch self {
        case .networkError, .timeoutError, .genericError:
            true
        case .authenticationError:
            false
        }
    }
}
