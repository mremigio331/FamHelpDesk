import Foundation
import os.log

/// Centralized logging system for authentication operations
/// Provides production-safe logging with structured error classification
final class AuthLogger {
    static let shared = AuthLogger()

    private let logger: Logger
    private let subsystem = "com.famhelpdesk.auth"

    private init() {
        logger = Logger(subsystem: subsystem, category: "Authentication")
    }

    // MARK: - Configuration Logging

    /// Log Amplify configuration events with specific error details and file paths
    func logConfigurationEvent(_ event: ConfigurationEvent) {
        switch event {
        case let .configurationStarted(environment):
            logger.info("🔧 Starting Amplify configuration for environment: \(environment)")

        case let .configurationFileLoaded(fileName, path):
            logger.info("📄 Configuration file loaded: \(fileName) from \(path)")

        case let .configurationValidationPassed(fileName):
            logger.info("✅ Configuration validation passed for: \(fileName)")

        case let .configurationSuccess(environment, fileName):
            logger.info("✅ Amplify configured successfully - Environment: \(environment), Config: \(fileName)")

        case let .configurationFailure(error, environment, fileName):
            let errorDetails = classifyConfigurationError(error)
            logger.error("❌ Configuration failed - Environment: \(environment), Config: \(fileName), Error: \(errorDetails.description)")

            // Log additional context for debugging
            #if DEBUG
                logger.debug("🔍 Configuration error details: \(String(describing: error))")
            #endif
        }
    }

    // MARK: - Authentication State Logging

    /// Log authentication state changes with structured information
    func logAuthenticationStateChange(_ event: AuthStateEvent) {
        switch event {
        case let .stateChanged(from, to):
            logger.info("🔄 Auth state changed: \(from.description) → \(to.description)")

        case let .signInStarted(method):
            logger.info("🔐 Sign-in started with method: \(method)")

        case let .signInSuccess(userId, method):
            // Log success without sensitive data
            let sanitizedUserId = sanitizeUserId(userId)
            logger.info("✅ Sign-in successful - Method: \(method), User: \(sanitizedUserId)")

        case let .signInFailure(error, method):
            let errorDetails = classifyAuthenticationError(error)
            logger.error("❌ Sign-in failed - Method: \(method), Error: \(errorDetails.description)")

        case .signOutStarted:
            logger.info("🔓 Sign-out started")

        case .signOutSuccess:
            logger.info("✅ Sign-out completed successfully")

        case let .signOutFailure(error):
            let errorDetails = classifyAuthenticationError(error)
            logger.error("❌ Sign-out failed - Error: \(errorDetails.description)")

        case let .sessionRestored(userId):
            let sanitizedUserId = sanitizeUserId(userId)
            logger.info("🔄 Session restored for user: \(sanitizedUserId)")

        case .sessionExpired:
            logger.warning("⚠️ Session expired, triggering re-authentication")

        case let .userAttributesLoaded(count):
            logger.info("📋 User attributes loaded: \(count) attributes")

        case let .userAttributesFailure(error):
            let errorDetails = classifyAuthenticationError(error)
            logger.warning("⚠️ Failed to load user attributes - Error: \(errorDetails.description)")
        }
    }

    // MARK: - Token Operation Logging

    /// Log token operations with error classification and recovery information
    func logTokenOperation(_ event: TokenEvent) {
        switch event {
        case let .tokenRequested(type):
            logger.debug("🔑 Token requested: \(type)")

        case let .tokenRetrieved(type, expiresIn):
            if let expiresIn {
                logger.debug("✅ Token retrieved: \(type), expires in \(expiresIn)s")
            } else {
                logger.debug("✅ Token retrieved: \(type)")
            }

        case let .tokenRefreshStarted(type):
            logger.info("🔄 Token refresh started: \(type)")

        case let .tokenRefreshSuccess(type):
            logger.info("✅ Token refresh successful: \(type)")

        case let .tokenRefreshFailure(error, type):
            let errorDetails = classifyTokenError(error)
            logger.error("❌ Token refresh failed - Type: \(type), Error: \(errorDetails.description)")

        case let .tokenValidationFailure(type, reason):
            logger.warning("⚠️ Token validation failed - Type: \(type), Reason: \(reason)")

        case .tokenCleared:
            logger.info("🧹 Authentication tokens cleared")

        case let .tokenNearExpiry(type, expiresIn):
            logger.info("⏰ Token near expiry - Type: \(type), expires in \(expiresIn)s")
        }
    }

