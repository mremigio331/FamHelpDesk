import Foundation

@Observable
final class MembershipSession {
    static let shared = MembershipSession()

    var familyMembers: [String: [FamilyMember]] = [:]
    var membershipRequests: [String: [MembershipRequest]] = [:]
    var isFetching: Bool = false

    // Add timestamp tracking for stale time
    private var familyMembersTimestamps: [String: Date] = [:]
    private var membershipRequestsTimestamps: [String: Date] = [:]

    // Configurable stale time (default: 5 minutes)
    private let staleTimeInterval: TimeInterval = 5 * 60 // 5 minutes

    private let membershipService = MembershipService()

    private init() {}

    @MainActor
    func fetchFamilyMembers(familyId: String, forceRefresh: Bool = false) async throws {
        // Check if data is still fresh (not stale)
        if !forceRefresh, let timestamp = familyMembersTimestamps[familyId] {
            let timeSinceLastFetch = Date().timeIntervalSince(timestamp)
            if timeSinceLastFetch < staleTimeInterval {
                print("📱 Using cached family members (fetched \(Int(timeSinceLastFetch))s ago)")
                return // Data is still fresh, don't refetch
            }
        }

        isFetching = true

        do {
            let members = try await membershipService.getFamilyMembers(familyId: familyId)
            familyMembers[familyId] = members
            familyMembersTimestamps[familyId] = Date() // Update timestamp
            print("📱 Fetched fresh family members data")
        } catch {
            print("Error fetching family members: \(error)")
            throw error
        }

        isFetching = false
    }

    @MainActor
    func fetchMembershipRequests(familyId: String, forceRefresh: Bool = false) async throws {
        // Check if data is still fresh (not stale)
        if !forceRefresh, let timestamp = membershipRequestsTimestamps[familyId] {
            let timeSinceLastFetch = Date().timeIntervalSince(timestamp)
            if timeSinceLastFetch < staleTimeInterval {
                print("📱 Using cached membership requests (fetched \(Int(timeSinceLastFetch))s ago)")
                return // Data is still fresh, don't refetch
            }
        }

        isFetching = true

        do {
            let requests = try await membershipService.getFamilyMembershipRequests(familyId: familyId)
            membershipRequests[familyId] = requests
            membershipRequestsTimestamps[familyId] = Date() // Update timestamp
            print("📱 Fetched fresh membership requests data")
        } catch {
            print("Error fetching membership requests: \(error)")
            throw error
        }

        isFetching = false
    }

    @MainActor
    func reviewRequest(_ requestId: String, action: MembershipAction) async throws {
        do {
            let response = try await membershipService.reviewMembershipRequest(requestId: requestId, action: action)

            // Update the request in our local state if successful
            if response.success, let updatedRequest = response.updatedRequest {
                // Find and update the request in the appropriate family's requests
                for (familyId, requests) in membershipRequests {
                    if let index = requests.firstIndex(where: { $0.requestId == requestId }) {
                        var updatedRequests = requests
                        updatedRequests[index] = updatedRequest
                        membershipRequests[familyId] = updatedRequests

                        // Invalidate the timestamp to force refresh on next fetch
                        membershipRequestsTimestamps[familyId] = Date().addingTimeInterval(-staleTimeInterval - 1)
                        break
                    }
                }
            }
        } catch {
            print("Error reviewing membership request: \(error)")
            throw error
        }
    }

    // Helper method to check if data is stale
    func isFamilyMembersStale(familyId: String) -> Bool {
        guard let timestamp = familyMembersTimestamps[familyId] else { return true }
        return Date().timeIntervalSince(timestamp) >= staleTimeInterval
    }

    // Helper method to manually invalidate cache
    @MainActor
    func invalidateFamilyMembers(familyId: String) {
        familyMembersTimestamps[familyId] = Date().addingTimeInterval(-staleTimeInterval - 1)
    }

    @MainActor
    func clearFamilyData(familyId: String) {
        familyMembers.removeValue(forKey: familyId)
        membershipRequests.removeValue(forKey: familyId)
        familyMembersTimestamps.removeValue(forKey: familyId)
        membershipRequestsTimestamps.removeValue(forKey: familyId)
    }

    @MainActor
    func clearAllData() {
        familyMembers.removeAll()
        membershipRequests.removeAll()
        familyMembersTimestamps.removeAll()
        membershipRequestsTimestamps.removeAll()
    }
}
