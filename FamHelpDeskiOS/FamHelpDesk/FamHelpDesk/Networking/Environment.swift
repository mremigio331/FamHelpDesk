import Foundation

enum APIEnvironment {
    case development
    case testing
    case production

    static var current: APIEnvironment {
        #if DEBUG
            return .testing     // Local development uses testing endpoint
        #else
            return .production  // App Store/TestFlight uses production endpoint
        #endif
    }

    var baseURL: String {
        switch self {
        case .development:
            "https://api.testing.famhelpdesk.com"  // Development also uses testing endpoint
        case .testing:
            "https://api.testing.famhelpdesk.com"  // Testing/staging environment
        case .production:
            "https://api.famhelpdesk.com"  // Production environment
        }
    }
}