    // MARK: - Network Operation Logging

    /// Log network operations with authentication context
    func logNetworkOperation(_ event: NetworkEvent) {
        switch event {
        case let .requestStarted(method, endpoint, hasAuth):
            let authStatus = hasAuth ? "with auth" : "without auth"
            logger.debug("🌐 \(method) request started: \(endpoint) (\(authStatus))")

        case let .requestSuccess(method, endpoint, statusCode):
            logger.debug("✅ \(method) request successful: \(endpoint) (\(statusCode))")

        case let .requestFailure(method, endpoint, error):
            let errorDetails = classifyNetworkError(error)
            logger.error("❌ \(method) request failed: \(endpoint) - \(errorDetails.description)")

        case .authHeaderAdded:
            logger.debug("🔑 Authorization header added to request")

        case let .authHeaderMissing(reason):
            logger.warning("⚠️ Authorization header missing: \(reason)")

        case let .unauthorizedResponse(endpoint):
            logger.warning("🚫 Unauthorized response from: \(endpoint)")

        case let .retryAttempt(attempt, maxRetries, endpoint):
            logger.info("🔄 Retry attempt \(attempt)/\(maxRetries) for: \(endpoint)")

        case .connectionRestored:
            logger.info("🌐 Network connection restored")

        case .connectionLost:
            logger.warning("⚠️ Network connection lost")
        }
    }

    // MARK: - Error Recovery Logging

    /// Log error recovery attempts and outcomes
    func logRecoveryAttempt(_ event: RecoveryEvent) {
        switch event {
        case let .recoveryStarted(strategy, originalError):
            let errorDetails = classifyGenericError(originalError)
            logger.info("🔧 Recovery started - Strategy: \(strategy), Original error: \(errorDetails.description)")

        case let .recoverySuccess(strategy):
            logger.info("✅ Recovery successful using strategy: \(strategy)")

        case let .recoveryFailure(strategy, error):
            let errorDetails = classifyGenericError(error)
            logger.error("❌ Recovery failed - Strategy: \(strategy), Error: \(errorDetails.description)")

        case let .fallbackActivated(fallback):
            logger.warning("⚠️ Fallback activated: \(fallback)")
        }
    }

    // MARK: - Production-Safe Data Sanitization

    /// Sanitize user ID for production-safe logging
    private func sanitizeUserId(_ userId: String) -> String {
        #if DEBUG
            return userId
        #else
            // In production, only show first 4 and last 4 characters
            guard userId.count > 8 else {
                return String(repeating: "*", count: userId.count)
            }
            let start = userId.prefix(4)
            let end = userId.suffix(4)
            let middle = String(repeating: "*", count: userId.count - 8)
            return "\(start)\(middle)\(end)"
        #endif
    }

    /// Sanitize token for production-safe logging (never log actual token content)
    private func sanitizeToken(_ token: String) -> String {
        "***TOKEN(\(token.count) chars)***"
    }

    // MARK: - Error Classification

    /// Classify configuration errors for structured error handling
    private func classifyConfigurationError(_ error: Error) -> ClassifiedError {
        if let configError = error as? ConfigurationError {
            switch configError {
            case let .fileNotFound(message):
                return ClassifiedError(
                    category: .configuration,
                    severity: .critical,
                    description: "Configuration file not found: \(message)",
                    recoverable: false
                )
            case .invalidFormat:
                return ClassifiedError(
                    category: .configuration,
                    severity: .critical,
                    description: "Invalid configuration file format",
                    recoverable: false
                )
            case let .missingRequiredKeys(keys):
                return ClassifiedError(
                    category: .configuration,
                    severity: .critical,
                    description: "Missing required configuration keys: \(keys.joined(separator: ", "))",
                    recoverable: false
                )
            case let .amplifyInitializationFailed(underlyingError):
                return ClassifiedError(
                    category: .configuration,
                    severity: .critical,
                    description: "Amplify initialization failed: \(underlyingError.localizedDescription)",
                    recoverable: false
                )
            }
        }

        return ClassifiedError(
            category: .configuration,
            severity: .critical,
            description: "Unknown configuration error: \(error.localizedDescription)",
            recoverable: false
        )
    }

