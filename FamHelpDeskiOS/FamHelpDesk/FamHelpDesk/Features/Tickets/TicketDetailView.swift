import SwiftUI

struct TicketDetailView: View {
    @State private var ticket: Ticket

    @State private var comments: [Comment] = []
    @State private var isLoadingComments = false
    @State private var commentsError: String?
    @State private var newCommentText = ""
    @State private var isSubmittingComment = false
    @State private var editingComment: Comment?
    @State private var editCommentText = ""
    @State private var showDeleteConfirmation = false
    @State private var commentToDelete: Comment?
    @State private var navigationBarVisible = true

    // Error handling states
    @State private var commentError: String?
    @State private var showCommentError = false
    @State private var editCommentError: String?
    @State private var showEditCommentError = false
    @State private var resolveError: String?
    @State private var showResolveError = false
    @State private var isResolvingTicket = false
    @State private var showResolveSuccess = false
    @State private var resolveSuccessMessage = ""

    // Edit ticket state
    @State private var showEditTicket = false

    // Navigation
    @Environment(\.dismiss) private var dismiss

    private let ticketService = TicketService()

    // MARK: - Initialization

    init(ticket: Ticket) {
        _ticket = State(initialValue: ticket)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation toolbar with back and edit buttons
            HStack {
                HStack {
                    NavigationToolbar(title: "Ticket Details", customBackAction: {
                        dismiss()
                    })
                }

                Spacer()

                // Action buttons
                HStack(spacing: 12) {
                    // Quick resolve button (only for open tickets)
                    if ticket.status == .open {
                        Button(action: {
                            Task {
                                await resolveTicket()
                            }
                        }) {
                            HStack(spacing: 4) {
                                if isResolvingTicket {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle")
                                }
                                Text("Resolve")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isResolvingTicket)
                    }

                    // Quick reopen button (only for resolved tickets within reopen window)
                    if ticket.status == .resolved, ticket.canReopen {
                        Button(action: {
                            Task {
                                await reopenTicket()
                            }
                        }) {
                            HStack(spacing: 4) {
                                if isResolvingTicket {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.counterclockwise")
                                }
                                Text("Reopen")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isResolvingTicket)
                    }

                    // Edit button
                    Button("Edit") {
                        showEditTicket = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.trailing)
            }
            .frame(height: 44) // Standard navigation bar height

            // Main content
            CollapsibleScrollView(navigationBarVisible: $navigationBarVisible) {
                VStack(spacing: 0) {
                    // Ticket details section
                    ticketDetailsSection

                    // Comments section
                    commentsSection
                }
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .top) {
            // Success toast for resolve action
            if showResolveSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(resolveSuccessMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, 60) // Account for navigation area
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: showResolveSuccess)
            }
        }
        .task {
            await loadComments()
        }
        .sheet(isPresented: $showEditTicket) {
            TicketFormView(
                mode: .edit(ticket: ticket),
                onSuccess: { updatedTicket in
                    ticket = updatedTicket
                }
            )
        }
        .alert("Delete Comment", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let comment = commentToDelete {
                    Task {
                        await deleteComment(comment)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this comment? This action cannot be undone.")
        }
        .alert("Comment Error", isPresented: $showCommentError) {
            Button("OK") {}
        } message: {
            Text(commentError ?? "An error occurred with your comment.")
        }
        .alert("Edit Error", isPresented: $showEditCommentError) {
            Button("OK") {}
        } message: {
            Text(editCommentError ?? "An error occurred while editing your comment.")
        }
        .alert("Resolve Error", isPresented: $showResolveError) {
            Button("OK") {}
        } message: {
            Text(resolveError ?? "An error occurred while resolving the ticket.")
        }
    }

    // MARK: - Ticket Details Section

    private var ticketDetailsSection: some View {
        VStack(spacing: 0) {
            // Ticket header with severity indicator
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    // Severity indicator
                    Text(ticket.severity.displayNumber)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(severityColor)
                        .frame(width: 50, height: 50)
                        .background(severityColor.opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 8) {
                        // Title
                        Text(ticket.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        // Status badge
                        statusBadge
                    }

                    Spacer()
                }

                // Description
                if let description = ticket.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                }
            }
            .padding()
            .background(Color(uiColor: .systemBackground))

            // Ticket properties
            List {
                Section("Ticket Information") {
                    DetailRow(label: "Ticket ID", value: ticket.ticketId)
                    DetailRow(label: "Status", value: ticket.status.rawValue)
                    DetailRow(label: "Severity", value: ticket.severity.displayName)
                    DetailRow(label: "Created", value: formatDate(ticket.creationDate))
                    DetailRow(label: "Last Updated", value: formatDate(ticket.lastUpdateTime))

                    if let resolvedDate = ticket.resolvedDate {
                        DetailRow(label: "Resolved", value: formatDate(resolvedDate))
                    }

                    if let closedDate = ticket.closedDate {
                        DetailRow(label: "Closed", value: formatDate(closedDate))
                    }
                }

                Section("Assignment") {
                    DetailRow(label: "Group", value: ticket.groupId.name ?? ticket.groupId.id)
                    DetailRow(label: "Queue", value: ticket.queueId.name ?? ticket.queueId.id)

                    if let assignedTo = ticket.assignedTo {
                        DetailRow(label: "Assigned To", value: assignedTo.name ?? assignedTo.id)
                    } else {
                        DetailRow(label: "Assigned To", value: "Unassigned")
                    }

                    DetailRow(label: "Created By", value: ticket.createdByDisplayName)
                }

                if ticket.canReopen {
                    Section("Reopen Window") {
                        if let reopenUntil = ticket.reopenUntil {
                            DetailRow(label: "Can Reopen Until", value: formatDate(reopenUntil))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .frame(height: 400) // Fixed height for ticket details
        }
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(spacing: 0) {
            // Comments header
            HStack {
                Text("Comments")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if isLoadingComments {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemBackground))

            if let error = commentsError {
                // Error state
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)

                    Text("Failed to load comments")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Retry") {
                        Task {
                            await loadComments()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .systemBackground))

            } else if comments.isEmpty, !isLoadingComments {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text("No Comments")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Be the first to add a comment to this ticket.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .systemBackground))

            } else {
                // Comments list
                LazyVStack(spacing: 0) {
                    ForEach(comments.sorted(by: { $0.commentDate < $1.commentDate })) { comment in
                        CommentRowView(
                            comment: comment,
                            isEditing: editingComment?.commentId == comment.commentId,
                            editText: $editCommentText,
                            onEdit: { startEditingComment(comment) },
                            onSaveEdit: { await saveCommentEdit(comment) },
                            onCancelEdit: { cancelEditingComment() },
                            onDelete: { confirmDeleteComment(comment) }
                        )
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        Divider()
                            .padding(.leading)
                    }
                }
                .background(Color(uiColor: .systemBackground))
            }

            // New comment input
            newCommentInputSection
        }
    }

    // MARK: - New Comment Input

    private var newCommentInputSection: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 12) {
                HStack {
                    Text("Add Comment")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    // Character count indicator
                    let characterCount = newCommentText.count
                    let maxCharacters = 2000 // Reasonable limit for comments
                    Text("\(characterCount)/\(maxCharacters)")
                        .font(.caption)
                        .foregroundColor(characterCount > maxCharacters ? .red : .secondary)
                }

                TextField("Enter your comment...", text: $newCommentText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3 ... 6)

                // Validation message
                if !isCommentValid, !newCommentText.isEmpty {
                    Text(commentValidationMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }

                HStack {
                    Spacer()

                    Button("Post Comment") {
                        Task {
                            await submitComment()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isCommentValid || isSubmittingComment)

                    if isSubmittingComment {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
        }
    }

    // MARK: - Computed Properties

    // Comment validation
    private var isCommentValid: Bool {
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 2000
    }

    private var commentValidationMessage: String {
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Comment cannot be empty"
        } else if trimmed.count > 2000 {
            return "Comment is too long (maximum 2000 characters)"
        }
        return ""
    }

    private var severityColor: Color {
        // For resolved/closed tickets, always show grey regardless of severity
        if ticket.status == .resolved || ticket.status == .closed {
            return .gray
        }

        // For open tickets, use severity color coding
        switch ticket.severity {
        case .sev1:
            return .red
        case .sev2, .sev2_5:
            return .orange
        case .sev3:
            return .yellow
        case .sev4, .sev5:
            return .green
        }
    }

    private var statusBadge: some View {
        Text(ticket.status.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusBackgroundColor)
            .foregroundColor(statusTextColor)
            .cornerRadius(12)
    }

    private var statusBackgroundColor: Color {
        switch ticket.status {
        case .open:
            severityColor.opacity(0.2)
        case .resolved, .closed:
            .gray.opacity(0.2)
        }
    }

    private var statusTextColor: Color {
        switch ticket.status {
        case .open:
            severityColor
        case .resolved, .closed:
            .gray
        }
    }

    // MARK: - Helper Methods

    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Comment Operations

    @MainActor
    private func loadComments() async {
        isLoadingComments = true
        commentsError = nil

        do {
            comments = try await ticketService.getComments(
                ticketId: ticket.ticketId
            )
            print("✅ Loaded \(comments.count) comments for ticket \(ticket.ticketId)")
        } catch {
            commentsError = error.localizedDescription
            print("❌ Error loading comments: \(error)")
        }

        isLoadingComments = false
    }

    @MainActor
    private func submitComment() async {
        let commentText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate comment before submission
        guard !commentText.isEmpty else {
            commentError = "Comment cannot be empty"
            showCommentError = true
            return
        }

        guard commentText.count <= 2000 else {
            commentError = "Comment is too long (maximum 2000 characters)"
            showCommentError = true
            return
        }

        isSubmittingComment = true
        commentError = nil

        do {
            let request = CreateCommentRequest(
                ticketId: ticket.ticketId,
                body: commentText
            )

            let newComment = try await ticketService.createComment(request: request)

            // Add comment to list and clear input on success
            comments.append(newComment)
            newCommentText = ""

            // Invalidate ticket cache to refresh last_update_time and other changes
            await TicketSession.shared.invalidateTickets()

            print("✅ Created comment: \(newComment.commentId)")
        } catch let error as NetworkError {
            handleCommentError(error)
        } catch {
            commentError = "Failed to create comment: \(error.localizedDescription)"
            showCommentError = true
            print("❌ Error creating comment: \(error)")
        }

        isSubmittingComment = false
    }

    private func startEditingComment(_ comment: Comment) {
        editingComment = comment
        editCommentText = comment.commentBody
    }

    private func cancelEditingComment() {
        editingComment = nil
        editCommentText = ""
    }

    @MainActor
    private func saveCommentEdit(_ comment: Comment) async {
        let updatedText = editCommentText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate edited comment
        guard !updatedText.isEmpty else {
            editCommentError = "Comment cannot be empty"
            showEditCommentError = true
            return
        }

        guard updatedText.count <= 2000 else {
            editCommentError = "Comment is too long (maximum 2000 characters)"
            showEditCommentError = true
            return
        }

        // Check if comment is still within edit window
        guard comment.canEdit(currentUserId: UserSession.shared.currentUser?.userId ?? "") else {
            editCommentError = "Edit window has expired for this comment"
            showEditCommentError = true
            cancelEditingComment()
            return
        }

        editCommentError = nil

        do {
            let request = UpdateCommentRequest(
                ticketId: ticket.ticketId,
                commentId: comment.commentId,
                body: updatedText
            )
            let updatedComment = try await ticketService.updateComment(request: request)

            // Update the comment in the list
            if let index = comments.firstIndex(where: { $0.commentId == comment.commentId }) {
                comments[index] = updatedComment
            }

            // Invalidate ticket cache to refresh last_update_time
            await TicketSession.shared.invalidateTickets()

            cancelEditingComment()
            print("✅ Updated comment: \(comment.commentId)")
        } catch let error as NetworkError {
            handleEditCommentError(error)
        } catch {
            editCommentError = "Failed to update comment: \(error.localizedDescription)"
            showEditCommentError = true
            print("❌ Error updating comment: \(error)")
        }
    }

    private func confirmDeleteComment(_ comment: Comment) {
        commentToDelete = comment
        showDeleteConfirmation = true
    }

    @MainActor
    private func deleteComment(_ comment: Comment) async {
        // Check if comment can still be deleted
        guard comment.canDelete(currentUserId: UserSession.shared.currentUser?.userId ?? "") else {
            commentError = "Delete window has expired for this comment"
            showCommentError = true
            commentToDelete = nil
            return
        }

        do {
            _ = try await ticketService.deleteComment(
                ticketId: ticket.ticketId,
                commentId: comment.commentId
            )

            // Remove the comment from the list
            comments.removeAll { $0.commentId == comment.commentId }

            // Invalidate ticket cache to refresh last_update_time
            await TicketSession.shared.invalidateTickets()

            print("✅ Deleted comment: \(comment.commentId)")
        } catch let error as NetworkError {
            handleCommentError(error)
        } catch {
            commentError = "Failed to delete comment: \(error.localizedDescription)"
            showCommentError = true
            print("❌ Error deleting comment: \(error)")
        }

        commentToDelete = nil
    }

    // MARK: - Ticket Operations

    @MainActor
    private func resolveTicket() async {
        isResolvingTicket = true
        resolveError = nil

        do {
            let request = UpdateTicketRequest(
                ticketId: ticket.ticketId,
                title: nil,
                description: nil,
                severity: nil,
                status: .resolved,
                assignedTo: nil
            )

            let updatedTicket = try await ticketService.updateTicket(request: request)

            // Update the local ticket state
            ticket = updatedTicket

            // Update the ticket in cache (TicketSession.updateTicket would handle this, but we're calling service directly)
            TicketSession.shared.updateTicketInCache(updatedTicket)
            await TicketSession.shared.invalidateTickets()

            // Show success feedback
            resolveSuccessMessage = "Ticket resolved successfully"
            showResolveSuccess = true

            // Hide success message after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showResolveSuccess = false
            }

            print("✅ Resolved ticket: \(ticket.ticketId)")
        } catch let error as NetworkError {
            handleResolveError(error)
        } catch {
            resolveError = "Failed to resolve ticket: \(error.localizedDescription)"
            showResolveError = true
            print("❌ Error resolving ticket: \(error)")
        }

        isResolvingTicket = false
    }

    @MainActor
    private func reopenTicket() async {
        isResolvingTicket = true
        resolveError = nil

        do {
            let request = UpdateTicketRequest(
                ticketId: ticket.ticketId,
                title: nil,
                description: nil,
                severity: nil,
                status: .open,
                assignedTo: nil
            )

            let updatedTicket = try await ticketService.updateTicket(request: request)

            // Update the local ticket state
            ticket = updatedTicket

            // Update the ticket in cache (TicketSession.updateTicket would handle this, but we're calling service directly)
            TicketSession.shared.updateTicketInCache(updatedTicket)
            await TicketSession.shared.invalidateTickets()

            // Show success feedback
            resolveSuccessMessage = "Ticket reopened successfully"
            showResolveSuccess = true

            // Hide success message after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showResolveSuccess = false
            }

            print("✅ Reopened ticket: \(ticket.ticketId)")
        } catch let error as NetworkError {
            handleResolveError(error)
        } catch {
            resolveError = "Failed to reopen ticket: \(error.localizedDescription)"
            showResolveError = true
            print("❌ Error reopening ticket: \(error)")
        }

        isResolvingTicket = false
    }

