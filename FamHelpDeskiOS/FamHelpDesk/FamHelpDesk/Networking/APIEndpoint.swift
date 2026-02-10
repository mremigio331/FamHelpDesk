import Foundation

enum APIEndpoint {
    // User endpoints
    case getProfile
    case getUserProfile(userId: String)
    case updateProfile

    // Family endpoints
    case getAllFamilies
    case getMyFamilies
    case getFamilyById(familyId: String)
    case createFamily
    case updateFamily(familyId: String)
    case getFamilyMembers(familyId: String)
    case getActiveFamilyMembers(familyId: String)
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
    case getNotificationSettings
    case updateNotificationSettings
    case getFamilyNotificationSettings(familyId: String)
    case updateFamilyNotificationSettings(familyId: String)

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

    // Ticket endpoints
    case getTickets(familyId: String)
    case searchTickets(familyId: String)
    case getTicket(familyId: String, ticketId: String)
    case getTicketById(ticketId: String)
    case createTicket
    case updateTicket

    // Comment endpoints
    case getComments
    case createComment
    case updateComment
    case deleteComment

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
        case let .getFamilyById(familyId):
            "/family/\(familyId)"
        case .createFamily:
            "/family"
        case let .updateFamily(familyId):
            "/family/\(familyId)"
        case let .getFamilyMembers(familyId):
            "/membership/\(familyId)/members"
        case let .getActiveFamilyMembers(familyId):
            "/membership/\(familyId)/active-members"
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
        case .getNotificationSettings:
            "/notifications/settings"
        case .updateNotificationSettings:
            "/notifications/settings"
        case let .getFamilyNotificationSettings(familyId):
            "/family/\(familyId)/notification-settings"
        case let .updateFamilyNotificationSettings(familyId):
            "/family/\(familyId)/notification-settings"
        case let .reviewMembershipRequest(familyId):
            "/membership/\(familyId)/review"
        case let .getGroupMembers(familyId, groupId):
            "/membership/\(familyId)/\(groupId)/members"
        case let .requestGroupMembership(familyId, groupId):
            "/membership/\(familyId)/\(groupId)/request"
        case let .addGroupMember(familyId, groupId):
            "/membership/\(familyId)/\(groupId)/members"
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
        case let .getTickets(familyId):
            "/ticket/tickets/\(familyId)"
        case let .searchTickets(familyId):
            "/ticket/tickets/\(familyId)/search"
        case let .getTicket(familyId, ticketId):
            "/ticket/\(ticketId)"
        case .createTicket:
            "/ticket/create"
        case .updateTicket:
            "/ticket/update"
        case .getComments:
            "/ticket/comment/get"
        case .createComment:
            "/ticket/comment/create"
        case .updateComment:
            "/ticket/comment/update"
        case .deleteComment:
            "/ticket/comment/delete"
        case let .getTicketById(ticketId: ticketId):
            "/ticket/\(ticketId)"
        }
    }
}
