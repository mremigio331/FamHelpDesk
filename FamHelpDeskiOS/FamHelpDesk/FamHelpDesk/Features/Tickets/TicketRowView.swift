import SwiftUI

struct TicketRowView: View {
    let ticket: Ticket
    let isSelected: Bool
    let searchQuery: String?

    init(ticket: Ticket, isSelected: Bool = false, searchQuery: String? = nil) {
        self.ticket = ticket
        self.isSelected = isSelected
        self.searchQuery = searchQuery
    }

    var body: some View {
        HStack(spacing: 12) {
            // Severity number on the left
            Text(ticket.severity.displayNumber)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(severityColor)
                .frame(width: 40, alignment: .center)

            // Main content section
            VStack(alignment: .leading, spacing: 6) {
                // Title with search highlighting
                if let searchQuery, !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(highlightedTitle)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else {
                    Text(ticket.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                // Status badge under title
                HStack {
                    statusBadge
                    Spacer()
                }

                // Assignment information
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Group:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ticket.groupId.name ?? ticket.groupId.id)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }

                    HStack {
                        Text("Queue:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ticket.queueId.name ?? ticket.queueId.id)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }

                    if let assignedTo = ticket.assignedTo {
                        HStack {
                            Text("Assigned:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(assignedTo.name ?? assignedTo.id)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Creation time
                HStack {
                    Text(relativeTimeString)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Severity Color

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

    // MARK: - Status Badge

    private var statusBadge: some View {
        Text(ticket.status.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusBackgroundColor)
            .foregroundColor(statusTextColor)
            .cornerRadius(8)
    }

    private var statusBackgroundColor: Color {
        switch ticket.status {
        case .open:
            severityColor.opacity(0.2)
        case .resolved:
            .gray.opacity(0.2)
        case .closed:
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

    // MARK: - Time Formatting

    private var relativeTimeString: String {
        let date = Date(timeIntervalSince1970: ticket.creationDate)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Search Highlighting

    private var highlightedTitle: AttributedString {
        guard let searchQuery = searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines),
              !searchQuery.isEmpty
        else {
            return AttributedString(ticket.title)
        }

        var attributedString = AttributedString(ticket.title)

        // Find all occurrences of the search query (case-insensitive)
        let lowercaseTitle = ticket.title.lowercased()
        let lowercaseQuery = searchQuery.lowercased()

        var searchRange = lowercaseTitle.startIndex

        while let range = lowercaseTitle.range(of: lowercaseQuery, range: searchRange ..< lowercaseTitle.endIndex) {
            // Convert String.Index to AttributedString.Index
            let startIndex = AttributedString.Index(range.lowerBound, within: attributedString)
            let endIndex = AttributedString.Index(range.upperBound, within: attributedString)

            if let startIndex, let endIndex {
                attributedString[startIndex ..< endIndex].backgroundColor = Color.yellow
                attributedString[startIndex ..< endIndex].foregroundColor = Color.black
            }

            searchRange = range.upperBound
        }

        return attributedString
    }
}

// MARK: - Preview

#Preview {
    List {
        TicketRowView(
            ticket: Ticket(
                familyId: EntityRef(id: "family123", name: "Test Family"),
                groupId: EntityRef(id: "group123", name: "General"),
                queueId: EntityRef(id: "queue123", name: "Support"),
                ticketId: "ticket123",
                title: "Critical Priority Ticket - System Down",
                description: "This is a critical severity ticket",
                severity: .sev1,
                status: .open,
                creationDate: Date().timeIntervalSince1970 - 3600, // 1 hour ago
                createdBy: EntityRef(id: "user123", name: "Test User"),
                lastUpdateTime: Date().timeIntervalSince1970,
                resolvedDate: nil,
                closedDate: nil,
                reopenUntil: nil,
                assignedTo: EntityRef(id: "user456", name: "John Doe"),
                isPrivate: false
            )
        )

        TicketRowView(
            ticket: Ticket(
                familyId: EntityRef(id: "family123", name: "Test Family"),
                groupId: EntityRef(id: "group123", name: "Development"),
                queueId: EntityRef(id: "queue124", name: "Bug Reports"),
                ticketId: "ticket124",
                title: "High Priority Bug - Login Issues",
                description: "This is a high severity ticket",
                severity: .sev2_5,
                status: .open,
                creationDate: Date().timeIntervalSince1970 - 7200, // 2 hours ago
                createdBy: EntityRef(id: "user123", name: "Test User"),
                lastUpdateTime: Date().timeIntervalSince1970,
                resolvedDate: nil,
                closedDate: nil,
                reopenUntil: nil,
                assignedTo: EntityRef(id: "user789", name: "Jane Smith"),
                isPrivate: false
            )
        )

        TicketRowView(
            ticket: Ticket(
                familyId: EntityRef(id: "family123", name: "Test Family"),
                groupId: EntityRef(id: "group123", name: "Operations"),
                queueId: EntityRef(id: "queue125", name: "Maintenance"),
                ticketId: "ticket125",
                title: "Medium Priority - Scheduled Maintenance Window",
                description: "This is a medium severity ticket",
                severity: .sev3,
                status: .open,
                creationDate: Date().timeIntervalSince1970 - 10800, // 3 hours ago
                createdBy: EntityRef(id: "user123", name: "Test User"),
                lastUpdateTime: Date().timeIntervalSince1970,
                resolvedDate: nil,
                closedDate: nil,
                reopenUntil: nil,
                assignedTo: nil,
                isPrivate: false
            )
        )

        TicketRowView(
            ticket: Ticket(
                familyId: EntityRef(id: "family123", name: "Test Family"),
                groupId: EntityRef(id: "group123", name: "Support"),
                queueId: EntityRef(id: "queue126", name: "General"),
                ticketId: "ticket126",
                title: "Low Priority - Feature Request",
                description: "This is a low severity ticket",
                severity: .sev5,
                status: .open,
                creationDate: Date().timeIntervalSince1970 - 14400, // 4 hours ago
                createdBy: EntityRef(id: "user123", name: "Test User"),
                lastUpdateTime: Date().timeIntervalSince1970,
                resolvedDate: nil,
                closedDate: nil,
                reopenUntil: nil,
                assignedTo: EntityRef(id: "user101", name: "Bob Wilson"),
                isPrivate: false
            )
        )

        TicketRowView(
            ticket: Ticket(
                familyId: EntityRef(id: "family123", name: "Test Family"),
                groupId: EntityRef(id: "group123", name: "Support"),
                queueId: EntityRef(id: "queue127", name: "Resolved"),
                ticketId: "ticket127",
                title: "Resolved Ticket - Shows Grey Styling",
                description: "This is a resolved ticket",
                severity: .sev1, // High severity but resolved, should show grey
                status: .resolved,
                creationDate: Date().timeIntervalSince1970 - 86400, // 1 day ago
                createdBy: EntityRef(id: "user123", name: "Test User"),
                lastUpdateTime: Date().timeIntervalSince1970,
                resolvedDate: Date().timeIntervalSince1970 - 3600,
                closedDate: nil,
                reopenUntil: Date().timeIntervalSince1970 + 86400,
                assignedTo: nil,
                isPrivate: false
            )
        )
    }
}
