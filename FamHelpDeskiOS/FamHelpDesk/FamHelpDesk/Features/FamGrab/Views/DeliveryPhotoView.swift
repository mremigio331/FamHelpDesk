import PhotosUI
import SwiftUI

struct DeliveryPhotoView: View {
    @Bindable var viewModel: FamGrabViewModel
    let familyId: String
    let request: GrabRequest
    let mode: PhotoMode

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var photoUrl: URL?
    @State private var isUploading = false
    @State private var isLoadingPhoto = false
    @State private var uploadComplete = false
    @Environment(\.dismiss) private var dismiss

    enum PhotoMode {
        case upload
        case view
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                switch mode {
                case .upload:
                    uploadContent
                case .view:
                    viewContent
                }
            }
            .padding()
            .navigationTitle(mode == .upload ? "Upload Photo" : "Delivery Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Upload Mode

    @ViewBuilder
    private var uploadContent: some View {
        VStack(spacing: 20) {
            if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("Take or select a photo as proof of delivery")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxHeight: 200)
            }

            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(
                    selectedImageData == nil ? "Select Photo" : "Change Photo",
                    systemImage: "photo.on.rectangle"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                    }
                }
            }

            Spacer()

            if uploadComplete {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    Text("Photo uploaded! Completing request...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Button {
                Task { await uploadAndComplete() }
            } label: {
                if isUploading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Upload & Complete Request", systemImage: "arrow.up.circle.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedImageData == nil || isUploading || uploadComplete)

            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - View Mode

    @ViewBuilder
    private var viewContent: some View {
        VStack(spacing: 16) {
            if isLoadingPhoto {
                ProgressView("Loading photo...")
            } else if let photoUrl {
                AsyncImage(url: photoUrl) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxHeight: 300)
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                                .foregroundColor(.orange)
                            Text("Failed to load photo")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxHeight: 200)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No photo available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: 200)
            }

            Spacer()
        }
        .task {
            await loadPhoto()
        }
    }

    // MARK: - Actions

    private func uploadAndComplete() async {
        guard let imageData = selectedImageData else { return }

        isUploading = true
        viewModel.clearError()

        // Upload photo and get the key
        // Use the first item claimed by the current user for the upload authorization
        let currentUserId = UserSession.shared.currentUser?.userId ?? ""
        let claimedItemId = request.items?.first(where: { $0.claimerId?.id == currentUserId })?.itemId ?? ""
        if let photoKey = await viewModel.uploadDeliveryPhoto(
            familyId: familyId,
            requestId: request.requestId,
            itemId: claimedItemId,
            imageData: imageData
        ) {
            uploadComplete = true

            // Complete the request with the photo key
            let success = await viewModel.completeRequest(
                familyId: familyId,
                requestId: request.requestId,
                proofPhotoKey: photoKey
            )

            if success {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Brief delay to show success
                dismiss()
            }
        }

        isUploading = false
    }

    private func loadPhoto() async {
        isLoadingPhoto = true
        photoUrl = await viewModel.getPhotoUrl(familyId: familyId, requestId: request.requestId)
        isLoadingPhoto = false
    }
}

#Preview {
    DeliveryPhotoView(
        viewModel: FamGrabViewModel(),
        familyId: "family-123",
        request: GrabRequest(
            requestId: "req-1",
            familyId: "family-123",
            requestorId: EntityRefResponse(id: "user-1", name: "Alice"),
            claimerId: EntityRefResponse(id: "user-2", name: "Bob"),
            status: .claimed,
            embolecCost: 15,
            title: "Iced Latte",
            note: nil,
            tipAmount: nil,
            proofPhotoKey: nil,
            createdAt: Date().timeIntervalSince1970,
            claimedAt: nil,
            completedAt: nil,
            confirmedAt: nil,
            cancelledAt: nil,
            cancelledBy: nil,
            items: nil
        ),
        mode: .upload
    )
}
