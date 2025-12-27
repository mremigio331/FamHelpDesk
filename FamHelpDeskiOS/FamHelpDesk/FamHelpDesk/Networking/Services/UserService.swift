import Foundation

final class UserService {
    private let networkManager: NetworkManager

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    /// Fetches the current user's profile
    /// - Returns: UserProfile object
    /// - Throws: NetworkError if the request fails
    func getUserProfile() async throws -> UserProfile {
        let response: UserProfileResponse = try await networkManager.get(
            endpoint: APIEndpoint.getProfile.path
        )
        print("📱 User Profile Response:")
        print("  - User ID: \(response.userProfile.userId)")
        print("  - Display Name: \(response.userProfile.displayName)")
        print("  - Nickname: \(response.userProfile.nickName)")
        print("  - Email: \(response.userProfile.email)")
        return response.userProfile
    }

    /// Updates the current user's profile
    /// - Parameters:
    ///   - displayName: Optional new display name
    ///   - nickName: Optional new nickname
    /// - Returns: Updated UserProfile object
    /// - Throws: NetworkError if the request fails
    func updateUserProfile(displayName: String?, nickName: String?) async throws -> UserProfile {
        var body: [String: String] = [:]

        if let displayName = displayName {
            body["display_name"] = displayName
        }

        if let nickName = nickName {
            body["nick_name"] = nickName
        }

        let response: UserProfileResponse = try await networkManager.put(
            endpoint: APIEndpoint.updateProfile.path,
            body: body
        )

        print("📱 Updated User Profile:")
        print("  - User ID: \(response.userProfile.userId)")
        print("  - Display Name: \(response.userProfile.displayName)")
        print("  - Nickname: \(response.userProfile.nickName)")
        print("  - Email: \(response.userProfile.email)")

        return response.userProfile
    }
}
