import Foundation

enum APIEndpoint {
    // User endpoints
    case getProfile
    case getUserProfile(userId: String)
    case updateProfile

    // Family endpoints
    case getAllFamilies
    case getMyFamilies
    case createFamily
    case getFamilyMembers(familyId: String)
    case getFamilyMembershipRequests(familyId: String)
    case requestFamilyMembership(familyId: String)

    // Group endpoints
    case getAllGroups(familyId: String)
    case getMyGroups
    case createGroup
    case updateGroup(groupId: String)
    case deleteGroup(groupId: String)

    // Notification endpoints
    case getNotifications
    case acknowledgeNotification(notificationId: String)
    case acknowledgeAllNotifications
    case getUnreadCount

    // Membership endpoints
    case reviewMembershipRequest(familyId: String)
    case getGroupMembers(familyId: String, groupId: String)
    case requestGroupMembership(familyId: String, groupId: String)
    case addGroupMember(familyId: String, groupId: String)
    case removeGroupMember(familyId: String, groupId: String, userId: String)
    case getGroupMembershipRequests(familyId: String, groupId: String)
    case updateGroupMemberRole(familyId: String, groupId: String, userId: String)
    case getGroupMembersWithRoles(familyId: String, groupId: String)

    // Queue endpoints
    case getAllQueues(familyId: String, groupId: String?)
    case createQueue
    case updateQueue
    case deleteQueue(familyId: String, groupId: String, queueId: String)
    case getQueueMembers(queueId: String)
    case assignQueueMember(queueId: String)
    case removeQueueMember(queueId: String, userId: String)

    // Search endpoints
    case searchFamilies

    var path: String {
        switch self {
        case .getProfile:
            "/user/profile"
        case let .getUserProfile(userId):
            "/user/profile/\(userId)"
        case .updateProfile:
            "/user/profile"
        case .getAllFamilies:
            "/family"
        case .getMyFamilies:
            "/family/mine"
        case .createFamily:
            "/family"
        case let .getFamilyMembers(familyId):
            "/membership/\(familyId)/members"
        case let .getFamilyMembershipRequests(familyId):
            "/membership/\(familyId)/requests"
        case let .requestFamilyMembership(familyId):
            "/membership/\(familyId)/request"
        case let .getAllGroups(familyId):
            "/group/\(familyId)"
        case .getMyGroups:
            "/group/mine"
        case .createGroup:
            "/group"
        case let .updateGroup(groupId):
            "/group/\(groupId)"
        case let .deleteGroup(groupId):
            "/group/\(groupId)"
        case .getNotifications:
            "/notifications"
        case let .acknowledgeNotification(notificationId):
            "/notifications/\(notificationId)/acknowledge"
        case .acknowledgeAllNotifications:
            "/notifications/acknowledge-all"
        case .getUnreadCount:
            "/notifications/unread"
        case let .reviewMembershipRequest(familyId):
            "/membership/\(familyId)/review"
        case let .getGroupMembers(familyId, groupId):
            "/membership/\(familyId)/\(groupId)/members"
        case let .requestGroupMembership(familyId, groupId):
            "/membership/\(familyId)/\(groupId)/request"
        case let .addGroupMember(familyId, groupId):
            "/membership/\(familyId)/\(groupId)/add"
        case let .removeGroupMember(familyId, groupId, userId):
            "/membership/\(familyId)/\(groupId)/remove/\(userId)"
        case let .getGroupMembershipRequests(familyId, groupId):
            "/membership/\(familyId)/\(groupId)/requests"
        case let .updateGroupMemberRole(familyId, groupId, userId):
            "/membership/\(familyId)/\(groupId)/role/\(userId)"
        case let .getGroupMembersWithRoles(familyId, groupId):
            "/membership/\(familyId)/\(groupId)/members-with-roles"
        case let .getAllQueues(familyId, groupId):
            if let groupId {
                "/queue/\(familyId)/\(groupId)"
            } else {
                "/queue/\(familyId)"
            }
        case .createQueue:
            "/queue/create"
        case .updateQueue:
            "/queue/update"
        case let .deleteQueue(familyId, groupId, queueId):
            "/queue/\(familyId)/\(groupId)/\(queueId)"
        case let .getQueueMembers(queueId):
            "/queue/\(queueId)/members"
        case let .assignQueueMember(queueId):
            "/queue/\(queueId)/members"
        case let .removeQueueMember(queueId, userId):
            "/queue/\(queueId)/members/\(userId)"
        case .searchFamilies:
            "/family/search"
        }
    }
}
