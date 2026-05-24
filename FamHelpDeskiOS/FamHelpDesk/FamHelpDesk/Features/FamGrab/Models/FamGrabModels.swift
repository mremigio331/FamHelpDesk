import Foundation

// MARK: - Embolec Formatting

extension Double {
    /// Formats an Embolec value: shows decimals only when fractional (e.g., "42" or "0.25")
    var embolecFormatted: String {
        if self == rounded(.down), self == rounded(.up) {
            return String(format: "%.0f", self)
        }
        return String(format: "%.2f", self)
    }
}

// MARK: - Embolec Balance

struct EmbolecBalance: Codable {
    let familyId: String
    let userId: String
    let balance: Double
    let lastRefreshDate: TimeInterval
    let totalEarned: Double
    let totalSpent: Double

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case userId = "user_id"
        case balance
        case lastRefreshDate = "last_refresh_date"
        case totalEarned = "total_earned"
        case totalSpent = "total_spent"
    }
}

// MARK: - Grab Request Status

enum GrabRequestStatus: String, Codable, CaseIterable {
    case open = "OPEN"
    case partiallyClaimed = "PARTIALLY_CLAIMED"
    case claimed = "CLAIMED"
    case partiallyCompleted = "PARTIALLY_COMPLETED"
    case completed = "COMPLETED"
    case confirmed = "CONFIRMED"
    case cancelled = "CANCELLED"

    var displayName: String {
        switch self {
        case .open: "Open"
        case .partiallyClaimed: "Partially Claimed"
        case .claimed: "Claimed"
        case .partiallyCompleted: "Partially Completed"
        case .completed: "Completed"
        case .confirmed: "Confirmed"
        case .cancelled: "Cancelled"
        }
    }

    var systemImage: String {
        switch self {
        case .open: "circle"
        case .partiallyClaimed: "hand.raised"
        case .claimed: "hand.raised.fill"
        case .partiallyCompleted: "checkmark.circle.badge.questionmark"
        case .completed: "checkmark.circle"
        case .confirmed: "checkmark.seal.fill"
        case .cancelled: "xmark.circle.fill"
        }
    }
}

// MARK: - Grab Request

struct GrabRequest: Codable, Identifiable {
    let requestId: String
    let familyId: String
    let requestorId: EntityRefResponse
    let claimerId: EntityRefResponse?
    let status: GrabRequestStatus
    let embolecCost: Double
    let title: String
    let note: String?
    let tipAmount: Double?
    let proofPhotoKey: String?
    let createdAt: TimeInterval
    let claimedAt: TimeInterval?
    let completedAt: TimeInterval?
    let confirmedAt: TimeInterval?
    let cancelledAt: TimeInterval?
    let cancelledBy: EntityRefResponse?
    var items: [GrabRequestItem]?

    var id: String { requestId }

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case familyId = "family_id"
        case requestorId = "requestor_id"
        case claimerId = "claimer_id"
        case status
        case embolecCost = "embolec_cost"
        case title
        case note
        case tipAmount = "tip_amount"
        case proofPhotoKey = "proof_photo_key"
        case createdAt = "created_at"
        case claimedAt = "claimed_at"
        case completedAt = "completed_at"
        case confirmedAt = "confirmed_at"
        case cancelledAt = "cancelled_at"
        case cancelledBy = "cancelled_by"
        case items
    }
}

// MARK: - Grab Request Item

struct GrabRequestItem: Codable, Identifiable {
    let itemId: String
    let requestId: String
    let familyId: String
    let name: String
    let quantity: Int
    let embolecCost: Double
    let note: String?
    let status: GrabRequestStatus?
    let claimerId: EntityRefResponse?
    let claimedAt: TimeInterval?
    let completedAt: TimeInterval?
    let confirmedAt: TimeInterval?
    let cancelledAt: TimeInterval?
    let cancelledBy: EntityRefResponse?
    let proofPhotoKey: String?
    let pickupPhotoKey: String?

    var id: String { itemId }

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case requestId = "request_id"
        case familyId = "family_id"
        case name
        case quantity
        case embolecCost = "embolec_cost"
        case note
        case status
        case claimerId = "claimer_id"
        case claimedAt = "claimed_at"
        case completedAt = "completed_at"
        case confirmedAt = "confirmed_at"
        case cancelledAt = "cancelled_at"
        case cancelledBy = "cancelled_by"
        case proofPhotoKey = "proof_photo_key"
        case pickupPhotoKey = "pickup_photo_key"
    }
}

// MARK: - Embolec Transaction

struct EmbolecTransaction: Codable, Identifiable {
    let transactionId: String
    let familyId: String
    let fromUserId: String
    let toUserId: String
    let amount: Int
    let transactionType: String
    let grabRequestId: String?
    let itemId: String?
    let createdAt: TimeInterval
    let note: String?

