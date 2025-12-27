import SwiftUI

struct UserProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthManager
    @State private var userSession = UserSession.shared

    var body: some View {
        NavigationStack {
            List {
                if userSession.isFetching {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else if let user = userSession.currentUser {
                    // User Info Section
                    Section("User Information") {
                        HStack {
                            Text("Display Name")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(user.displayName)
                        }

                        HStack {
                            Text("Nickname")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(user.nickName)
                        }

                        HStack {
                            Text("Email")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(user.email)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }

                    // Actions Section
                    Section("Actions") {
                        Button {
                            Task {
                                await userSession.refreshProfile()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh Profile")
                            }
                        }
                        .disabled(userSession.isFetching)
                    }

                    // Sign Out Section
                    Section {
                        Button(role: .destructive) {
                            auth.signOut()
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                                Spacer()
                            }
                        }
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            "No Profile",
                            systemImage: "person.crop.circle.badge.xmark",
                            description: Text("Unable to load user profile")
                        )
                    }

                    // Sign Out Section - available even without profile
                    Section {
                        Button(role: .destructive) {
                            auth.signOut()
                            dismiss()
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
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    UserProfileDetailView()
        .environmentObject(AuthManager())
}
