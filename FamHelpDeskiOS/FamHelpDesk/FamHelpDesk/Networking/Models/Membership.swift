import Foundation

// MARK: - Membership Models

struct FamilyMember: Codable, Identifiable {
    let userId: String
    let displayName: String
    let email: String
    let status: MembershipStatus
    let isAdmin: Bool
    let joinedAt: String
    
    var id: String { userId }
}

struct MembershipRequest: Codable, Identifiable {
    let requestId: String
    let userId: String
    let familyId: String
    let displayName: String
    let email: String
    let status: RequestStatus
    let requestDate: String
    
    var id: String { requestId }
}

enum MembershipStatus: String, Codable {
    case member = "MEMBER"
    case pending = "PENDING"
    case rejected = "REJECTED"
}

enum RequestStatus: String, Codable {
    case pending = "PENDING"
    case approved = "APPROVED"
    case rejected = "REJECTED"
}

enum MembershipAction: String, Codable {
    case approve = "APPROVE"
    case reject = "REJECT"
}

// MARK: - Membership Response Models

struct GetFamilyMembersResponse: Codable {
    let members: [FamilyMember]
}

struct GetMembershipRequestsResponse: Codable {
    let requests: [MembershipRequest]
}

struct ReviewMembershipResponse: Codable {
    let success: Bool
    let message: String?
    let updatedRequest: MembershipRequest?
}

struct RequestMembershipResponse: Codable {
    let request: MembershipRequest
    let message: String?
}

// MARK: - Membership Request Models

struct ReviewMembershipRequest: Codable {
    let requestId: String
    let action: MembershipAction
}

struct RequestFamilyMembershipRequest: Codable {
    let familyId: String
}