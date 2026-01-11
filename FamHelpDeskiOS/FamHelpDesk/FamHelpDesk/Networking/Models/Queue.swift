import Foundation

// MARK: - Queue Models

struct Queue: Codable, Identifiable, Hashable {
    let queueId: String
    let familyId: String
    let groupId: String
    let queueName: String
    let queueDescription: String?
    let createdBy: String
    let creationDate: TimeInterval
    let openTicketCount: Int
    let totalTicketCount: Int

    var id: String { queueId }

    var createdAt: String {
        let date = Date(timeIntervalSince1970: creationDate)
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    enum CodingKeys: String, CodingKey {
        case queueId = "queue_id"
        case familyId = "family_id"
        case groupId = "group_id"
        case queueName = "queue_name"
        case queueDescription = "queue_description"
        case createdBy = "created_by"
        case creationDate = "creation_date"
        case openTicketCount = "open_ticket_count"
        case totalTicketCount = "total_ticket_count"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(queueId)
    }

    static func == (lhs: Queue, rhs: Queue) -> Bool {
        lhs.queueId == rhs.queueId
    }
}

// MARK: - Queue Member Models

enum QueueRole: String, Codable, CaseIterable {
    case assignee = "ASSIGNEE"
    case viewer = "VIEWER"
    
    var displayName: String {
        switch self {
        case .assignee:
            return "Assignee"
        case .viewer:
            return "Viewer"
        }
    }
}

struct QueueMember: Codable, Identifiable {
    let userId: String
    let displayName: String
    let email: String
    let role: QueueRole
    let assignedAt: String

    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case email
        case role
        case assignedAt = "assigned_at"
    }
}

// MARK: - API Request/Response Models

struct GetAllQueuesResponse: Codable {
    let queues: [Queue]
}

struct CreateQueueRequest: Codable {
    let familyId: String
    let groupId: String
    let queueName: String
    let queueDescription: String?

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case groupId = "group_id"
        case queueName = "queue_name"
        case queueDescription = "queue_description"
    }
}

struct CreateQueueResponse: Codable {
    let queue: Queue
}

struct UpdateQueueRequest: Codable {
    let queueName: String?
    let queueDescription: String?

    enum CodingKeys: String, CodingKey {
        case queueName = "queue_name"
        case queueDescription = "queue_description"
    }
}

struct UpdateQueueResponse: Codable {
    let queue: Queue
}

struct DeleteQueueResponse: Codable {
    let success: Bool
    let message: String
}

struct GetQueueMembersResponse: Codable {
    let members: [QueueMember]
}

struct AssignQueueMemberRequest: Codable {
    let userId: String
    let role: QueueRole

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
    }
}

struct QueueMemberResponse: Codable {
    let success: Bool
    let message: String
}