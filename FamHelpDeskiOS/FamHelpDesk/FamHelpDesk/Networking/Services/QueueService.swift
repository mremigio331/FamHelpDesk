import Foundation

final class QueueService {
    private let networkManager: NetworkManager
    private let retryHelper = RetryHelper()

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    // MARK: - Queue CRUD Operations

    /// Fetches all queues for a family or specific group with enhanced error handling
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: Optional group ID to filter queues by group
    /// - Returns: Array of Queue objects
    /// - Throws: ServiceError with structured error information
    func getAllQueues(familyId: String, groupId: String? = nil) async throws -> [Queue] {
        do {
            // Use custom decoder without convertFromSnakeCase since we have manual CodingKeys
            let rawData = try await networkManager.getRawData(
                endpoint: APIEndpoint.getAllQueues(familyId: familyId, groupId: groupId).path
            )

            let decoder = JSONDecoder()
            let response = try decoder.decode(GetAllQueuesResponse.self, from: rawData)

            print("📱 All Queues Response: \(response.queues.count) queues")
            return response.queues
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching all queues: \(serviceError)")
            throw serviceError
        }
    }

    /// Creates a new queue with enhanced validation and error handling
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    ///   - name: The name of the queue
    ///   - description: Optional description
    /// - Returns: The created Queue object
    /// - Throws: ServiceError for validation errors or network failures
    func createQueue(familyId: String, groupId: String, name: String, description: String?) async throws -> Queue {
        // Validate queue name requirements
        try validateQueueInput(name: name, description: description)

        do {
            let request = CreateQueueRequest(
                familyId: familyId,
                groupId: groupId,
                queueName: name,
                queueDescription: description
            )
            let response: CreateQueueResponse = try await networkManager.post(
                endpoint: APIEndpoint.createQueue.path,
                body: request
            )
            print("📱 Created Queue: \(response.queue.queueName)")
            return response.queue
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error creating queue: \(serviceError)")
            throw serviceError
        }
    }

    /// Updates an existing queue with enhanced validation and error handling
    /// - Parameters:
    ///   - queueId: The ID of the queue to update
    ///   - name: The new name of the queue (optional)
    ///   - description: The new description (optional)
    /// - Returns: The updated Queue object
    /// - Throws: ServiceError for validation errors or network failures
    func updateQueue(queueId: String, name: String?, description: String?) async throws -> Queue {
        // Validate queue input if provided
        if let name {
            try validateQueueInput(name: name, description: description)
        } else if let description {
            try validateQueueInput(name: "temp", description: description) // Just validate description
        }

        do {
            let request = UpdateQueueRequest(
                queueName: name,
                queueDescription: description
            )
            let response: UpdateQueueResponse = try await networkManager.put(
                endpoint: APIEndpoint.updateQueue(queueId: queueId).path,
                body: request
            )
            print("📱 Updated Queue: \(response.queue.queueName)")
            return response.queue
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error updating queue: \(serviceError)")
            throw serviceError
        }
    }

    /// Deletes a queue with proper error handling
    /// - Parameter queueId: The ID of the queue to delete
    /// - Returns: Success response
    /// - Throws: ServiceError for network failures or business logic errors
    func deleteQueue(queueId: String) async throws -> DeleteQueueResponse {
        do {
            let response: DeleteQueueResponse = try await networkManager.delete(
                endpoint: APIEndpoint.deleteQueue(queueId: queueId).path
            )
            print("📱 Deleted Queue: \(queueId)")
            return response
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error deleting queue: \(serviceError)")
            throw serviceError
        }
    }

    // MARK: - Queue Member Management

    /// Fetches queue members with enhanced error handling
    /// - Parameter queueId: The ID of the queue
    /// - Returns: Array of QueueMember objects
    /// - Throws: ServiceError with structured error information
    func getQueueMembers(queueId: String) async throws -> [QueueMember] {
        do {
            let response: GetQueueMembersResponse = try await networkManager.get(
                endpoint: APIEndpoint.getQueueMembers(queueId: queueId).path
            )
            print("📱 Queue Members Response: \(response.members.count) members")
            return response.members
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching queue members: \(serviceError)")
            throw serviceError
        }
    }

    /// Assigns a member to a queue with enhanced error handling
    /// - Parameters:
    ///   - queueId: The ID of the queue
    ///   - userId: The ID of the user to assign
    ///   - role: The role to assign (assignee or viewer)
    /// - Returns: Success response
    /// - Throws: ServiceError for network failures or business logic errors
    func assignQueueMember(queueId: String, userId: String, role: QueueRole) async throws -> QueueMemberResponse {
        do {
            let request = AssignQueueMemberRequest(userId: userId, role: role)
            let response: QueueMemberResponse = try await networkManager.post(
                endpoint: APIEndpoint.assignQueueMember(queueId: queueId).path,
                body: request
            )
            print("📱 Assigned Queue Member: \(userId) to \(queueId) as \(role.rawValue)")
            return response
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error assigning queue member: \(serviceError)")
            throw serviceError
        }
    }

    /// Removes a member from a queue with enhanced error handling
    /// - Parameters:
    ///   - queueId: The ID of the queue
    ///   - userId: The ID of the user to remove
    /// - Returns: Success response
    /// - Throws: ServiceError for network failures or business logic errors
    func removeQueueMember(queueId: String, userId: String) async throws -> QueueMemberResponse {
        do {
            let response: QueueMemberResponse = try await networkManager.delete(
                endpoint: APIEndpoint.removeQueueMember(queueId: queueId, userId: userId).path
            )
            print("📱 Removed Queue Member: \(userId) from \(queueId)")
            return response
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error removing queue member: \(serviceError)")
            throw serviceError
        }
    }

    // MARK: - Private Validation Methods

    /// Validates queue input according to requirements
    /// - Parameters:
    ///   - name: The queue name to validate
    ///   - description: The optional description to validate
    /// - Throws: ValidationError if inputs are invalid
    private func validateQueueInput(name: String, description: String?) throws {
        // Validate queue name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            throw ValidationError.emptyQueueName
        }

        if trimmedName.count < 2 {
            throw ValidationError.queueNameTooShort
        }

        if trimmedName.count > 50 {
            throw ValidationError.queueNameTooLong
        }

        // Validate description if provided
        if let description {
            let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedDescription.count > 200 {
                throw ValidationError.queueDescriptionTooLong
            }
        }
    }
}