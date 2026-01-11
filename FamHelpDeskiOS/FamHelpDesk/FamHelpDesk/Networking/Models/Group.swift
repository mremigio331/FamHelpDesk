import Foundation

struct FamilyGroup: Codable, Identifiable, Hashable {
    let groupId: String
    let familyId: String
    let groupName: String
    let groupDescription: String?
    let createdBy: String
    let creationDate: TimeInterval

    var id: String { groupId }

    var createdAt: String {
        let date = Date(timeIntervalSince1970: creationDate)
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case familyId = "family_id"
        case groupName = "group_name"
        case groupDescription = "group_description"
        case createdBy = "created_by"
        case creationDate = "creation_date"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(groupId)
    }

    static func == (lhs: FamilyGroup, rhs: FamilyGroup) -> Bool {
        lhs.groupId == rhs.groupId
    }
}

struct GroupMembership: Codable {
    let userId: String
    let familyId: String
    let groupId: String
    let status: String
    let joinedAt: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case familyId = "family_id"
        case groupId = "group_id"
        case status
        case joinedAt = "joined_at"
    }
}

struct MyGroupItem: Codable {
    let group: FamilyGroup
    let membership: GroupMembership
}

struct GetAllGroupsResponse: Codable {
    let groups: [FamilyGroup]
}

struct GetMyGroupsResponse: Codable {
    let groups: [String: MyGroupItem]
}

struct CreateGroupRequest: Codable {
    let familyId: String
    let groupName: String
    let groupDescription: String?
}

struct CreateGroupResponse: Codable {
    let group: FamilyGroup
}

struct UpdateGroupRequest: Codable {
    let groupName: String?
    let groupDescription: String?
}

struct UpdateGroupResponse: Codable {
    let group: FamilyGroup
}

struct DeleteGroupResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - Group Member Models

struct GroupMember: Codable, Identifiable {
    let familyId: String
    let groupId: String
    let userId: String
    let status: String
    let isAdmin: Bool
    let requestDate: TimeInterval
    let userDisplayName: String?
    let userEmail: String?

    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case groupId = "group_id"
        case userId = "user_id"
        case status
        case isAdmin = "is_admin"
        case requestDate = "request_date"
        case userDisplayName = "user_display_name"
        case userEmail = "user_email"
    }
}

struct GetGroupMembersResponse: Codable {
    let members: [GroupMember]
    let count: Int
}

// MARK: - Group Membership Request/Response Models

struct GroupMembershipRequest: Codable {
    let familyId: String
    let groupId: String
}

struct GroupMembershipResponse: Codable {
    let success: Bool
    let message: String
}

struct AddGroupMemberRequest: Codable {
    let familyId: String
    let groupId: String
    let userId: String
    let isAdmin: Bool
}

struct GroupMembershipRequestItem: Codable, Identifiable {
    let familyId: String
    let groupId: String
    let userId: String
    let status: String
    let requestDate: TimeInterval
    let userDisplayName: String?
    let userEmail: String?

    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case groupId = "group_id"
        case userId = "user_id"
        case status
        case requestDate = "request_date"
        case userDisplayName = "user_display_name"
        case userEmail = "user_email"
    }
}

struct GetGroupMembershipRequestsResponse: Codable {
    let requests: [GroupMembershipRequestItem]
    let count: Int
}

struct UpdateGroupMemberRoleRequest: Codable {
    let isAdmin: Bool
}

struct GroupMemberWithRole: Codable, Identifiable {
    let familyId: String
    let groupId: String
    let userId: String
    let status: String
    let isAdmin: Bool
    let joinedAt: String?
    let userDisplayName: String?
    let userEmail: String?

    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case groupId = "group_id"
        case userId = "user_id"
        case status
        case isAdmin = "is_admin"
        case joinedAt = "joined_at"
        case userDisplayName = "user_display_name"
        case userEmail = "user_email"
    }
}

struct GetGroupMembersWithRolesResponse: Codable {
    let members: [GroupMemberWithRole]
    let count: Int
}
