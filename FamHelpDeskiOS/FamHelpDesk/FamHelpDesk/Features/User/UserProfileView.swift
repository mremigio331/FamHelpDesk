import SwiftUI

struct UserProfileView: View {
    @Environment(UserSession.self) private var userSession

    var body: some View {
        NavigationStack {
            Group {
                if userSession.isLoading || userSession.isFetching {
                    ProgressView("Loading profile...")
                } else if let errorMessage = userSession.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await userSession.refreshProfile()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if let profile = userSession.currentUser {
                    ProfileContentView(profile: profile)
                } else {
                    ContentUnavailableView(
                        "No Profile",
                        systemImage: "person.crop.circle.badge.xmark",
                        description: Text("Please sign in to view your profile")
                    )
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await userSession.refreshProfile()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(userSession.isFetching)
                }
            }
        }
    }
}

struct ProfileContentView: View {
    let profile: UserProfile

    var body: some View {
        List {
            Section("User Information") {
                LabeledRow(label: "Display Name", value: profile.displayName)
                LabeledRow(label: "Nickname", value: profile.nickName)
                LabeledRow(label: "Email", value: profile.email)
                LabeledRow(label: "User ID", value: profile.userId)
            }
        }
    }
}

struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}

#Preview {
    UserProfileView()
}
