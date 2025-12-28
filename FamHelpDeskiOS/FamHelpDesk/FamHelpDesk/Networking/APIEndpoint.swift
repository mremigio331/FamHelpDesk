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
        case let .getAllGroups(familyId):
            "/group/\(familyId)"
        case .getMyGroups:
            "/group/mine"
        case .createGroup:
            "/group"
        }
    }
}