    /// Classify authentication errors for structured error handling
    private func classifyAuthenticationError(_ error: Error) -> ClassifiedError {
        if let authError = error as? AuthError {
            switch authError {
            case let .configurationError(message):
                return ClassifiedError(
                    category: .authentication,
                    severity: .critical,
                    description: "Auth configuration error: \(message)",
                    recoverable: false
                )
            case let .networkError(networkError):
                return ClassifiedError(
                    category: .network,
                    severity: .moderate,
                    description: "Network error during authentication: \(networkError.localizedDescription)",
                    recoverable: true
                )
            case .tokenExpired:
                return ClassifiedError(
                    category: .authentication,
                    severity: .moderate,
                    description: "Authentication token expired",
                    recoverable: true
                )
            case .invalidCredentials:
                return ClassifiedError(
                    category: .authentication,
                    severity: .low,
                    description: "Invalid credentials provided",
                    recoverable: true
                )
            case .userCancelled:
                return ClassifiedError(
                    category: .user,
                    severity: .low,
                    description: "Authentication cancelled by user",
                    recoverable: true
                )
            case let .unknownError(unknownError):
                return ClassifiedError(
                    category: .authentication,
                    severity: .moderate,
                    description: "Unknown authentication error: \(unknownError.localizedDescription)",
                    recoverable: true
                )
            }
        }

        return classifyGenericError(error)
    }

    /// Classify token errors for structured error handling
    private func classifyTokenError(_ error: Error) -> ClassifiedError {
        if let tokenError = error as? TokenError {
            switch tokenError {
            case .userNotSignedIn:
                return ClassifiedError(
                    category: .authentication,
                    severity: .moderate,
                    description: "User not signed in",
                    recoverable: true
                )
            case .tokenProviderUnavailable:
                return ClassifiedError(
                    category: .configuration,
                    severity: .critical,
                    description: "Token provider unavailable",
                    recoverable: false
                )
            case let .tokenRetrievalFailed(underlyingError):
                return ClassifiedError(
                    category: .token,
                    severity: .moderate,
                    description: "Token retrieval failed: \(underlyingError.localizedDescription)",
                    recoverable: true
                )
            case .tokenExpired:
                return ClassifiedError(
                    category: .token,
                    severity: .moderate,
                    description: "Token expired",
                    recoverable: true
                )
            case .tokenValidationFailed:
                return ClassifiedError(
                    category: .token,
                    severity: .moderate,
                    description: "Token validation failed",
                    recoverable: true
                )
            case let .authenticationFailure(authError):
                return ClassifiedError(
                    category: .authentication,
                    severity: .moderate,
                    description: "Authentication failure: \(authError.localizedDescription)",
                    recoverable: true
                )
            }
        }

        return classifyGenericError(error)
    }

