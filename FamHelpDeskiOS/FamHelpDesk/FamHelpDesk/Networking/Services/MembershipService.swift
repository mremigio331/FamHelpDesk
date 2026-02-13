import Foundation

final class MembershipService {
    private let networkManager: NetworkManager
    private let retryHelper = RetryHelper()

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    /// Fetches all members of a family with enhanced error handling
    /// - Parameter familyId: The ID of the family
    /// - Returns: Array of FamilyMember objects
    /// - Throws: ServiceError with structured error information
    func getFamilyMembers(familyId: String) async throws -> [FamilyMember] {
        do {
            // Get the raw data
            let rawData = try await networkManager.getRawData(
                endpoint: APIEndpoint.getFamilyMembers(familyId: familyId).path
            )

            // Decode the response (don't use convertFromSnakeCase since we have explicit CodingKeys)
            let decoder = JSONDecoder()
            let response = try decoder.decode(GetFamilyMembersResponse.self, from: rawData)

            print("📱 Family Members Response: \(response.members.count) members")
            return response.members
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching family members: \(serviceError)")
            throw serviceError
        }
    }

    /// Fetches active family members for ticket assignment with enhanced error handling
    /// - Parameter familyId: The ID of the family
    /// - Returns: Array of ActiveFamilyMember objects optimized for ticket assignment
    /// - Throws: ServiceError with structured error information
    func getActiveFamilyMembers(familyId: String) async throws -> [ActiveFamilyMember] {
        do {
            // Get the raw data
            let rawData = try await networkManager.getRawData(
                endpoint: APIEndpoint.getActiveFamilyMembers(familyId: familyId).path
            )

            // Decode the response
            let decoder = JSONDecoder()
            let response = try decoder.decode(GetActiveFamilyMembersResponse.self, from: rawData)

            print("📱 Active Family Members Response: \(response.members.count) members")
            return response.members
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching active family members: \(serviceError)")
            throw serviceError
        }
    }

    /// Fetches pending membership requests for a family with enhanced error handling
    /// - Parameter familyId: The ID of the family
    /// - Returns: Array of MembershipRequest objects
    /// - Throws: ServiceError with structured error information
    func getFamilyMembershipRequests(familyId: String) async throws -> [MembershipRequest] {
        do {
            // Get the raw data
            let rawData = try await networkManager.getRawData(
                endpoint: APIEndpoint.getFamilyMembershipRequests(familyId: familyId).path
            )

            // Decode the response
            let decoder = JSONDecoder()
            let response = try decoder.decode(GetMembershipRequestsResponse.self, from: rawData)

            print("📱 Membership Requests Response: \(response.requests.count) requests")
            return response.requests
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching membership requests: \(serviceError)")
            throw serviceError
        }
    }

    /// Reviews a membership request (approve or reject) with enhanced error handling
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - userId: The ID of the user requesting membership
    ///   - action: The action to take (approve or reject)
    /// - Throws: ServiceError with structured error information
    func reviewMembershipRequest(familyId: String, userId: String, action: MembershipAction) async throws {
        let approve = action == .approve
        let request = ReviewMembershipRequest(familyId: familyId, targetUserId: userId, approve: approve)

        do {
            // We don't need to parse the response, just check that the request succeeds (2xx status)
            _ = try await networkManager.putRawData(
                endpoint: APIEndpoint.reviewMembershipRequest(familyId: familyId).path,
                body: request
            )

            print("📱 Successfully reviewed membership request: \(userId) in family \(familyId) - \(action.rawValue)")
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error reviewing membership request: \(serviceError)")
            throw serviceError
        }
    }

    /// Requests membership to a family with enhanced error handling
    /// - Parameter familyId: The ID of the family to request membership for
    /// - Throws: ServiceError with structured error information
    func requestFamilyMembership(familyId: String) async throws {
        let request = RequestFamilyMembershipRequest(familyId: familyId)

        do {
            // We don't need to parse the response, just check that the request succeeds (2xx status)
            _ = try await networkManager.postRawData(
                endpoint: APIEndpoint.requestFamilyMembership(familyId: familyId).path,
                body: request
            )

            print("📱 Successfully requested membership for family: \(familyId)")
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error requesting family membership: \(serviceError)")
            throw serviceError
        }
    }

    /// Updates a family member's admin role with enhanced error handling
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - targetUserId: The ID of the user whose role should be updated
    ///   - isAdmin: Whether the user should be an admin
    /// - Throws: ServiceError with structured error information
    func updateFamilyMemberRole(familyId: String, targetUserId: String, isAdmin: Bool) async throws {
        let request = UpdateFamilyMemberRoleRequest(targetUserId: targetUserId, isAdmin: isAdmin)

        do {
            _ = try await networkManager.putRawData(
                endpoint: APIEndpoint.updateFamilyMemberRole(familyId: familyId).path,
                body: request
            )

            print("📱 Successfully updated role for user \(targetUserId) in family \(familyId) to admin=\(isAdmin)")
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error updating family member role: \(serviceError)")
            throw serviceError
        }
    }

    /// Removes a member from a family with enhanced error handling
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - targetUserId: The ID of the user to remove
    /// - Throws: ServiceError with structured error information
    func removeFamilyMember(familyId: String, targetUserId: String) async throws {
        do {
            _ = try await networkManager.deleteRawData(
                endpoint: APIEndpoint.removeFamilyMember(familyId: familyId, targetUserId: targetUserId).path
            )

            print("📱 Successfully removed user \(targetUserId) from family \(familyId)")
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error removing family member: \(serviceError)")
            throw serviceError
        }
    }

    /// Fetches all members of a group with enhanced error handling
    /// - Parameters:
    ///   - familyId: The ID of the family containing the group
    ///   - groupId: The ID of the group
    /// - Returns: Array of GroupMember objects
    /// - Throws: ServiceError with structured error information
    func getGroupMembers(familyId: String, groupId: String) async throws -> [GroupMember] {
        do {
            // Get the raw data
            let rawData = try await networkManager.getRawData(
                endpoint: APIEndpoint.getGroupMembers(familyId: familyId, groupId: groupId).path
            )

            // Decode the response
            let decoder = JSONDecoder()
            let response = try decoder.decode(GetGroupMembersResponse.self, from: rawData)

            print("📱 Group Members Response: \(response.members.count) members")
            return response.members
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching group members: \(serviceError)")
            throw serviceError
        }
    }
}
