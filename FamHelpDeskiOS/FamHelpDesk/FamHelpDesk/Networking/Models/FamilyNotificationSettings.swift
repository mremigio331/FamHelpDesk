import Foundation

struct FamilyNotificationSettingsResponse: Codable {
    let settings: FamilyNotificationSettings
}

struct FamilyNotificationSettings: Codable, Identifiable {
    var id: String { "\(userId)_\(familyId)" }

    let userId: String
    let familyId: String
    let createdDate: Int
    let lastUpdated: Int?

    // Family
    let newFamilyCreationEnabled: Bool
    let welcomeEnabled: Bool

    // Family Membership
    let welcomeToFamilyEnabled: Bool
    let newFamilyMemberEnabled: Bool
    let familyMembershipApproved: Bool
    let familyMembershipDenied: Bool
    let familyMembershipInvitation: Bool
    let familyMembershipJoined: Bool
    let familyMembershipLeft: Bool
    let familyMembershipRequest: Bool

    // Group Membership
    let groupMembershipApproved: Bool
    let groupMembershipDenied: Bool
    let groupMembershipAdded: Bool
    let groupMembershipJoined: Bool
    let groupMembershipLeft: Bool
    let groupMembershipRequest: Bool
    let newGroupCreation: Bool

    // Tickets
    let ticketCreationFamily: Bool
    let ticketCreationGroup: Bool
    let ticketAssigned: Bool
    let ticketComment: Bool
    let ticketStatusChange: Bool
    let ticketResolved: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case familyId = "family_id"
        case createdDate = "created_date"
        case lastUpdated = "last_updated"

        // Family
        case newFamilyCreationEnabled = "new_family_creation_enabled"
        case welcomeEnabled = "welcome_enabled"

        // Family Membership
        case welcomeToFamilyEnabled = "welcome_to_family_enabled"
        case newFamilyMemberEnabled = "new_family_member_enabled"
        case familyMembershipApproved = "family_membership_approved"
        case familyMembershipDenied = "family_membership_denied"
        case familyMembershipInvitation = "family_membership_invitation"
        case familyMembershipJoined = "family_membership_joined"
        case familyMembershipLeft = "family_membership_left"
        case familyMembershipRequest = "family_membership_request"

        // Group Membership
        case groupMembershipApproved = "group_membership_approved"
        case groupMembershipDenied = "group_membership_denied"
        case groupMembershipAdded = "group_membership_added"
        case groupMembershipJoined = "group_membership_joined"
        case groupMembershipLeft = "group_membership_left"
        case groupMembershipRequest = "group_membership_request"
        case newGroupCreation = "new_group_creation"

