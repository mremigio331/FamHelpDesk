import PhotosUI
import SwiftUI

struct CompleteItemSheet: View {
    @Bindable var viewModel: FamGrabViewModel
    let familyId: String
    let requestId: String
    let item: GrabRequestItem

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoPreview: Image?
    @State private var isPhotoPublic: Bool = false
    @State private var isUploading = false
    @State private var showCamera = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 44))
                        .foregroundColor(.purple)

                    Text("Complete Item")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("Mark \"\(item.name)\" as complete")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Photo section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Proof Photo (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Add a photo to show the item has been delivered.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let photoPreview {
                        photoPreview
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    photoData = nil
                                    self.photoPreview = nil
                                    selectedPhoto = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                                .padding(8)
                            }
                    } else {
                        HStack(spacing: 12) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Choose Photo", systemImage: "photo.on.rectangle")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                showCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera.fill")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    if photoData != nil {
                        Toggle("Make photo public", isOn: $isPhotoPublic)
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        Task { await completeItem() }
                    } label: {
                        if isUploading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(photoData != nil ? "Upload Photo & Complete" : "Complete Without Photo")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.large)
                    .disabled(isUploading)

                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }

                if let error = viewModel.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle("Complete Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let newValue,
                       let data = try? await newValue.loadTransferable(type: Data.self)
                    {
                        // Convert to JPEG for upload compatibility (iPhones default to HEIC)
                        if let uiImage = UIImage(data: data),
                           let jpegData = uiImage.jpegData(compressionQuality: 0.85)
                        {
                            photoData = jpegData
                            photoPreview = Image(uiImage: uiImage)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { uiImage in
                    if let jpegData = uiImage.jpegData(compressionQuality: 0.85) {
                        photoData = jpegData
                        photoPreview = Image(uiImage: uiImage)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func completeItem() async {
        isUploading = true
        viewModel.clearError()

        var photoKey: String?

        // Upload photo if one was selected
        if let photoData {
            photoKey = await viewModel.uploadDeliveryPhoto(
                familyId: familyId,
                requestId: requestId,
                itemId: item.itemId,
                imageData: photoData
            )
            if photoKey == nil {
                // Upload failed, error is already set on viewModel
                isUploading = false
                return
            }
        }

        let success = await viewModel.completeItems(
            familyId: familyId,
            requestId: requestId,
            itemIds: [item.itemId],
            proofPhotoKey: photoKey,
            photoVisibility: photoData != nil ? (isPhotoPublic ? "public" : "private") : nil
        )

        isUploading = false

        if success {
            dismiss()
        }
    }
}
