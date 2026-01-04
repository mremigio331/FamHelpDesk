import Amplify
import AWSCognitoAuthPlugin
import Combine
import Foundation
import UIKit // Import UIKit for UIWindow and UIApplication

// MARK: - Authentication Error Types

enum AuthError: Error, LocalizedError {
    case configurationError(String)
    case networkError(Error)
    case tokenExpired
    case invalidCredentials
    case userCancelled
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case let .configurationError(message):
            "Configuration error: \(message)"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case .tokenExpired:
            "Authentication token has expired"
        case .invalidCredentials:
            "Invalid credentials provided"
        case .userCancelled:
            "Authentication was cancelled by user"
        case let .unknownError(error):
            "Unknown authentication error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Authentication State

enum AuthenticationState {
    case unknown
    case authenticated(user: AuthUser)
    case unauthenticated
    case error(AuthError)
}

// MARK: - Auth User Model

struct AuthUser {
    let userId: String
    let displayName: String?
    let email: String?
    let attributes: [AuthUserAttribute]
}

final class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userDisplayName: String?
    @Published var authError: AuthError?
    @Published var authenticationState: AuthenticationState = .unknown

    private var cancellables = Set<AnyCancellable>()
    private let logger = AuthLogger.shared
    private let errorRecovery = AuthErrorRecovery.shared

    init() {
        Task {
            await checkAuthStatus()
        }

        // Listen for authentication state changes
        setupAuthStateListener()
    }

    // MARK: - Authentication State Management

    private func setupAuthStateListener() {
        // Listen for Amplify auth state changes
        Task {
            for await authState in Amplify.Hub.publisher(for: .auth).values {
                await handleAuthStateChange(authState)
            }
        }
    }

    @MainActor
    private func handleAuthStateChange(_ hubPayload: HubPayload) {
        guard let authEventName = hubPayload.eventName as? String else { return }

        let previousState = authenticationState
        logger.logAuthenticationStateChange(.stateChanged(from: previousState, to: authenticationState))

        switch authEventName {
        case HubPayload.EventName.Auth.signedIn:
            logger.logAuthenticationStateChange(.stateChanged(from: previousState, to: .authenticated(user: AuthUser(userId: "pending", displayName: nil, email: nil, attributes: []))))
            Task {
                await loadUserAttributesAndUpdateState()
            }
        case HubPayload.EventName.Auth.signedOut:
            logger.logAuthenticationStateChange(.signOutSuccess)
            isAuthenticated = false
            userDisplayName = nil
            authError = nil
            authenticationState = .unauthenticated
        case HubPayload.EventName.Auth.sessionExpired:
            logger.logAuthenticationStateChange(.sessionExpired)
            authError = AuthError.tokenExpired
            authenticationState = .error(.tokenExpired)
            Task {
                await handleSessionExpiry()
            }
        default:
            break
        }
    }

    /// Handle session expiry with automatic recovery
    private func handleSessionExpiry() async {
        let context = AuthContext(operation: "session_expiry", attempt: 1, userInitiated: false)
        let recoveryResult = await errorRecovery.recoverFromAuthenticationError(.tokenExpired, context: context)

        switch recoveryResult {
        case let .recovered(_, nextAction):
            switch nextAction {
            case .checkAuthStatus:
                await checkAuthStatus()
            case .retryOriginalOperation:
                // Session expiry doesn't have a specific operation to retry
                await checkAuthStatus()
            }
        case let .userAction(action, reason):
            await MainActor.run {
                self.authError = AuthError.tokenExpired
                self.authenticationState = .error(.tokenExpired)
            }
            logger.logAuthenticationStateChange(.signOutFailure(error: AuthError.tokenExpired))
        case let .fallback(_, reason):
            await signOut()
        case let .failed(reason):
            await signOut()
        }
    }

