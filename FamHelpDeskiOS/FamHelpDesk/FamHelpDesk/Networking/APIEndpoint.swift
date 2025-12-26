import Foundation

enum APIEndpoint {
    // User endpoints
    case getProfile

    var path: String {
        switch self {
        case .getProfile:
            return "/user/profile"
        }
    }
}
