import Foundation

final class TicketService {
    private let networkManager: NetworkManager
    private let retryHelper = RetryHelper()

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    // MARK: - Ticket CRUD Operations

    /// Search tickets with pagination support and multiple filter options
    func searchTickets(
        familyId: String,
        queueIds: [String]? = nil,
        groupIds: [String]? = nil,
        assignedToUsers: [String]? = nil,
        statuses: [String]? = nil,
        severities: [Double]? = nil,
        limit: Int = 25,
        nextToken: String? = nil
    ) async throws -> PaginatedTickets {
        let request = SearchTicketsRequest(
            queueIds: queueIds,
            groupIds: groupIds,
            assignedToUsers: assignedToUsers,
            statuses: statuses,
            severities: severities,
            limit: limit,
            nextToken: nextToken
        )

        do {
            let response: GetTicketsResponse = try await networkManager.post(
                endpoint: APIEndpoint.searchTickets(familyId: familyId).path,
                body: request
            )

            return PaginatedTickets(
                tickets: response.tickets,
                nextToken: response.nextToken
            )
        } catch {
            throw error
        }
    }

    /// Get tickets with pagination support and multiple filter options (legacy method)
    /// Use searchTickets for new implementations
    func getTickets(
        familyId: String,
        queueId: String? = nil,
        groupId: String? = nil,
        assignedTo: String? = nil,
        status: String? = nil,
        severities: [Double]? = nil,
        limit: Int = 25,
        nextToken: String? = nil
    ) async throws -> PaginatedTickets {
        // Convert single values to arrays for the new search method
        try await searchTickets(
            familyId: familyId,
            queueIds: queueId != nil ? [queueId!] : nil,
            groupIds: groupId != nil ? [groupId!] : nil,
            assignedToUsers: assignedTo != nil ? [assignedTo!] : nil,
            statuses: status != nil ? [status!] : nil,
            severities: severities,
            limit: limit,
            nextToken: nextToken
        )
    }

    /// Get a single ticket by family ID and ticket ID
    func getTicket(familyId: String, ticketId: String) async throws -> Ticket {
        do {
            let response: GetTicketResponse = try await networkManager.get(
                endpoint: APIEndpoint.getTicket(familyId: familyId, ticketId: ticketId).path
            )
            return response.ticket
        } catch {
            throw error
        }
    }

    /// Get a single ticket by ticket ID only (using GSI)
    func getTicketById(ticketId: String) async throws -> Ticket {
        do {
            let response: GetTicketResponse = try await networkManager.get(
                endpoint: APIEndpoint.getTicketById(ticketId: ticketId).path
            )
            return response.ticket
        } catch {
            throw error
        }
    }

    /// Create a new ticket
    func createTicket(request: CreateTicketRequest) async throws -> Ticket {
        do {
            let response: CreateTicketResponse = try await networkManager.post(
                endpoint: APIEndpoint.createTicket.path,
                body: request
            )
            return response.ticket
        } catch {
            throw error
        }
    }

    /// Update an existing ticket
    func updateTicket(request: UpdateTicketRequest) async throws -> Ticket {
        print("🔍 UpdateTicketRequest being sent:")

        do {
            let response: UpdateTicketResponse = try await networkManager.put(
                endpoint: APIEndpoint.updateTicket.path,
                body: request
            )

            // Debug: Print what we got back
            print("🔍 UpdateTicketResponse received:")
            print("   - ticketId: \(response.ticket.ticketId)")
            print("   - groupId: \(response.ticket.groupId.id) (\(response.ticket.groupId.name ?? "no name"))")
            print("   - queueId: \(response.ticket.queueId.id) (\(response.ticket.queueId.name ?? "no name"))")

            return response.ticket
        } catch {
            throw error
        }
    }

    // MARK: - Comment CRUD Operations

    /// Get all comments for a ticket
    func getComments(ticketId: String) async throws -> [Comment] {
        let queryItems = [
            URLQueryItem(name: "ticket_id", value: ticketId),
        ]

        do {
            let response: GetCommentsResponse = try await networkManager.get(
                endpoint: APIEndpoint.getComments.path,
                queryItems: queryItems
            )
            return response.comments
        } catch {
            throw error
        }
    }

    /// Create a new comment on a ticket
    func createComment(request: CreateCommentRequest) async throws -> Comment {
        do {
            let response: CreateCommentResponse = try await networkManager.post(
                endpoint: APIEndpoint.createComment.path,
                body: request
            )
            return response.comment
        } catch {
            throw error
        }
    }

    /// Update an existing comment
    func updateComment(request: UpdateCommentRequest) async throws -> Comment {
        do {
            let response: UpdateCommentResponse = try await networkManager.put(
                endpoint: APIEndpoint.updateComment.path,
                body: request
            )
            return response.comment
        } catch {
            throw error
        }
    }

    /// Delete a comment
    func deleteComment(ticketId: String, commentId: String) async throws -> DeleteCommentResponse {
        // Build endpoint with query parameters
        let endpoint = "\(APIEndpoint.deleteComment.path)?ticket_id=\(ticketId)&comment_id=\(commentId)"

        do {
            let response: DeleteCommentResponse = try await networkManager.delete(
                endpoint: endpoint
            )
            return response
        } catch {
            throw error
        }
    }
}

// MARK: - Response Models

struct SearchTicketsRequest: Codable {
    let queueIds: [String]?
    let groupIds: [String]?
    let assignedToUsers: [String]?
    let statuses: [String]?
    let severities: [Double]?
    let limit: Int
    let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case queueIds = "queue_ids"
        case groupIds = "group_ids"
        case assignedToUsers = "assigned_to_users"
        case statuses
        case severities
        case limit
        case nextToken = "next_token"
    }
}

struct GetTicketResponse: Codable {
    let ticket: Ticket
}