    @MainActor
    func checkAuthStatus() async {
        do {
            logger.logAuthenticationStateChange(.stateChanged(from: authenticationState, to: .unknown))
            let session = try await Amplify.Auth.fetchAuthSession()

            if session.isSignedIn {
                logger.logAuthenticationStateChange(.sessionRestored(userId: "pending"))
                await loadUserAttributesAndUpdateState()
            } else {
                logger.logAuthenticationStateChange(.stateChanged(from: authenticationState, to: .unauthenticated))
                isAuthenticated = false
                userDisplayName = nil
                authError = nil
                authenticationState = .unauthenticated
            }
        } catch {
            logger.logAuthenticationStateChange(.signInFailure(error: error, method: "status_check"))
            let authError = mapAmplifyError(error)

            // Attempt error recovery
            let context = AuthContext(operation: "check_auth_status", attempt: 1, userInitiated: false)
            let recoveryResult = await errorRecovery.recoverFromAuthenticationError(authError, context: context)

            switch recoveryResult {
            case let .recovered(_, nextAction):
                switch nextAction {
                case .checkAuthStatus:
                    await checkAuthStatus()
                case .retryOriginalOperation:
                    await checkAuthStatus()
                }
            case .userAction(_, _), .fallback(_, _), .failed:
                await MainActor.run {
                    self.isAuthenticated = false
                    self.userDisplayName = nil
                    self.authError = authError
                    self.authenticationState = .error(authError)
                }
            }
        }
    }

    @MainActor
    private func loadUserAttributesAndUpdateState() async {
        do {
            let currentUser = try await Amplify.Auth.getCurrentUser()

            // Try to get user attributes first
            var attributes: [AuthUserAttribute] = []
            var displayName: String?
            var email: String?

            do {
                attributes = try await loadUserAttributes()

                // Extract display name from attributes
                displayName = attributes.first(where: { $0.key == .name })?.value
                    ?? attributes.first(where: { $0.key == .givenName })?.value
                    ?? attributes.first(where: { $0.key == .email })?.value

                email = attributes.first(where: { $0.key == .email })?.value

                logger.logAuthenticationStateChange(.userAttributesLoaded(count: attributes.count))

            } catch {
                logger.logAuthenticationStateChange(.userAttributesFailure(error: error))

                // Fallback: Try to extract user info from ID token
                do {
                    if let idToken = try await AuthSessionManager.shared.getIDToken() {
                        let tokenInfo = extractUserInfoFromIDToken(idToken)
                        displayName = tokenInfo.name ?? tokenInfo.email ?? currentUser.username
                        email = tokenInfo.email
                        logger.logAuthenticationStateChange(.userAttributesLoaded(count: 0))
                    } else {
                        displayName = currentUser.username
                    }
                } catch {
                    logger.logAuthenticationStateChange(.userAttributesFailure(error: error))
                    displayName = currentUser.username
                }
            }

            let authUser = AuthUser(
                userId: currentUser.userId,
                displayName: displayName ?? currentUser.username,
                email: email,
                attributes: attributes
            )

            isAuthenticated = true
            userDisplayName = displayName ?? currentUser.username
            authError = nil
            authenticationState = .authenticated(user: authUser)

            logger.logAuthenticationStateChange(.signInSuccess(userId: currentUser.userId, method: "session_restore"))

        } catch {
            logger.logAuthenticationStateChange(.signInFailure(error: error, method: "load_user_attributes"))
            let authError = mapAmplifyError(error)
            self.authError = authError
            authenticationState = .error(authError)
        }
    }

