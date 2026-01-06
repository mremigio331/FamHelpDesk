import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var userSession = UserSession.shared
    @State private var displayName: String
    @State private var nickName: String
    @State private var selectedProfileColor: ProfileColor
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var showingColorPicker = false

    private let userService = UserService()

    init(currentProfile: UserProfile) {
        _displayName = State(initialValue: currentProfile.displayName)
        _nickName = State(initialValue: currentProfile.nickName)
        _selectedProfileColor = State(initialValue: ProfileColor(rawValue: currentProfile.profileColor) ?? .black)
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

                Section("Appearance") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Profile Color")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: {
                            showingColorPicker = true
                        }) {
                            HStack {
                                Circle()
                                    .fill(selectedProfileColor.color)
                                    .frame(width: 24, height: 24)
                                Text(selectedProfileColor.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
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
            .sheet(isPresented: $showingColorPicker) {
                ColorPickerView(selectedColor: $selectedProfileColor)
            }
        }
    }

    private var isFormValid: Bool {
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespaces)
        let trimmedNickName = nickName.trimmingCharacters(in: .whitespaces)

        return !trimmedDisplayName.isEmpty &&
            !trimmedNickName.isEmpty &&
            trimmedDisplayName.count <= 100 &&
            trimmedNickName.count <= 50
    }

    @MainActor
    private func updateProfile() async {
        isUpdating = true
        errorMessage = nil

        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespaces)
        let trimmedNickName = nickName.trimmingCharacters(in: .whitespaces)

        // Validate input lengths
        if trimmedDisplayName.count > 100 {
            errorMessage = "Display name must be less than 100 characters"
            isUpdating = false
            return
        }

        if trimmedNickName.count > 50 {
            errorMessage = "Nickname must be less than 50 characters"
            isUpdating = false
            return
        }

        do {
            let updatedProfile = try await userService.updateUserProfile(
                displayName: trimmedDisplayName,
                nickName: trimmedNickName,
                profileColor: selectedProfileColor.rawValue,
                darkMode: nil
            )

            // Update the user session with the new profile
            userSession.currentUser = updatedProfile

            dismiss()
        } catch {
            if let networkError = error as? NetworkError {
                switch networkError {
                case .invalidURL:
                    errorMessage = "Invalid request URL"
                case .invalidResponse:
                    errorMessage = "Invalid response from server"
                case .noData:
                    errorMessage = "No data received from server"
                case .decodingError:
                    errorMessage = "Failed to process server response"
                case let .serverError(statusCode, message):
                    if statusCode == 400 {
                        errorMessage = message ?? "Invalid input provided"
                    } else {
                        errorMessage = message ?? "Server error occurred"
                    }
                case .unauthorized:
                    errorMessage = "Authentication required"
                case .tokenRefreshFailed:
                    errorMessage = "Authentication failed"
                case .authenticationFailure:
                    errorMessage = "Authentication error"
                case .networkTimeout:
                    errorMessage = "Request timed out"
                case .malformedResponse:
                    errorMessage = "Malformed server response"
                }
            } else {
                errorMessage = "Failed to update profile: \(error.localizedDescription)"
            }
            print("❌ Error updating profile: \(error)")
        }

        isUpdating = false
    }
}

struct ColorPickerView: View {
    @Binding var selectedColor: ProfileColor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(ProfileColor.allCases) { color in
                    Button(action: {
                        selectedColor = color
                        dismiss()
                    }) {
                        HStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 32, height: 32)
                            Text(color.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedColor == color {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Profile Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EditProfileView(currentProfile: UserProfile(
        userId: "123",
        displayName: "John Doe",
        nickName: "johnd",
        email: "john@example.com",
        profileColor: "Blue",
        darkMode: DarkModeSettings(web: false, mobile: true, ios: false)
    ))
}
