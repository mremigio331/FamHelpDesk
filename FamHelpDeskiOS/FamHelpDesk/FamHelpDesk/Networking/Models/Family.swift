import Foundation

struct Family: Codable, Identifiable, Hashable {
    let familyId: String
    let familyName: String
    let familyDescription: String?
    let createdBy: String
    let creationDate: TimeInterval

    var id: String { familyId }

    var createdAt: String {
        let date = Date(timeIntervalSince1970: creationDate)
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(familyId)
    }

    static func == (lhs: Family, rhs: Family) -> Bool {
        lhs.familyId == rhs.familyId
    }
}

struct FamilyMembership: Codable {
    let userId: String
    let familyId: String
    let status: String
    let isAdmin: Bool
    let requestDate: TimeInterval

    var joinedAt: String? {
        let date = Date(timeIntervalSince1970: requestDate)
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}

struct MyFamilyItem: Codable {
    let family: Family
    let membership: FamilyMembership
}

struct GetAllFamiliesResponse: Codable {
    let families: [Family]
}

struct GetMyFamiliesResponse: Codable {
    let families: [String: MyFamilyItem]
}

struct CreateFamilyRequest: Codable {
    let familyName: String
    let familyDescription: String?
}

struct CreateFamilyResponse: Codable {
    let family: Family
}
