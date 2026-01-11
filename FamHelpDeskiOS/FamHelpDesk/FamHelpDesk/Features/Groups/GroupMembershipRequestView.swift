import SwiftUI

struct GroupMembershipRequestView: View {
    let group: FamilyGroup
    let onRequestSuccess: (() -> Void)?
    @State private var groupSession = GroupSession.shared
    @State private var isRequesting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var requestSuccess = false

    @Environment(\.dismiss) private var dismiss

    init(group: FamilyGroup, onRequestSuccess: (() -> Void)? = nil) {
        self.group = group
        self.onRequestSuccess = onRequestSuccess
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Group Info Header
                VStack(spacing: 16) {
                    Image(systemName: "rectangle.3.group.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)

                    VStack(spacing: 8) {
                        Text(group.groupName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        if let description = group.groupDescription, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.top, 32)

                // Request Info
                VStack(spacing: 16) {
                    Text("Request Group Membership")
                        .font(.headline)

                    Text("You're requesting to join this group. A group admin will review your request and decide whether to approve it.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: requestMembership) {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "person.badge.plus")
                                Text("Request to Join")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isRequesting)

                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Join Group")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert(requestSuccess ? "Request Sent" : "Error", isPresented: $showingAlert) {
            Button("OK") {
                if requestSuccess {
                    onRequestSuccess?() // Call the callback before dismissing
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }

    private func requestMembership() {
        Task {
            await performMembershipRequest()
        }
    }

    @MainActor
    private func performMembershipRequest() async {
        isRequesting = true

        let success = await groupSession.requestGroupMembership(
            familyId: group.familyId,
            groupId: group.groupId
        )

        isRequesting = false

        if success {
            requestSuccess = true
            alertMessage = "Your membership request has been sent to the group admins for review."
        } else {
            requestSuccess = false
            alertMessage = groupSession.errorMessage ?? "Failed to send membership request. Please try again."
        }

        showingAlert = true
    }
}

#Preview {
    GroupMembershipRequestView(
        group: FamilyGroup(
            groupId: "group123",
            familyId: "family123",
            groupName: "Family Activities",
            groupDescription: "Planning and organizing family activities and events",
            createdBy: "user123",
            creationDate: Date().timeIntervalSince1970
        )
    )
}
