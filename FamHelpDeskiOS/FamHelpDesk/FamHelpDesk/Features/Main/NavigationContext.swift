import Foundation
import SwiftUI

/// Navigation context manager for handling deep linking and navigation state preservation
@Observable
final class NavigationContext {
    static let shared = NavigationContext()

    // MARK: - Navigation State

    /// Current navigation path for the main navigation stack
    var navigationPath = NavigationPath()

    /// Currently selected family (for context preservation)
    var selectedFamily: Family?

    /// Currently selected group (for context preservation)
    var selectedGroup: FamilyGroup?

    /// Current tab selection in family detail view
    var selectedFamilyTab: FamilyDetailView.Tab = .overview

    /// Navigation history for back navigation
    private var navigationHistory: [NavigationItem] = []

    /// Navigation breadcrumbs for better context tracking
    var navigationBreadcrumbs: [String] = []

    /// Whether navigation state should be preserved across app lifecycle
    var shouldPreserveState = true

    /// Last saved navigation timestamp for state validation
    private var lastSavedTimestamp: Date?

    /// Maximum age for preserved navigation state (24 hours)
    private let maxStateAge: TimeInterval = 24 * 60 * 60

    // MARK: - Deep Link Support

    /// Pending deep link to process when app becomes active
    var pendingDeepLink: DeepLink?

    /// Whether we're currently processing a deep link
    var isProcessingDeepLink = false

    /// Deep link processing queue for handling multiple deep links
    private var deepLinkQueue: [DeepLink] = []

    /// Whether the app is ready to process deep links
    var isReadyForDeepLinks = false

    // MARK: - App Lifecycle Support

    /// Whether the app is currently in background
    var isInBackground = false

    /// Timestamp when app went to background
    private var backgroundTimestamp: Date?

    private init() {
        setupAppLifecycleObservers()
    }

    // MARK: - Navigation Methods

    /// Navigate to a specific family
    func navigateToFamily(_ family: Family, tab: FamilyDetailView.Tab = .overview) {
        selectedFamily = family
        selectedFamilyTab = tab
        navigationPath.append(family)
        addToHistory(.family(family))
        updateBreadcrumbs(with: "Family: \(family.familyName)")
        saveNavigationState()
    }

    /// Navigate to a specific group
    func navigateToGroup(_ group: FamilyGroup) {
        selectedGroup = group
        navigationPath.append(group)
        addToHistory(.group(group))
        updateBreadcrumbs(with: "Group: \(group.groupName)")
        saveNavigationState()
    }

    /// Navigate to user profile
    func navigateToProfile() {
        addToHistory(.profile)
        updateBreadcrumbs(with: "Profile")
        saveNavigationState()
    }

    /// Navigate to notifications
    func navigateToNotifications() {
        addToHistory(.notifications)
        updateBreadcrumbs(with: "Notifications")
        saveNavigationState()
    }

    /// Navigate to family search
    func navigateToSearch() {
        addToHistory(.search)
        updateBreadcrumbs(with: "Search")
        saveNavigationState()
    }

    /// Pop to root navigation
    func popToRoot() {
        navigationPath.removeLast(navigationPath.count)
        selectedFamily = nil
        selectedGroup = nil
        selectedFamilyTab = .overview
        navigationHistory.removeAll()
        navigationBreadcrumbs.removeAll()
        saveNavigationState()
    }

