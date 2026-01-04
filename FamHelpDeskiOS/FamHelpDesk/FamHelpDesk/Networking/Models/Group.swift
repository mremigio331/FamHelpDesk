import Foundation

struct FamilyGroup: Codable, Identifiable {
    let groupId: String
    let familyId: String
    let groupName: String
    let groupDescription: String?
    let createdBy: String
    let createdAt: String

    var id: String { groupId }
}

struct GroupMembership: Codable {
    let userId: String
    let familyId: String
    let groupId: String
    let status: String
    let joinedAt: String?
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

// MARK: - Enhanced Group Models

struct GroupMember: Codable, Identifiable {
    let userId: String
    let displayName: String
    let email: String
    let role: GroupRole
    let joinedAt: String
    
    var id: String { userId }
}

enum GroupRole: String, Codable {
    case member = "MEMBER"
    case admin = "ADMIN"
}

// MARK: - Additional Group Response Models

struct GetGroupMembersResponse: Codable {
    let members: [GroupMember]
}
