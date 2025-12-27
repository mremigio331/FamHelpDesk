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

    // Group endpoints
    case getAllGroups(familyId: String)
    case getMyGroups
    case createGroup

    var path: String {
        switch self {
        case .getProfile:
            return "/user/profile"
        case let .getUserProfile(userId):
            return "/user/profile/\(userId)"
        case .updateProfile:
            return "/user/profile"
        case .getAllFamilies:
            return "/family"
        case .getMyFamilies:
            return "/family/mine"
        case .createFamily:
            return "/family"
        case let .getAllGroups(familyId):
            return "/group/\(familyId)"
        case .getMyGroups:
            return "/group/mine"
        case .createGroup:
            return "/group"
        }
    }
}
