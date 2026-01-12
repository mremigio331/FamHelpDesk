import Foundation

@Observable
final class QueueSession {
    static let shared = QueueSession()

    private let queueService = QueueService()

    var groupQueues: [String: [Queue]] = [:]
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
    /// - Returns: True if successful, false otherwise
    /// - Requirements: 2.2 - Allow creating new queues within groups with appropriate permissions
    @MainActor
    func createQueue(familyId: String, groupId: String, name: String, description: String?) async -> Bool {
        isFetching = true
        errorMessage = nil

        do {
            let success = try await queueService.createQueue(
                familyId: familyId,
                groupId: groupId,
                name: name,
                description: description
            )

            if success {
                // Refresh the queues for this group to get the updated list
                await fetchGroupQueues(familyId: familyId, groupId: groupId)
                print("✅ Created queue and refreshed queue list for group \(groupId)")
            }

            isFetching = false
            return success

        } catch {
            if let validationError = error as? ValidationError {
                errorMessage = validationError.localizedDescription
            } else {
                errorMessage = "Failed to create queue: \(error.localizedDescription)"
            }
            print("❌ Error creating queue: \(error)")
            isFetching = false
            return false
        }
    }

    /// Updates an existing queue and updates local state
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    ///   - queueId: The ID of the queue to update
    ///   - name: The new name of the queue
    ///   - description: The new description
    /// - Returns: True if successful, false otherwise
    /// - Requirements: 2.2 - Allow updating queues with appropriate permissions
    @MainActor
    func updateQueue(familyId: String, groupId: String, queueId: String, name: String, description: String?) async -> Bool {
        isFetching = true
        errorMessage = nil

        do {
            let success = try await queueService.updateQueue(
                familyId: familyId,
                groupId: groupId,
                queueId: queueId,
                name: name,
                description: description
            )

            if success {
                // Refresh the queues for this group to get the updated data
                await fetchGroupQueues(familyId: familyId, groupId: groupId)
                print("✅ Updated queue and refreshed queue list for group \(groupId)")
            }

            isFetching = false
            return success

        } catch {
            if let validationError = error as? ValidationError {
                errorMessage = validationError.localizedDescription
            } else {
                errorMessage = "Failed to update queue: \(error.localizedDescription)"
            }
            print("❌ Error updating queue: \(error)")
            isFetching = false
            return false
        }
    }

    /// Deletes a queue and updates local state
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group
    ///   - queueId: The ID of the queue to delete
    /// - Returns: True if successful, false otherwise
    /// - Requirements: 2.2 - Allow deleting queues with appropriate permissions
    @MainActor
    func deleteQueue(familyId: String, groupId: String, queueId: String) async -> Bool {
        isFetching = true
        errorMessage = nil

        do {
            let success = try await queueService.deleteQueue(familyId: familyId, groupId: groupId, queueId: queueId)

            if success {
                // Update local state - remove the queue from all caches
                removeQueueFromLocalState(queueId)
                print("✅ Deleted queue: \(queueId)")
            }

            isFetching = false
            return success

        } catch {
            errorMessage = "Failed to delete queue: \(error.localizedDescription)"
            print("❌ Error deleting queue: \(error)")
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

    /// Refreshes all queue data for a group
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - groupId: The ID of the group to refresh
    @MainActor
    func refreshGroupQueues(familyId: String, groupId: String) async {
        await fetchGroupQueues(familyId: familyId, groupId: groupId)
    }

    // MARK: - Private Helper Methods

    /// Removes a queue from all local state caches
    /// - Parameter queueId: The ID of the queue to remove
    private func removeQueueFromLocalState(_ queueId: String) {
        // Remove from groupQueues cache
        for (groupId, queues) in groupQueues {
            groupQueues[groupId] = queues.filter { $0.queueId != queueId }
        }
    }

    /// Clears error message
    func clearError() {
        errorMessage = nil
    }
}