    var id: String { transactionId }

    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case familyId = "family_id"
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case amount
        case transactionType = "transaction_type"
        case grabRequestId = "grab_request_id"
        case itemId = "item_id"
        case createdAt = "created_at"
        case note
    }
}

// MARK: - Grab Leaderboard Entry

struct GrabLeaderboardEntry: Codable, Identifiable {
    let userId: EntityRefResponse
    let totalEarned: Double
    let totalSpent: Double
    let currentBalance: Double
    let fulfillmentCount: Int
    let monthlyEarnings: Double

    var id: String { userId.id }
    var displayName: String { userId.name ?? userId.id }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case totalEarned = "total_earned"
        case totalSpent = "total_spent"
        case currentBalance = "current_balance"
        case fulfillmentCount = "fulfillment_count"
        case monthlyEarnings = "monthly_earnings"
    }
}

struct EntityRefResponse: Codable {
    let id: String
    let name: String?
}

// MARK: - API Request/Response Models

struct CreateGrabRequestBody: Codable {
    let title: String
    let items: [CreateGrabRequestItemBody]
    let note: String?
}

struct CreateGrabRequestItemBody: Codable {
    let name: String
    let embolecCost: Double
    let note: String?

    enum CodingKeys: String, CodingKey {
        case name
        case embolecCost = "embolec_cost"
        case note
    }
}

struct ConfirmRequestBody: Codable {
    let tipAmount: Double?

    enum CodingKeys: String, CodingKey {
        case tipAmount = "tip_amount"
    }
}

struct CompleteRequestBody: Codable {
    let proofPhotoKey: String?

    enum CodingKeys: String, CodingKey {
        case proofPhotoKey = "proof_photo_key"
    }
}

// MARK: - Item-Level API Request/Response Models

struct ClaimItemsBody: Codable {
    let itemIds: [String]

    enum CodingKeys: String, CodingKey {
        case itemIds = "item_ids"
    }
}

struct CompleteItemsBody: Codable {
    let itemIds: [String]
    let proofPhotoKey: String?
    let photoVisibility: String?

    enum CodingKeys: String, CodingKey {
        case itemIds = "item_ids"
        case proofPhotoKey = "proof_photo_key"
        case photoVisibility = "photo_visibility"
    }
}

struct ConfirmItemsBody: Codable {
    let itemIds: [String]
    let tipAmount: Double?
    let itemRatings: [ItemRating]?

    enum CodingKeys: String, CodingKey {
        case itemIds = "item_ids"
        case tipAmount = "tip_amount"
        case itemRatings = "item_ratings"
    }
}

struct ItemRating: Codable {
    let itemId: String
    let starRating: Int
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case starRating = "star_rating"
        case comment
    }
}

struct CancelItemsBody: Codable {
    let itemIds: [String]

    enum CodingKeys: String, CodingKey {
        case itemIds = "item_ids"
    }
}

struct UploadPhotoBody: Codable {
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
    }
}

struct ItemsResponse: Codable {
    let items: [GrabRequestItem]
}

// MARK: - API Response Wrappers

struct GetBalanceResponse: Codable {
    let balance: EmbolecBalance
}

struct GrabRequestResponse: Codable {
    let request: GrabRequest
    let items: [GrabRequestItem]?
}

struct GrabRequestListResponse: Codable {
    let requests: [GrabRequest]
    let lastKey: String?

    enum CodingKeys: String, CodingKey {
        case requests
        case lastKey = "last_key"
    }

    var nextToken: String? { lastKey }
}

struct GrabLeaderboardResponse: Codable {
    let leaderboard: [GrabLeaderboardEntry]
}

struct GrabTransactionsResponse: Codable {
    let transactions: [EmbolecTransaction]
    let lastKey: String?

    enum CodingKeys: String, CodingKey {
        case transactions
        case lastKey = "last_key"
    }

    var nextToken: String? { lastKey }
}

struct UploadUrlResponse: Codable {
    let uploadUrl: String
    let s3Key: String

    enum CodingKeys: String, CodingKey {
        case uploadUrl = "upload_url"
        case s3Key = "s3_key"
    }

    var photoKey: String { s3Key }
}

struct PhotoUrlResponse: Codable {
    let viewUrl: String

    enum CodingKeys: String, CodingKey {
        case viewUrl = "view_url"
    }

    var photoUrl: String { viewUrl }
}

struct SavePickupPhotoBody: Codable {
    let itemId: String
    let s3Key: String
    let photoVisibility: String?

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case s3Key = "s3_key"
        case photoVisibility = "photo_visibility"
    }
}

struct SavePickupPhotoResponse: Codable {
    let item: GrabRequestItem
}
