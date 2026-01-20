import SwiftUI

struct TicketFormView: View {
    // MARK: - Form Mode

    enum FormMode {
        case create(familyId: String)
        case edit(ticket: Ticket)

        var isEditing: Bool {
            switch self {
            case .create: false
            case .edit: true
            }
        }

        var title: String {
            switch self {
            case .create: "Create Ticket"
            case .edit: "Edit Ticket"
            }
        }

        var familyId: String {
            switch self {
            case let .create(familyId): familyId
            case let .edit(ticket): ticket.familyId.id
            }
        }
    }

    // MARK: - Properties

    let mode: FormMode
    let onSuccess: (Ticket) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var userSession = UserSession.shared
    @State private var ticketSession = TicketSession.shared

    // MARK: - Form State

    @State private var title = ""
    @State private var description = ""
    @State private var selectedSeverity: TicketSeverity = .sev3
    @State private var selectedStatus: TicketStatus = .open
    @State private var selectedGroup: FamilyGroup?
    @State private var selectedQueue: Queue?
    @State private var selectedAssignedUser: ActiveFamilyMember?

    // MARK: - Data Loading State

    @State private var groups: [FamilyGroup] = []
    @State private var queues: [Queue] = []
    @State private var familyMembers: [ActiveFamilyMember] = []
    @State private var isLoadingGroups = false
    @State private var isLoadingQueues = false
    @State private var isLoadingMembers = false

    // MARK: - Form Submission State

    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showError = false

    // MARK: - Services

    private let groupService = GroupService()
    private let queueService = QueueService()
    private let ticketService = TicketService()
    private let membershipService = MembershipService()

    // MARK: - Initialization

