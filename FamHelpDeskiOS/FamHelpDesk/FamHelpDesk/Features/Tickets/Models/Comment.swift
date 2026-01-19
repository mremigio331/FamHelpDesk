import Foundation

// MARK: - Comment Model

struct Comment: Codable, Identifiable, Hashable {
    let familyId: String
    let groupId: String
    let queueId: String
    let ticketId: String
    let commentId: String
    let commentUser: String
    let commentBody: String
    let commentDate: TimeInterval
    let lastUpdate: TimeInterval

    var id: String { commentId }

    // MARK: - Computed Properties

    var createdAt: String {
        let date = Date(timeIntervalSince1970: commentDate)
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    var updatedAt: String {
        let date = Date(timeIntervalSince1970: lastUpdate)
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    var wasEdited: Bool {
        // Consider edited if last_update is more than 1 second after comment_date
        lastUpdate > commentDate + 1
    }

    // MARK: - Edit/Delete Permission Logic

    func canEdit(currentUserId: String) -> Bool {
        canModify(currentUserId: currentUserId)
    }

    func canDelete(currentUserId: String) -> Bool {
        canModify(currentUserId: currentUserId)
    }

    private func canModify(currentUserId: String) -> Bool {
        // User must be the comment author
        guard currentUserId == commentUser else { return false }

        // Must be within 4-hour edit window (14400 seconds)
        let currentTime = Date().timeIntervalSince1970
        let timeSinceCreation = currentTime - commentDate

        return timeSinceCreation < 14400 // 4 hours in seconds
    }

    var editWindowExpired: Bool {
        let currentTime = Date().timeIntervalSince1970
        let timeSinceCreation = currentTime - commentDate
        return timeSinceCreation >= 14400
    }

    var timeRemainingInEditWindow: TimeInterval? {
        let currentTime = Date().timeIntervalSince1970
        let timeSinceCreation = currentTime - commentDate
        let remaining = 14400 - timeSinceCreation

        return remaining > 0 ? remaining : nil
    }

    var editWindowExpiresAt: Date {
        Date(timeIntervalSince1970: commentDate + 14400)
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case groupId = "group_id"
        case queueId = "queue_id"
        case ticketId = "ticket_id"
        case commentId = "comment_id"
        case commentUser = "comment_user"
        case commentBody = "comment_body"
        case commentDate = "comment_date"
        case lastUpdate = "last_update"
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(commentId)
    }

    static func == (lhs: Comment, rhs: Comment) -> Bool {
        lhs.commentId == rhs.commentId
    }
}

// MARK: - API Request/Response Models

struct CreateCommentRequest: Codable {
    let familyId: String
    let ticketId: String
    let commentBody: String

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case ticketId = "ticket_id"
        case commentBody = "comment_body"
    }
}

struct UpdateCommentRequest: Codable {
    let commentBody: String

    enum CodingKeys: String, CodingKey {
        case commentBody = "comment_body"
    }
}

struct GetCommentsResponse: Codable {
    let comments: [Comment]
}

struct CreateCommentResponse: Codable {
    let comment: Comment
}

struct UpdateCommentResponse: Codable {
    let comment: Comment
}

struct DeleteCommentResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - Comment Display Helpers

extension Comment {
    var relativeTimeString: String {
        let date = Date(timeIntervalSince1970: commentDate)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var shortTimeString: String {
        let date = Date(timeIntervalSince1970: commentDate)
        let formatter = DateFormatter()

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }

    var editWindowStatusText: String? {
        guard let timeRemaining = timeRemainingInEditWindow else {
            return "Edit window expired"
        }

        let hours = Int(timeRemaining) / 3600
        let minutes = Int(timeRemaining.truncatingRemainder(dividingBy: 3600)) / 60

        if hours > 0 {
            return "Can edit for \(hours)h \(minutes)m"
        } else {
            return "Can edit for \(minutes)m"
        }
    }
}
