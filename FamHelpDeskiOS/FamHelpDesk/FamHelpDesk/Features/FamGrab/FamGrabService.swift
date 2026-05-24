import Foundation

final class FamGrabService {
    private let networkManager: NetworkManager

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    // MARK: - Balance

    /// Get the current user's Embolec balance (triggers lazy monthly refresh)
    func getBalance(familyId: String) async throws -> EmbolecBalance {
        let response: GetBalanceResponse = try await networkManager.get(
            endpoint: "/family/\(familyId)/grab/balance"
        )
        return response.balance
    }

    // MARK: - Requests

    /// Create a new Grab Request
    func createRequest(familyId: String, body: CreateGrabRequestBody) async throws -> GrabRequest {
        let response: GrabRequestResponse = try await networkManager.post(
            endpoint: "/family/\(familyId)/grab/requests",
            body: body
        )
        return response.request
    }

    /// List requests with optional filters and pagination
    func listRequests(
        familyId: String,
        status: GrabRequestStatus? = nil,
        userRole: String? = nil,
        startDate: TimeInterval? = nil,
        endDate: TimeInterval? = nil,
        limit: Int = 20,
        lastKey: String? = nil
    ) async throws -> GrabRequestListResponse {
        var queryItems: [URLQueryItem] = []

        if let status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        if let userRole {
            queryItems.append(URLQueryItem(name: "user_role", value: userRole))
        }
        if let startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: String(Int(startDate))))
        }
        if let endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: String(Int(endDate))))
        }
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        if let lastKey {
            queryItems.append(URLQueryItem(name: "last_key", value: lastKey))
        }

        let response: GrabRequestListResponse = try await networkManager.get(
            endpoint: "/family/\(familyId)/grab/requests",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
        return response
    }

    /// Get a specific request with its items
    func getRequest(familyId: String, requestId: String) async throws -> GrabRequest {
        let response: GrabRequestResponse = try await networkManager.get(
            endpoint: "/family/\(familyId)/grab/requests/\(requestId)"
        )
        var request = response.request
        request.items = response.items
        return request
    }

    // MARK: - Request Lifecycle

    /// Claim an open request
    func claimRequest(familyId: String, requestId: String) async throws -> GrabRequest {
        let response: GrabRequestResponse = try await networkManager.post(
            endpoint: "/family/\(familyId)/grab/requests/\(requestId)/claim",
            body: EmptyBody()
        )
        return response.request
    }

    /// Mark a request as completed
    func completeRequest(familyId: String, requestId: String, proofPhotoKey: String? = nil) async throws -> GrabRequest {
        let body = CompleteRequestBody(proofPhotoKey: proofPhotoKey)
        let response: GrabRequestResponse = try await networkManager.post(
            endpoint: "/family/\(familyId)/grab/requests/\(requestId)/complete",
            body: body
        )
        return response.request
    }

    /// Confirm delivery and transfer Embolecs
    func confirmRequest(familyId: String, requestId: String, tipAmount: Double? = nil) async throws -> GrabRequest {
        let body = ConfirmRequestBody(tipAmount: tipAmount)
        let response: GrabRequestResponse = try await networkManager.post(
            endpoint: "/family/\(familyId)/grab/requests/\(requestId)/confirm",
            body: body
        )
        return response.request
    }

    /// Cancel a request
    func cancelRequest(familyId: String, requestId: String) async throws -> GrabRequest {
        let response: GrabRequestResponse = try await networkManager.post(
            endpoint: "/family/\(familyId)/grab/requests/\(requestId)/cancel",
            body: EmptyBody()
        )
        return response.request
    }

    // MARK: - Item-Level Lifecycle

    /// Claim specific items in a request
    func claimItems(familyId: String, requestId: String, itemIds: [String]) async throws -> [GrabRequestItem] {
        let body = ClaimItemsBody(itemIds: itemIds)
        let response: ItemsResponse = try await networkManager.post(
            endpoint: "/family/\(familyId)/grab/requests/\(requestId)/claim-items",
            body: body
        )
        return response.items
    }

    /// Mark specific items as completed
    func completeItems(familyId: String, requestId: String, itemIds: [String], proofPhotoKey: String? = nil, photoVisibility: String? = nil) async throws -> [GrabRequestItem] {
        let body = CompleteItemsBody(itemIds: itemIds, proofPhotoKey: proofPhotoKey, photoVisibility: photoVisibility)
        let response: ItemsResponse = try await networkManager.post(
            endpoint: "/family/\(familyId)/grab/requests/\(requestId)/complete-items",
            body: body
        )
        return response.items
    }

    /// Confirm specific items and transfer Embolecs
    func confirmItems(familyId: String, requestId: String, itemIds: [String], tipAmount: Double? = nil, itemRatings: [ItemRating]? = nil) async throws -> [GrabRequestItem] {
        let body = ConfirmItemsBody(itemIds: itemIds, tipAmount: tipAmount, itemRatings: itemRatings)
        let response: ItemsResponse = try await networkManager.post(
            endpoint: "/family/\(familyId)/grab/requests/\(requestId)/confirm-items",
            body: body
        )
        return response.items
    }

    /// Cancel specific items in a request
    func cancelItems(familyId: String, requestId: String, itemIds: [String]) async throws -> [GrabRequestItem] {
        let body = CancelItemsBody(itemIds: itemIds)
        let response: ItemsResponse = try await networkManager.post(
            endpoint: "/family/\(familyId)/grab/requests/\(requestId)/cancel-items",
            body: body
        )
        return response.items
    }

    // MARK: - Photos

    /// Get a presigned upload URL for delivery photo
    func getUploadUrl(familyId: String, requestId: String, itemId: String) async throws -> UploadUrlResponse {
        let body = UploadPhotoBody(itemId: itemId)
        let response: UploadUrlResponse = try await networkManager.post(
            endpoint: "/family/\(familyId)/grab/requests/\(requestId)/photo/upload-url",
            body: body
        )
        return response
    }

    /// Get a presigned URL to view the delivery photo
    func getPhotoUrl(familyId: String, requestId: String, itemId: String? = nil) async throws -> PhotoUrlResponse {
        var endpoint = "/family/\(familyId)/grab/requests/\(requestId)/photo"
        if let itemId {
            endpoint += "?item_id=\(itemId)"
        }
        let response: PhotoUrlResponse = try await networkManager.get(
            endpoint: endpoint
        )
        return response
    }

    // MARK: - Pickup Photos

    /// Get a presigned upload URL for a pickup photo
    func getPickupPhotoUploadUrl(familyId: String, requestId: String, itemId: String) async throws -> UploadUrlResponse {
        let body = UploadPhotoBody(itemId: itemId)
        let response: UploadUrlResponse = try await networkManager.post(
            endpoint: "/family/\(familyId)/grab/requests/\(requestId)/pickup-photo/upload-url",
            body: body
        )
        return response
    }

    /// Save the pickup photo key on the item after upload. Triggers content moderation.
    func savePickupPhoto(familyId: String, requestId: String, itemId: String, s3Key: String, photoVisibility: String? = nil) async throws -> GrabRequestItem {
        let body = SavePickupPhotoBody(itemId: itemId, s3Key: s3Key, photoVisibility: photoVisibility)
        let response: SavePickupPhotoResponse = try await networkManager.post(
            endpoint: "/family/\(familyId)/grab/requests/\(requestId)/pickup-photo/save",
            body: body
        )
        return response.item
    }

    /// Get a presigned URL to view the pickup photo
    func getPickupPhotoUrl(familyId: String, requestId: String, itemId: String) async throws -> PhotoUrlResponse {
        let response: PhotoUrlResponse = try await networkManager.get(
            endpoint: "/family/\(familyId)/grab/requests/\(requestId)/pickup-photo?item_id=\(itemId)"
        )
        return response
    }

    /// Upload photo data directly to S3 using a presigned URL
    func uploadPhoto(data: Data, to uploadUrl: String, contentType: String = "image/jpeg") async throws {
        guard let url = URL(string: uploadUrl) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode)
        else {
            throw NetworkError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500, message: "Photo upload failed")
        }
    }

    // MARK: - Review History

    /// Get a user's review history within a family
    func getReviewHistory(
        familyId: String,
        userId: String,
        limit: Int = 20,
        lastKey: String? = nil
    ) async throws -> UserReviewHistoryResponse {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let lastKey {
            queryItems.append(URLQueryItem(name: "last_key", value: lastKey))
        }

        let response: UserReviewHistoryResponse = try await networkManager.get(
            endpoint: "/family/\(familyId)/grab/reviews/\(userId)",
            queryItems: queryItems
        )
        return response
    }

    // MARK: - Leaderboard

    /// Get the family leaderboard
    func getLeaderboard(familyId: String) async throws -> [GrabLeaderboardEntry] {
        let response: GrabLeaderboardResponse = try await networkManager.get(
            endpoint: "/family/\(familyId)/grab/leaderboard"
        )
        return response.leaderboard
    }

    // MARK: - Transactions

    /// Get Embolec transactions for the family
    func getTransactions(
        familyId: String,
        limit: Int = 20,
        lastKey: String? = nil
    ) async throws -> GrabTransactionsResponse {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let lastKey {
            queryItems.append(URLQueryItem(name: "last_key", value: lastKey))
        }

        let response: GrabTransactionsResponse = try await networkManager.get(
            endpoint: "/family/\(familyId)/grab/transactions",
            queryItems: queryItems
        )
        return response
    }
}

// MARK: - Helper Types

private struct EmptyBody: Codable {}
