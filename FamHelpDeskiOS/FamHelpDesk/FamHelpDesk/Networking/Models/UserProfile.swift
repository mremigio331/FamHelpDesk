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

struct UserProfile: Codable, Identifiable {
    let userId: String
    let displayName: String
    let email: String
    let profileColor: String
    let darkMode: Bool

    var id: String { userId }

    // Memberwise initializer for creating instances in code
    init(userId: String, displayName: String, email: String, profileColor: String, darkMode: Bool = false) {
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
}

struct UserProfileResponse: Codable {
    let userProfile: UserProfile

    enum CodingKeys: String, CodingKey {
        case userProfile = "user_profile"
    }
}
