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
        isFetching = true
        errorMessage = nil

        print("🔄 Loading user profile...")
        do {
            currentUser = try await userService.getUserProfile()
            print("✅ User profile loaded successfully")
        } catch let error as NetworkError {
            print("❌ Network error loading profile: \(error)")
            errorMessage = handleNetworkError(error)
            // Only sign out on unauthorized, not other errors
            if case .unauthorized = error {
                signOut()
            }
        } catch {
            print("❌ Unexpected error loading profile: \(error)")
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }

        isFetching = false
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