    /// Pop one level back
    func popBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
            if !navigationHistory.isEmpty {
                navigationHistory.removeLast()
            }
            if !navigationBreadcrumbs.isEmpty {
                navigationBreadcrumbs.removeLast()
            }
        }

        // Update context based on remaining navigation
        updateContextFromPath()
        saveNavigationState()
    }

    /// Navigate back to a specific item in history
    func navigateBackTo(_ item: NavigationItem) {
        guard let index = navigationHistory.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        // Remove items after the target index
        let itemsToRemove = navigationHistory.count - index - 1
        if itemsToRemove > 0 {
            navigationPath.removeLast(itemsToRemove)
            navigationHistory.removeLast(itemsToRemove)
            navigationBreadcrumbs.removeLast(min(itemsToRemove, navigationBreadcrumbs.count))
        }

        updateContextFromPath()
        saveNavigationState()
    }

    /// Check if we can navigate back
    var canNavigateBack: Bool {
        !navigationHistory.isEmpty
    }

    /// Get current navigation depth
    var navigationDepth: Int {
        navigationHistory.count
    }

    // MARK: - Deep Link Processing

    /// Process a deep link URL
    func processDeepLink(_ url: URL) {
        guard let deepLink = DeepLink.from(url) else {
            print("❌ Invalid deep link URL: \(url)")
            return
        }

        if isReadyForDeepLinks, !isProcessingDeepLink {
            // Process immediately if ready
            pendingDeepLink = deepLink
            isProcessingDeepLink = true

            Task {
                await executeDeepLink(deepLink)
            }
        } else {
            // Queue for later processing
            deepLinkQueue.append(deepLink)
            print("🔗 Queued deep link for later processing: \(url)")
        }
    }

    /// Mark the app as ready to process deep links
    func setReadyForDeepLinks() {
        isReadyForDeepLinks = true

        // Process any queued deep links
        if !deepLinkQueue.isEmpty, !isProcessingDeepLink {
            let nextDeepLink = deepLinkQueue.removeFirst()
            processDeepLink(nextDeepLink.url)
        }
    }

    /// Execute a deep link navigation
    @MainActor
    private func executeDeepLink(_ deepLink: DeepLink) async {
        defer {
            isProcessingDeepLink = false
            pendingDeepLink = nil

            // Process next queued deep link if any
            if !deepLinkQueue.isEmpty {
                let nextDeepLink = deepLinkQueue.removeFirst()
                Task {
                    await executeDeepLink(nextDeepLink)
                }
            }
        }

        // Clear current navigation
        popToRoot()

        switch deepLink {
        case let .family(familyId, tab):
            await navigateToFamilyById(familyId, tab: tab)

        case let .group(familyId, groupId):
            await navigateToGroupById(familyId: familyId, groupId: groupId)

        case .profile:
            navigateToProfile()

        case .notifications:
            navigateToNotifications()

        case .search:
            navigateToSearch()
        }
    }

    /// Navigate to family by ID (for deep linking)
    @MainActor
    private func navigateToFamilyById(_ familyId: String, tab: FamilyDetailView.Tab) async {
        let familySession = FamilySession.shared

        // Try to find family in current session
        if let familyItem = familySession.myFamilies[familyId] {
            navigateToFamily(familyItem.family, tab: tab)
            return
        }

        // If not found, refresh families and try again
        await familySession.fetchMyFamilies()

        if let familyItem = familySession.myFamilies[familyId] {
            navigateToFamily(familyItem.family, tab: tab)
        } else {
            print("❌ Family not found for deep link: \(familyId)")
        }
    }

    /// Navigate to group by ID (for deep linking)
    @MainActor
    private func navigateToGroupById(familyId: String, groupId: String) async {
        // First navigate to family
        await navigateToFamilyById(familyId, tab: .groups)

        // Try to find group in cache first
        let groupSession = GroupSession.shared
        let cachedGroups = groupSession.getGroupsForFamily(familyId)

        if let group = cachedGroups.first(where: { $0.groupId == groupId }) {
            // Found in cache, navigate directly
            navigateToGroup(group)
        } else {
            // Not in cache, need to fetch groups for deep link
            print("🔗 Deep link requires loading groups for family: \(familyId)")
            await groupSession.fetchFamilyGroups(familyId: familyId)

            let groups = groupSession.getGroupsForFamily(familyId)
            if let group = groups.first(where: { $0.groupId == groupId }) {
                navigateToGroup(group)
            } else {
                print("❌ Group not found for deep link: \(groupId)")
            }
        }
    }

    // MARK: - State Preservation

    /// Save current navigation state
    func saveNavigationState() {
        guard shouldPreserveState else { return }

        let state = NavigationState(
            selectedFamilyId: selectedFamily?.familyId,
            selectedGroupId: selectedGroup?.groupId,
            selectedFamilyTab: selectedFamilyTab,
            navigationHistory: navigationHistory,
            navigationBreadcrumbs: navigationBreadcrumbs,
            timestamp: Date()
        )

        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: "NavigationState")
            lastSavedTimestamp = Date()
        }
    }

    /// Restore navigation state
    func restoreNavigationState() {
        guard shouldPreserveState else { return }

        guard let data = UserDefaults.standard.data(forKey: "NavigationState"),
              let state = try? JSONDecoder().decode(NavigationState.self, from: data)
        else {
            return
        }

        // Check if state is too old
        if let timestamp = state.timestamp,
           Date().timeIntervalSince(timestamp) > maxStateAge
        {
            print("🗑️ Navigation state too old, clearing")
            clearNavigationState()
            return
        }

        selectedFamilyTab = state.selectedFamilyTab
        navigationHistory = state.navigationHistory
        navigationBreadcrumbs = state.navigationBreadcrumbs
        lastSavedTimestamp = state.timestamp

        // Restore family and group context if available
        Task {
            await restoreNavigationContext(state)
        }
    }

    /// Clear saved navigation state
    func clearNavigationState() {
        UserDefaults.standard.removeObject(forKey: "NavigationState")
        lastSavedTimestamp = nil
    }

    /// Restore navigation context from saved state
    @MainActor
    private func restoreNavigationContext(_ state: NavigationState) async {
        let familySession = FamilySession.shared

        // Restore family context
        if let familyId = state.selectedFamilyId {
            await familySession.fetchMyFamilies()
            if let familyItem = familySession.myFamilies[familyId] {
                selectedFamily = familyItem.family
            }
        }

        // Restore group context - but don't automatically load groups
        // Groups will be loaded when user actually navigates to them
        if let groupId = state.selectedGroupId,
           let familyId = state.selectedFamilyId
        {
            // Just store the IDs for later use, don't fetch groups automatically
            print("📝 Restored group context: familyId=\(familyId), groupId=\(groupId) (groups will load when needed)")

            // Only set selectedGroup if we already have the groups cached
            let groupSession = GroupSession.shared
            let cachedGroups = groupSession.getGroupsForFamily(familyId)
            selectedGroup = cachedGroups.first(where: { $0.groupId == groupId })
        }
    }

    // MARK: - App Lifecycle Support

    /// Setup app lifecycle observers
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillResignActive()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidBecomeActive()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidEnterBackground()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillEnterForeground()
        }
    }

    /// Handle app will resign active
    private func handleAppWillResignActive() {
        saveNavigationState()
    }

    /// Handle app did become active
    private func handleAppDidBecomeActive() {
        setReadyForDeepLinks()
    }

    /// Handle app entering background
    private func handleAppDidEnterBackground() {
        isInBackground = true
        backgroundTimestamp = Date()
        saveNavigationState()
    }

    /// Handle app entering foreground
    private func handleAppWillEnterForeground() {
        isInBackground = false

        // Check if app was in background for too long
        if let backgroundTime = backgroundTimestamp,
           Date().timeIntervalSince(backgroundTime) > maxStateAge
        {
            // Clear navigation state if app was backgrounded too long
            popToRoot()
            clearNavigationState()
        }

        backgroundTimestamp = nil
    }

    // MARK: - Private Methods

    private func addToHistory(_ item: NavigationItem) {
        navigationHistory.append(item)

        // Limit history size
        if navigationHistory.count > 20 {
            navigationHistory.removeFirst()
        }
    }

    private func updateBreadcrumbs(with title: String) {
        navigationBreadcrumbs.append(title)

        // Limit breadcrumbs size
        if navigationBreadcrumbs.count > 10 {
            navigationBreadcrumbs.removeFirst()
        }
    }

    private func updateContextFromPath() {
        // Update selected family and group based on current navigation history

        // Find the most recent family in history
        for item in navigationHistory.reversed() {
            if case let .family(family) = item {
                selectedFamily = family
                break
            }
        }

        // Find the most recent group in history
        for item in navigationHistory.reversed() {
            if case let .group(group) = item {
                selectedGroup = group
                break
            }
        }

        // If no family found in history, clear family context
        if !navigationHistory.contains(where: { if case .family = $0 { return true }; return false }) {
            selectedFamily = nil
            selectedFamilyTab = .overview
        }

        // If no group found in history, clear group context
        if !navigationHistory.contains(where: { if case .group = $0 { return true }; return false }) {
            selectedGroup = nil
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

enum NavigationItem: Codable, Identifiable {
    case family(Family)
    case group(FamilyGroup)
    case profile
    case notifications
    case search

    var id: String {
        switch self {
        case let .family(family):
            "family-\(family.familyId)"
        case let .group(group):
            "group-\(group.groupId)"
        case .profile:
            "profile"
        case .notifications:
            "notifications"
        case .search:
            "search"
        }
    }

    var displayName: String {
        switch self {
        case let .family(family):
            family.familyName
        case let .group(group):
            group.groupName
        case .profile:
            "Profile"
        case .notifications:
            "Notifications"
        case .search:
            "Search"
        }
    }
}

enum DeepLink {
    case family(String, FamilyDetailView.Tab)
    case group(familyId: String, groupId: String)
    case profile
    case notifications
    case search

    var url: URL {
        var components = URLComponents()
        components.scheme = "famhelpdesk"

        switch self {
        case let .family(familyId, tab):
            components.path = "/family"
            components.queryItems = [
                URLQueryItem(name: "id", value: familyId),
                URLQueryItem(name: "tab", value: tab.rawValue),
            ]
        case let .group(familyId, groupId):
            components.path = "/group"
            components.queryItems = [
                URLQueryItem(name: "familyId", value: familyId),
                URLQueryItem(name: "groupId", value: groupId),
            ]
        case .profile:
            components.path = "/profile"
        case .notifications:
            components.path = "/notifications"
        case .search:
            components.path = "/search"
        }

        return components.url ?? URL(string: "famhelpdesk://")!
    }

    static func from(_ url: URL) -> DeepLink? {
        guard url.scheme == "famhelpdesk" else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = components?.path ?? ""
        let queryItems = components?.queryItems ?? []

        switch path {
        case "/family":
            guard let familyId = queryItems.first(where: { $0.name == "id" })?.value else {
                return nil
            }

            let tabString = queryItems.first(where: { $0.name == "tab" })?.value ?? "overview"
            let tab = FamilyDetailView.Tab(rawValue: tabString) ?? .overview

            return .family(familyId, tab)

        case "/group":
            guard let familyId = queryItems.first(where: { $0.name == "familyId" })?.value,
                  let groupId = queryItems.first(where: { $0.name == "groupId" })?.value
            else {
                return nil
            }

            return .group(familyId: familyId, groupId: groupId)

        case "/profile":
            return .profile

        case "/notifications":
            return .notifications

        case "/search":
            return .search

        default:
            return nil
        }
    }
}

struct NavigationState: Codable {
    let selectedFamilyId: String?
    let selectedGroupId: String?
    let selectedFamilyTab: FamilyDetailView.Tab
    let navigationHistory: [NavigationItem]
    let navigationBreadcrumbs: [String]
    let timestamp: Date?

    init(selectedFamilyId: String?, selectedGroupId: String?, selectedFamilyTab: FamilyDetailView.Tab, navigationHistory: [NavigationItem], navigationBreadcrumbs: [String] = [], timestamp: Date? = nil) {
        self.selectedFamilyId = selectedFamilyId
        self.selectedGroupId = selectedGroupId
        self.selectedFamilyTab = selectedFamilyTab
        self.navigationHistory = navigationHistory
        self.navigationBreadcrumbs = navigationBreadcrumbs
        self.timestamp = timestamp
    }
}

// MARK: - Extensions

extension FamilyDetailView.Tab: Codable {
    // Already conforms to Codable through RawRepresentable
}
