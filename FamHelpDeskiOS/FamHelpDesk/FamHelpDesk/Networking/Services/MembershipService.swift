import Foundation

final class MembershipService {
    private let networkManager: NetworkManager

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    /// Fetches all members of a family
    /// - Parameter familyId: The ID of the family
    /// - Returns: Array of FamilyMember objects
    /// - Throws: NetworkError if the request fails
    func getFamilyMembers(familyId: String) async throws -> [FamilyMember] {
        let response: GetFamilyMembersResponse = try await networkManager.get(
            endpoint: APIEndpoint.getFamilyMembers(familyId: familyId).path
        )
        print("📱 Family Members Response: \(response.members.count) members")
        return response.members
    }

    /// Fetches pending membership requests for a family
    /// - Parameter familyId: The ID of the family
    /// - Returns: Array of MembershipRequest objects
    /// - Throws: NetworkError if the request fails
    func getFamilyMembershipRequests(familyId: String) async throws -> [MembershipRequest] {
        let response: GetMembershipRequestsResponse = try await networkManager.get(
            endpoint: APIEndpoint.getFamilyMembershipRequests(familyId: familyId).path
        )
        print("📱 Membership Requests Response: \(response.requests.count) requests")
        return response.requests
    }

    /// Reviews a membership request (approve or reject)
    /// - Parameters:
    ///   - requestId: The ID of the membership request
    ///   - action: The action to take (approve or reject)
    /// - Returns: ReviewMembershipResponse indicating success and updated request
    /// - Throws: NetworkError if the request fails
    func reviewMembershipRequest(requestId: String, action: MembershipAction) async throws -> ReviewMembershipResponse {
        let request = ReviewMembershipRequest(requestId: requestId, action: action)
        let response: ReviewMembershipResponse = try await networkManager.post(
            endpoint: APIEndpoint.reviewMembershipRequest(requestId: requestId).path,
            body: request
        )
        print("📱 Reviewed membership request: \(requestId) - \(action.rawValue)")
        return response
    }

    /// Requests membership to a family
    /// - Parameter familyId: The ID of the family to request membership for
    /// - Returns: RequestMembershipResponse containing the created request
    /// - Throws: NetworkError if the request fails
    func requestFamilyMembership(familyId: String) async throws -> RequestMembershipResponse {
        let request = RequestFamilyMembershipRequest(familyId: familyId)
        let response: RequestMembershipResponse = try await networkManager.post(
            endpoint: APIEndpoint.requestFamilyMembership(familyId: familyId).path,
            body: request
        )
        print("📱 Requested membership for family: \(familyId)")
        return response
    }
}
