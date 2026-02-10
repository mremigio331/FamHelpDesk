import Combine
import Foundation
import SwiftUI

/// Coordinator for handling navigation from push notifications
final class NavigationCoordinator: ObservableObject {
    static let shared = NavigationCoordinator()

    private let navigationContext = NavigationContext.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupNotificationObserver()
    }

    // MARK: - Setup

    /// Set up observer for notification navigation events
    private func setupNotificationObserver() {
        Foundation.NotificationCenter.default.publisher(for: Foundation.Notification.Name.navigateFromNotification)
            .compactMap { $0.userInfo?["payload"] as? NotificationNavigationPayload }
            .sink { [weak self] payload in
                self?.handleNavigationPayload(payload)
            }
            .store(in: &cancellables)
    }

    // MARK: - Navigation Handling

    /// Handle navigation from notification payload
    private func handleNavigationPayload(_ payload: NotificationNavigationPayload) {
        print("🧭 [NavigationCoordinator] Handling navigation for type: \(payload.notificationType)")

        Task { @MainActor in
            // Determine navigation based on notification type
            switch payload.notificationType {
            // Ticket notifications
            case "Ticket Assigned", "Ticket Comment", "Ticket Status Changed", "Ticket Resolved":
                await navigateToTicket(payload)

            case "Family Ticket Creation", "Group Ticket Creation":
                await navigateToTickets(payload)

            // Group notifications
            case "Group Membership Approved", "Group Membership Denied", "Group Membership Added",
                 "Group Membership Accepted", "Group Member left", "Group Membership Request",
                 "New Group Creation":
                await navigateToGroup(payload)

            // Family notifications
            case "Family Membership Approved", "Family Membership Denied", "Family Membership Invitation",
                 "Family Membership Accepted", "Family Member left", "Family Membership Request",
                 "New Family Member", "Welcome to Family", "New Family Created":
                await navigateToFamily(payload)

            // Welcome notification
            case "Welcome":
                // Navigate to home/profile
                navigationContext.popToRoot()

            default:
                print("⚠️ [NavigationCoordinator] Unknown notification type: \(payload.notificationType)")
                // Default to notifications view
                navigationContext.navigateToNotifications()
            }
        }
    }

    // MARK: - Specific Navigation Methods

    /// Navigate to a specific ticket
    @MainActor
    private func navigateToTicket(_ payload: NotificationNavigationPayload) async {
        guard let ticketId = payload.ticketId,
              let familyId = payload.familyId
        else {
            print("⚠️ [NavigationCoordinator] Missing ticket or family ID")
            return
        }

        // Navigate to family tickets tab first
        await navigateToFamilyById(familyId, tab: .tickets)

        // TODO: Once ticket detail view is accessible, navigate to specific ticket
        // For now, just navigate to tickets list
        print("🎫 [NavigationCoordinator] Navigated to tickets for family: \(familyId), ticket: \(ticketId)")
    }

    /// Navigate to tickets list for a family
    @MainActor
    private func navigateToTickets(_ payload: NotificationNavigationPayload) async {
        guard let familyId = payload.familyId else {
            print("⚠️ [NavigationCoordinator] Missing family ID")
            return
        }

        await navigateToFamilyById(familyId, tab: .tickets)
        print("🎫 [NavigationCoordinator] Navigated to tickets for family: \(familyId)")
    }

    /// Navigate to a specific group
    @MainActor
    private func navigateToGroup(_ payload: NotificationNavigationPayload) async {
        guard let groupId = payload.groupId,
              let familyId = payload.familyId
        else {
            print("⚠️ [NavigationCoordinator] Missing group or family ID")
            return
        }

        // First navigate to family groups tab
        await navigateToFamilyById(familyId, tab: .groups)

        // Then navigate to specific group
        let groupSession = GroupSession.shared

        // Try to find group in cache first
        let cachedGroups = groupSession.getGroupsForFamily(familyId)

        if let group = cachedGroups.first(where: { $0.groupId == groupId }) {
            navigationContext.navigateToGroup(group)
            print("👥 [NavigationCoordinator] Navigated to group: \(groupId)")
        } else {
            // Not in cache, fetch groups
            await groupSession.fetchFamilyGroups(familyId: familyId)

            let groups = groupSession.getGroupsForFamily(familyId)
            if let group = groups.first(where: { $0.groupId == groupId }) {
                navigationContext.navigateToGroup(group)
                print("👥 [NavigationCoordinator] Navigated to group: \(groupId)")
            } else {
                print("❌ [NavigationCoordinator] Group not found: \(groupId)")
            }
        }
    }

    /// Navigate to a specific family
    @MainActor
    private func navigateToFamily(_ payload: NotificationNavigationPayload) async {
        guard let familyId = payload.familyId else {
            print("⚠️ [NavigationCoordinator] Missing family ID")
            return
        }

        await navigateToFamilyById(familyId, tab: .overview)
        print("👨‍👩‍👧‍👦 [NavigationCoordinator] Navigated to family: \(familyId)")
    }

    // MARK: - Helper Methods

    /// Navigate to family by ID
    @MainActor
    private func navigateToFamilyById(_ familyId: String, tab: FamilyDetailView.Tab) async {
        let familySession = FamilySession.shared

        // Try to find family in current session
        if let familyItem = familySession.myFamilies[familyId] {
            navigationContext.navigateToFamily(familyItem.family, tab: tab)
            return
        }

        // If not found, refresh families and try again
        await familySession.fetchMyFamilies()

        if let familyItem = familySession.myFamilies[familyId] {
            navigationContext.navigateToFamily(familyItem.family, tab: tab)
        } else {
            print("❌ [NavigationCoordinator] Family not found: \(familyId)")
        }
    }
}
