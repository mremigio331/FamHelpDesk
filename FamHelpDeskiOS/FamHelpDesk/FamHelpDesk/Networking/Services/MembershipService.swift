import Foundation

final class MembershipService {
    private let networkManager: NetworkManager

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    /// Fetches all members of a family
    /// - Parameter familyId: The ID of the family
    /// - Returns: Array of FamilyMember objects
    /// - Throws: NetworkError if the request fails
    func getFamilyMembers(familyId: String) async throws -> [FamilyMember] {
        do {
            // First get the raw data to see what we're receiving
            let rawData = try await networkManager.getRawData(
                endpoint: APIEndpoint.getFamilyMembers(familyId: familyId).path
            )

            // Print the raw response for debugging
            if let rawString = String(data: rawData, encoding: .utf8) {
                print("📱 Raw API Response: \(rawString)")
            }

            // Try to decode the response (don't use convertFromSnakeCase since we have explicit CodingKeys)
            let decoder = JSONDecoder()
            let response = try decoder.decode(GetFamilyMembersResponse.self, from: rawData)

            print("📱 Family Members Response: \(response.members.count) members")
            return response.members
        } catch let decodingError as DecodingError {
            print("📱 Decoding Error Details:")
            switch decodingError {
            case let .typeMismatch(type, context):
                print("  - Type mismatch: Expected \(type), at path: \(context.codingPath)")
                print("  - Context: \(context.debugDescription)")
            case let .valueNotFound(type, context):
                print("  - Value not found: \(type), at path: \(context.codingPath)")
                print("  - Context: \(context.debugDescription)")
            case let .keyNotFound(key, context):
                print("  - Key not found: \(key), at path: \(context.codingPath)")
                print("  - Context: \(context.debugDescription)")
            case let .dataCorrupted(context):
                print("  - Data corrupted at path: \(context.codingPath)")
                print("  - Context: \(context.debugDescription)")
            @unknown default:
                print("  - Unknown decoding error: \(decodingError)")
            }
            throw decodingError
        } catch {
            print("📱 Network Error: \(error)")
            throw error
        }
    }

    /// Fetches pending membership requests for a family
    /// - Parameter familyId: The ID of the family
    /// - Returns: Array of MembershipRequest objects
    /// - Throws: NetworkError if the request fails
    func getFamilyMembershipRequests(familyId: String) async throws -> [MembershipRequest] {
        do {
            // First get the raw data to see what we're receiving
            let rawData = try await networkManager.getRawData(
                endpoint: APIEndpoint.getFamilyMembershipRequests(familyId: familyId).path
            )

            // Print the raw response for debugging
            if let rawString = String(data: rawData, encoding: .utf8) {
                print("📱 Raw Membership Requests API Response: \(rawString)")
            }

            // Try to decode the response
            let decoder = JSONDecoder()
            let response = try decoder.decode(GetMembershipRequestsResponse.self, from: rawData)

            print("📱 Membership Requests Response: \(response.requests.count) requests")
            return response.requests
        } catch let decodingError as DecodingError {
            print("📱 Membership Requests Decoding Error Details:")
            switch decodingError {
            case let .typeMismatch(type, context):
                print("  - Type mismatch: Expected \(type), at path: \(context.codingPath)")
                print("  - Context: \(context.debugDescription)")
            case let .valueNotFound(type, context):
                print("  - Value not found: \(type), at path: \(context.codingPath)")
                print("  - Context: \(context.debugDescription)")
            case let .keyNotFound(key, context):
                print("  - Key not found: \(key), at path: \(context.codingPath)")
                print("  - Context: \(context.debugDescription)")
            case let .dataCorrupted(context):
                print("  - Data corrupted at path: \(context.codingPath)")
                print("  - Context: \(context.debugDescription)")
            @unknown default:
                print("  - Unknown decoding error: \(decodingError)")
            }
            throw decodingError
        } catch {
            print("📱 Network Error: \(error)")
            throw error
        }
    }

    /// Reviews a membership request (approve or reject)
    /// - Parameters:
    ///   - familyId: The ID of the family
    ///   - userId: The ID of the user requesting membership
    ///   - action: The action to take (approve or reject)
    /// - Throws: NetworkError if the request fails
    func reviewMembershipRequest(familyId: String, userId: String, action: MembershipAction) async throws {
        let approve = action == .approve
        let request = ReviewMembershipRequest(familyId: familyId, targetUserId: userId, approve: approve)

        // We don't need to parse the response, just check that the request succeeds (2xx status)
        _ = try await networkManager.putRawData(
            endpoint: APIEndpoint.reviewMembershipRequest(familyId: familyId).path,
            body: request
        )

        print("📱 Successfully reviewed membership request: \(userId) in family \(familyId) - \(action.rawValue)")
    }

    /// Requests membership to a family
    /// - Parameter familyId: The ID of the family to request membership for
    /// - Throws: NetworkError if the request fails
    func requestFamilyMembership(familyId: String) async throws {
        let request = RequestFamilyMembershipRequest(familyId: familyId)

        // We don't need to parse the response, just check that the request succeeds (2xx status)
        _ = try await networkManager.postRawData(
            endpoint: APIEndpoint.requestFamilyMembership(familyId: familyId).path,
            body: request
        )

        print("📱 Successfully requested membership for family: \(familyId)")
    }

    /// Fetches all members of a group
    /// - Parameters:
    ///   - familyId: The ID of the family containing the group
    ///   - groupId: The ID of the group
    /// - Returns: Array of GroupMember objects
    /// - Throws: NetworkError if the request fails
    func getGroupMembers(familyId: String, groupId: String) async throws -> [GroupMember] {
        do {
            // First get the raw data to see what we're receiving
            let rawData = try await networkManager.getRawData(
                endpoint: APIEndpoint.getGroupMembers(familyId: familyId, groupId: groupId).path
            )

            // Print the raw response for debugging
            if let rawString = String(data: rawData, encoding: .utf8) {
                print("📱 Raw Group Members API Response: \(rawString)")
            }

            // Try to decode the response
            let decoder = JSONDecoder()
            let response = try decoder.decode(GetGroupMembersResponse.self, from: rawData)

            print("📱 Group Members Response: \(response.members.count) members")
            return response.members
        } catch let decodingError as DecodingError {
            print("📱 Group Members Decoding Error Details:")
            switch decodingError {
            case let .typeMismatch(type, context):
                print("  - Type mismatch: Expected \(type), at path: \(context.codingPath)")
                print("  - Context: \(context.debugDescription)")
            case let .valueNotFound(type, context):
                print("  - Value not found: \(type), at path: \(context.codingPath)")
                print("  - Context: \(context.debugDescription)")
            case let .keyNotFound(key, context):
                print("  - Key not found: \(key), at path: \(context.codingPath)")
                print("  - Context: \(context.debugDescription)")
            case let .dataCorrupted(context):
                print("  - Data corrupted at path: \(context.codingPath)")
                print("  - Context: \(context.debugDescription)")
            @unknown default:
                print("  - Unknown decoding error: \(decodingError)")
            }
            throw decodingError
        } catch {
            print("📱 Network Error: \(error)")
            throw error
        }
    }
}
