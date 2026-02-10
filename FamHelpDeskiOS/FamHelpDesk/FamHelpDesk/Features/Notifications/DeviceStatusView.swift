import SwiftUI

/// View for displaying and managing device push notification registration status
struct DeviceStatusView: View {
    @StateObject private var viewModel = DeviceStatusViewModel()
    @State private var showUnregisterConfirmation = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading device status...")
            } else {
                Form {
                    if let device = viewModel.device {
                        // Device is registered
                        Section {
                            LabeledContent("Device ID", value: device.deviceId)
                            LabeledContent("Environment", value: device.environment.capitalized)
                            LabeledContent("Bundle ID", value: device.bundleId)
                            LabeledContent("Status", value: device.enabled ? "Enabled" : "Disabled")
                            LabeledContent("Registered", value: device.formattedDate)
                        } header: {
                            Text("Current Device")
                        } footer: {
                            Text("This device is registered to receive push notifications")
                        }

                        Section {
                            Button(role: .destructive) {
                                showUnregisterConfirmation = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Unregister Device")
                                    Spacer()
                                }
                            }
                        } footer: {
                            Text("Unregistering will stop push notifications on this device")
                        }
                    } else {
                        // Device is not registered
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Device Not Registered")
                                    .font(.headline)

                                Text("This device is not currently registered for push notifications. Register to receive notifications about tickets, groups, and family activities.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)

                            Button {
                                Task {
                                    await viewModel.registerDevice()
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Register Device")
                                    Spacer()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
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
        .navigationTitle("Device Status")
        .task {
            await viewModel.loadDeviceStatus()
        }
        .confirmationDialog(
            "Unregister Device",
            isPresented: $showUnregisterConfirmation,
            titleVisibility: .visible
        ) {
            Button("Unregister", role: .destructive) {
                Task {
                    await viewModel.unregisterDevice()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to unregister this device? You will stop receiving push notifications.")
        }
    }
}

#Preview {
    NavigationStack {
        DeviceStatusView()
    }
}
