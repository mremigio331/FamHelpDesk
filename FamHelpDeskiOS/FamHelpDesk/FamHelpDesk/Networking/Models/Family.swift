import Foundation

struct Family: Codable, Identifiable, Hashable {
    let familyId: String
    let familyName: String
    let familyDescription: String?
    let createdBy: String
    let creationDate: TimeInterval
    let isPrivate: Bool

    var id: String { familyId }

    var createdAt: String {
        let date = Date(timeIntervalSince1970: creationDate)
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case familyName = "family_name"
        case familyDescription = "family_description"
        case createdBy = "created_by"
        case creationDate = "creation_date"
        case isPrivate = "private"
    }

    // Regular initializer for direct creation
    init(
        familyId: String,
        familyName: String,
        familyDescription: String?,
        createdBy: String,
        creationDate: TimeInterval,
        isPrivate: Bool
    ) {
        self.familyId = familyId
        self.familyName = familyName
        self.familyDescription = familyDescription
        self.createdBy = createdBy
        self.creationDate = creationDate
        self.isPrivate = isPrivate
    }

    // Custom decoder that ignores unknown fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        familyId = try container.decode(String.self, forKey: .familyId)
        familyName = try container.decode(String.self, forKey: .familyName)
        familyDescription = try container.decodeIfPresent(String.self, forKey: .familyDescription)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        creationDate = try container.decode(TimeInterval.self, forKey: .creationDate)
        isPrivate = try container.decode(Bool.self, forKey: .isPrivate)
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

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case familyId = "family_id"
        case status
        case isAdmin = "is_admin"
        case requestDate = "request_date"
    }

    // Regular initializer for direct creation
    init(
        userId: String,
        familyId: String,
        status: String,
        isAdmin: Bool,
        requestDate: TimeInterval
    ) {
        self.userId = userId
        self.familyId = familyId
        self.status = status
        self.isAdmin = isAdmin
        self.requestDate = requestDate
    }

    // Custom decoder that ignores unknown fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        familyId = try container.decode(String.self, forKey: .familyId)
        status = try container.decode(String.self, forKey: .status)
        isAdmin = try container.decode(Bool.self, forKey: .isAdmin)
        requestDate = try container.decode(TimeInterval.self, forKey: .requestDate)
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

struct GetFamilyByIdResponse: Codable {
    let family: Family
}

struct CreateFamilyRequest: Codable {
    let familyName: String
    let familyDescription: String?
    let isPrivate: Bool

    enum CodingKeys: String, CodingKey {
        case familyName = "family_name"
        case familyDescription = "family_description"
        case isPrivate = "private"
    }
}

struct CreateFamilyResponse: Codable {
    let family: Family
}

struct UpdateFamilyRequest: Codable {
    let familyName: String
    let familyDescription: String?
    let isPrivate: Bool

    enum CodingKeys: String, CodingKey {
        case familyName = "family_name"
        case familyDescription = "family_description"
        case isPrivate = "private"
    }
}

struct UpdateFamilyResponse: Codable {
    let family: Family
}