    init(mode: FormMode, onSuccess: @escaping (Ticket) -> Void) {
        self.mode = mode
        self.onSuccess = onSuccess
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation toolbar with back button
            NavigationToolbar(title: mode.title, customBackAction: {
                dismiss()
            })

            Form {
                // Required Fields Section
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter ticket title", text: $title)
                            .textFieldStyle(.plain)
                            .disabled(isSubmitting)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Severity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Severity", selection: $selectedSeverity) {
                            ForEach(TicketSeverity.allCases, id: \.self) { severity in
                                HStack {
                                    Circle()
                                        .fill(severityColor(for: severity))
                                        .frame(width: 12, height: 12)
                                    Text(severity.displayName)
                                }
                                .tag(severity)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(isSubmitting)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Group")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if isLoadingGroups {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                        Picker("Group", selection: $selectedGroup) {
                            Text("Select a group").tag(nil as FamilyGroup?)
                            ForEach(groups) { group in
                                Text(group.groupName).tag(group as FamilyGroup?)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(isSubmitting || isLoadingGroups)
                        .onChange(of: selectedGroup) { _, newGroup in
                            if newGroup != nil {
                                selectedQueue = nil
                                selectedAssignedUser = nil
                                Task {
                                    await loadQueues()
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Queue")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if isLoadingQueues {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                        Picker("Queue", selection: $selectedQueue) {
                            Text("Select a queue").tag(nil as Queue?)
                            ForEach(queues) { queue in
                                Text(queue.queueName).tag(queue as Queue?)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(isSubmitting || isLoadingQueues || selectedGroup == nil)
                        .onChange(of: selectedQueue) { _, newQueue in
                            if newQueue != nil, mode.isEditing {
                                selectedAssignedUser = nil
                                // Family members are loaded once on form initialization
                            }
                        }
                    }
                } header: {
                    Text("Required Information")
                } footer: {
                    Text("All fields in this section are required")
                }

                // Optional Fields Section
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter ticket description (optional)", text: $description, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3 ... 6)
                            .disabled(isSubmitting)
                    }

                    // Assignment is available for both create and edit modes
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Assign To")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if isLoadingMembers {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                        Picker("Assign To", selection: $selectedAssignedUser) {
                            Text("Unassigned").tag(nil as ActiveFamilyMember?)
                            ForEach(familyMembers) { member in
                                Text(member.displayName).tag(member as ActiveFamilyMember?)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(isSubmitting || isLoadingMembers)
                    }
                } header: {
                    Text("Optional Information")
                } footer: {
                    Text("These fields are optional and can be updated later")
                }

                // Status Section (Edit Mode Only)
                if mode.isEditing {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Status", selection: $selectedStatus) {
                                ForEach(availableStatuses, id: \.self) { status in
                                    Text(status.rawValue).tag(status)
                                }
                            }
                            .pickerStyle(.segmented)
                            .disabled(isSubmitting || !canChangeStatus)
                        }
                    } header: {
                        Text("Status")
                    } footer: {
                        Text(statusFooterText)
                    }
                }

                // Validation Errors
                if let errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .overlay {
                if isSubmitting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text(mode.isEditing ? "Updating Ticket..." : "Creating Ticket...")
                                .font(.headline)
                        }
                        .padding(32)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    }
                }
            }

            // Submit Button
            VStack(spacing: 0) {
                Divider()

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSubmitting)

                    Spacer()

                    Button(mode.isEditing ? "Update Ticket" : "Create Ticket") {
                        Task {
                            await submitForm()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid || isSubmitting)
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadInitialData()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty &&
            trimmedTitle.count <= 200 &&
            selectedGroup != nil &&
            selectedQueue != nil
    }

    private var availableStatuses: [TicketStatus] {
        guard case let .edit(ticket) = mode else { return [] }

        switch ticket.status {
        case .open:
            return [.open, .resolved]
        case .resolved:
            if ticket.canReopen {
                return [.open, .resolved, .closed]
            } else {
                return [.resolved, .closed]
            }
        case .closed:
            return [.closed] // Closed tickets cannot change status
        }
    }

    private var canChangeStatus: Bool {
        guard case let .edit(ticket) = mode else { return false }
        return ticket.status != .closed
    }

    private var statusFooterText: String {
        guard case let .edit(ticket) = mode else { return "" }

        switch ticket.status {
        case .open:
            return "You can resolve this ticket or keep it open"
        case .resolved:
            if ticket.canReopen {
                return "You can reopen, keep resolved, or close this ticket"
            } else {
                return "Reopen window has expired. You can only close this ticket"
            }
        case .closed:
            return "Closed tickets cannot be reopened or changed"
        }
    }

    // MARK: - Helper Methods

    private func severityColor(for severity: TicketSeverity) -> Color {
        switch severity {
        case .sev1:
            .red
        case .sev2, .sev2_5:
            .orange
        case .sev3:
            .yellow
        case .sev4, .sev5:
            .green
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadInitialData() async {
        // Load family members for assignment (both create and edit modes)
        await loadFamilyMembers()

        // Initialize form with existing ticket data if editing
        if case let .edit(ticket) = mode {
            title = ticket.title
            description = ticket.description ?? ""
            selectedSeverity = ticket.severity
            selectedStatus = ticket.status

            // Find and set the group
            await loadGroups()
            selectedGroup = groups.first { $0.groupId == ticket.groupId.id }

            // Load queues for the group
            if selectedGroup != nil {
                await loadQueues()
                selectedQueue = queues.first { $0.queueId == ticket.queueId.id }

                // Set assigned user from family members
                selectedAssignedUser = familyMembers.first { $0.userId == ticket.assignedTo?.id }
            }
        } else {
            // For create mode, just load groups
            await loadGroups()
        }
    }

    @MainActor
    private func loadGroups() async {
        isLoadingGroups = true

        do {
            groups = try await groupService.getAllGroups(familyId: mode.familyId)
            print("✅ Loaded \(groups.count) groups")
        } catch {
            errorMessage = "Failed to load groups: \(error.localizedDescription)"
            print("❌ Error loading groups: \(error)")
        }

        isLoadingGroups = false
    }

    @MainActor
    private func loadQueues() async {
        guard let selectedGroup else { return }

        isLoadingQueues = true
        queues.removeAll()

        do {
            queues = try await queueService.getAllQueues(
                familyId: mode.familyId,
                groupId: selectedGroup.groupId
            )
            print("✅ Loaded \(queues.count) queues for group \(selectedGroup.groupName)")
        } catch {
            errorMessage = "Failed to load queues: \(error.localizedDescription)"
            print("❌ Error loading queues: \(error)")
        }

        isLoadingQueues = false
    }

    @MainActor
    private func loadFamilyMembers() async {
        isLoadingMembers = true
        familyMembers.removeAll()

        do {
            familyMembers = try await membershipService.getActiveFamilyMembers(familyId: mode.familyId)
            print("✅ Loaded \(familyMembers.count) active family members")
        } catch {
            errorMessage = "Failed to load family members: \(error.localizedDescription)"
            print("❌ Error loading family members: \(error)")
        }

        isLoadingMembers = false
    }

    // MARK: - Form Submission

    @MainActor
    private func submitForm() async {
        guard isFormValid else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            let ticket: Ticket = if case .create = mode {
                try await createTicket()
            } else {
                try await updateTicket()
            }

            // Call success callback and dismiss
            onSuccess(ticket)
            dismiss()

        } catch let error as NetworkError {
            handleNetworkError(error)
        } catch {
            errorMessage = "Failed to \(mode.isEditing ? "update" : "create") ticket: \(error.localizedDescription)"
            showError = true
            print("❌ Error \(mode.isEditing ? "updating" : "creating") ticket: \(error)")
        }

        isSubmitting = false
    }

    private func createTicket() async throws -> Ticket {
        guard let selectedGroup, let selectedQueue else {
            throw ValidationError.missingRequiredFields
        }

        let request = CreateTicketRequest(
            familyId: mode.familyId,
            groupId: selectedGroup.groupId,
            queueId: selectedQueue.queueId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            severity: selectedSeverity,
            description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            assignedTo: selectedAssignedUser?.userId
        )

        // Use TicketSession to create the ticket so cache management happens automatically
        let success = await ticketSession.createTicket(request: request)
        
        if !success {
            throw NetworkError.serverError(statusCode: 500, message: "Failed to create ticket")
        }
        
        // Get the newly created ticket from the cache (should be at index 0)
        if let newTicket = ticketSession.tickets.first {
            print("✅ Created ticket: \(newTicket.ticketId)")
            return newTicket
        } else {
            // Fallback: call the service directly if not found in cache
            let ticket = try await ticketService.createTicket(request: request)
            print("✅ Created ticket (fallback): \(ticket.ticketId)")
            return ticket
        }
    }

    private func updateTicket() async throws -> Ticket {
        guard case let .edit(originalTicket) = mode else {
            throw ValidationError.invalidOperation
        }

        let request = UpdateTicketRequest(
            ticketId: originalTicket.ticketId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            severity: selectedSeverity,
            status: selectedStatus,
            assignedTo: selectedAssignedUser?.userId
        )

        // Use TicketSession to update the ticket so cache invalidation happens automatically
        let success = await ticketSession.updateTicket(ticketId: originalTicket.ticketId, request: request)
        
        if !success {
            throw NetworkError.serverError(statusCode: 500, message: "Failed to update ticket")
        }
        
        // Get the updated ticket from the cache
        if let updatedTicket = ticketSession.tickets.first(where: { $0.ticketId == originalTicket.ticketId }) {
            print("✅ Updated ticket: \(updatedTicket.ticketId)")
            return updatedTicket
        } else {
            // Fallback: call the service directly if not found in cache
            let ticket = try await ticketService.updateTicket(request: request)
            print("✅ Updated ticket (fallback): \(ticket.ticketId)")
            return ticket
        }
    }

    // MARK: - Error Handling

    private func handleNetworkError(_ error: NetworkError) {
        switch error {
        case .unauthorized:
            errorMessage = "You are not authorized to perform this action"
        case let .serverError(statusCode, message):
            if statusCode == 400 {
                errorMessage = message ?? "Invalid input provided"
            } else if statusCode == 403 {
                errorMessage = "You don't have permission to perform this action"
            } else {
                errorMessage = message ?? "Server error occurred"
            }
        case .networkTimeout:
            errorMessage = "Request timed out. Please try again."
        case .noConnection:
            errorMessage = "No internet connection. Please check your network."
        case .decodingError:
            errorMessage = "Failed to process server response"
        default:
            errorMessage = "An error occurred: \(error.localizedDescription)"
        }
        showError = true
    }
}

// MARK: - Preview

#Preview("Create Mode") {
    NavigationStack {
        TicketFormView(
            mode: .create(familyId: "family123"),
            onSuccess: { ticket in
                print("Created ticket: \(ticket.title)")
            }
        )
    }
}

#Preview("Edit Mode") {
    NavigationStack {
        TicketFormView(
            mode: .edit(ticket: Ticket(
                familyId: EntityRef(id: "family123", name: "Test Family"),
                groupId: EntityRef(id: "group123", name: "Support"),
                queueId: EntityRef(id: "queue123", name: "General"),
                ticketId: "ticket123",
                title: "Sample Ticket",
                description: "This is a sample ticket description",
                severity: .sev2,
                status: .open,
                creationDate: Date().timeIntervalSince1970 - 3600,
                createdBy: EntityRef(id: "user123", name: "Alice Johnson"),
                lastUpdateTime: Date().timeIntervalSince1970,
                resolvedDate: nil,
                closedDate: nil,
                reopenUntil: nil,
                assignedTo: EntityRef(id: "user456", name: "John Doe"),
                isPrivate: false
            )),
            onSuccess: { ticket in
                print("Updated ticket: \(ticket.title)")
            }
        )
    }
}
