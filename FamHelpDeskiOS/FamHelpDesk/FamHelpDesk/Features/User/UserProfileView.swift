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
    @Environment(UserSession.self) private var userSession
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var deviceViewModel = DeviceStatusViewModel()

    var body: some View {
        List {
            Section("User Information") {
                LabeledRow(label: "Display Name", value: profile.displayName)
                LabeledRow(label: "Email", value: profile.email)
                LabeledRow(label: "User ID", value: profile.userId)
            }

            // Push Notifications Section - Prominent placement with toggle
            Section {
                // Master toggle right in the profile
                Toggle(isOn: Binding(
                    get: { deviceViewModel.device?.enabled ?? false },
                    set: { newValue in
                        Task {
                            if newValue {
                                if deviceViewModel.device == nil {
                                    // Need to register first
                                    await deviceViewModel.registerDevice()
                                } else {
                                    // Just enable
                                    await deviceViewModel.enableDevice()
                                }
                            } else {
                                // Disable
                                await deviceViewModel.disableDevice()
                            }
                        }
                    }
                )) {
                    HStack {
                        Label("Push Notifications", systemImage: "bell.badge.fill")

                        Spacer()

                        // Status indicator
                        if deviceViewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if !notificationManager.isAuthorized {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                }
                .disabled(!notificationManager.isAuthorized)

                // Show permission prompt if needed
                if !notificationManager.isAuthorized {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Enable in iOS Settings")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.caption)
                        }
                    }
                }
            } header: {
                Text("Notifications")
            } footer: {
                if !notificationManager.isAuthorized {
                    Text("Enable push notifications in iOS Settings to receive updates about tickets, groups, and family activities.")
                } else if let device = deviceViewModel.device, device.enabled {
                    Text("Push notifications are enabled for this device.")
                } else {
                    Text("Enable push notifications to receive updates about tickets, groups, and family activities.")
                }
            }
        }
        .refreshable {
            await userSession.refreshProfile()
        }
        .task {
            await notificationManager.checkAuthorizationStatus()
            await deviceViewModel.loadDeviceStatus()
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
