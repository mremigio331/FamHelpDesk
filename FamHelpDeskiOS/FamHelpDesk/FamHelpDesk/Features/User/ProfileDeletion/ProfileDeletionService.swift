//
//  ProfileDeletionService.swift
//  FamHelpDesk
//
//  Created on 1/25/26.
//

import Foundation

/// Protocol defining the profile deletion service interface
protocol ProfileDeletionServiceProtocol {
    /// Initiates profile deletion request
    /// - Returns: Result indicating success or failure with error details
    func deleteProfile() async -> Result<Void, ProfileDeletionError>
}

/// Service responsible for orchestrating the profile deletion flow
final class ProfileDeletionService: ProfileDeletionServiceProtocol {
    private let apiClient: APIClient
    private let authManager: AuthManager

    /// Initialize the profile deletion service with dependencies
    /// - Parameters:
    ///   - apiClient: The API client for making network requests
    ///   - authManager: The authentication manager for sign-out operations
    init(apiClient: APIClient = .shared, authManager: AuthManager) {
        self.apiClient = apiClient
        self.authManager = authManager
    }

    /// Deletes the user's profile and signs them out
    /// - Returns: Result indicating success or failure with error details
    func deleteProfile() async -> Result<Void, ProfileDeletionError> {
        print("🗑️ [PROFILE DELETION SERVICE] Starting profile deletion")
        print("🗑️ [PROFILE DELETION SERVICE] Auth state: \(authManager.authenticationState)")
        print("🗑️ [PROFILE DELETION SERVICE] Is authenticated: \(authManager.isAuthenticated)")

        do {
            // 1. Send DELETE request to /user/profile
            print("🗑️ [PROFILE DELETION SERVICE] Calling API client deleteUserProfile()")
            let response = try await apiClient.deleteUserProfile()

            // 2. Check response status code
            let statusCode = response.statusCode
            print("🗑️ [PROFILE DELETION SERVICE] Received status code: \(statusCode)")

            // 3. If 2xx, return success WITHOUT signing out
            // The confirmation view will be shown, and the user can tap "Back to Login"
            // to complete the sign-out process
            if (200 ..< 300).contains(statusCode) {
                print("🗑️ [PROFILE DELETION SERVICE] ✅ Success! Status code is 2xx")
                print("🗑️ [PROFILE DELETION SERVICE] Profile deletion successful - will show confirmation")
                return .success(())
            }

            // 4. If non-2xx, map to appropriate ProfileDeletionError
            print("🗑️ [PROFILE DELETION SERVICE] ❌ Non-2xx status code: \(statusCode)")
            let error = mapStatusCodeToError(statusCode: statusCode)
            print("🗑️ [PROFILE DELETION SERVICE] Mapped to error: \(error)")
            print("🗑️ [PROFILE DELETION SERVICE] User-facing message: \(error.userFacingMessage)")
            return .failure(error)

        } catch let error as ProfileDeletionError {
            // Already a ProfileDeletionError, return as-is
            print("🗑️ [PROFILE DELETION SERVICE] ❌ Caught ProfileDeletionError: \(error)")
            print("🗑️ [PROFILE DELETION SERVICE] User-facing message: \(error.userFacingMessage)")
            return .failure(error)
        } catch {
            // Network or other errors
            print("🗑️ [PROFILE DELETION SERVICE] ❌ Caught network/other error: \(error)")
            print("🗑️ [PROFILE DELETION SERVICE] Error type: \(type(of: error))")
            print("🗑️ [PROFILE DELETION SERVICE] Error description: \(error.localizedDescription)")
            return .failure(.networkError(error))
        }
    }

    /// Performs a local sign-out without triggering web views
    /// This clears all local authentication state and tokens
    /// Note: We skip Amplify.Auth.signOut() because it triggers a web view for Hosted UI users
    @MainActor
    private func performLocalSignOut() async {
        print("🗑️ [PROFILE DELETION SERVICE] Starting local sign-out (no web view)...")

        // Clear tokens FIRST before changing auth state
        // This prevents Amplify from trying to refresh tokens
        await AuthSessionManager.shared.clearTokens()
        print("🗑️ [PROFILE DELETION SERVICE] Tokens cleared")

        // Clear network managers
        APIClient.shared.clearAccessToken()
        NetworkManager.shared.clearAccessToken()
        print("🗑️ [PROFILE DELETION SERVICE] Network managers cleared")

        // Clear user session
        UserSession.shared.signOut()
        print("🗑️ [PROFILE DELETION SERVICE] User session cleared")

        // Now clear auth state LAST
        authManager.isAuthenticated = false
        authManager.userDisplayName = nil
        authManager.authError = nil
        authManager.authenticationState = .unauthenticated
        print("🗑️ [PROFILE DELETION SERVICE] Local auth state cleared")

        // Add a small delay to let the state settle
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // NOTE: We intentionally DO NOT call Amplify.Auth.signOut() here because:
        // 1. The user signed in with Hosted UI (signInWithWebUI)
        // 2. Amplify.Auth.signOut() tries to sign out through Hosted UI web view
        // 3. This causes the SFAuthenticationViewController error
        // 4. The backend has already deleted the user, so we just need to clear local state

        print("🗑️ [PROFILE DELETION SERVICE] Local sign-out complete (Amplify sign-out skipped)")
    }

    /// Maps HTTP status codes to appropriate ProfileDeletionError cases
    /// - Parameter statusCode: The HTTP status code from the response
    /// - Returns: The appropriate ProfileDeletionError
    private func mapStatusCodeToError(statusCode: Int) -> ProfileDeletionError {
        switch statusCode {
        case 401, 403:
            .authenticationRequired
        case 400 ..< 500:
            .clientError(statusCode: statusCode, message: nil)
        case 500 ..< 600:
            .serverError(statusCode: statusCode)
        default:
            .unknownError
        }
    }
}