        // Tickets
        case ticketCreationFamily = "ticket_creation_family"
        case ticketCreationGroup = "ticket_creation_group"
        case ticketAssigned = "ticket_assigned"
        case ticketComment = "ticket_comment"
        case ticketStatusChange = "ticket_status_change"
        case ticketResolved = "ticket_resolved"
    }

    // Custom decoder that ignores unknown fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        familyId = try container.decode(String.self, forKey: .familyId)
        createdDate = try container.decode(Int.self, forKey: .createdDate)
        lastUpdated = try container.decodeIfPresent(Int.self, forKey: .lastUpdated)

        // Family
        newFamilyCreationEnabled = try container.decode(Bool.self, forKey: .newFamilyCreationEnabled)
        welcomeEnabled = try container.decode(Bool.self, forKey: .welcomeEnabled)

        // Family Membership
        welcomeToFamilyEnabled = try container.decode(Bool.self, forKey: .welcomeToFamilyEnabled)
        newFamilyMemberEnabled = try container.decode(Bool.self, forKey: .newFamilyMemberEnabled)
        familyMembershipApproved = try container.decode(Bool.self, forKey: .familyMembershipApproved)
        familyMembershipDenied = try container.decode(Bool.self, forKey: .familyMembershipDenied)
        familyMembershipInvitation = try container.decode(Bool.self, forKey: .familyMembershipInvitation)
        familyMembershipJoined = try container.decode(Bool.self, forKey: .familyMembershipJoined)
        familyMembershipLeft = try container.decode(Bool.self, forKey: .familyMembershipLeft)
        familyMembershipRequest = try container.decode(Bool.self, forKey: .familyMembershipRequest)

        // Group Membership
        groupMembershipApproved = try container.decode(Bool.self, forKey: .groupMembershipApproved)
        groupMembershipDenied = try container.decode(Bool.self, forKey: .groupMembershipDenied)
        groupMembershipAdded = try container.decode(Bool.self, forKey: .groupMembershipAdded)
        groupMembershipJoined = try container.decode(Bool.self, forKey: .groupMembershipJoined)
        groupMembershipLeft = try container.decode(Bool.self, forKey: .groupMembershipLeft)
        groupMembershipRequest = try container.decode(Bool.self, forKey: .groupMembershipRequest)
        newGroupCreation = try container.decode(Bool.self, forKey: .newGroupCreation)

        // Tickets
        ticketCreationFamily = try container.decode(Bool.self, forKey: .ticketCreationFamily)
        ticketCreationGroup = try container.decode(Bool.self, forKey: .ticketCreationGroup)
        ticketAssigned = try container.decode(Bool.self, forKey: .ticketAssigned)
        ticketComment = try container.decode(Bool.self, forKey: .ticketComment)
        ticketStatusChange = try container.decode(Bool.self, forKey: .ticketStatusChange)
        ticketResolved = try container.decode(Bool.self, forKey: .ticketResolved)
    }
}

struct UpdateFamilyNotificationSettingsRequest: Codable {
    // Family
    let newFamilyCreationEnabled: Bool?
    let welcomeEnabled: Bool?

    // Family Membership
    let welcomeToFamilyEnabled: Bool?
    let newFamilyMemberEnabled: Bool?
    let familyMembershipApproved: Bool?
    let familyMembershipDenied: Bool?
    let familyMembershipInvitation: Bool?
    let familyMembershipJoined: Bool?
    let familyMembershipLeft: Bool?
    let familyMembershipRequest: Bool?

    // Group Membership
    let groupMembershipApproved: Bool?
    let groupMembershipDenied: Bool?
    let groupMembershipAdded: Bool?
    let groupMembershipJoined: Bool?
    let groupMembershipLeft: Bool?
    let groupMembershipRequest: Bool?
    let newGroupCreation: Bool?

    // Tickets
    let ticketCreationFamily: Bool?
    let ticketCreationGroup: Bool?
    let ticketAssigned: Bool?
    let ticketComment: Bool?
    let ticketStatusChange: Bool?
    let ticketResolved: Bool?

    enum CodingKeys: String, CodingKey {
        // Family
        case newFamilyCreationEnabled = "new_family_creation_enabled"
        case welcomeEnabled = "welcome_enabled"

        // Family Membership
        case welcomeToFamilyEnabled = "welcome_to_family_enabled"
        case newFamilyMemberEnabled = "new_family_member_enabled"
        case familyMembershipApproved = "family_membership_approved"
        case familyMembershipDenied = "family_membership_denied"
        case familyMembershipInvitation = "family_membership_invitation"
        case familyMembershipJoined = "family_membership_joined"
        case familyMembershipLeft = "family_membership_left"
        case familyMembershipRequest = "family_membership_request"

        // Group Membership
        case groupMembershipApproved = "group_membership_approved"
        case groupMembershipDenied = "group_membership_denied"
        case groupMembershipAdded = "group_membership_added"
        case groupMembershipJoined = "group_membership_joined"
        case groupMembershipLeft = "group_membership_left"
        case groupMembershipRequest = "group_membership_request"
        case newGroupCreation = "new_group_creation"

        // Tickets
        case ticketCreationFamily = "ticket_creation_family"
        case ticketCreationGroup = "ticket_creation_group"
        case ticketAssigned = "ticket_assigned"
        case ticketComment = "ticket_comment"
        case ticketStatusChange = "ticket_status_change"
        case ticketResolved = "ticket_resolved"
    }
}
