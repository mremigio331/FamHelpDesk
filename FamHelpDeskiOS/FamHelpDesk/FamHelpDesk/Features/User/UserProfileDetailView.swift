import SwiftUI

struct UserProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthManager

    @State private var userSession = UserSession.shared
    @State private var showEditProfile = false

    var body: some View {
        NavigationStack {
            List {
                if userSession.isFetching {
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
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                if let currentUser = userSession.currentUser {
                    EditProfileView(currentProfile: currentUser)
                    // If EditProfileView needs to call async work in a callback,
                    // do it by wrapping in Task { ... } inside that view or inside the callback.
                }
            }
            // Optional: auto-load on appear
            .task {
                if userSession.currentUser == nil, !userSession.isFetching {
                    await userSession.refreshProfile()
                }
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
