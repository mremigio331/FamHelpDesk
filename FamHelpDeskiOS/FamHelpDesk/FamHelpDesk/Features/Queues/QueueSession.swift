import Foundation

@Observable
final class QueueSession {
    static let shared = QueueSession()

    private let queueService = QueueService()

    var groupQueues: [String: [Queue]] = [:]
    var queueMembers: [String: [QueueMember]] = [:]
    var isFetching = false
    var errorMessage: String?

    private init() {}

    /// Fetches all queues for a specific group
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    /// - Requirements: 2.1 - Display all queues within a group
    @MainActor
    func fetchGroupQueues(familyId: String, groupId: String) async {
        isFetching = true
        errorMessage = nil

        do {
            let queues = try await queueService.getAllQueues(familyId: familyId, groupId: groupId)
            groupQueues[groupId] = queues
            print("✅ Fetched \(queues.count) queues for group \(groupId)")
        } catch {
            errorMessage = "Failed to load group queues: \(error.localizedDescription)"
            print("❌ Error fetching group queues: \(error)")
        }

        isFetching = false
    }

    /// Creates a new queue within a group and updates local state
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group (required - queues must belong to a group)
    ///   - name: The name of the queue
    ///   - description: Optional description
    /// - Returns: The created Queue if successful, nil otherwise
    /// - Requirements: 2.2 - Allow creating new queues within groups with appropriate permissions
    @MainActor
    func createQueue(familyId: String, groupId: String, name: String, description: String?) async -> Queue? {
        isFetching = true
        errorMessage = nil

        do {
            let newQueue = try await queueService.createQueue(
                familyId: familyId,
                groupId: groupId,
                name: name,
                description: description
            )

            // Update local state - add the new queue to group cache
            if groupQueues[groupId] != nil {
                groupQueues[groupId]?.append(newQueue)
            } else {
                groupQueues[groupId] = [newQueue]
            }

            print("✅ Created queue: \(newQueue.queueName) in group \(groupId)")
            isFetching = false
            return newQueue

        } catch {
            if let validationError = error as? ValidationError {
                errorMessage = validationError.localizedDescription
            } else {
                errorMessage = "Failed to create queue: \(error.localizedDescription)"
            }
            print("❌ Error creating queue: \(error)")
            isFetching = false
            return nil
        }
    }

    /// Updates an existing queue and updates local state
    /// - Parameters:
    ///   - queueId: The ID of the queue to update
    ///   - name: The new name of the queue (optional)
    ///   - description: The new description (optional)
    /// - Returns: The updated Queue if successful, nil otherwise
    /// - Requirements: 2.2 - Allow updating queues with appropriate permissions
    @MainActor
    func updateQueue(queueId: String, name: String?, description: String?) async -> Queue? {
        isFetching = true
        errorMessage = nil

        do {
            let updatedQueue = try await queueService.updateQueue(
                queueId: queueId,
                name: name,
                description: description
            )

            // Update local state - find and replace the queue in all relevant caches
            updateQueueInLocalState(updatedQueue)

            print("✅ Updated queue: \(updatedQueue.queueName)")
            isFetching = false
            return updatedQueue

        } catch {
            if let validationError = error as? ValidationError {
                errorMessage = validationError.localizedDescription
            } else {
                errorMessage = "Failed to update queue: \(error.localizedDescription)"
            }
            print("❌ Error updating queue: \(error)")
            isFetching = false
            return nil
        }
    }

    /// Deletes a queue and updates local state
    /// - Parameter queueId: The ID of the queue to delete
    /// - Returns: True if successful, false otherwise
    /// - Requirements: 2.2 - Allow deleting queues with appropriate permissions
    @MainActor
    func deleteQueue(queueId: String) async -> Bool {
        isFetching = true
        errorMessage = nil

        do {
            _ = try await queueService.deleteQueue(queueId: queueId)

            // Update local state - remove the queue from all caches
            removeQueueFromLocalState(queueId)

            print("✅ Deleted queue: \(queueId)")
            isFetching = false
            return true

        } catch {
            errorMessage = "Failed to delete queue: \(error.localizedDescription)"
            print("❌ Error deleting queue: \(error)")
            isFetching = false
            return false
        }
    }

