import Amplify
import AWSCognitoAuthPlugin
import AWSPluginsCore
import Foundation

/// Helper class for testing authentication functionality
class AuthTestHelper {
    /// Test the complete authentication flow
    static func testAuthenticationFlow() async {
        print("🧪 Starting authentication flow test...")

        // 1. Check current auth status
        await testAuthStatus()

        // 2. Test token retrieval
        await testTokenRetrieval()

        // 3. Test user info extraction
        await testUserInfoExtraction()

        print("🧪 Authentication flow test completed")
    }

    /// Test authentication status check
    private static func testAuthStatus() async {
        print("\n📋 Testing authentication status...")

        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            print("✅ Auth session fetched successfully")
            print("   - Is signed in: \(session.isSignedIn)")

            if let cognitoSession = session as? AuthCognitoTokensProvider {
                let tokensResult = cognitoSession.getCognitoTokens()
                switch tokensResult {
                case let .success(tokens):
                    print("   - Has ID token: \(tokens.idToken.count > 0)")
                    print("   - Has access token: \(tokens.accessToken.count > 0)")
                    print("   - Has refresh token: \(tokens.refreshToken != nil)")
                case let .failure(error):
                    print("   - Token retrieval failed: \(error)")
                }
            }

        } catch {
            print("❌ Auth status check failed: \(error)")
        }
    }

    /// Test token retrieval through AuthSessionManager
    private static func testTokenRetrieval() async {
        print("\n🔑 Testing token retrieval...")

        do {
            let idToken = try await AuthSessionManager.shared.getIDToken()
            if let token = idToken {
                print("✅ ID token retrieved successfully (length: \(token.count))")

                // Decode and inspect token
                if let payload = decodeJWTPayload(token) {
                    print("   - Token type: \(payload["token_use"] as? String ?? "unknown")")
                    print("   - Audience: \(payload["aud"] as? String ?? "unknown")")
                    print("   - Subject: \(payload["sub"] as? String ?? "unknown")")
                    print("   - Email: \(payload["email"] as? String ?? "not present")")
                    print("   - Name: \(payload["name"] as? String ?? "not present")")
                    print("   - Given name: \(payload["given_name"] as? String ?? "not present")")

                    if let exp = payload["exp"] as? TimeInterval {
                        let expirationDate = Date(timeIntervalSince1970: exp)
                        let timeLeft = expirationDate.timeIntervalSinceNow
                        print("   - Expires in: \(Int(timeLeft)) seconds")
                    }
                }
            } else {
                print("⚠️ No ID token available")
            }

            let accessToken = try await AuthSessionManager.shared.getAccessToken()
            if let token = accessToken {
                print("✅ Access token retrieved successfully (length: \(token.count))")

                // Decode and inspect token
                if let payload = decodeJWTPayload(token) {
                    print("   - Token type: \(payload["token_use"] as? String ?? "unknown")")
                    print("   - Scope: \(payload["scope"] as? String ?? "unknown")")
                    print("   - Client ID: \(payload["client_id"] as? String ?? "unknown")")
                }
            } else {
                print("⚠️ No access token available")
            }

        } catch {
            print("❌ Token retrieval failed: \(error)")
        }
    }

    /// Test user info extraction from different sources
    private static func testUserInfoExtraction() async {
        print("\n👤 Testing user info extraction...")

        // Test 1: Try Amplify.Auth.getCurrentUser()
        do {
            let currentUser = try await Amplify.Auth.getCurrentUser()
            print("✅ Current user retrieved successfully")
            print("   - User ID: \(currentUser.userId)")
            print("   - Username: \(currentUser.username)")
        } catch {
            print("❌ Failed to get current user: \(error)")
        }

        // Test 2: Try Amplify.Auth.fetchUserAttributes()
        do {
            let attributes = try await Amplify.Auth.fetchUserAttributes()
            print("✅ User attributes retrieved successfully (\(attributes.count) attributes)")
            for attribute in attributes {
                print("   - \(attribute.key.rawValue): \(attribute.value)")
            }
        } catch {
            print("❌ Failed to fetch user attributes: \(error)")

            // Check if it's a scope issue
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("access token does not have required scopes") {
                print("   🔍 This is a scope issue - the access token doesn't have permission to read user attributes")
                print("   💡 This might be a Cognito User Pool app client configuration issue")
            }
        }

        // Test 3: Extract info from ID token
        do {
            if let idToken = try await AuthSessionManager.shared.getIDToken() {
                if let payload = decodeJWTPayload(idToken) {
                    print("✅ ID token decoded successfully")
                    let name = payload["name"] as? String ?? payload["given_name"] as? String
                    let email = payload["email"] as? String
                    print("   - Name from ID token: \(name ?? "not present")")
                    print("   - Email from ID token: \(email ?? "not present")")
                } else {
                    print("❌ Failed to decode ID token")
                }
            }
        } catch {
            print("❌ Failed to get ID token for extraction: \(error)")
        }
    }

    /// Helper method to decode JWT payload
    private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }

        let payload = segments[1]
        // Add padding if needed for base64 decoding
        let paddedPayload = payload.padding(toLength: ((payload.count + 3) / 4) * 4, withPad: "=", startingAt: 0)

        guard let data = Data(base64Encoded: paddedPayload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        return json
    }
}
