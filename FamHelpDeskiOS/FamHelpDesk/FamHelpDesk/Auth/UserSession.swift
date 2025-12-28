import Foundation
import SwiftUI

@Observable
final class UserSession {
    static let shared = UserSession()

    // User state
    var currentUser: UserProfile?
    var authToken: String?

    // Loading states
    var isLoading = false
    var isFetching = false
    var errorMessage: String?

    // Computed properties
    var isAuthenticated: Bool { currentUser != nil }

    private let userService = UserService()

    // AppStorage for token persistence
    @ObservationIgnored
    @AppStorage("authToken") private var storedToken: String?

    private init() {
        // Auto-load profile if we have a stored token
        if let token = storedToken {
            authToken = token
            NetworkManager.shared.setAccessToken(token)
            Task {
                await loadUserProfile()
            }
        }
    }

    /// Sign in with a token and load user profile
    /// - Parameter token: The authentication token from Cognito
    @MainActor
    func signIn(token: String) async {
        isLoading = true
        errorMessage = nil

        authToken = token
        storedToken = token
        NetworkManager.shared.setAccessToken(token)

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
    func signOut() {
        currentUser = nil
        authToken = nil
        storedToken = nil
        errorMessage = nil
        NetworkManager.shared.clearAccessToken()
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
        }
    }
}
