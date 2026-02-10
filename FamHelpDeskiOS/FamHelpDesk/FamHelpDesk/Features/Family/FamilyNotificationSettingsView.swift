import SwiftUI

struct FamilyNotificationSettingsView: View {
    @StateObject private var viewModel = FamilyNotificationSettingsViewModel()
    let familyId: String
    let familyName: String?

    var body: some View {
        Form {
            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading settings...")
                        Spacer()
                    }
                }
            } else {
                // Section 1: Membership Notifications
                Section {
                    // Set All buttons
                    HStack {
                        Button("Enable All") {
                            Task {
                                await viewModel.setAllMembershipNotifications(enabled: true)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)

                        Spacer()

                        Button("Disable All") {
                            Task {
                                await viewModel.setAllMembershipNotifications(enabled: false)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .listRowBackground(Color.clear)

                    Toggle("Welcome to Family", isOn: $viewModel.welcomeToFamilyEnabled)
                        .onChange(of: viewModel.welcomeToFamilyEnabled) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("New Family Member", isOn: $viewModel.newFamilyMemberEnabled)
                        .onChange(of: viewModel.newFamilyMemberEnabled) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Membership Approved", isOn: $viewModel.familyMembershipApproved)
                        .onChange(of: viewModel.familyMembershipApproved) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Membership Denied", isOn: $viewModel.familyMembershipDenied)
                        .onChange(of: viewModel.familyMembershipDenied) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Membership Invitation", isOn: $viewModel.familyMembershipInvitation)
                        .onChange(of: viewModel.familyMembershipInvitation) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Member Joined", isOn: $viewModel.familyMembershipJoined)
                        .onChange(of: viewModel.familyMembershipJoined) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Member Left", isOn: $viewModel.familyMembershipLeft)
                        .onChange(of: viewModel.familyMembershipLeft) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Membership Request", isOn: $viewModel.familyMembershipRequest)
                        .onChange(of: viewModel.familyMembershipRequest) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }
                } header: {
                    Text("Membership Notifications")
                } footer: {
                    Text("Notifications about family membership changes")
                }

                // Section 2: Group Notifications
                Section {
                    // Set All buttons
                    HStack {
                        Button("Enable All") {
                            Task {
                                await viewModel.setAllGroupNotifications(enabled: true)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)

                        Spacer()

                        Button("Disable All") {
                            Task {
                                await viewModel.setAllGroupNotifications(enabled: false)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .listRowBackground(Color.clear)

                    Toggle("Group Membership Approved", isOn: $viewModel.groupMembershipApproved)
                        .onChange(of: viewModel.groupMembershipApproved) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Group Membership Denied", isOn: $viewModel.groupMembershipDenied)
                        .onChange(of: viewModel.groupMembershipDenied) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Added to Group", isOn: $viewModel.groupMembershipAdded)
                        .onChange(of: viewModel.groupMembershipAdded) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Group Member Joined", isOn: $viewModel.groupMembershipJoined)
                        .onChange(of: viewModel.groupMembershipJoined) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Group Member Left", isOn: $viewModel.groupMembershipLeft)
                        .onChange(of: viewModel.groupMembershipLeft) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Group Membership Request", isOn: $viewModel.groupMembershipRequest)
                        .onChange(of: viewModel.groupMembershipRequest) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("New Group Created", isOn: $viewModel.newGroupCreation)
                        .onChange(of: viewModel.newGroupCreation) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }
                } header: {
                    Text("Group Notifications")
                } footer: {
                    Text("Notifications about group membership and creation")
                }

                // Section 3: Ticket Notifications
                Section {
                    // Set All buttons
                    HStack {
                        Button("Enable All") {
                            Task {
                                await viewModel.setAllTicketNotifications(enabled: true)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)

                        Spacer()

                        Button("Disable All") {
                            Task {
                                await viewModel.setAllTicketNotifications(enabled: false)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .listRowBackground(Color.clear)
                    .listRowBackground(Color.clear)

                    Toggle("Ticket Created (Family)", isOn: $viewModel.ticketCreationFamily)
                        .onChange(of: viewModel.ticketCreationFamily) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Ticket Created (Group)", isOn: $viewModel.ticketCreationGroup)
                        .onChange(of: viewModel.ticketCreationGroup) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Ticket Assigned", isOn: $viewModel.ticketAssigned)
                        .onChange(of: viewModel.ticketAssigned) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Ticket Comment", isOn: $viewModel.ticketComment)
                        .onChange(of: viewModel.ticketComment) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Ticket Status Changed", isOn: $viewModel.ticketStatusChange)
                        .onChange(of: viewModel.ticketStatusChange) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }

                    Toggle("Ticket Resolved", isOn: $viewModel.ticketResolved)
                        .onChange(of: viewModel.ticketResolved) { _, _ in
                            Task { await viewModel.saveSettings() }
                        }
                } header: {
                    Text("Ticket Notifications")
                } footer: {
                    Text("Notifications about ticket creation, assignment, and updates")
                }
            }

            // Error message section
            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(familyName ?? "Notification Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSettings(familyId: familyId)
        }
    }
}

#Preview {
    NavigationStack {
        FamilyNotificationSettingsView(
            familyId: "family_123",
            familyName: "Smith Family"
        )
    }
}
