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
