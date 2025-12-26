import Foundation

enum AppStage {
    case dev
    case staging
    case prod

    static var current: AppStage {
        #if DEBUG
            return .dev
        #elseif STAGING
            return .staging
        #else
            return .prod
        #endif
    }
}

struct CognitoConfig {
    let region: String
    let userPoolId: String
    let clientId: String
    let domain: String
    let redirectURI: String
    let signOutRedirectURI: String
    let scopes: [String]
    let googleIdpName: String
}

enum AuthConfig {
    // Per-environment raw configs. Fill with your real values.
    private static let dev = CognitoConfig(
        region: "us-west-2",
        userPoolId: "us-west-2_rcVQ8xkpe",
        clientId: "31tqa0op65nqnh70q32pspmdc6",
        domain: "https://famhelpdesk-testing.auth.us-west-2.amazoncognito.com",
        redirectURI: "famHelpDesk://auth/callback",
        signOutRedirectURI: "famHelpDesk://signout",
        scopes: ["openid", "email", "profile"],
        googleIdpName: "Google"
    )

    private static let staging = CognitoConfig(
        region: "us-west-2",
        userPoolId: "us-west-2_rcVQ8xkpe",
        clientId: "31tqa0op65nqnh70q32pspmdc6",
        domain: "https://famhelpdesk-testing.auth.us-west-2.amazoncognito.com",
        redirectURI: "famHelpDesk://auth/callback",
        signOutRedirectURI: "famHelpDesk://signout",
        scopes: ["openid", "email", "profile"],
        googleIdpName: "Google"
    )

    private static let prod = CognitoConfig(
        region: "us-west-2",
        userPoolId: "YOUR_PROD_USER_POOL_ID",
        clientId: "YOUR_PROD_APP_CLIENT_ID",
        domain: "https://famhelpdesk-prod.auth.us-west-2.amazoncognito.com",
        redirectURI: "famHelpDesk://auth/callback",
        signOutRedirectURI: "famHelpDesk://signout",
        scopes: ["openid", "email", "profile"],
        googleIdpName: "Google"
    )

    private static var active: CognitoConfig {
        switch AppStage.current {
        case .dev: return dev
        case .staging: return staging
        case .prod: return prod
        }
    }

    // Public computed properties consumed by the app
    static var region: String { active.region }
    static var userPoolId: String { active.userPoolId }
    static var clientId: String { active.clientId }
    static var domain: String { active.domain }
    static var redirectURI: String { active.redirectURI }
    static var signOutRedirectURI: String { active.signOutRedirectURI }
    static var scopes: [String] { active.scopes }
    static var googleIdpName: String { active.googleIdpName }
}
