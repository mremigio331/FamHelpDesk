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
        do {
            // Get raw data to see the actual API response
            let rawData = try await networkManager.getRawData(
                endpoint: APIEndpoint.getProfile.path
            )

            print("📱 Raw User Profile API Response:")
            if let responseString = String(data: rawData, encoding: .utf8) {
                print(responseString)
            }

            let decoder = JSONDecoder()

            // The API returns {"user_profile": {...}} so decode as UserProfileResponse
            let response = try decoder.decode(UserProfileResponse.self, from: rawData)

            print("📱 User Profile Response:")
            print("  - User ID: \(response.userProfile.userId)")
            print("  - Display Name: \(response.userProfile.displayName)")
            print("  - Email: \(response.userProfile.email)")
            print("  - Profile Color: \(response.userProfile.profileColor)")
            print("  - Dark Mode: \(response.userProfile.darkMode)")

            return response.userProfile
        } catch {
            print("❌ Error in getUserProfile: \(error)")
            throw error
        }
    }

    /// Updates the current user's profile
    /// - Parameters:
    ///   - displayName: Optional new display name
    ///   - profileColor: Optional new profile color
    ///   - darkMode: Optional new dark mode setting
    /// - Returns: Updated UserProfile object
    /// - Throws: NetworkError if the request fails
    func updateUserProfile(
        displayName: String? = nil,
        profileColor: String? = nil,
        darkMode: Bool? = nil
    ) async throws -> UserProfile {
        let request = UpdateUserProfileRequest(
            displayName: displayName,
            profileColor: profileColor,
            darkMode: darkMode
        )

        print("📱 Sending update request: \(request)")

        let response: UserProfileResponse = try await networkManager.put(
            endpoint: APIEndpoint.updateProfile.path,
            body: request
        )

        print("📱 Updated User Profile:")
        print("  - User ID: \(response.userProfile.userId)")
        print("  - Display Name: \(response.userProfile.displayName)")
        print("  - Email: \(response.userProfile.email)")
        print("  - Profile Color: \(response.userProfile.profileColor)")
        print("  - Dark Mode: \(response.userProfile.darkMode)")

        return response.userProfile
    }

    /// Updates only the display name
    func updateDisplayName(_ displayName: String) async throws -> UserProfile {
        try await updateUserProfile(displayName: displayName)
    }

    /// Updates only the profile color
    func updateProfileColor(_ profileColor: String) async throws -> UserProfile {
        try await updateUserProfile(profileColor: profileColor)
    }

    /// Updates only the dark mode setting
    func updateDarkMode(_ darkMode: Bool) async throws -> UserProfile {
        try await updateUserProfile(darkMode: darkMode)
    }
}

struct UpdateUserProfileRequest: Codable {
    let displayName: String?
    let profileColor: String?
    let darkMode: Bool?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case profileColor = "profile_color"
        case darkMode = "dark_mode"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Only encode non-nil values
        if let displayName {
            try container.encode(displayName, forKey: .displayName)
        }

        if let profileColor {
            try container.encode(profileColor, forKey: .profileColor)
        }

        if let darkMode {
            try container.encode(darkMode, forKey: .darkMode)
        }
    }
}
