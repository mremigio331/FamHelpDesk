import Foundation
import SwiftUI

enum ProfileColor: String, CaseIterable, Identifiable {
    case black = "Black"
    case white = "White"
    case red = "Red"
    case blue = "Blue"
    case green = "Green"
    case yellow = "Yellow"
    case orange = "Orange"
    case purple = "Purple"
    case pink = "Pink"
    case brown = "Brown"
    case gray = "Gray"
    case cyan = "Cyan"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var color: Color {
        switch self {
        case .black: .black
        case .white: .white
        case .red: .red
        case .blue: .blue
        case .green: .green
        case .yellow: .yellow
        case .orange: .orange
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        case .gray: .gray
        case .cyan: .cyan
        }
    }
}

extension Color {
    static let brown = Color(red: 0.6, green: 0.4, blue: 0.2)
    static let cyan = Color.cyan
}

struct DarkModeSettings: Codable {
    let web: Bool
    let mobile: Bool
    let ios: Bool
}

struct UserProfile: Codable, Identifiable {
    let userId: String
    let displayName: String
    let email: String
    let profileColor: String
    let darkMode: DarkModeSettings?

    var id: String { userId }

    // Memberwise initializer for creating instances in code
    init(userId: String, displayName: String, email: String, profileColor: String, darkMode: DarkModeSettings? = nil) {
        self.userId = userId
        self.displayName = displayName
        self.email = email
        self.profileColor = profileColor
        self.darkMode = darkMode
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case email
        case profileColor = "profile_color"
        case darkMode = "dark_mode"
    }

    // Custom decoder to handle both boolean and object dark_mode
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        userId = try container.decode(String.self, forKey: .userId)
        displayName = try container.decode(String.self, forKey: .displayName)
        email = try container.decode(String.self, forKey: .email)
        profileColor = try container.decode(String.self, forKey: .profileColor)

        // Handle dark_mode as either boolean or DarkModeSettings object
        if let darkModeObject = try? container.decode(DarkModeSettings.self, forKey: .darkMode) {
            darkMode = darkModeObject
        } else if let darkModeBool = try? container.decode(Bool.self, forKey: .darkMode) {
            // Convert boolean to DarkModeSettings
            darkMode = DarkModeSettings(web: darkModeBool, mobile: darkModeBool, ios: darkModeBool)
        } else {
            darkMode = nil
        }
    }
}

struct UserProfileResponse: Codable {
    let userProfile: UserProfile

    enum CodingKeys: String, CodingKey {
        case userProfile = "user_profile"
    }
}