    // MARK: - Error Handling

    private func handleCommentError(_ error: NetworkError) {
        switch error {
        case .unauthorized:
            commentError = "You are not authorized to perform this action"
        case let .serverError(statusCode, message):
            if statusCode == 403 {
                commentError = "You don't have permission to perform this action"
            } else {
                commentError = message ?? "Server error occurred"
            }
        case .networkTimeout:
            commentError = "Request timed out. Please try again."
        case .noConnection:
            commentError = "No internet connection. Please check your network."
        default:
            commentError = "An error occurred: \(error.localizedDescription)"
        }
        showCommentError = true
    }

    private func handleEditCommentError(_ error: NetworkError) {
        switch error {
        case .unauthorized:
            editCommentError = "You are not authorized to edit this comment"
        case let .serverError(statusCode, message):
            if statusCode == 403 {
                editCommentError = "You don't have permission to edit this comment"
            } else if statusCode == 400 {
                editCommentError = "Edit window has expired for this comment"
            } else {
                editCommentError = message ?? "Server error occurred"
            }
        case .networkTimeout:
            editCommentError = "Request timed out. Please try again."
        case .noConnection:
            editCommentError = "No internet connection. Please check your network."
        default:
            editCommentError = "An error occurred: \(error.localizedDescription)"
        }
        showEditCommentError = true
    }

