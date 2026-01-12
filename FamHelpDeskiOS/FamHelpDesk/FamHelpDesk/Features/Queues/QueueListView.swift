import SwiftUI

struct QueueListView: View {
    let group: FamilyGroup
    @State private var queueSession = QueueSession.shared
    @State private var userSession = UserSession.shared
    @State private var showingCreateQueue = false
    @State private var alertType: AlertType?

    enum AlertType: Identifiable {
        case error(String)

        var id: String {
            switch self {
            case .error: "error"
            }
        }
    }

    private var queues: [Queue] {
        queueSession.getQueuesForGroup(group.groupId)
    }

    // Check if current user is admin of the group (can create queues)
    private var canCreateQueues: Bool {
        // For now, assume any group member can create queues
        // This can be enhanced later with proper permission checking
        true
    }

    var body: some View {
        List {
            if queueSession.isFetching, queues.isEmpty {
                // Loading state
                Section {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading queues...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                }
            } else if queues.isEmpty {
                // Empty state - no queues exist for this group
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "tray.2")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        Text("No Queues Yet")
                            .font(.headline)
                        Text("Create the first queue for this group to organize tickets.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                // Queues list
                Section("Queues (\(queues.count))") {
                    ForEach(queues) { queue in
                        NavigationLink(destination: QueueDetailView(initialQueue: queue)) {
                            QueueRowView(queue: queue)
                        }
                    }
                }
            }

            // Create queue section - only show if user can create queues
            if canCreateQueues {
                Section {
                    Button(action: {
                        showingCreateQueue = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Create New Queue")
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(queueSession.isFetching)
                }
            }
        }
        .navigationTitle("Queues")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await queueSession.refreshGroupQueues(familyId: group.familyId, groupId: group.groupId)
        }
        .task {
            // Queues are already loaded by GroupDetailView, but load if empty
            if queues.isEmpty {
                await queueSession.fetchGroupQueues(familyId: group.familyId, groupId: group.groupId)
            }
        }
        .sheet(isPresented: $showingCreateQueue) {
            CreateQueueView(group: group)
        }
        .alert(item: $alertType) { alertType in
            switch alertType {
            case let .error(message):
                Alert(
                    title: Text("Error"),
                    message: Text(message),
                    dismissButton: .default(Text("OK")) {
                        queueSession.clearError()
                    }
                )
            }
        }
        .onChange(of: queueSession.errorMessage) { _, newValue in
            if let errorMessage = newValue {
                alertType = .error(errorMessage)
            }
        }
    }
}

// MARK: - Queue Row View

struct QueueRowView: View {
    let queue: Queue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(queue.queueName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let description = queue.queueDescription, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Created \(formatDate(queue.createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: date)
    }
}

// MARK: - Create Queue View

struct CreateQueueView: View {
    let group: FamilyGroup
    @Environment(\.dismiss) private var dismiss
    @State private var queueSession = QueueSession.shared

    @State private var queueName = ""
    @State private var queueDescription = ""
    @State private var isCreating = false
    @State private var alertType: AlertType?

    enum AlertType: Identifiable {
        case error(String)

        var id: String {
            switch self {
            case .error: "error"
            }
        }
    }

    private var isFormValid: Bool {
        !queueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Queue Name", text: $queueName)
                        .textInputAutocapitalization(.words)

                    TextField("Description (Optional)", text: $queueDescription, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text("Queue Information")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Queue name must be 2-50 characters long.")
                        if !queueDescription.isEmpty {
                            Text("Description can be up to 200 characters.")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Section {
                    Text("Group: \(group.groupName)")
                        .foregroundColor(.secondary)
                    Text("Family: \(group.familyId)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .navigationTitle("Create Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await createQueue()
                        }
                    }
                    .disabled(!isFormValid || isCreating)
                }
            }
            .alert(item: $alertType) { alertType in
                switch alertType {
                case let .error(message):
                    Alert(
                        title: Text("Error"),
                        message: Text(message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
    }

    @MainActor
    private func createQueue() async {
        isCreating = true

        let trimmedDescription = queueDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDescription = trimmedDescription.isEmpty ? nil : trimmedDescription

        let success = await queueSession.createQueue(
            familyId: group.familyId,
            groupId: group.groupId,
            name: queueName,
            description: finalDescription
        )

        isCreating = false

        if success {
            // Success - dismiss the sheet
            dismiss()
        } else if let errorMessage = queueSession.errorMessage {
            // Show error
            alertType = .error(errorMessage)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        QueueListView(
            group: FamilyGroup(
                groupId: "group123",
                familyId: "family123",
                groupName: "Development Team",
                groupDescription: "Software development group",
                createdBy: "user123",
                creationDate: Date().timeIntervalSince1970
            )
        )
    }
}

#Preview("Create Queue") {
    CreateQueueView(
        group: FamilyGroup(
            groupId: "group123",
            familyId: "family123",
            groupName: "Development Team",
            groupDescription: "Software development group",
            createdBy: "user123",
            creationDate: Date().timeIntervalSince1970
        )
    )
}
