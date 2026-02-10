import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var viewModel = NotificationSettingsViewModel()
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading settings...")
            } else {
                Form {
                    // Notification Permission Status Section
                    Section {
                        HStack {
                            Label("Push Notifications", systemImage: "bell.badge.fill")
                            Spacer()
                            Text(notificationManager.isAuthorized ? "Enabled" : "Disabled")
                                .foregroundColor(notificationManager.isAuthorized ? .green : .secondary)
                        }

                        if !notificationManager.isAuthorized {
                            Button {
                                openSystemSettings()
                            } label: {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Open Settings")
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.app")
                                        .font(.caption)
                                }
                            }
                        }
                    } header: {
                        Text("Permission Status")
                    } footer: {
                        if notificationManager.isAuthorized {
                            Text("Push notifications are enabled for this device")
                        } else {
                            Text("Push notifications are disabled. Enable them in Settings to receive notifications.")
                        }
                    }

                    Section {
                        Toggle("Welcome Messages", isOn: $viewModel.welcomeEnabled)
                            .onChange(of: viewModel.welcomeEnabled) { _, _ in
                                Task {
                                    await viewModel.saveSettings()
                                }
                            }

                        Toggle("Membership Updates", isOn: $viewModel.membershipEnabled)
                            .onChange(of: viewModel.membershipEnabled) { _, _ in
                                Task {
                                    await viewModel.saveSettings()
                                }
                            }

                        Toggle("Group Invitations", isOn: $viewModel.groupInvitationEnabled)
                            .onChange(of: viewModel.groupInvitationEnabled) { _, _ in
                                Task {
                                    await viewModel.saveSettings()
                                }
                            }
                    } header: {
                        Text("General")
                    } footer: {
                        Text("These are global defaults. You can customize per family.")
                    }

                    Section {
                        Toggle("Ticket Creation", isOn: $viewModel.ticketCreationEnabled)
                            .onChange(of: viewModel.ticketCreationEnabled) { _, _ in
                                Task {
                                    await viewModel.saveSettings()
                                }
                            }

                        Toggle("Ticket Assigned", isOn: $viewModel.ticketAssignedEnabled)
                            .onChange(of: viewModel.ticketAssignedEnabled) { _, _ in
                                Task {
                                    await viewModel.saveSettings()
                                }
                            }

                        Toggle("Ticket Comments", isOn: $viewModel.ticketCommentEnabled)
                            .onChange(of: viewModel.ticketCommentEnabled) { _, _ in
                                Task {
                                    await viewModel.saveSettings()
                                }
                            }

                        Toggle("Ticket Status Changes", isOn: $viewModel.ticketStatusChangedEnabled)
                            .onChange(of: viewModel.ticketStatusChangedEnabled) { _, _ in
                                Task {
                                    await viewModel.saveSettings()
                                }
                            }
                    } header: {
                        Text("Tickets")
                    } footer: {
                        Text("These are global defaults. You can customize per family.")
                    }

                    // Per-Family Settings Section
                    Section {
                        NavigationLink {
                            FamilyNotificationSettingsListView()
                        } label: {
                            Label("Manage Family Settings", systemImage: "bell.badge")
                        }
                    } header: {
                        Text("Per-Family Settings")
                    } footer: {
                        Text("Customize notification preferences for each family individually")
                    }

                    Section {
                        NavigationLink {
                            DeviceStatusView()
                        } label: {
                            Label("Device Status", systemImage: "iphone")
                        }
                    } header: {
                        Text("Device Management")
                    } footer: {
                        Text("View and manage push notification registration for this device")
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
