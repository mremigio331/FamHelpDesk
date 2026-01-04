import Amplify
import AWSCognitoAuthPlugin
import Foundation

/// Error recovery system for authentication operations
/// Implements automatic recovery strategies for common failure scenarios
final class AuthErrorRecovery {
    static let shared = AuthErrorRecovery()

    private let logger = AuthLogger.shared
    private let maxRetryAttempts = 3
    private let retryDelaySeconds: TimeInterval = 1.0

    private init() {}

    // MARK: - Configuration Error Recovery

    /// Attempt to recover from configuration errors
    func recoverFromConfigurationError(_ error: ConfigurationError, environment: AppStage) async -> ConfigurationRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "configuration_recovery", originalError: error))

        switch error {
        case let .fileNotFound(message):
            return await recoverFromMissingConfigFile(message: message, environment: environment)

        case .invalidFormat:
            return await recoverFromInvalidConfigFormat(environment: environment)

        case let .missingRequiredKeys(keys):
            return await recoverFromMissingConfigKeys(keys: keys, environment: environment)

        case let .amplifyInitializationFailed(underlyingError):
            return await recoverFromAmplifyInitFailure(underlyingError: underlyingError, environment: environment)
        }
    }

    private func recoverFromMissingConfigFile(message: String, environment: AppStage) async -> ConfigurationRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "missing_config_file", originalError: ConfigurationError.fileNotFound(message)))

        // Strategy 1: Try alternative configuration file
        let alternativeFiles = getAlternativeConfigFiles(for: environment)

        for altFile in alternativeFiles {
            if let configURL = Bundle.main.url(forResource: altFile, withExtension: "json") {
                logger.logRecoveryAttempt(.recoverySuccess(strategy: "alternative_config_file"))
                return .recovered(strategy: .alternativeConfigFile(altFile), configURL: configURL)
            }
        }

        // Strategy 2: Use fallback configuration
        logger.logRecoveryAttempt(.fallbackActivated(fallback: "default_config"))
        return .fallback(strategy: .defaultConfiguration, reason: "No valid configuration files found")
    }

    private func recoverFromInvalidConfigFormat(environment: AppStage) async -> ConfigurationRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "invalid_config_format", originalError: ConfigurationError.invalidFormat))

        // Strategy: Try to use a known good configuration file
        let fallbackFile = environment == .prod ? "amplifyconfiguration.testing" : "amplifyconfiguration.prod"

        if let configURL = Bundle.main.url(forResource: fallbackFile, withExtension: "json") {
            logger.logRecoveryAttempt(.recoverySuccess(strategy: "fallback_config_file"))
            return .recovered(strategy: .alternativeConfigFile(fallbackFile), configURL: configURL)
        }

        logger.logRecoveryAttempt(.fallbackActivated(fallback: "default_config"))
        return .fallback(strategy: .defaultConfiguration, reason: "Invalid configuration format, no fallback available")
    }

    private func recoverFromMissingConfigKeys(keys: [String], environment _: AppStage) async -> ConfigurationRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "missing_config_keys", originalError: ConfigurationError.missingRequiredKeys(keys)))

        // For missing keys, we can't easily recover, so use fallback
        logger.logRecoveryAttempt(.fallbackActivated(fallback: "default_config"))
        return .fallback(strategy: .defaultConfiguration, reason: "Missing required configuration keys: \(keys.joined(separator: ", "))")
    }

    private func recoverFromAmplifyInitFailure(underlyingError: Error, environment _: AppStage) async -> ConfigurationRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "amplify_init_failure", originalError: underlyingError))

        // Strategy: Retry with exponential backoff
        for attempt in 1 ... maxRetryAttempts {
            do {
                try await Task.sleep(nanoseconds: UInt64(retryDelaySeconds * Double(attempt) * 1_000_000_000))

                // Try to fetch auth session to test if Amplify is working
                _ = try await Amplify.Auth.fetchAuthSession()

                logger.logRecoveryAttempt(.recoverySuccess(strategy: "amplify_retry"))
                return .retrySuccessful(attempt: attempt)

            } catch {
                logger.logRecoveryAttempt(.recoveryFailure(strategy: "amplify_retry_\(attempt)", error: error))

                if attempt == maxRetryAttempts {
                    logger.logRecoveryAttempt(.fallbackActivated(fallback: "offline_mode"))
                    return .fallback(strategy: .offlineMode, reason: "Amplify initialization failed after \(maxRetryAttempts) attempts")
                }
            }
        }

        return .failed(reason: "Unexpected error in recovery logic")
    }

    // MARK: - Authentication Error Recovery

    /// Attempt to recover from authentication errors
    func recoverFromAuthenticationError(_ error: AuthError, context: AuthContext) async -> AuthRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "auth_recovery", originalError: error))

        switch error {
        case let .configurationError(message):
            return await recoverFromAuthConfigError(message: message, context: context)

        case let .networkError(networkError):
            return await recoverFromNetworkError(networkError: networkError, context: context)

        case .tokenExpired:
            return await recoverFromTokenExpiry(context: context)

        case .invalidCredentials:
            return await recoverFromInvalidCredentials(context: context)

        case .userCancelled:
            return .userAction(action: .retrySignIn, reason: "User cancelled authentication")

        case let .unknownError(unknownError):
            return await recoverFromUnknownAuthError(unknownError: unknownError, context: context)
        }
    }

    private func recoverFromAuthConfigError(message: String, context _: AuthContext) async -> AuthRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "auth_config_error", originalError: AuthError.configurationError(message)))

        // Strategy: Reinitialize authentication system
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

            // This would trigger a reconfiguration in the main app
            logger.logRecoveryAttempt(.recoverySuccess(strategy: "auth_reinit"))
            return .recovered(strategy: .reinitializeAuth, nextAction: .checkAuthStatus)

        } catch {
            logger.logRecoveryAttempt(.recoveryFailure(strategy: "auth_reinit", error: error))
            return .fallback(strategy: .offlineMode, reason: "Authentication configuration error: \(message)")
        }
    }

    private func recoverFromNetworkError(networkError: Error, context _: AuthContext) async -> AuthRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "network_error", originalError: networkError))

        // Strategy: Retry with exponential backoff
        for attempt in 1 ... maxRetryAttempts {
            do {
                let delay = retryDelaySeconds * pow(2.0, Double(attempt - 1))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Test network connectivity by attempting a simple auth check
                _ = try await Amplify.Auth.fetchAuthSession()

                logger.logRecoveryAttempt(.recoverySuccess(strategy: "network_retry"))
                return .recovered(strategy: .retryWithBackoff, nextAction: .retryOriginalOperation)

            } catch {
                logger.logRecoveryAttempt(.recoveryFailure(strategy: "network_retry_\(attempt)", error: error))

                if attempt == maxRetryAttempts {
                    logger.logRecoveryAttempt(.fallbackActivated(fallback: "offline_mode"))
                    return .fallback(strategy: .offlineMode, reason: "Network error persists after \(maxRetryAttempts) attempts")
                }
            }
        }

        return .failed(reason: "Network recovery logic error")
    }

    private func recoverFromTokenExpiry(context _: AuthContext) async -> AuthRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "token_expiry", originalError: AuthError.tokenExpired))

        // Strategy: Automatic token refresh
        do {
            _ = try await AuthSessionManager.shared.getIDToken(forceRefresh: true)
            logger.logRecoveryAttempt(.recoverySuccess(strategy: "token_refresh"))
            return .recovered(strategy: .refreshTokens, nextAction: .retryOriginalOperation)

        } catch {
            logger.logRecoveryAttempt(.recoveryFailure(strategy: "token_refresh", error: error))

            // Fallback: Force re-authentication
            logger.logRecoveryAttempt(.fallbackActivated(fallback: "force_reauth"))
            return .userAction(action: .forceSignIn, reason: "Token refresh failed, re-authentication required")
        }
    }

    private func recoverFromInvalidCredentials(context _: AuthContext) async -> AuthRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "invalid_credentials", originalError: AuthError.invalidCredentials))

        // Strategy: Clear stored credentials and prompt for re-authentication
        await AuthSessionManager.shared.clearTokens()

        logger.logRecoveryAttempt(.recoverySuccess(strategy: "clear_credentials"))
        return .userAction(action: .retrySignIn, reason: "Invalid credentials, please sign in again")
    }

    private func recoverFromUnknownAuthError(unknownError: Error, context: AuthContext) async -> AuthRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "unknown_auth_error", originalError: unknownError))

        let errorDescription = unknownError.localizedDescription.lowercased()

        // Strategy: Classify and handle based on error content
        if errorDescription.contains("already a user in signedin state") {
            // Force sign out and retry
            await AuthSessionManager.shared.clearTokens()
            logger.logRecoveryAttempt(.recoverySuccess(strategy: "force_signout"))
            return .recovered(strategy: .forceSignOut, nextAction: .retryOriginalOperation)

        } else if errorDescription.contains("network") || errorDescription.contains("connection") {
            // Treat as network error
            return await recoverFromNetworkError(networkError: unknownError, context: context)

        } else {
            // Generic recovery: Clear state and prompt user
            await AuthSessionManager.shared.clearTokens()
            logger.logRecoveryAttempt(.fallbackActivated(fallback: "user_retry"))
            return .userAction(action: .retrySignIn, reason: "Authentication error: \(unknownError.localizedDescription)")
        }
    }

    // MARK: - Token Error Recovery

    /// Attempt to recover from token errors
    func recoverFromTokenError(_ error: TokenError, context: TokenContext) async -> TokenRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "token_recovery", originalError: error))

        switch error {
        case .userNotSignedIn:
            return .userAction(action: .signIn, reason: "User not signed in")

        case .tokenProviderUnavailable:
            return await recoverFromTokenProviderUnavailable(context: context)

        case let .tokenRetrievalFailed(underlyingError):
            return await recoverFromTokenRetrievalFailure(underlyingError: underlyingError, context: context)

        case .tokenExpired:
            return await recoverFromTokenExpired(context: context)

        case .tokenValidationFailed:
            return await recoverFromTokenValidationFailure(context: context)

        case let .authenticationFailure(authError):
            return await recoverFromTokenAuthFailure(authError: authError, context: context)
        }
    }

    private func recoverFromTokenProviderUnavailable(context _: TokenContext) async -> TokenRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "token_provider_unavailable", originalError: TokenError.tokenProviderUnavailable))

        // Strategy: Reinitialize auth session
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

            // Force a new auth session
            _ = try await Amplify.Auth.fetchAuthSession(options: .forceRefresh())

            logger.logRecoveryAttempt(.recoverySuccess(strategy: "reinit_session"))
            return .recovered(strategy: .reinitializeSession, token: nil)

        } catch {
            logger.logRecoveryAttempt(.recoveryFailure(strategy: "reinit_session", error: error))
            return .fallback(strategy: .useManualToken, reason: "Token provider unavailable")
        }
    }

    private func recoverFromTokenRetrievalFailure(underlyingError: Error, context _: TokenContext) async -> TokenRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "token_retrieval_failure", originalError: underlyingError))

        // Strategy: Retry with exponential backoff
        for attempt in 1 ... maxRetryAttempts {
            do {
                let delay = retryDelaySeconds * pow(2.0, Double(attempt - 1))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                let token = try await AuthSessionManager.shared.getIDToken(forceRefresh: true)

                logger.logRecoveryAttempt(.recoverySuccess(strategy: "token_retry"))
                return .recovered(strategy: .retryWithBackoff, token: token)

            } catch {
                logger.logRecoveryAttempt(.recoveryFailure(strategy: "token_retry_\(attempt)", error: error))

                if attempt == maxRetryAttempts {
                    logger.logRecoveryAttempt(.fallbackActivated(fallback: "manual_token"))
                    return .fallback(strategy: .useManualToken, reason: "Token retrieval failed after \(maxRetryAttempts) attempts")
                }
            }
        }

        return .failed(reason: "Token retrieval recovery logic error")
    }

    private func recoverFromTokenExpired(context _: TokenContext) async -> TokenRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "token_expired", originalError: TokenError.tokenExpired))

        // Strategy: Force refresh
        do {
            let token = try await AuthSessionManager.shared.getIDToken(forceRefresh: true)
            logger.logRecoveryAttempt(.recoverySuccess(strategy: "force_refresh"))
            return .recovered(strategy: .forceRefresh, token: token)

        } catch {
            logger.logRecoveryAttempt(.recoveryFailure(strategy: "force_refresh", error: error))
            return .userAction(action: .signIn, reason: "Token expired and refresh failed")
        }
    }

    private func recoverFromTokenValidationFailure(context _: TokenContext) async -> TokenRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "token_validation_failure", originalError: TokenError.tokenValidationFailed))

        // Strategy: Clear tokens and get fresh ones
        await AuthSessionManager.shared.clearTokens()

        do {
            let token = try await AuthSessionManager.shared.getIDToken(forceRefresh: true)
            logger.logRecoveryAttempt(.recoverySuccess(strategy: "clear_and_refresh"))
            return .recovered(strategy: .clearAndRefresh, token: token)

        } catch {
            logger.logRecoveryAttempt(.recoveryFailure(strategy: "clear_and_refresh", error: error))
            return .userAction(action: .signIn, reason: "Token validation failed")
        }
    }

    private func recoverFromTokenAuthFailure(authError: Error, context _: TokenContext) async -> TokenRecoveryResult {
        logger.logRecoveryAttempt(.recoveryStarted(strategy: "token_auth_failure", originalError: authError))

        // Strategy: Clear all auth state and prompt re-authentication
        await AuthSessionManager.shared.clearTokens()

        logger.logRecoveryAttempt(.recoverySuccess(strategy: "clear_auth_state"))
        return .userAction(action: .signIn, reason: "Authentication failure: \(authError.localizedDescription)")
    }

    // MARK: - Helper Methods

    private func getAlternativeConfigFiles(for environment: AppStage) -> [String] {
        switch environment {
        case .dev, .staging:
            ["amplifyconfiguration.prod", "amplifyconfiguration"]
        case .prod:
            ["amplifyconfiguration.testing", "amplifyconfiguration"]
        }
    }
}

