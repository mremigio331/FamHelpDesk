import SwiftUI

struct QueueDetailView: View {
    let initialQueue: Queue
    @Environment(\.dismiss) private var dismiss
    @State private var queueSession = QueueSession.shared
    @State private var userSession = UserSession.shared
    @State private var selectedTab: QueueDetailTab = .overview

    @State private var showingEditQueue = false
    @State private var alertType: AlertType?

    // Get the current queue from session, fallback to initial queue
    private var queue: Queue {
        let queues = queueSession.getQueuesForGroup(initialQueue.groupId)
        return queues.first { $0.queueId == initialQueue.queueId } ?? initialQueue
    }

    enum AlertType: Identifiable {
        case error(String)
        case deleteConfirmation

        var id: String {
            switch self {
            case .error: "error"
            case .deleteConfirmation: "deleteConfirmation"
            }
        }
    }

    enum QueueDetailTab: String, CaseIterable {
        case overview = "Overview"
        case tickets = "Tickets"

        var systemImage: String {
            switch self {
            case .overview: "info.circle"
            case .tickets: "doc.text"
            }
        }
    }

    // Check if current user can edit this queue (for now, assume any member can edit)
    private var canEditQueue: Bool {
        // This can be enhanced later with proper permission checking
        true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(QueueDetailTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top, 8)

            // Tab Content
            switch selectedTab {
            case .overview:
                QueueOverviewView(
                    queue: queue,
                    canEditQueue: canEditQueue,
                    showingEditQueue: $showingEditQueue,
                    onDeleteTapped: {
                        alertType = .deleteConfirmation
                    }
                )
            case .tickets:
                QueueTicketsView(queue: queue)
            }
        }
        .navigationTitle(queue.queueName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if canEditQueue {
                    Menu {
                        Button(action: {
                            showingEditQueue = true
                        }) {
                            Label("Edit Queue", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive, action: {
                            alertType = .deleteConfirmation
                        }) {
                            Label("Delete Queue", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .refreshable {
            // No need to refresh members since queues don't have their own members
        }
        .task {
            // No need to load queue members since they don't exist
        }
        .sheet(isPresented: $showingEditQueue) {
            EditQueueView(queue: queue)
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
            case .deleteConfirmation:
                Alert(
                    title: Text("Delete Queue"),
                    message: Text("Are you sure you want to delete '\(queue.queueName)'? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        Task {
                            await deleteQueue()
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onChange(of: queueSession.errorMessage) { _, newValue in
            if let errorMessage = newValue {
                alertType = .error(errorMessage)
            }
        }
    }

    @MainActor
    private func deleteQueue() async {
        let success = await queueSession.deleteQueue(
            familyId: initialQueue.familyId,
            groupId: initialQueue.groupId,
            queueId: initialQueue.queueId
        )

        if success {
            // Navigate back after successful deletion
            dismiss()
        } else if let errorMessage = queueSession.errorMessage {
            alertType = .error(errorMessage)
        }
    }
}

// MARK: - Queue Overview View

struct QueueOverviewView: View {
    let queue: Queue
    let canEditQueue: Bool
    @Binding var showingEditQueue: Bool
    let onDeleteTapped: () -> Void

    var body: some View {
        List {
            // Queue Information Section
            Section("Queue Information") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "tray.2.fill")
                            .font(.title)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(queue.queueName)
                                .font(.title2)
                                .fontWeight(.bold)

                            if let description = queue.queueDescription, !description.isEmpty {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Divider()

                    HStack {
                        Text("Created")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(queue.createdAt))
                    }

                    HStack {
                        Text("Queue ID")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(queue.queueId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 8)
            }

            // Quick Stats Section
            Section("Quick Stats") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Group Access")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Via Group")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Tickets")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("0") // TODO: Replace with actual ticket count when tickets are implemented
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, 8)
            }

            // Quick Actions Section
            if canEditQueue {
                Section("Quick Actions") {
                    Button(action: {
                        showingEditQueue = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                            Text("Edit Queue")
                                .foregroundColor(.blue)
                        }
                    }

                    Button(action: {
                        onDeleteTapped()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Delete Queue")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
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

// MARK: - Queue Tickets View

struct QueueTicketsView: View {
    let queue: Queue

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    Text("Tickets Coming Soon")
                        .font(.headline)
                    Text("Ticket management functionality will be available in a future update.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
}

// MARK: - Edit Queue View

struct EditQueueView: View {
    let initialQueue: Queue
    @Environment(\.dismiss) private var dismiss
    @State private var queueSession = QueueSession.shared

    @State private var queueName: String
    @State private var queueDescription: String
    @State private var isUpdating = false
    @State private var alertType: AlertType?

    // Get the current queue from session, fallback to initial queue
    private var queue: Queue {
        let queues = queueSession.getQueuesForGroup(initialQueue.groupId)
        return queues.first { $0.queueId == initialQueue.queueId } ?? initialQueue
    }

    enum AlertType: Identifiable {
        case error(String)

        var id: String {
            switch self {
            case .error: "error"
            }
        }
    }

    init(queue: Queue) {
        initialQueue = queue
        _queueName = State(initialValue: queue.queueName)
        _queueDescription = State(initialValue: queue.queueDescription ?? "")
    }

    private var isFormValid: Bool {
        !queueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasChanges: Bool {
        let trimmedName = queueName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = queueDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalDescription = queue.queueDescription ?? ""

        let nameChanged = trimmedName != queue.queueName
        let descriptionChanged = trimmedDescription != originalDescription
        let hasChanges = nameChanged || descriptionChanged

        print("🔍 hasChanges check:")
        print("   - Original name: '\(queue.queueName)'")
        print("   - Current name: '\(trimmedName)'")
        print("   - Name changed: \(nameChanged)")
        print("   - Original description: '\(originalDescription)'")
        print("   - Current description: '\(trimmedDescription)'")
        print("   - Description changed: \(descriptionChanged)")
        print("   - Has changes: \(hasChanges)")

        return hasChanges
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
                    Text("Queue ID: \(queue.queueId)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("Created: \(formatDate(queue.createdAt))")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .navigationTitle("Edit Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isUpdating)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await updateQueue()
                        }
                    }
                    .disabled(!isFormValid || !hasChanges || isUpdating)
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
    private func updateQueue() async {
        isUpdating = true

        let trimmedName = queueName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = queueDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDescription = trimmedDescription.isEmpty ? nil : trimmedDescription

        print("🔄 Starting queue update:")
        print("   - familyId: \(initialQueue.familyId)")
        print("   - groupId: \(initialQueue.groupId)")
        print("   - queueId: \(initialQueue.queueId)")
        print("   - name: \(trimmedName)")
        print("   - description: \(finalDescription ?? "nil")")

        let success = await queueSession.updateQueue(
            familyId: initialQueue.familyId,
            groupId: initialQueue.groupId,
            queueId: initialQueue.queueId,
            name: trimmedName,
            description: finalDescription
        )

        print("🔄 Queue update result: \(success)")

        isUpdating = false

        if success {
            // Success - dismiss the sheet
            dismiss()
        } else if let errorMessage = queueSession.errorMessage {
            // Show error
            alertType = .error(errorMessage)
        }
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

// MARK: - Preview

#Preview {
    NavigationStack {
        QueueDetailView(
            initialQueue: Queue(
                queueId: "queue123",
                familyId: "family123",
                groupId: "group123",
                queueName: "Bug Reports",
                queueDescription: "Track and manage bug reports for the application",
                creationDate: Date().timeIntervalSince1970
            )
        )
    }
}

#Preview("Edit Queue") {
    EditQueueView(
        queue: Queue(
            queueId: "queue123",
            familyId: "family123",
            groupId: "group123",
            queueName: "Bug Reports",
            queueDescription: "Track and manage bug reports for the application",
            creationDate: Date().timeIntervalSince1970
        )
    )
}
