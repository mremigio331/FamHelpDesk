import Amplify
import Foundation
import SwiftUI

@Observable
final class UserSession {
    static let shared = UserSession()

    // User state
    var currentUser: UserProfile?

    // Note: authToken is managed by AuthManager via Keychain - not stored here
    // This avoids duplicate token storage and synchronization issues

    // Loading states
    var isLoading = false
    var isFetching = false
    var errorMessage: String?

    // Computed properties
    var isAuthenticated: Bool { currentUser != nil }

    private let userService = UserService()

    private init() {
        // Token management is centralized in AuthManager
        // AuthManager will call signIn(token:) when restoring session from Keychain
    }

    /// Sign in with a token and load user profile
    /// - Parameter token: The authentication token from Cognito (managed by AuthManager)
    /// Note: Token persistence is handled by AuthManager via Keychain
    @MainActor
    func signIn(token _: String) async {
        isLoading = true
        errorMessage = nil

        // Don't store token here - AuthManager handles token persistence via Keychain
        // NetworkManager token is already set by AuthManager

        await loadUserProfile()

        isLoading = false
    }

    /// Load or refresh the user's profile
    @MainActor
    func loadUserProfile() async {
        // Don't start loading if already loading
        guard !isFetching else { return }

        isFetching = true
        isLoading = true
        errorMessage = nil

        print("🔄 Loading user profile...")

        // Retry logic for profile loading
        for attempt in 1 ... 3 {
            do {
                currentUser = try await userService.getUserProfile()
                print("✅ User profile loaded successfully on attempt \(attempt)")
                errorMessage = nil
                isFetching = false
                isLoading = false
                return

            } catch let error as NetworkError {
                print("🔄 Attempt \(attempt)/3 failed with network error: \(error)")

                // Only sign out on unauthorized, not other errors
                if case .unauthorized = error {
                    print("❌ Unauthorized error - signing out via Amplify")
                    await handleUnauthorizedError()
                    isFetching = false
                    isLoading = false
                    return
                }

                // For other errors, retry unless it's the last attempt
                if attempt < 3 {
                    // Wait before retrying (exponential backoff)
                    do {
                        try await Task.sleep(nanoseconds: UInt64(attempt * 500_000_000)) // 0.5s, 1s, 1.5s
                    } catch {
                        // Sleep was cancelled, continue anyway
                    }
                } else {
                    // All attempts failed
                    print("❌ All attempts failed to load profile: \(error)")
                    errorMessage = handleNetworkError(error)
                }

            } catch {
                print("🔄 Attempt \(attempt)/3 failed with unexpected error: \(error)")

                if attempt < 3 {
                    // Wait before retrying
                    do {
                        try await Task.sleep(nanoseconds: UInt64(attempt * 500_000_000))
                    } catch {
                        // Sleep was cancelled, continue anyway
                    }
                } else {
                    // All attempts failed
                    print("❌ All attempts failed with unexpected error: \(error)")
                    errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                }
            }
        }

        isFetching = false
        isLoading = false
    }

    /// Handle unauthorized errors by signing out
    private func handleUnauthorizedError() async {
        // Clear local state
        currentUser = nil
        errorMessage = nil

        // Clear network manager tokens
        NetworkManager.shared.clearAccessToken()
        APIClient.shared.clearAccessToken()

        // Sign out from Amplify to trigger auth state change
        do {
            _ = await Amplify.Auth.signOut()
            print("✅ Successfully signed out from Amplify")
        } catch {
            print("⚠️ Error during Amplify sign out: \(error)")
            // Force clear tokens anyway
            await AuthSessionManager.shared.clearTokens()
        }
    }

    /// Sign out and clear all user data
    /// Note: Token cleanup is handled by AuthManager.signOut()
    func signOut() {
        currentUser = nil
        errorMessage = nil
        // NetworkManager token clearing is handled by AuthManager
    }

    /// Refresh user profile data
    @MainActor
    func refreshProfile() async {
        await loadUserProfile()
    }

    private func handleNetworkError(_ error: NetworkError) -> String {
        switch error {
        case .invalidURL:
            "Invalid URL configuration"
        case .invalidResponse:
            "Invalid server response"
        case let .serverError(statusCode, message):
            message ?? "Server error (\(statusCode))"
        case .decodingError:
            "Failed to process server response"
        case .noData:
            "No data received from server"
        case .unauthorized:
            "Unauthorized - please log in again"
        case let .tokenRefreshFailed(underlyingError):
            "Token refresh failed: \(underlyingError.localizedDescription)"
        case let .authenticationFailure(underlyingError):
            "Authentication failed: \(underlyingError.localizedDescription)"
        case .networkTimeout:
            "Network request timed out"
        case .malformedResponse:
            "Received malformed response from server"
        case .noConnection:
            "No internet connection available"
        }
    }
}
