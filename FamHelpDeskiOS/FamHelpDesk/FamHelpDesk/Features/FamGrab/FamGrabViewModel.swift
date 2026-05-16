import Foundation
import SwiftUI

@MainActor
@Observable
final class FamGrabViewModel {
    // MARK: - Published Properties

    var balance: EmbolecBalance?
    var requests: [GrabRequest] = []
    var currentRequest: GrabRequest?
    var leaderboard: [GrabLeaderboardEntry] = []
    var transactions: [EmbolecTransaction] = []

    var isLoading = false
    var isLoadingMore = false
    var isLoadingBalance = false
    var isLoadingLeaderboard = false
    var error: String?

    // Pagination
    var nextToken: String?
    var hasMore = false

    // Review History
    var reviewHistoryReviews: [UserReview] = []
    var reviewHistoryAverageRating: Double = 0
    var reviewHistoryTotalCount: Int = 0
    var reviewHistoryLastKey: String?
    var isLoadingReviewHistory = false

    // Filters
    var statusFilter: GrabRequestStatus?
    var userRoleFilter: String? // "requestor" or "claimer"

    // MARK: - Private Properties

    private let service = FamGrabService()
    private var currentFamilyId: String?

    // MARK: - Balance

    func loadBalance(familyId: String) async {
        isLoadingBalance = true
        do {
            balance = try await service.getBalance(familyId: familyId)
            error = nil
        } catch is CancellationError {
            // Task was cancelled (view disappeared), ignore
            return
        } catch {
            self.error = "Failed to load balance: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.loadBalance error: \(error)")
        }
        isLoadingBalance = false
    }

    // MARK: - Requests

    func loadRequests(familyId: String, status: GrabRequestStatus? = nil, userRole: String? = nil, refresh: Bool = false) async {
        guard !isLoading else { return }

        if refresh {
            requests.removeAll()
            nextToken = nil
            hasMore = false
        }

        currentFamilyId = familyId
        statusFilter = status
        userRoleFilter = userRole
        isLoading = true
        error = nil

        do {
            let response = try await service.listRequests(
                familyId: familyId,
                status: status,
                userRole: userRole,
                limit: 20,
                lastKey: nil
            )
            requests = response.requests
            nextToken = response.nextToken
            hasMore = response.nextToken != nil
        } catch is CancellationError {
            isLoading = false
            return
        } catch {
            self.error = "Failed to load requests: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.loadRequests error: \(error)")
        }

        isLoading = false
    }

    func loadMoreRequests() async {
        guard hasMore, !isLoadingMore, !isLoading,
              let familyId = currentFamilyId,
              let lastKey = nextToken
        else { return }

        isLoadingMore = true

        do {
            let response = try await service.listRequests(
                familyId: familyId,
                status: statusFilter,
                userRole: userRoleFilter,
                limit: 20,
                lastKey: lastKey
            )
            requests.append(contentsOf: response.requests)
            nextToken = response.nextToken
            hasMore = response.nextToken != nil
        } catch {
            self.error = "Failed to load more requests: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.loadMoreRequests error: \(error)")
        }

        isLoadingMore = false
    }

    func refreshRequests() async {
        guard let familyId = currentFamilyId else { return }
        await loadRequests(familyId: familyId, status: statusFilter, userRole: userRoleFilter, refresh: true)
    }

    func loadRequest(familyId: String, requestId: String) async {
        do {
            currentRequest = try await service.getRequest(familyId: familyId, requestId: requestId)
            error = nil
        } catch {
            self.error = "Failed to load request: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.loadRequest error: \(error)")
        }
    }

    // MARK: - Leaderboard

    func loadLeaderboard(familyId: String) async {
        isLoadingLeaderboard = true
        do {
            leaderboard = try await service.getLeaderboard(familyId: familyId)
            error = nil
        } catch {
            self.error = "Failed to load leaderboard: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.loadLeaderboard error: \(error)")
        }
        isLoadingLeaderboard = false
    }

    // MARK: - Transactions

    func loadTransactions(familyId: String) async {
        do {
            let response = try await service.getTransactions(familyId: familyId)
            transactions = response.transactions
            error = nil
        } catch {
            self.error = "Failed to load transactions: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.loadTransactions error: \(error)")
        }
    }

    // MARK: - Review History

    func loadReviewHistory(familyId: String, userId: String, limit: Int = 20, lastKey: String? = nil) async {
        isLoadingReviewHistory = true
        error = nil

        do {
            let response = try await service.getReviewHistory(
                familyId: familyId,
                userId: userId,
                limit: limit,
                lastKey: lastKey
            )

            if lastKey != nil {
                reviewHistoryReviews.append(contentsOf: response.reviews)
            } else {
                reviewHistoryReviews = response.reviews
            }
            reviewHistoryAverageRating = response.averageRating
            reviewHistoryTotalCount = response.totalReviewCount
            reviewHistoryLastKey = response.lastKey
        } catch is CancellationError {
            isLoadingReviewHistory = false
            return
        } catch {
            self.error = "Failed to load review history: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.loadReviewHistory error: \(error)")
        }

        isLoadingReviewHistory = false
    }

    // MARK: - Actions

    func createRequest(familyId: String, title: String, items: [CreateGrabRequestItemBody], note: String?) async -> Bool {
        let body = CreateGrabRequestBody(
            title: title,
            items: items,
            note: note
        )

        do {
            let newRequest = try await service.createRequest(familyId: familyId, body: body)
            requests.insert(newRequest, at: 0)
            // Refresh balance after creating a request
            await loadBalance(familyId: familyId)
            error = nil
            return true
        } catch {
            self.error = "Failed to create request: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.createRequest error: \(error)")
            return false
        }
    }

    func claimRequest(familyId: String, requestId: String) async -> Bool {
        do {
            let updatedRequest = try await service.claimRequest(familyId: familyId, requestId: requestId)
            updateRequestInList(updatedRequest)
            currentRequest = updatedRequest
            error = nil
            return true
        } catch {
            self.error = "Failed to claim request: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.claimRequest error: \(error)")
            return false
        }
    }

    func completeRequest(familyId: String, requestId: String, proofPhotoKey: String? = nil) async -> Bool {
        do {
            let updatedRequest = try await service.completeRequest(familyId: familyId, requestId: requestId, proofPhotoKey: proofPhotoKey)
            updateRequestInList(updatedRequest)
            currentRequest = updatedRequest
            error = nil
            return true
        } catch {
            self.error = "Failed to complete request: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.completeRequest error: \(error)")
            return false
        }
    }

    func confirmRequest(familyId: String, requestId: String, tipAmount: Double? = nil) async -> Bool {
        do {
            let updatedRequest = try await service.confirmRequest(familyId: familyId, requestId: requestId, tipAmount: tipAmount)
            updateRequestInList(updatedRequest)
            currentRequest = updatedRequest
            // Refresh balance after confirmation (Embolecs transferred)
            await loadBalance(familyId: familyId)
            error = nil
            return true
        } catch {
            self.error = "Failed to confirm request: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.confirmRequest error: \(error)")
            return false
        }
    }

    func cancelRequest(familyId: String, requestId: String) async -> Bool {
        do {
            let updatedRequest = try await service.cancelRequest(familyId: familyId, requestId: requestId)
            updateRequestInList(updatedRequest)
            currentRequest = updatedRequest
            error = nil
            return true
        } catch {
            self.error = "Failed to cancel request: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.cancelRequest error: \(error)")
            return false
        }
    }

    // MARK: - Item-Level Actions

    func claimItems(familyId: String, requestId: String, itemIds: [String]) async -> Bool {
        do {
            _ = try await service.claimItems(familyId: familyId, requestId: requestId, itemIds: itemIds)
            await loadRequest(familyId: familyId, requestId: requestId)
            error = nil
            return true
        } catch {
            self.error = "Failed to claim items: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.claimItems error: \(error)")
            return false
        }
    }

    func completeItems(familyId: String, requestId: String, itemIds: [String], proofPhotoKey: String? = nil, photoVisibility: String? = nil) async -> Bool {
        do {
            _ = try await service.completeItems(familyId: familyId, requestId: requestId, itemIds: itemIds, proofPhotoKey: proofPhotoKey, photoVisibility: photoVisibility)
            await loadRequest(familyId: familyId, requestId: requestId)
            error = nil
            return true
        } catch {
            self.error = "Failed to complete items: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.completeItems error: \(error)")
            return false
        }
    }

    func confirmItems(familyId: String, requestId: String, itemIds: [String], tipAmount: Double? = nil, itemRatings: [ItemRating]? = nil) async -> Bool {
        do {
            _ = try await service.confirmItems(familyId: familyId, requestId: requestId, itemIds: itemIds, tipAmount: tipAmount, itemRatings: itemRatings)
            await loadRequest(familyId: familyId, requestId: requestId)
            // Refresh balance after confirmation (Embolecs transferred)
            await loadBalance(familyId: familyId)
            error = nil
            return true
        } catch {
            self.error = "Failed to confirm items: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.confirmItems error: \(error)")
            return false
        }
    }

    func cancelItems(familyId: String, requestId: String, itemIds: [String]) async -> Bool {
        do {
            _ = try await service.cancelItems(familyId: familyId, requestId: requestId, itemIds: itemIds)
            await loadRequest(familyId: familyId, requestId: requestId)
            error = nil
            return true
        } catch {
            self.error = "Failed to cancel items: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.cancelItems error: \(error)")
            return false
        }
    }

    // MARK: - Photo

    func uploadDeliveryPhoto(familyId: String, requestId: String, itemId: String, imageData: Data) async -> String? {
        do {
            let uploadResponse = try await service.getUploadUrl(familyId: familyId, requestId: requestId, itemId: itemId)
            try await service.uploadPhoto(data: imageData, to: uploadResponse.uploadUrl)
            return uploadResponse.photoKey
        } catch {
            self.error = "Failed to upload photo: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.uploadDeliveryPhoto error: \(error)")
            return nil
        }
    }

    func getPhotoUrl(familyId: String, requestId: String) async -> URL? {
        do {
            let response = try await service.getPhotoUrl(familyId: familyId, requestId: requestId)
            return URL(string: response.photoUrl)
        } catch {
            self.error = "Failed to get photo URL: \(error.localizedDescription)"
            print("❌ FamGrabViewModel.getPhotoUrl error: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    func clearError() {
        error = nil
    }

    func shouldLoadMore(for request: GrabRequest) -> Bool {
        guard hasMore, !isLoadingMore, !isLoading else { return false }
        guard let index = requests.firstIndex(where: { $0.requestId == request.requestId }) else { return false }
        return index >= requests.count - 5
    }

    private func updateRequestInList(_ updatedRequest: GrabRequest) {
        if let index = requests.firstIndex(where: { $0.requestId == updatedRequest.requestId }) {
            requests[index] = updatedRequest
        }
    }
}
