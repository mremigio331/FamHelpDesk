import Foundation

final class TicketService {
    private let networkManager: NetworkManager
    private let retryHelper = RetryHelper()

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    // MARK: - Ticket CRUD Operations

    /// Get tickets with pagination support and multiple filter options
    func getTickets(
        familyId: String,
        queueId: String? = nil,
        groupId: String? = nil,
        assignedTo: String? = nil,
        status: String? = nil,
        severity: String? = nil,
        limit: Int = 25,
        nextToken: String? = nil
    ) async throws -> PaginatedTickets {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        // Add filter parameters if provided
        if let queueId {
            queryItems.append(URLQueryItem(name: "queue_id", value: queueId))
        }
        if let groupId {
            queryItems.append(URLQueryItem(name: "group_id", value: groupId))
        }
        if let assignedTo {
            queryItems.append(URLQueryItem(name: "assigned_to", value: assignedTo))
        }
        if let status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if let severity {
            queryItems.append(URLQueryItem(name: "severity", value: severity))
        }
        if let nextToken {
            queryItems.append(URLQueryItem(name: "next_token", value: nextToken))
        }

        do {
            // First, let's get the raw data to see what we're receiving
            let rawData = try await networkManager.getRawData(
                endpoint: APIEndpoint.getTickets(familyId: familyId).path,
                queryItems: queryItems
            )

            // Now try to decode it
            let decoder = JSONDecoder()
            let response = try decoder.decode(GetTicketsResponse.self, from: rawData)

            return PaginatedTickets(
                tickets: response.tickets,
                nextToken: response.nextToken
            )
        } catch {
            throw error
        }
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
    func updateTicket(familyId: String, ticketId: String, request: UpdateTicketRequest) async throws -> Ticket {
        do {
            let response: UpdateTicketResponse = try await networkManager.put(
                endpoint: APIEndpoint.updateTicket(familyId: familyId, ticketId: ticketId).path,
                body: request
            )
            return response.ticket
        } catch {
            throw error
        }
    }

    // MARK: - Comment CRUD Operations

    /// Get all comments for a ticket
    func getComments(familyId: String, ticketId: String) async throws -> [Comment] {
        let queryItems = [
            URLQueryItem(name: "family_id", value: familyId),
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
    func updateComment(commentId: String, request: UpdateCommentRequest) async throws -> Comment {
        do {
            let response: UpdateCommentResponse = try await networkManager.put(
                endpoint: APIEndpoint.updateComment(commentId: commentId).path,
                body: request
            )
            return response.comment
        } catch {
            throw error
        }
    }

    /// Delete a comment
    func deleteComment(commentId: String) async throws -> DeleteCommentResponse {
        do {
            let response: DeleteCommentResponse = try await networkManager.delete(
                endpoint: APIEndpoint.deleteComment(commentId: commentId).path
            )
            return response
        } catch {
            throw error
        }
    }
}

// MARK: - Response Models

struct GetTicketResponse: Codable {
    let ticket: Ticket
}
