import SwiftUI

struct UserProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthManager

    @State private var userSession = UserSession.shared
    @State private var showEditProfile = false
    @StateObject private var deletionViewModel: ProfileDeletionViewModel
    @State private var showDeletionAlert = false

    init() {
        let deletionService = ProfileDeletionService(authManager: AuthManager())
        _deletionViewModel = StateObject(wrappedValue: ProfileDeletionViewModel(deletionService: deletionService))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation toolbar with back button
            NavigationToolbar(title: "Profile", customBackAction: {
                dismiss()
            })

            List {
                if userSession.isFetching, userSession.currentUser == nil {
                    // Only show loading if profile is not loaded yet
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else if let user = userSession.currentUser {
                    Section("User Information") {
                        HStack {
                            Text("Display Name").foregroundColor(.secondary)
                            Spacer()
                            Text(user.displayName)
                        }

                        HStack {
                            Text("Email").foregroundColor(.secondary)
                            Spacer()
                            Text(user.email)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        HStack {
                            Text("Profile Color").foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(colorFromString(user.profileColor))
                                    .frame(width: 16, height: 16)
                                Text(user.profileColor)
                            }
                        }
                    }

                    Section("Actions") {
                        Button {
                            showEditProfile = true
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Profile")
                            }
                        }

                        Button {
                            Task { await userSession.refreshProfile() }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh Profile")
                            }
                        }
                        .disabled(userSession.isFetching)
                    }

                    Section {
                        Button(role: .destructive) {
                            Task {
                                await auth.signOut()
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                                Spacer()
                            }
                        }

                        Button(role: .destructive) {
                            showDeletionAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                if deletionViewModel.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 8)
                                }
                                Image(systemName: "trash")
                                Text("Delete Profile")
                                Spacer()
                            }
                        }
                        .disabled(deletionViewModel.isLoading)

                        // Testing Helper (Debug builds only)
                        #if DEBUG
                            Button(role: .destructive) {
                                Task {
                                    await auth.forceSignOut()
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(systemName: "trash.circle")
                                    Text("Force Sign Out")
                                    Spacer()
                                }
                            }

                            Button {
                                Task {
                                    await AuthTestHelper.testAuthenticationFlow()
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(systemName: "testtube.2")
                                    Text("Test Auth Flow")
                                    Spacer()
                                }
                            }
                        #endif
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            "No Profile",
                            systemImage: "person.crop.circle.badge.xmark",
                            description: Text("Unable to load user profile")
                        )
                    }

                    Section {
                        Button(role: .destructive) {
                            Task {
                                await auth.signOut()
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                                Spacer()
                            }
                        }
                    }
                }

                if let errorMessage = userSession.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .refreshable {
                await userSession.refreshProfile()
            }
            .sheet(isPresented: $showEditProfile) {
                if let currentUser = userSession.currentUser {
                    EditProfileView(currentProfile: currentUser)
                    // If EditProfileView needs to call async work in a callback,
                    // do it by wrapping in Task { ... } inside that view or inside the callback.
                }
            }
            .alert("Delete Profile", isPresented: $showDeletionAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await deletionViewModel.initiateProfileDeletion()
                    }
                }
            } message: {
                Text("Are you sure you want to delete your profile? This action cannot be undone. You will receive an email once the deletion is completed.")
            }
            .alert("Deletion Failed", isPresented: .constant(deletionViewModel.errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    deletionViewModel.errorMessage = nil
                }
                Button("Retry") {
                    Task {
                        await deletionViewModel.retryDeletion()
                    }
                }
            } message: {
                if let errorMessage = deletionViewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .fullScreenCover(isPresented: $deletionViewModel.showDeletionConfirmation) {
                DeletionConfirmationView(onBackToHome: {
                    // Perform minimal sign-out when user taps "Back to Home"
                    Task {
                        print("🗑️ [CONFIRMATION VIEW] User tapped Back to Home")
                        print("🗑️ [CONFIRMATION VIEW] Clearing local state only...")

                        await MainActor.run {
                            // Clear auth state ONLY - don't touch Amplify
                            auth.isAuthenticated = false
                            auth.userDisplayName = nil
                            auth.authError = nil
                            auth.authenticationState = .unauthenticated

                            // Clear network managers
                            APIClient.shared.clearAccessToken()
                            NetworkManager.shared.clearAccessToken()

                            // Clear user session
                            UserSession.shared.signOut()

                            print("🗑️ [CONFIRMATION VIEW] Local state cleared")

                            // Dismiss the confirmation view
                            deletionViewModel.showDeletionConfirmation = false

                            print("🗑️ [CONFIRMATION VIEW] Confirmation view dismissed")
                        }
                    }
                })
                .environmentObject(auth)
                .interactiveDismissDisabled(true) // Prevent swipe to dismiss
            }
        }
    }

    // Helper function to convert color string to SwiftUI Color
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "black":
            .black
        case "white":
            .white
        case "red":
            .red
        case "blue":
            .blue
        case "green":
            .green
        case "yellow":
            .yellow
        case "orange":
            .orange
        case "purple":
            .purple
        case "pink":
            .pink
        case "brown":
            .brown
        case "gray":
            .gray
        case "cyan":
            .cyan
        default:
            .black
        }
    }
}

#Preview {
    UserProfileDetailView()
        .environmentObject(AuthManager())
}
