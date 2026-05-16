import SwiftUI

// MARK: - Review History Models

struct UserReviewHistoryResponse: Codable {
    let userId: String
    let averageRating: Double
    let totalReviewCount: Int
    let reviews: [UserReview]
    let lastKey: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case averageRating = "average_rating"
        case totalReviewCount = "total_review_count"
        case reviews
        case lastKey = "last_key"
    }
}

struct UserReview: Codable, Identifiable {
    let reviewId: String
    let itemName: String
    let starRating: Int
    let comment: String?
    let createdAt: TimeInterval
    let photoVisibility: String?
    let photoUrl: String?

    var id: String { reviewId }

    enum CodingKeys: String, CodingKey {
        case reviewId = "review_id"
        case itemName = "item_name"
        case starRating = "star_rating"
        case comment
        case createdAt = "created_at"
        case photoVisibility = "photo_visibility"
        case photoUrl = "photo_url"
    }
}

// MARK: - User Review History View

struct UserReviewHistoryView: View {
    @Bindable var viewModel: FamGrabViewModel
    let userId: String
    let familyId: String
    let displayName: String

    @State private var reviews: [UserReview] = []
    @State private var averageRating: Double = 0
    @State private var totalReviewCount: Int = 0
    @State private var lastKey: String?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var error: String?
    @State private var selectedPhotoUrl: URL?
    @State private var hasAppeared = false

    private let service = FamGrabService()

    var body: some View {
        Group {
            if isLoading, reviews.isEmpty {
                ProgressView("Loading reviews...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if reviews.isEmpty, hasAppeared {
                emptyView
            } else {
                reviewContent
            }
        }
        .navigationTitle("Review History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !hasAppeared else { return }
            hasAppeared = true
            await loadReviews()
        }
        .sheet(item: $selectedPhotoUrl) { url in
            FullSizePhotoSheet(photoUrl: url)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 12) {
            Text(displayName)
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 16) {
                // Average rating
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", averageRating))
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                // Total review count
                HStack(spacing: 4) {
                    Image(systemName: "text.bubble")
                        .foregroundColor(.secondary)
                    Text("\(totalReviewCount) review\(totalReviewCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName), average rating \(String(format: "%.1f", averageRating)) stars, \(totalReviewCount) reviews")
    }

    // MARK: - Review List

    private var reviewContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                headerView
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                ForEach(reviews) { review in
                    ReviewRow(review: review) { url in
                        selectedPhotoUrl = url
                    }
                    .onAppear {
                        if shouldLoadMore(for: review) {
                            Task {
                                await loadMoreReviews()
                            }
                        }
                    }

                    if review.id != reviews.last?.id {
                        Divider()
                            .padding(.horizontal)
                    }
                }

                if isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
        }
        .refreshable {
            await loadReviews(refresh: true)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.bubble")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Reviews Yet")
                .font(.headline)

            Text("\(displayName) hasn't received any reviews yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Pagination

    private func shouldLoadMore(for review: UserReview) -> Bool {
        guard lastKey != nil, !isLoadingMore, !isLoading else { return false }
        guard let index = reviews.firstIndex(where: { $0.id == review.id }) else { return false }
        return index >= reviews.count - 5
    }

    // MARK: - Data Loading

    private func loadReviews(refresh: Bool = false) async {
        if refresh {
            reviews.removeAll()
            lastKey = nil
        }

        isLoading = true
        error = nil

        do {
            let response = try await service.getReviewHistory(
                familyId: familyId,
                userId: userId,
                limit: 20,
                lastKey: nil
            )
            reviews = response.reviews
            averageRating = response.averageRating
            totalReviewCount = response.totalReviewCount
            lastKey = response.lastKey
        } catch is CancellationError {
            isLoading = false
            return
        } catch {
            self.error = "Failed to load reviews: \(error.localizedDescription)"
            print("❌ UserReviewHistoryView.loadReviews error: \(error)")
        }

        isLoading = false
    }

    private func loadMoreReviews() async {
        guard let currentLastKey = lastKey, !isLoadingMore, !isLoading else { return }

        isLoadingMore = true

        do {
            let response = try await service.getReviewHistory(
                familyId: familyId,
                userId: userId,
                limit: 20,
                lastKey: currentLastKey
            )
            reviews.append(contentsOf: response.reviews)
            lastKey = response.lastKey
        } catch {
            self.error = "Failed to load more reviews: \(error.localizedDescription)"
            print("❌ UserReviewHistoryView.loadMoreReviews error: \(error)")
        }

        isLoadingMore = false
    }
}

// MARK: - Review Row

struct ReviewRow: View {
    let review: UserReview
    let onPhotoTap: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Item name and rating
            HStack {
                Text(review.itemName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                starRatingDisplay(rating: review.starRating)
            }

            // Comment
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            // Photo thumbnail
            if let photoUrlString = review.photoUrl, let photoUrl = URL(string: photoUrlString) {
                Button {
                    onPhotoTap(photoUrl)
                } label: {
                    AsyncImage(url: photoUrl) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(uiColor: .tertiarySystemFill))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    ProgressView()
                                }
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(uiColor: .tertiarySystemFill))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .accessibilityLabel("View delivery photo for \(review.itemName)")
            }

            // Date
            Text(formatDate(review.createdAt))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }

    private func starRatingDisplay(rating: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1 ... 5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.4))
            }
        }
        .accessibilityLabel("\(rating) out of 5 stars")
    }

    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Full Size Photo Sheet

struct FullSizePhotoSheet: View {
    let photoUrl: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AsyncImage(url: photoUrl) { phase in
                switch phase {
                case .empty:
                    ProgressView("Loading photo...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(.orange)
                        Text("Failed to load photo")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    EmptyView()
                }
            }
            .navigationTitle("Delivery Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - URL Identifiable Conformance

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    NavigationStack {
        UserReviewHistoryView(
            viewModel: FamGrabViewModel(),
            userId: "user-123",
            familyId: "family-123",
            displayName: "Alice"
        )
    }
}