    /// Fetches queue members for a specific queue
    /// - Parameter queueId: The ID of the queue
    /// - Returns: Array of QueueMember objects if successful, empty array otherwise
    /// - Requirements: 2.1 - Display queue membership information
    @MainActor
    func fetchQueueMembers(queueId: String) async -> [QueueMember] {
        isFetching = true
        errorMessage = nil

        do {
            let members = try await queueService.getQueueMembers(queueId: queueId)
            queueMembers[queueId] = members
            print("✅ Fetched \(members.count) members for queue \(queueId)")
            isFetching = false
            return members
        } catch {
            errorMessage = "Failed to load queue members: \(error.localizedDescription)"
            print("❌ Error fetching queue members: \(error)")
            isFetching = false
            return []
        }
    }

    /// Assigns a member to a queue
    /// - Parameters:
    ///   - queueId: The ID of the queue
    ///   - userId: The ID of the user to assign
    ///   - role: The role to assign (assignee or viewer)
    /// - Returns: True if successful, false otherwise
    /// - Requirements: 2.2 - Allow assigning queue members with appropriate permissions
    @MainActor
    func assignQueueMember(queueId: String, userId: String, role: QueueRole) async -> Bool {
        isFetching = true
        errorMessage = nil

        do {
            _ = try await queueService.assignQueueMember(queueId: queueId, userId: userId, role: role)

            // Refresh queue members to get updated list
            await fetchQueueMembers(queueId: queueId)

            print("✅ Assigned member \(userId) to queue \(queueId) as \(role.rawValue)")
            isFetching = false
            return true
        } catch {
            errorMessage = "Failed to assign queue member: \(error.localizedDescription)"
            print("❌ Error assigning queue member: \(error)")
            isFetching = false
            return false
        }
    }

    /// Removes a member from a queue
    /// - Parameters:
    ///   - queueId: The ID of the queue
    ///   - userId: The ID of the user to remove
    /// - Returns: True if successful, false otherwise
    /// - Requirements: 2.2 - Allow removing queue members with appropriate permissions
    @MainActor
    func removeQueueMember(queueId: String, userId: String) async -> Bool {
        isFetching = true
        errorMessage = nil

        do {
            _ = try await queueService.removeQueueMember(queueId: queueId, userId: userId)

            // Update local state - remove member from cache
            queueMembers[queueId]?.removeAll { $0.userId == userId }

            print("✅ Removed member \(userId) from queue \(queueId)")
            isFetching = false
            return true
        } catch {
            errorMessage = "Failed to remove queue member: \(error.localizedDescription)"
            print("❌ Error removing queue member: \(error)")
            isFetching = false
            return false
        }
    }

    /// Gets queues for a specific group from local cache
    /// - Parameter groupId: The ID of the group
    /// - Returns: Array of Queue objects for the group
    func getQueuesForGroup(_ groupId: String) -> [Queue] {
        groupQueues[groupId] ?? []
    }

    /// Gets members for a specific queue from local cache
    /// - Parameter queueId: The ID of the queue
    /// - Returns: Array of QueueMember objects for the queue
    func getMembersForQueue(_ queueId: String) -> [QueueMember] {
        queueMembers[queueId] ?? []
    }

    /// Refreshes all queue data for a group
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group to refresh
    @MainActor
    func refreshGroupQueues(familyId: String, groupId: String) async {
        await fetchGroupQueues(familyId: familyId, groupId: groupId)
    }

    /// Refreshes queue members for a specific queue
    /// - Parameter queueId: The ID of the queue to refresh
    @MainActor
    func refreshQueueMembers(queueId: String) async {
        await fetchQueueMembers(queueId: queueId)
    }

    // MARK: - Private Helper Methods

    /// Updates a queue in all local state caches
    /// - Parameter updatedQueue: The updated queue to replace in caches
    private func updateQueueInLocalState(_ updatedQueue: Queue) {
        // Update in groupQueues cache
        for (groupId, queues) in groupQueues {
            if let index = queues.firstIndex(where: { $0.queueId == updatedQueue.queueId }) {
                groupQueues[groupId]?[index] = updatedQueue
            }
        }
    }

    /// Removes a queue from all local state caches
    /// - Parameter queueId: The ID of the queue to remove
    private func removeQueueFromLocalState(_ queueId: String) {
        // Remove from groupQueues cache
        for (groupId, queues) in groupQueues {
            groupQueues[groupId] = queues.filter { $0.queueId != queueId }
        }

        // Remove from queueMembers cache
        queueMembers.removeValue(forKey: queueId)
    }

    /// Clears error message
    func clearError() {
        errorMessage = nil
    }
}