    private func handleResolveError(_ error: NetworkError) {
        switch error {
        case .unauthorized:
            resolveError = "You are not authorized to perform this action on this ticket"
        case let .serverError(statusCode, message):
            if statusCode == 403 {
                resolveError = "You don't have permission to perform this action on this ticket"
            } else if statusCode == 400 {
                resolveError = "This ticket cannot be updated in its current state"
            } else {
                resolveError = message ?? "Server error occurred"
            }
        case .networkTimeout:
            resolveError = "Request timed out. Please try again."
        case .noConnection:
            resolveError = "No internet connection. Please check your network."
        default:
            resolveError = "An error occurred: \(error.localizedDescription)"
        }
        showResolveError = true
    }
}

// MARK: - Comment Row View

struct CommentRowView: View {
    let comment: Comment
    let isEditing: Bool
    @Binding var editText: String
    let onEdit: () -> Void
    let onSaveEdit: () async -> Void
    let onCancelEdit: () -> Void
    let onDelete: () -> Void

    @State private var userSession = UserSession.shared

    private var currentUserId: String {
        userSession.currentUser?.userId ?? ""
    }

    // Edit validation
    private var isEditTextValid: Bool {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 2000
    }

    private var editValidationMessage: String {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Comment cannot be empty"
        } else if trimmed.count > 2000 {
            return "Comment is too long (maximum 2000 characters)"
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Comment header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.authorDisplayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Text(comment.relativeTimeString)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if comment.wasEdited {
                            Text("• edited")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Edit/Delete buttons
                if comment.canEdit(currentUserId: currentUserId) || comment.canDelete(currentUserId: currentUserId) {
                    Menu {
                        if comment.canEdit(currentUserId: currentUserId) {
                            Button("Edit", systemImage: "pencil") {
                                onEdit()
                            }
                        }

                        if comment.canDelete(currentUserId: currentUserId) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                onDelete()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                }
            }

            // Comment content
            if isEditing {
                // Edit mode
                VStack(spacing: 8) {
                    TextField("Edit comment...", text: $editText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3 ... 6)

                    // Character count and validation for edit mode
                    HStack {
                        let characterCount = editText.count
                        let maxCharacters = 2000
                        Text("\(characterCount)/\(maxCharacters)")
                            .font(.caption2)
                            .foregroundColor(characterCount > maxCharacters ? .red : .secondary)

                        Spacer()

                        if let timeRemaining = comment.editWindowStatusText {
                            Text(timeRemaining)
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }

                    // Validation message for edit mode
                    if !isEditTextValid, !editText.isEmpty {
                        Text(editValidationMessage)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }

                    HStack {
                        Spacer()

                        Button("Cancel") {
                            onCancelEdit()
                        }
                        .buttonStyle(.bordered)

                        Button("Save") {
                            Task {
                                await onSaveEdit()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isEditTextValid)
                    }
                }
            } else {
                // Display mode
                Text(comment.commentBody)
                    .font(.body)
                    .foregroundColor(.primary)

                // Edit window status for user's own comments
                if comment.commentUser.id == currentUserId,
                   let statusText = comment.editWindowStatusText
                {
                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

// MARK: - Detail Row Helper

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TicketDetailView(
            ticket: Ticket(
                familyId: EntityRef(id: "family123", name: "Test Family"),
                groupId: EntityRef(id: "group123", name: "Support"),
                queueId: EntityRef(id: "queue123", name: "General"),
                ticketId: "ticket123",
                title: "Sample Ticket Title That Might Be Long",
                description: "This is a detailed description of the ticket that explains the issue or request in detail. It can be quite long and should wrap properly in the UI.",
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
            )
        )
    }
}

#Preview("Resolved Ticket") {
    NavigationStack {
        TicketDetailView(
            ticket: Ticket(
                familyId: EntityRef(id: "family123", name: "Test Family"),
                groupId: EntityRef(id: "group123", name: "Support"),
                queueId: EntityRef(id: "queue123", name: "General"),
                ticketId: "ticket124",
                title: "Resolved Ticket Example",
                description: "This ticket has been resolved and should show grey styling.",
                severity: .sev1, // High severity but resolved
                status: .resolved,
                creationDate: Date().timeIntervalSince1970 - 86400,
                createdBy: EntityRef(id: "user123", name: "Bob Wilson"),
                lastUpdateTime: Date().timeIntervalSince1970 - 3600,
                resolvedDate: Date().timeIntervalSince1970 - 3600,
                closedDate: nil,
                reopenUntil: Date().timeIntervalSince1970 + 86400,
                assignedTo: EntityRef(id: "user456", name: "Jane Smith"),
                isPrivate: false
            )
        )
    }
}
