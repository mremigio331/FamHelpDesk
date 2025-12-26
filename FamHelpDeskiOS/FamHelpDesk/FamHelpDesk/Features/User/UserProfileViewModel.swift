import Foundation
import Observation

/// Legacy ViewModel - Consider using UserSession from @Environment instead
/// This ViewModel is still useful for isolated profile operations that don't need global state
@Observable
final class UserProfileViewModel {
    var userProfile: UserProfile?
    var isLoading = false
    var errorMessage: String?

    private let userService: UserService

    init(userService: UserService = UserService()) {
        self.userService = userService
    }

    @MainActor
    func fetchUserProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            userProfile = try await userService.getUserProfile()
        } catch let error as NetworkError {
            handleNetworkError(error)
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func handleNetworkError(_ error: NetworkError) {
        switch error {
        case .invalidURL:
            errorMessage = "Invalid URL configuration"
        case .invalidResponse:
            errorMessage = "Invalid server response"
        case let .serverError(statusCode, message):
            errorMessage = message ?? "Server error (\(statusCode))"
        case .decodingError:
            errorMessage = "Failed to process server response"
        case .noData:
            errorMessage = "No data received from server"
        case .unauthorized:
            errorMessage = "Unauthorized - please log in again"
        }
    }

    func clearProfile() {
        userProfile = nil
        errorMessage = nil
    }
}
