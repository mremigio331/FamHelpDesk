import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var viewModel = NotificationSettingsViewModel()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var deviceViewModel = DeviceStatusViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading || deviceViewModel.isLoading {
                VStack {
                    ProgressView()
                    Text("Loading settings...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    // Status Summary Section
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: deviceViewModel.device?.enabled == true ? "bell.badge.fill" : "bell.slash.fill")
                                    .font(.title2)
                                    .foregroundColor(deviceViewModel.device?.enabled == true ? .green : .secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Push Notifications")
                                        .font(.headline)

                                    if !notificationManager.isAuthorized {
                                        Text("iOS permission required")
                                            .font(.subheadline)
                                            .foregroundColor(.orange)
                                    } else if deviceViewModel.device?.enabled == true {
                                        Text("Enabled on this device")
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                    } else {
                                        Text("Disabled on this device")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()
                            }

                            if !notificationManager.isAuthorized {
                                Text("Enable push notifications in iOS Settings to receive updates about tickets, groups, and family activities.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Master Toggle Section
                    Section {
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
                            Label("Enable on This Device", systemImage: "iphone")
                        }
                        .disabled(!notificationManager.isAuthorized)

                        if !notificationManager.isAuthorized {
                            Button {
                                openSystemSettings()
                            } label: {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Open iOS Settings")
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.app")
                                        .font(.caption)
                                }
                            }
                        }
                    } header: {
                        Text("Device Settings")
                    } footer: {
                        if !notificationManager.isAuthorized {
                            Text("You must grant notification permission in iOS Settings before enabling push notifications.")
                        } else if deviceViewModel.device?.enabled == true {
                            Text("This device will receive push notifications for tickets, groups, and family activities.")
                        } else {
                            Text("Enable to start receiving push notifications on this device.")
                        }
                    }

                    Section {
                        NavigationLink {
                            DeviceStatusView()
                        } label: {
                            Label("Device Registration Details", systemImage: "iphone.circle")
                        }
                    } header: {
                        Text("Advanced")
                    } footer: {
                        Text("View detailed device registration information and manage device tokens.")
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("Notification Settings")
        .task {
            await viewModel.loadSettings()
            await notificationManager.checkAuthorizationStatus()
            await deviceViewModel.loadDeviceStatus()
        }
    }

    /// Open iOS Settings app
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
