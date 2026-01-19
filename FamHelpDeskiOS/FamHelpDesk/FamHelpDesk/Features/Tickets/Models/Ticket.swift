import Foundation

// MARK: - Ticket Enums

enum TicketStatus: String, CaseIterable, Codable {
    case open = "OPEN"
    case resolved = "RESOLVED"
    case closed = "CLOSED"
}

enum TicketSeverity: String, CaseIterable, Codable {
    case sev1 = "1.0"
    case sev2 = "2.0"
    case sev2_5 = "2.5"
    case sev3 = "3.0"
    case sev4 = "4.0"
    case sev5 = "5.0"

    var displayName: String {
        switch self {
        case .sev1: "SEV 1"
        case .sev2: "SEV 2"
        case .sev2_5: "SEV 2.5"
        case .sev3: "SEV 3"
        case .sev4: "SEV 4"
        case .sev5: "SEV 5"
        }
    }

    var colorCategory: TicketSeverityColor {
        switch self {
        case .sev1, .sev2, .sev2_5:
            .high
        case .sev3, .sev4, .sev5:
            .low
        }
    }
}

enum TicketSeverityColor {
    case high // Red for SEV_1, SEV_2, SEV_2_5
    case low // Green for SEV_3, SEV_4, SEV_5
}

// MARK: - Ticket Model

struct Ticket: Codable, Identifiable, Hashable {
    let familyId: String
    let groupId: String
    let queueId: String
    let ticketId: String
    let title: String
    let description: String?
    let severity: TicketSeverity
    let status: TicketStatus
    let creationDate: TimeInterval
    let createdBy: String
    let lastUpdateTime: TimeInterval
    let resolvedDate: TimeInterval?
    let closedDate: TimeInterval?
    let reopenUntil: TimeInterval?
    let assignedTo: String?
    let isPrivate: Bool

    var id: String { ticketId }

    // MARK: - Computed Properties

    var createdAt: String {
        let date = Date(timeIntervalSince1970: creationDate)
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    var lastUpdatedAt: String {
        let date = Date(timeIntervalSince1970: lastUpdateTime)
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    var resolvedAt: String? {
        guard let resolvedDate else { return nil }
        let date = Date(timeIntervalSince1970: resolvedDate)
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    var closedAt: String? {
        guard let closedDate else { return nil }
        let date = Date(timeIntervalSince1970: closedDate)
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    var canReopen: Bool {
        guard status == .resolved,
              let reopenUntil else { return false }
        return Date().timeIntervalSince1970 < reopenUntil
    }

    var isResolved: Bool {
        status == .resolved
    }

    var isClosed: Bool {
        status == .closed
    }

    var isOpen: Bool {
        status == .open
    }

    var displayColor: TicketSeverityColor {
        // For resolved/closed tickets, always show grey regardless of severity
        if status == .resolved || status == .closed {
            return .low // Will be rendered as grey in UI
        }
        return severity.colorCategory
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case groupId = "group_id"
        case queueId = "queue_id"
        case ticketId = "ticket_id"
        case title
        case description
        case severity
        case status
        case creationDate = "creation_date"
        case createdBy = "created_by"
        case lastUpdateTime = "last_update_time"
        case resolvedDate = "resolved_date"
        case closedDate = "closed_date"
        case reopenUntil = "reopen_until"
        case assignedTo = "assigned_to"
        case isPrivate = "private"
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(ticketId)
    }

    static func == (lhs: Ticket, rhs: Ticket) -> Bool {
        lhs.ticketId == rhs.ticketId
    }
}

// MARK: - API Request/Response Models

struct CreateTicketRequest: Codable {
    let familyId: String
    let groupId: String
    let queueId: String
    let title: String
    let severity: TicketSeverity
    let description: String?
    let assignedTo: String?

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case groupId = "group_id"
        case queueId = "queue_id"
        case title
        case severity
        case description
        case assignedTo = "assigned_to"
    }
}

struct UpdateTicketRequest: Codable {
    let title: String?
    let description: String?
    let severity: TicketSeverity?
    let status: TicketStatus?
    let assignedTo: String?
    let groupId: String?
    let queueId: String?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case severity
        case status
        case assignedTo = "assigned_to"
        case groupId = "group_id"
        case queueId = "queue_id"
    }
}

struct GetTicketsResponse: Codable {
    let tickets: [Ticket]
    let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case tickets
        case nextToken = "next_token"
    }
}

struct CreateTicketResponse: Codable {
    let ticket: Ticket
}

struct UpdateTicketResponse: Codable {
    let ticket: Ticket
}

// MARK: - Pagination Support

struct PaginatedTickets {
    let tickets: [Ticket]
    let nextToken: String?
    let hasMore: Bool

    init(tickets: [Ticket], nextToken: String?) {
        self.tickets = tickets
        self.nextToken = nextToken
        hasMore = nextToken != nil
    }
}
