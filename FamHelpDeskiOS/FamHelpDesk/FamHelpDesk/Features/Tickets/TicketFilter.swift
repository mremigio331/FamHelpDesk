import Foundation

/// Provides filtering logic for queue-specific ticket displays
enum TicketFilter {
    /// Filter tickets by both group_id and queue_id
    /// - Parameters:
    ///   - tickets: The array of tickets to filter
    ///   - groupId: The group ID to filter by
    ///   - queueId: The queue ID to filter by
    /// - Returns: An array of tickets that match both the group_id and queue_id
    static func filterTickets(
        tickets: [Ticket],
        groupId: String,
        queueId: String
    ) -> [Ticket] {
        tickets.filter { ticket in
            ticket.groupId.id == groupId && ticket.queueId.id == queueId
        }
    }

    /// Count tickets for a specific queue
    /// - Parameters:
    ///   - tickets: The array of tickets to count
    ///   - groupId: The group ID to filter by
    ///   - queueId: The queue ID to filter by
    /// - Returns: The count of tickets that match both the group_id and queue_id
    static func countTickets(
        tickets: [Ticket],
        groupId: String,
        queueId: String
    ) -> Int {
        filterTickets(tickets: tickets, groupId: groupId, queueId: queueId).count
    }
}
