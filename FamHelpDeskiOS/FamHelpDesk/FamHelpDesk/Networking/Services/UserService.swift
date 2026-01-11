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
            if let darkMode = response.userProfile.darkMode {
                print("  - Dark Mode: Web=\(darkMode.web), Mobile=\(darkMode.mobile), iOS=\(darkMode.ios)")
            }

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
    ///   - darkMode: Optional new dark mode settings
    /// - Returns: Updated UserProfile object
    /// - Throws: NetworkError if the request fails
    func updateUserProfile(
        displayName: String? = nil,
        profileColor: String? = nil,
        darkMode: DarkModeSettings? = nil
    ) async throws -> UserProfile {
        let request = UpdateUserProfileRequest(
            displayName: displayName,
            profileColor: profileColor,
            darkMode: darkMode
        )

        let response: UserProfileResponse = try await networkManager.put(
            endpoint: APIEndpoint.updateProfile.path,
            body: request
        )

        print("📱 Updated User Profile:")
        print("  - User ID: \(response.userProfile.userId)")
        print("  - Display Name: \(response.userProfile.displayName)")
        print("  - Email: \(response.userProfile.email)")
        print("  - Profile Color: \(response.userProfile.profileColor)")
        if let darkMode = response.userProfile.darkMode {
            print("  - Dark Mode: Web=\(darkMode.web), Mobile=\(darkMode.mobile), iOS=\(darkMode.ios)")
        }

        return response.userProfile
    }
}

struct UpdateUserProfileRequest: Codable {
    let displayName: String?
    let profileColor: String?
    let darkMode: DarkModeSettings?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case profileColor = "profile_color"
        case darkMode = "dark_mode"
    }
}
