import Foundation

struct UserProfile: Codable, Identifiable {
    let userId: String
    let displayName: String
    let nickName: String
    let email: String

    var id: String { userId }
}

struct UserProfileResponse: Codable {
    let userProfile: UserProfile
}
