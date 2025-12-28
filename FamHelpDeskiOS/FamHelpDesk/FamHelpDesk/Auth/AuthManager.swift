import AuthenticationServices
import Combine
import Foundation

final class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userDisplayName: String?

    private let keychain = Keychain()
    private let sessionKey = "fhd_session_token"
    private let idTokenKey = "fhd_id_token"

    init() {
        // Try to load ID token first (preferred for API calls)
        let idToken = keychain.get(idTokenKey)
        let accessToken = keychain.get(sessionKey)
        
        // Use ID token for API if available, otherwise fall back to access token
        let apiToken = idToken ?? accessToken
        
        if let token = apiToken, !token.isEmpty {
            print("🔐 Loaded token from keychain (length: \(token.count))")

            // Decode and verify token type
            if let claims = decodeTokenClaims(token) {
                print("📋 Stored token type: \(claims["token_use"] as? String ?? "unknown")")

                // Check if token is expired
                if let exp = claims["exp"] as? TimeInterval {
                    let now = Date().timeIntervalSince1970
                    let isExpired = now > exp
                    print("⏰ Token expiration: \(isExpired ? "EXPIRED ❌" : "Valid ✅")")
                    if isExpired {
                        print("   Token expired \(Int(now - exp)) seconds ago")
                    } else {
                        print("   Token expires in \(Int(exp - now)) seconds")
                    }
                }
            }

            isAuthenticated = true
            APIClient.shared.setAccessToken(token)
            NetworkManager.shared.setAccessToken(token) // Send ID token to API

            // Use id_token for user info if available, otherwise fall back to access token
            let tokenForUserInfo = idToken ?? accessToken ?? token
            userDisplayName = decodeDisplayName(fromJWT: tokenForUserInfo)

            // Log user info for existing session
            if let userInfo = decodeUserInfo(fromJWT: tokenForUserInfo) {
                print("User Info: \(userInfo)")
                print("✅ Restored authenticated session:")
                print("  Name: \(userInfo.name ?? "N/A")")
                print("  Email: \(userInfo.email ?? "N/A")")
            }

            // Load user profile from API
            Task {
                await UserSession.shared.signIn(token: token)
            }
        }
    }

    func signIn(username: String, password: String) async throws {
        // Replace with your own password auth if needed (kept for dev/testing)
        let result: LoginResponse = try await APIClient.shared.post("/auth/login", body: [
            "username": username,
            "password": password,
        ])
        try persistSession(token: result.accessToken)

        // Load user profile from API
        await UserSession.shared.signIn(token: result.accessToken)
    }

    // Hosted UI Sign-in
    func hostedUISignIn() async throws {
        let hostedUI = CognitoHostedUI()
        let tokens = try await hostedUI.startSignIn(identityProvider: nil, mode: .signIn)
        try persistSession(accessToken: tokens.accessToken, idToken: tokens.idToken)

        // Load user profile from API
        await UserSession.shared.signIn(token: tokens.accessToken)
    }

    // Hosted UI Sign-up (screen_hint=signup)
    func hostedUISignUp() async throws {
        let hostedUI = CognitoHostedUI()
        let tokens = try await hostedUI.startSignIn(identityProvider: nil, mode: .signUp)
        try persistSession(accessToken: tokens.accessToken, idToken: tokens.idToken)

        // Load user profile from API
        await UserSession.shared.signIn(token: tokens.accessToken)
    }

    // Optional: continue with Google (uses same Hosted UI)
    func signInWithGoogle() async throws {
        let hostedUI = CognitoHostedUI()
        let tokens = try await hostedUI.startSignIn(identityProvider: AuthConfig.googleIdpName, mode: .signIn)
        try persistSession(accessToken: tokens.accessToken, idToken: tokens.idToken)

        // Load user profile from API
        await UserSession.shared.signIn(token: tokens.accessToken)
    }

    func signOut() {
        keychain.delete(sessionKey)
        keychain.delete(idTokenKey)
        APIClient.shared.clearAccessToken()
        NetworkManager.shared.clearAccessToken() // 🔧 FIX: Also clear NetworkManager!
        isAuthenticated = false
        userDisplayName = nil

        // Clear user session
        UserSession.shared.signOut()
    }

    private func persistSession(token: String) throws {
        keychain.set(token, forKey: sessionKey)
        APIClient.shared.setAccessToken(token)
        NetworkManager.shared.setAccessToken(token) // 🔧 FIX: Also set on NetworkManager!
        isAuthenticated = true
        userDisplayName = decodeDisplayName(fromJWT: token)

        // Log user info if authenticated
        if let userInfo = decodeUserInfo(fromJWT: token) {
            print("User Info: \(userInfo)")
            print("✅ User authenticated:")
            print("  Name: \(userInfo.name ?? "N/A")")
            print("  Email: \(userInfo.email ?? "N/A")")
        }
    }

    private func persistSession(accessToken: String, idToken: String?) throws {
        print("🔐 Storing tokens - Access token length: \(accessToken.count), ID token length: \(idToken?.count ?? 0)")

        // Decode and verify we're storing the right token
        if let idToken = idToken, let claims = decodeTokenClaims(idToken) {
            print("📋 ID token type: \(claims["token_use"] as? String ?? "unknown")")
        }

        keychain.set(accessToken, forKey: sessionKey)
        if let idToken = idToken {
            keychain.set(idToken, forKey: idTokenKey)
        }
        
        // Send ID token to API (contains user claims), fall back to access token if unavailable
        let apiToken = idToken ?? accessToken
        APIClient.shared.setAccessToken(apiToken)
        NetworkManager.shared.setAccessToken(apiToken)
        isAuthenticated = true

        // Use id_token for user info if available, otherwise fall back to access token
        let tokenForUserInfo = idToken ?? accessToken
        userDisplayName = decodeDisplayName(fromJWT: tokenForUserInfo)

        // Log user info if authenticated
        if let userInfo = decodeUserInfo(fromJWT: tokenForUserInfo) {
            print("User Info: \(userInfo)")
            print("✅ User authenticated:")
            print("  Name: \(userInfo.name ?? "N/A")")
            print("  Email: \(userInfo.email ?? "N/A")")
        }
    }

    private func decodeDisplayName(fromJWT token: String) -> String? {
        return decodeUserInfo(fromJWT: token)?.name
    }

    private func decodeUserInfo(fromJWT token: String) -> (name: String?, email: String?)? {
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else {
            print("❌ JWT token doesn't have enough segments")
            return nil
        }

        // JWT payload is the second segment (index 1)
        var base64 = segments[1]

        // Add padding if needed for base64 decoding
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        // Replace URL-safe characters
        base64 = base64.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            print("❌ Failed to decode JWT payload")
            return nil
        }

        // Print all available claims
        print("📋 All JWT claims:")
        for (key, value) in json.sorted(by: { $0.key < $1.key }) {
            print("  \(key): \(value)")
        }

        // Try different possible name fields
        let name = json["name"] as? String
            ?? json["given_name"] as? String
            ?? json["cognito:username"] as? String
            ?? json["username"] as? String
        let email = json["email"] as? String

        return (name: name, email: email)
    }

    private func decodeTokenClaims(_ token: String) -> [String: Any]? {
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }

        var base64 = segments[1]
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        base64 = base64.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        return json
    }
}

struct LoginResponse: Decodable {
    let accessToken: String
}

// Tokens returned by Cognito Hosted UI token exchange
struct OAuthTokens: Decodable {
    let access_token: String
    let id_token: String?
    let refresh_token: String?
    let token_type: String
    let expires_in: Int

    // Cognito returns tokens correctly in standard OAuth2 format
    var accessToken: String { access_token }
    var idToken: String? { id_token }
}
