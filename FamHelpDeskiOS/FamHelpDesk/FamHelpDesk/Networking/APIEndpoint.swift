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

    // Notification endpoints
    case getNotifications
    case acknowledgeNotification(notificationId: String)
    case acknowledgeAllNotifications
    case getUnreadCount

    // Membership endpoints
    case reviewMembershipRequest(familyId: String)
    case getGroupMembers(familyId: String, groupId: String)

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
        case .searchFamilies:
            "/family/search"
        }
    }
}
