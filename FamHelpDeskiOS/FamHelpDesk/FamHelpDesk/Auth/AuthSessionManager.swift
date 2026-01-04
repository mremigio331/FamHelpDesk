import Amplify
import AWSPluginsCore // <-- important (defines AuthCognitoTokensProvider)
import Foundation

enum TokenError: Error {
    case userNotSignedIn
    case tokenProviderUnavailable
    case tokenRetrievalFailed(Error)
    case tokenExpired
    case tokenValidationFailed
    case authenticationFailure(Error)
}

final class AuthSessionManager {
    static let shared = AuthSessionManager()
    private let logger = AuthLogger.shared
    private let errorRecovery = AuthErrorRecovery.shared

    private init() {}

    // MARK: - Public Token Methods

    /// Enhanced getIDToken method with proper error handling
    func getIDToken(forceRefresh: Bool = false) async throws -> String? {
        logger.logTokenOperation(.tokenRequested(type: "id_token"))

        do {
            let session = try await Amplify.Auth.fetchAuthSession(
                options: forceRefresh ? .forceRefresh() : .init()
            )

            guard session.isSignedIn else {
                logger.logTokenOperation(.tokenValidationFailure(type: "id_token", reason: "user_not_signed_in"))
                throw TokenError.userNotSignedIn
            }

            guard let tokenProvider = session as? AuthCognitoTokensProvider else {
                logger.logTokenOperation(.tokenValidationFailure(type: "id_token", reason: "token_provider_unavailable"))
                throw TokenError.tokenProviderUnavailable
            }

            let tokens = try tokenProvider.getCognitoTokens().get()
            let idToken = tokens.idToken

            // Validate token expiry
            if !forceRefresh, isTokenExpired(idToken) {
                logger.logTokenOperation(.tokenNearExpiry(type: "id_token", expiresIn: 0))
                return try await getIDToken(forceRefresh: true)
            }

            // Log successful token retrieval with expiry info
            if let expiresIn = getTokenExpirySeconds(idToken) {
                logger.logTokenOperation(.tokenRetrieved(type: "id_token", expiresIn: expiresIn))
            } else {
                logger.logTokenOperation(.tokenRetrieved(type: "id_token", expiresIn: nil))
            }

            return idToken

        } catch let error as TokenError {
            logger.logTokenOperation(.tokenRefreshFailure(error: error, type: "id_token"))

            // Attempt error recovery
            let context = TokenContext(tokenType: "id_token", operation: "get_id_token", attempt: 1)
            let recoveryResult = await errorRecovery.recoverFromTokenError(error, context: context)

            switch recoveryResult {
            case let .recovered(_, token):
                return token
            case .userAction(_, _), .fallback(_, _), .failed:
                throw error
            }
        } catch {
            logger.logTokenOperation(.tokenRefreshFailure(error: error, type: "id_token"))
            throw TokenError.tokenRetrievalFailed(error)
        }
    }

    /// Add getAccessToken method for access token retrieval
    func getAccessToken(forceRefresh: Bool = false) async throws -> String? {
        logger.logTokenOperation(.tokenRequested(type: "access_token"))

        do {
            let session = try await Amplify.Auth.fetchAuthSession(
                options: forceRefresh ? .forceRefresh() : .init()
            )

            guard session.isSignedIn else {
                logger.logTokenOperation(.tokenValidationFailure(type: "access_token", reason: "user_not_signed_in"))
                throw TokenError.userNotSignedIn
            }

            guard let tokenProvider = session as? AuthCognitoTokensProvider else {
                logger.logTokenOperation(.tokenValidationFailure(type: "access_token", reason: "token_provider_unavailable"))
                throw TokenError.tokenProviderUnavailable
            }

            let tokens = try tokenProvider.getCognitoTokens().get()
            let accessToken = tokens.accessToken

            // Validate token expiry
            if !forceRefresh, isTokenExpired(accessToken) {
                logger.logTokenOperation(.tokenNearExpiry(type: "access_token", expiresIn: 0))
                return try await getAccessToken(forceRefresh: true)
            }

            // Log successful token retrieval with expiry info
            if let expiresIn = getTokenExpirySeconds(accessToken) {
                logger.logTokenOperation(.tokenRetrieved(type: "access_token", expiresIn: expiresIn))
            } else {
                logger.logTokenOperation(.tokenRetrieved(type: "access_token", expiresIn: nil))
            }

            return accessToken

        } catch let error as TokenError {
            logger.logTokenOperation(.tokenRefreshFailure(error: error, type: "access_token"))

            // Attempt error recovery
            let context = TokenContext(tokenType: "access_token", operation: "get_access_token", attempt: 1)
            let recoveryResult = await errorRecovery.recoverFromTokenError(error, context: context)

            switch recoveryResult {
            case let .recovered(_, token):
                return token
            case .userAction(_, _), .fallback(_, _), .failed:
                throw error
            }
        } catch {
            logger.logTokenOperation(.tokenRefreshFailure(error: error, type: "access_token"))
            throw TokenError.tokenRetrievalFailed(error)
        }
    }