    // Helper method to extract user info from ID token
    private func extractUserInfoFromIDToken(_ idToken: String) -> (name: String?, email: String?) {
        let segments = idToken.components(separatedBy: ".")
        guard segments.count > 1 else {
            print("⚠️ Invalid ID token format")
            return (nil, nil)
        }

        let payload = segments[1]
        // Add padding if needed for base64 decoding
        let paddedPayload = payload.padding(toLength: ((payload.count + 3) / 4) * 4, withPad: "=", startingAt: 0)

        guard let data = Data(base64Encoded: paddedPayload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            print("⚠️ Could not decode ID token payload")
            return (nil, nil)
        }

        let name = json["name"] as? String ?? json["given_name"] as? String
        let email = json["email"] as? String

        print("🔍 ID token contains - name: \(name ?? "none"), email: \(email ?? "none")")

        return (name, email)
    }

    private func loadUserAttributes() async throws -> [AuthUserAttribute] {
        do {
            let attributes = try await Amplify.Auth.fetchUserAttributes()
            logger.logAuthenticationStateChange(.userAttributesLoaded(count: attributes.count))
            return attributes
        } catch {
            logger.logAuthenticationStateChange(.userAttributesFailure(error: error))
            throw mapAmplifyError(error)
        }
    }

    // MARK: - Authentication Methods

    // Hosted UI Sign-in
    func signInWithHostedUI() async throws {
        logger.logAuthenticationStateChange(.signInStarted(method: "hosted_ui"))

        do {
            authError = nil

            let signInResult = try await Amplify.Auth.signInWithWebUI(
                presentationAnchor: getPresentationAnchor()
            )

            if signInResult.isSignedIn {
                logger.logAuthenticationStateChange(.signInSuccess(userId: "pending", method: "hosted_ui"))
                await loadUserAttributesAndUpdateState()
            } else {
                let error = NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sign-in completed but user not authenticated"])
                logger.logAuthenticationStateChange(.signInFailure(error: error, method: "hosted_ui"))
                throw AuthError.unknownError(error)
            }
        } catch {
            logger.logAuthenticationStateChange(.signInFailure(error: error, method: "hosted_ui"))

            // Check if error is due to user already being signed in
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("already a user in signedin state") {
                logger.logAuthenticationStateChange(.signOutStarted)
                await forceSignOut()

                // Wait a moment for sign out to complete
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                // Retry sign in
                return try await signInWithHostedUI()
            }

            // Attempt error recovery
            let authError = mapAmplifyError(error)
            let context = AuthContext(operation: "sign_in_hosted_ui", attempt: 1, userInitiated: true)
            let recoveryResult = await errorRecovery.recoverFromAuthenticationError(authError, context: context)

            switch recoveryResult {
            case let .recovered(_, nextAction):
                switch nextAction {
                case .retryOriginalOperation:
                    return try await signInWithHostedUI()
                case .checkAuthStatus:
                    await checkAuthStatus()
                    return
                }
            case .userAction(_, _), .fallback(_, _), .failed:
                await MainActor.run {
                    self.authError = authError
                    self.authenticationState = .error(authError)
                }
                throw authError
            }
        }
    }

    // Hosted UI Sign-up
    func hostedUISignUp() async throws {
        // Amplify doesn't have a direct signUp mode for web UI
        // Use signIn and Cognito will show signup option
        try await signInWithHostedUI()
    }

    // Sign in with Google
    func signInWithGoogle() async throws {
        logger.logAuthenticationStateChange(.signInStarted(method: "google"))

        do {
            authError = nil

            let signInResult = try await Amplify.Auth.signInWithWebUI(
                for: .google,
                presentationAnchor: getPresentationAnchor()
            )

            if signInResult.isSignedIn {
                logger.logAuthenticationStateChange(.signInSuccess(userId: "pending", method: "google"))
                await loadUserAttributesAndUpdateState()
            } else {
                let error = NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google sign-in completed but user not authenticated"])
                logger.logAuthenticationStateChange(.signInFailure(error: error, method: "google"))
                throw AuthError.unknownError(error)
            }
        } catch {
            logger.logAuthenticationStateChange(.signInFailure(error: error, method: "google"))

            // Attempt error recovery
            let authError = mapAmplifyError(error)
            let context = AuthContext(operation: "sign_in_google", attempt: 1, userInitiated: true)
            let recoveryResult = await errorRecovery.recoverFromAuthenticationError(authError, context: context)

            switch recoveryResult {
            case let .recovered(_, nextAction):
                switch nextAction {
                case .retryOriginalOperation:
                    return try await signInWithGoogle()
                case .checkAuthStatus:
                    await checkAuthStatus()
                    return
                }
            case .userAction(_, _), .fallback(_, _), .failed:
                await MainActor.run {
                    self.authError = authError
                    self.authenticationState = .error(authError)
                }
                throw authError
            }
        }
    }