    /// Classify network errors for structured error handling
    private func classifyNetworkError(_ error: Error) -> ClassifiedError {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .invalidURL:
                return ClassifiedError(
                    category: .configuration,
                    severity: .critical,
                    description: "Invalid URL configuration",
                    recoverable: false
                )
            case .invalidResponse:
                return ClassifiedError(
                    category: .network,
                    severity: .moderate,
                    description: "Invalid response format",
                    recoverable: true
                )
            case let .serverError(statusCode, message):
                let severity: ErrorSeverity = statusCode >= 500 ? .moderate : .low
                return ClassifiedError(
                    category: .network,
                    severity: severity,
                    description: "Server error (\(statusCode)): \(message ?? "Unknown")",
                    recoverable: true
                )
            case .decodingError:
                return ClassifiedError(
                    category: .network,
                    severity: .moderate,
                    description: "Response decoding error",
                    recoverable: true
                )
            case .noData:
                return ClassifiedError(
                    category: .network,
                    severity: .moderate,
                    description: "No data received",
                    recoverable: true
                )
            case .unauthorized:
                return ClassifiedError(
                    category: .authentication,
                    severity: .moderate,
                    description: "Unauthorized request",
                    recoverable: true
                )
            case let .tokenRefreshFailed(tokenError):
                return ClassifiedError(
                    category: .token,
                    severity: .moderate,
                    description: "Token refresh failed: \(tokenError.localizedDescription)",
                    recoverable: true
                )
            case let .authenticationFailure(authError):
                return ClassifiedError(
                    category: .authentication,
                    severity: .moderate,
                    description: "Authentication failure: \(authError.localizedDescription)",
                    recoverable: true
                )
            case .networkTimeout:
                return ClassifiedError(
                    category: .network,
                    severity: .moderate,
                    description: "Network timeout",
                    recoverable: true
                )
            case .malformedResponse:
                return ClassifiedError(
                    category: .network,
                    severity: .moderate,
                    description: "Malformed response",
                    recoverable: true
                )
            case .noConnection:
                return ClassifiedError(
                    category: .network,
                    severity: .moderate,
                    description: "No network connection",
                    recoverable: true
                )
            }
        }

        return classifyGenericError(error)
    }

    /// Classify generic errors
    private func classifyGenericError(_ error: Error) -> ClassifiedError {
        let description = error.localizedDescription.lowercased()

        if description.contains("network") || description.contains("connection") {
            return ClassifiedError(
                category: .network,
                severity: .moderate,
                description: "Network error: \(error.localizedDescription)",
                recoverable: true
            )
        } else if description.contains("token") {
            return ClassifiedError(
                category: .token,
                severity: .moderate,
                description: "Token error: \(error.localizedDescription)",
                recoverable: true
            )
        } else if description.contains("auth") {
            return ClassifiedError(
                category: .authentication,
                severity: .moderate,
                description: "Authentication error: \(error.localizedDescription)",
                recoverable: true
            )
        } else {
            return ClassifiedError(
                category: .unknown,
                severity: .moderate,
                description: "Unknown error: \(error.localizedDescription)",
                recoverable: true
            )
        }
    }
}

// MARK: - Event Types

enum ConfigurationEvent {
    case configurationStarted(environment: String)
    case configurationFileLoaded(fileName: String, path: String)
    case configurationValidationPassed(fileName: String)
    case configurationSuccess(environment: String, fileName: String)
    case configurationFailure(error: Error, environment: String, fileName: String)
}

enum AuthStateEvent {
    case stateChanged(from: AuthenticationState, to: AuthenticationState)
    case signInStarted(method: String)
    case signInSuccess(userId: String, method: String)
    case signInFailure(error: Error, method: String)
    case signOutStarted
    case signOutSuccess
    case signOutFailure(error: Error)
    case sessionRestored(userId: String)
    case sessionExpired
    case userAttributesLoaded(count: Int)
    case userAttributesFailure(error: Error)
}

enum TokenEvent {
    case tokenRequested(type: String)
    case tokenRetrieved(type: String, expiresIn: Int?)
    case tokenRefreshStarted(type: String)
    case tokenRefreshSuccess(type: String)
    case tokenRefreshFailure(error: Error, type: String)
    case tokenValidationFailure(type: String, reason: String)
    case tokenCleared
    case tokenNearExpiry(type: String, expiresIn: Int)
}

enum NetworkEvent {
    case requestStarted(method: String, endpoint: String, hasAuth: Bool)
    case requestSuccess(method: String, endpoint: String, statusCode: Int)
    case requestFailure(method: String, endpoint: String, error: Error)
    case authHeaderAdded
    case authHeaderMissing(reason: String)
    case unauthorizedResponse(endpoint: String)
    case retryAttempt(attempt: Int, maxRetries: Int, endpoint: String)
    case connectionRestored
    case connectionLost
}

enum RecoveryEvent {
    case recoveryStarted(strategy: String, originalError: Error)
    case recoverySuccess(strategy: String)
    case recoveryFailure(strategy: String, error: Error)
    case fallbackActivated(fallback: String)
}

// MARK: - Error Classification Types

struct ClassifiedError {
    let category: ErrorCategory
    let severity: ErrorSeverity
    let description: String
    let recoverable: Bool
}

enum ErrorCategory {
    case configuration
    case authentication
    case token
    case network
    case user
    case unknown
}

enum ErrorSeverity {
    case low
    case moderate
    case critical
}

// MARK: - Authentication State Extensions

extension AuthenticationState {
    var description: String {
        switch self {
        case .unknown:
            "unknown"
        case let .authenticated(user):
            "authenticated(\(user.userId))"
        case .unauthenticated:
            "unauthenticated"
        case let .error(error):
            "error(\(error.localizedDescription))"
        }
    }
}
