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

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "user_display_name"
        case email = "user_email"
        case status
        case isAdmin = "is_admin"
        case joinedAt = "request_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        displayName = try container.decode(String.self, forKey: .displayName)
        email = try container.decode(String.self, forKey: .email)
        status = try container.decode(MembershipStatus.self, forKey: .status)
        isAdmin = try container.decode(Bool.self, forKey: .isAdmin)

        // Handle the timestamp conversion
        let timestamp = try container.decode(TimeInterval.self, forKey: .joinedAt)
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = ISO8601DateFormatter()
        joinedAt = formatter.string(from: date)
    }
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
    let count: Int
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
