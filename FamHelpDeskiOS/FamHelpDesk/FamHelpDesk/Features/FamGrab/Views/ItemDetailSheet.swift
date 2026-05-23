import SwiftUI

struct ItemDetailSheet: View {
    @Bindable var viewModel: FamGrabViewModel
    let familyId: String
    let requestId: String
    let item: GrabRequestItem

    @State private var photoUrl: URL?
    @State private var isLoadingPhoto = false
    @Environment(\.dismiss) private var dismiss

    private var hasPhoto: Bool {
        item.proofPhotoKey != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Item header
                    itemHeader

                    // Completion info
                    if item.status == .completed || item.status == .confirmed {
                        completionInfoSection
                    }

                    // Delivery photo
                    if hasPhoto {
                        photoSection
                    }
                }
                .padding()
            }
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if hasPhoto {
                    await loadPhoto()
                }
            }
        }
    }

    // MARK: - Item Header

    @ViewBuilder
    private var itemHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.title3)
                        .fontWeight(.bold)

                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let status = item.status {
                    ItemStatusBadge(status: status)
                }
            }

            HStack {
                if item.quantity > 1 {
                    Label("Qty: \(item.quantity)", systemImage: "number")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(item.embolecCost.embolecFormatted) Embolecs")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
    }

    // MARK: - Completion Info

    @ViewBuilder
    private var completionInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delivery Info")
                .font(.headline)

            if let claimerId = item.claimerId {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .foregroundColor(.purple)
                    Text("Completed by")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(claimerId.name ?? claimerId.id)
                        .fontWeight(.medium)
                }
                .font(.subheadline)
            }

            if let completedAt = item.completedAt {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.purple)
                    Text("Completed")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDate(completedAt))
                        .fontWeight(.medium)
                }
                .font(.subheadline)
            }

            if let confirmedAt = item.confirmedAt {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Confirmed")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDate(confirmedAt))
                        .fontWeight(.medium)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
    }

    // MARK: - Photo Section

    @ViewBuilder
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delivery Photo")
                .font(.headline)

            if isLoadingPhoto {
                HStack {
                    Spacer()
                    ProgressView("Loading photo...")
                    Spacer()
                }
                .frame(height: 200)
            } else if let photoUrl {
                AsyncImage(url: photoUrl) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title2)
                                .foregroundColor(.orange)
                            Text("Photo has expired or failed to load")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 150)
                    case .empty:
                        ProgressView()
                            .frame(height: 200)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Photo unavailable or expired")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
    }

    // MARK: - Helpers

    private func loadPhoto() async {
        isLoadingPhoto = true
        photoUrl = await viewModel.getPhotoUrl(
            familyId: familyId,
            requestId: requestId,
            itemId: item.itemId
        )
        isLoadingPhoto = false
    }

    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