    /// Implement automatic token refresh logic
    func refreshTokensIfNeeded() async throws {
        logger.logTokenOperation(.tokenRefreshStarted(type: "all_tokens"))

        do {
            // Check if we need to refresh by attempting to get tokens without force refresh
            let idToken = try await getIDToken(forceRefresh: false)
            let accessToken = try await getAccessToken(forceRefresh: false)

            // If either token is near expiry, force refresh both
            if let idToken, isTokenNearExpiry(idToken) {
                logger.logTokenOperation(.tokenNearExpiry(type: "id_token", expiresIn: getTokenExpirySeconds(idToken) ?? 0))
                _ = try await getIDToken(forceRefresh: true)
                _ = try await getAccessToken(forceRefresh: true)
                logger.logTokenOperation(.tokenRefreshSuccess(type: "all_tokens"))
            } else if let accessToken, isTokenNearExpiry(accessToken) {
                logger.logTokenOperation(.tokenNearExpiry(type: "access_token", expiresIn: getTokenExpirySeconds(accessToken) ?? 0))
                _ = try await getIDToken(forceRefresh: true)
                _ = try await getAccessToken(forceRefresh: true)
                logger.logTokenOperation(.tokenRefreshSuccess(type: "all_tokens"))
            }

        } catch {
            logger.logTokenOperation(.tokenRefreshFailure(error: error, type: "all_tokens"))
            await handleTokenRefreshError(error)
            throw error
        }
    }

    /// Ensure proper token clearing on authentication failures
    func clearTokens() async {
        logger.logTokenOperation(.tokenCleared)
        _ = await Amplify.Auth.signOut()
    }

    // MARK: - Private Token Validation Methods

    /// Add token validation and expiry checking
    private func validateTokenExpiry(_ token: String) -> Bool {
        !isTokenExpired(token)
    }

    private func isTokenExpired(_ token: String) -> Bool {
        guard let payload = extractTokenPayload(token),
              let exp = payload["exp"] as? TimeInterval
        else {
            logger.logTokenOperation(.tokenValidationFailure(type: "unknown", reason: "could_not_extract_expiration"))
            return true // Assume expired if we can't validate
        }

        let expirationDate = Date(timeIntervalSince1970: exp)
        let now = Date()
        let isExpired = now >= expirationDate

        if isExpired {
            let expiresIn = Int(exp - now.timeIntervalSince1970)
            logger.logTokenOperation(.tokenValidationFailure(type: "unknown", reason: "token_expired_\(abs(expiresIn))s_ago"))
        }

        return isExpired
    }

    private func isTokenNearExpiry(_ token: String, bufferSeconds: TimeInterval = 300) -> Bool {
        guard let payload = extractTokenPayload(token),
              let exp = payload["exp"] as? TimeInterval
        else {
            logger.logTokenOperation(.tokenValidationFailure(type: "unknown", reason: "could_not_extract_expiration"))
            return true // Assume near expiry if we can't validate
        }

        let expirationDate = Date(timeIntervalSince1970: exp)
        let now = Date()
        let bufferDate = expirationDate.addingTimeInterval(-bufferSeconds)
        let isNearExpiry = now >= bufferDate

        if isNearExpiry {
            let expiresIn = Int(exp - now.timeIntervalSince1970)
            logger.logTokenOperation(.tokenNearExpiry(type: "unknown", expiresIn: expiresIn))
        }

        return isNearExpiry
    }

    private func extractTokenPayload(_ token: String) -> [String: Any]? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            logger.logTokenOperation(.tokenValidationFailure(type: "unknown", reason: "invalid_jwt_format"))
            return nil
        }

        let payload = parts[1]
        // Add padding if needed for base64 decoding
        let paddedPayload = payload.padding(toLength: ((payload.count + 3) / 4) * 4, withPad: "=", startingAt: 0)

        guard let data = Data(base64Encoded: paddedPayload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            logger.logTokenOperation(.tokenValidationFailure(type: "unknown", reason: "could_not_decode_jwt_payload"))
            return nil
        }

        return json
    }

    /// Get token expiry in seconds from now
    private func getTokenExpirySeconds(_ token: String) -> Int? {
        guard let payload = extractTokenPayload(token),
              let exp = payload["exp"] as? TimeInterval
        else {
            return nil
        }

        let now = Date().timeIntervalSince1970
        return Int(exp - now)
    }

    private func handleTokenRefreshError(_ error: Error) async {
        logger.logTokenOperation(.tokenRefreshFailure(error: error, type: "refresh_error_handler"))

        // Clear tokens on authentication failures
        if case TokenError.userNotSignedIn = error {
            await clearTokens()
        } else if case TokenError.authenticationFailure = error {
            await clearTokens()
        } else {
            // For any other authentication-related errors, clear tokens as a safety measure
            let errorDescription = String(describing: error).lowercased()
            if errorDescription.contains("unauthorized") ||
                errorDescription.contains("expired") ||
                errorDescription.contains("invalid") ||
                errorDescription.contains("signedout")
            {
                logger.logTokenOperation(.tokenCleared)
                await clearTokens()
            }
        }
    }
}
