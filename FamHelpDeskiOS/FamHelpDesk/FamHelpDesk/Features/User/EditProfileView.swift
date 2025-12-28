import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var userSession = UserSession.shared
    @State private var displayName: String
    @State private var nickName: String
    @State private var isUpdating = false
    @State private var errorMessage: String?

    private let userService = UserService()

    init(currentProfile: UserProfile) {
        _displayName = State(initialValue: currentProfile.displayName)
        _nickName = State(initialValue: currentProfile.nickName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Information") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Display Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Display Name", text: $displayName)
                            .textFieldStyle(.plain)
                            .disabled(isUpdating)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nickname")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Nickname", text: $nickName)
                            .textFieldStyle(.plain)
                            .disabled(isUpdating)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isUpdating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await updateProfile()
                        }
                    }
                    .disabled(isUpdating || !isFormValid)
                }
            }
            .overlay {
                if isUpdating {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
                }
            }
        }
    }

    private var isFormValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
            !nickName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @MainActor
    private func updateProfile() async {
        isUpdating = true
        errorMessage = nil

        do {
            let updatedProfile = try await userService.updateUserProfile(
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                nickName: nickName.trimmingCharacters(in: .whitespaces)
            )

            // Update the user session with the new profile
            userSession.currentUser = updatedProfile

            dismiss()
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
            print("❌ Error updating profile: \(error)")
        }

        isUpdating = false
    }
}

#Preview {
    EditProfileView(currentProfile: UserProfile(
        userId: "123",
        displayName: "John Doe",
        nickName: "johnd",
        email: "john@example.com"
    ))
}
