import Combine
import Foundation
import UIKit

/// Manages family-scoped data including users, groups, and tickets
/// Provides centralized state management with caching and automatic refresh
@MainActor
class FamilyDataStore: ObservableObject {
    // MARK: - Published Properties

    /// List of family members (users)
    @Published var users: [UserProfile] = []

    /// List of groups in the current family
    @Published var groups: [FamilyGroup] = []

    /// List of tickets in the current family
    @Published var tickets: [Ticket] = []

    /// Loading state indicator
    @Published var isLoading: Bool = false

    /// Current error state, if any
    @Published var error: ServiceError?

    // MARK: - Family Context

    /// Current family ID with observer to trigger data reload
    var currentFamilyId: String? {
        didSet {
            if currentFamilyId != oldValue {
                Task {
                    await handleFamilyContextChange()
                }
            }
        }
    }

    // MARK: - Cache Management

    /// Timestamp of last successful data fetch
    private var lastCacheUpdate: Date?

    /// Cache validity duration (5 minutes)
    private let cacheValidityDuration: TimeInterval = 300

    // MARK: - Data Loaders

    private let userLoader: UserLoader
    private let groupLoader: GroupLoader
    private let ticketLoader: TicketLoader

    // MARK: - Initialization

    init(
        userLoader: UserLoader = UserLoader(),
        groupLoader: GroupLoader = GroupLoader(),
        ticketLoader: TicketLoader = TicketLoader()
    ) {
        self.userLoader = userLoader
        self.groupLoader = groupLoader
        self.ticketLoader = ticketLoader

        setupAppLifecycleObservers()
    }

    // MARK: - App Lifecycle Observers

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func handleAppWillEnterForeground() {
        Task {
            await checkCacheAndRefresh()
        }
    }

    // MARK: - Cache Validation

    /// Check if the current cache is still valid
    private func isCacheValid() -> Bool {
        guard let lastUpdate = lastCacheUpdate else {
            return false
        }

        let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
        return timeSinceUpdate < cacheValidityDuration
    }

    /// Check cache validity and refresh if expired
    private func checkCacheAndRefresh() async {
        guard !isCacheValid() else {
            return
        }

        await loadFamilyData()
    }

    // MARK: - Data Loading

    /// Load all family data concurrently
    func loadFamilyData() async {
        guard let familyId = currentFamilyId else {
            return
        }

        // Set loading state
        isLoading = true
        error = nil

        do {
            // Fetch all three data types concurrently using async let
            async let usersResult = userLoader.fetchUsers(familyId: familyId)
            async let groupsResult = groupLoader.fetchGroups(familyId: familyId)
            async let ticketsResult = ticketLoader.fetchTickets(familyId: familyId)

            // Await all results
            let (fetchedUsers, fetchedGroups, fetchedTickets) = try await (usersResult, groupsResult, ticketsResult)

            // Update published properties on successful fetch
            users = fetchedUsers
            groups = fetchedGroups
            tickets = fetchedTickets

            // Update cache timestamp
            lastCacheUpdate = Date()

            // Clear loading state
            isLoading = false

        } catch {
            // Handle errors and set error state
            isLoading = false
            self.error = mapToServiceError(error)
        }
    }

    // MARK: - Family Context Management

    /// Handle family context change by clearing and reloading data
    private func handleFamilyContextChange() async {
        // Clear previous family data
        users = []
        groups = []
        tickets = []
        error = nil
        lastCacheUpdate = nil

        // Trigger loadFamilyData for new family
        await loadFamilyData()
    }

    // MARK: - Cache Management Methods

    /// Clear all cached data
    func clearCache() {
        // Implementation will be added in task 7.4
    }

    // MARK: - Retry

    /// Retry loading data after an error
    func retry() async {
        // Implementation will be added in task 7.6
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Placeholder Loaders

/// Placeholder for UserLoader - will be implemented in task 4.1
class UserLoader {
    func fetchUsers(familyId _: String) async throws -> [UserProfile] {
        // Placeholder implementation
        []
    }
}

/// Placeholder for GroupLoader - will be implemented in task 4.2
class GroupLoader {
    func fetchGroups(familyId _: String) async throws -> [FamilyGroup] {
        // Placeholder implementation
        []
    }
}

/// Placeholder for TicketLoader - will be implemented in task 4.3
class TicketLoader {
    func fetchTickets(familyId _: String) async throws -> [Ticket] {
        // Placeholder implementation
        []
    }
}
