import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

enum HostedUIMode { case signIn, signUp }

final class CognitoHostedUI: NSObject {
    private var currentSession: ASWebAuthenticationSession?

    func startSignIn(identityProvider: String?, mode: HostedUIMode = .signIn) async throws -> OAuthTokens {
        // Build authorize/login URL with PKCE
        let codeVerifier = Self.randomURLSafeString(length: 64)
        let codeChallenge = Self.codeChallengeS256(verifier: codeVerifier)

        // Use /oauth2/authorize; add screen_hint=signup when needed.
        var comps = URLComponents(string: AuthConfig.domain + "/oauth2/authorize")!
        var query: [URLQueryItem] = [
            URLQueryItem(name: "client_id", value: AuthConfig.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: AuthConfig.redirectURI),
            URLQueryItem(name: "scope", value: AuthConfig.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        if mode == .signUp { query.append(URLQueryItem(name: "screen_hint", value: "signup")) }
        if let idp = identityProvider { query.append(URLQueryItem(name: "identity_provider", value: idp)) }
        comps.queryItems = query
        let authURL = comps.url!

        let callbackScheme = URL(string: AuthConfig.redirectURI)!.scheme!
        let callbackURL = try await presentAuthSession(url: authURL, callbackScheme: callbackScheme)

        // Exchange code for tokens
        let tokens = try await exchangeCodeForTokens(callbackURL: callbackURL, codeVerifier: codeVerifier)
        return tokens
    }

    private func presentAuthSession(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let url = callbackURL else {
                    cont.resume(throwing: NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing callback URL"]))
                    return
                }
                cont.resume(returning: url)
            }
            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = self
            self.currentSession = session
            session.start()
        }
    }

    private func exchangeCodeForTokens(callbackURL: URL, codeVerifier: String) async throws -> OAuthTokens {
        guard let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = comps.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw NSError(domain: "Auth", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing auth code"])
        }

        var req = URLRequest(url: URL(string: AuthConfig.domain + "/oauth2/token")!)
        req.httpMethod = "POST"
        req.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyPairs: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": AuthConfig.clientId,
            "code": code,
            "redirect_uri": AuthConfig.redirectURI,
            "code_verifier": codeVerifier,
        ]
        let body = bodyPairs.map { key, value in
            let escaped = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(key)=\(escaped)"
        }.joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "<no body>"
            throw NSError(domain: "Auth", code: -3, userInfo: [NSLocalizedDescriptionKey: "Token exchange failed: \(text)"])
        }

        // DEBUG: Print raw JSON response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 Raw Cognito response (first 500 chars):")
            print(String(jsonString.prefix(500)))
        }

        let tokens = try JSONDecoder().decode(OAuthTokens.self, from: data)

        // DEBUG: Print token types
        print("🔍 Token exchange response:")
        print("  Access token length: \(tokens.access_token.count)")
        print("  ID token length: \(tokens.id_token?.count ?? 0)")
        if let accessClaims = Self.decodeTokenType(tokens.access_token) {
            print("  Access token type: \(accessClaims["token_use"] as? String ?? "unknown")")
        }
        if let idToken = tokens.id_token, let idClaims = Self.decodeTokenType(idToken) {
            print("  ID token type: \(idClaims["token_use"] as? String ?? "unknown")")
        }

        return tokens
    }

    private static func decodeTokenType(_ token: String) -> [String: Any]? {
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }
        var base64 = segments[1]
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        base64 = base64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    private static func randomURLSafeString(length: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let data = Data(bytes)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func codeChallengeS256(verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let data = Data(digest)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension CognitoHostedUI: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first
        {
            return window
        }
        return ASPresentationAnchor()
    }
}