    func signOut() async {
        logger.logAuthenticationStateChange(.signOutStarted)

        do {
            // Sign out from Amplify
            _ = await Amplify.Auth.signOut()

            await MainActor.run {
                isAuthenticated = false
                userDisplayName = nil
                authError = nil
                authenticationState = .unauthenticated

                // Clear network managers
                APIClient.shared.clearAccessToken()
                NetworkManager.shared.clearAccessToken()

                // Clear user session
                UserSession.shared.signOut()
            }

            logger.logAuthenticationStateChange(.signOutSuccess)

        } catch {
            logger.logAuthenticationStateChange(.signOutFailure(error: error))

            // Still clear local state even if sign out fails
            await MainActor.run {
                isAuthenticated = false
                userDisplayName = nil
                authError = mapAmplifyError(error)
                authenticationState = .unauthenticated

                // Clear network managers
                APIClient.shared.clearAccessToken()
                NetworkManager.shared.clearAccessToken()

                // Clear user session
                UserSession.shared.signOut()
            }
        }
    }

    // MARK: - Force Sign Out (Testing Helper)

    /// Force sign out - clears all authentication state and tokens
    /// Useful for testing scenarios where normal sign out might fail
    func forceSignOut() async {
        logger.logAuthenticationStateChange(.signOutStarted)

        do {
            // Try global sign out first (signs out from all devices)
            let signOutResult = await Amplify.Auth.signOut(options: .init(globalSignOut: true))
            logger.logAuthenticationStateChange(.signOutSuccess)
        } catch {
            logger.logAuthenticationStateChange(.signOutFailure(error: error))
        }

        // Clear all local state regardless of sign out result
        await MainActor.run {
            isAuthenticated = false
            userDisplayName = nil
            authError = nil
            authenticationState = .unauthenticated

            // Clear network managers
            APIClient.shared.clearAccessToken()
            NetworkManager.shared.clearAccessToken()

            // Clear user session
            UserSession.shared.signOut()
        }

        // Clear tokens from AuthSessionManager
        await AuthSessionManager.shared.clearTokens()

        logger.logAuthenticationStateChange(.signOutSuccess)
    }

    // MARK: - Helper Methods

    // Helper to get presentation anchor for web UI
    @MainActor
    private func getPresentationAnchor() -> UIWindow {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first ?? UIWindow()
    }

    // Legacy method for backward compatibility
    func signIn() async throws {
        try await signInWithHostedUI()
    }

    // MARK: - Error Mapping

    private func mapAmplifyError(_ error: Error) -> AuthError {
        if let authError = error as? AuthError {
            return authError
        }

        // Map Amplify-specific errors to our AuthError types
        let errorDescription = error.localizedDescription.lowercased()

        if errorDescription.contains("network") || errorDescription.contains("connection") {
            return .networkError(error)
        } else if errorDescription.contains("token") && errorDescription.contains("expired") {
            return .tokenExpired
        } else if errorDescription.contains("invalid") && (errorDescription.contains("credential") || errorDescription.contains("password")) {
            return .invalidCredentials
        } else if errorDescription.contains("cancel") || errorDescription.contains("abort") {
            return .userCancelled
        } else if errorDescription.contains("configuration") {
            return .configurationError(error.localizedDescription)
        } else {
            return .unknownError(error)
        }
    }
}