// MARK: - Recovery Result Types

enum ConfigurationRecoveryResult {
    case recovered(strategy: ConfigurationRecoveryStrategy, configURL: URL)
    case retrySuccessful(attempt: Int)
    case fallback(strategy: FallbackStrategy, reason: String)
    case failed(reason: String)
}

enum AuthRecoveryResult {
    case recovered(strategy: AuthRecoveryStrategy, nextAction: AuthAction)
    case userAction(action: UserAction, reason: String)
    case fallback(strategy: FallbackStrategy, reason: String)
    case failed(reason: String)
}

enum TokenRecoveryResult {
    case recovered(strategy: TokenRecoveryStrategy, token: String?)
    case userAction(action: UserAction, reason: String)
    case fallback(strategy: FallbackStrategy, reason: String)
    case failed(reason: String)
}

// MARK: - Recovery Strategy Types

enum ConfigurationRecoveryStrategy {
    case alternativeConfigFile(String)
    case retryWithBackoff
}

enum AuthRecoveryStrategy {
    case reinitializeAuth
    case retryWithBackoff
    case refreshTokens
    case forceSignOut
}

enum TokenRecoveryStrategy {
    case reinitializeSession
    case retryWithBackoff
    case forceRefresh
    case clearAndRefresh
}

enum FallbackStrategy {
    case defaultConfiguration
    case offlineMode
    case useManualToken
}

// MARK: - Action Types

enum AuthAction {
    case checkAuthStatus
    case retryOriginalOperation
}

enum UserAction {
    case signIn
    case retrySignIn
    case forceSignIn
}

// MARK: - Context Types

struct AuthContext {
    let operation: String
    let attempt: Int
    let userInitiated: Bool
}

struct TokenContext {
    let tokenType: String
    let operation: String
    let attempt: Int
}
