import Foundation

enum APIEnvironment {
    case development
    case testing
    case production

    static var current: APIEnvironment {
        #if DEBUG
            return .development
        #else
            return .production
        #endif
    }

    var baseURL: String {
        switch self {
        case .development:
            return "https://api.testing.famhelpdesk.com"
        case .testing:
            return "https://api.testing.famhelpdesk.com"
        case .production:
            return "https://api.famhelpdesk.com"
        }
    }
}
