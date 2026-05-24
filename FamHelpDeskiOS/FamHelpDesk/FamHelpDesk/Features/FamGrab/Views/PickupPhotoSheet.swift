import PhotosUI
import SwiftUI

struct PickupPhotoSheet: View {
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
                    Image(systemName: "camera.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.purple)

                    Text("Add Pickup Photo")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("Add a pickup photo for \"\(item.name)\"")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Photo section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pickup Photo")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Take or select a photo to show the item has been picked up.")
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
                        Task { await uploadPhoto() }
                    } label: {
                        if isUploading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Upload Pickup Photo")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.large)
                    .disabled(isUploading || photoData == nil)

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
            .navigationTitle("Add Pickup Photo")
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

    private func uploadPhoto() async {
        guard let photoData else { return }

        isUploading = true
        viewModel.clearError()

        let success = await viewModel.uploadPickupPhoto(
            familyId: familyId,
            requestId: requestId,
            itemId: item.itemId,
            imageData: photoData,
            isPublic: isPhotoPublic
        )

        isUploading = false

        if success {
            dismiss()
        }
    }
}
