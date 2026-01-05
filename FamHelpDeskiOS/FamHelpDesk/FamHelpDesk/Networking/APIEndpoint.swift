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
    case getGroupMembers(groupId: String)

    // Notification endpoints
    case getNotifications
    case acknowledgeNotification(notificationId: String)
    case acknowledgeAllNotifications
    case getUnreadCount

    // Membership endpoints
    case reviewMembershipRequest(requestId: String)

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
            "/membership/\(familyId)/membership-requests"
        case let .requestFamilyMembership(familyId):
            "/membership/\(familyId)/request"
        case let .getAllGroups(familyId):
            "/group/\(familyId)"
        case .getMyGroups:
            "/group/mine"
        case .createGroup:
            "/group"
        case let .getGroupMembers(groupId):
            "/group/\(groupId)/members"
        case .getNotifications:
            "/notifications"
        case let .acknowledgeNotification(notificationId):
            "/notifications/\(notificationId)/acknowledge"
        case .acknowledgeAllNotifications:
            "/notifications/acknowledge-all"
        case .getUnreadCount:
            "/notifications/unread"
        case let .reviewMembershipRequest(requestId):
            "/membership-requests/\(requestId)/review"
        case .searchFamilies:
            "/family/search"
        }
    }
}
