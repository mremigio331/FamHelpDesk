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
}

struct UserProfileResponse: Codable {
    let userProfile: UserProfile
}
