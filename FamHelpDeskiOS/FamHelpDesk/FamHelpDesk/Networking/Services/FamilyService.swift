import Foundation

final class FamilyService {
    private let networkManager: NetworkManager
    private let retryHelper = RetryHelper()

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    /// Fetches all families with enhanced error handling and retry logic
    /// - Returns: Array of Family objects
    /// - Throws: ServiceError with structured error information
    func getAllFamilies() async throws -> [Family] {
        do {
            let response: GetAllFamiliesResponse = try await networkManager.get(
                endpoint: APIEndpoint.getAllFamilies.path
            )
            print("📱 All Families Response: \(response.families.count) families")
            return response.families
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching all families: \(serviceError)")
            throw serviceError
        }
    }

    /// Fetches families for the current user with enhanced error handling
    /// - Returns: Dictionary of family items keyed by family ID
    /// - Throws: ServiceError with structured error information
    func getMyFamilies() async throws -> [String: MyFamilyItem] {
        do {
            let response: GetMyFamiliesResponse = try await networkManager.get(
                endpoint: APIEndpoint.getMyFamilies.path
            )
            print("📱 My Families Response: \(response.families.count) families")
            return response.families
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error fetching my families: \(serviceError)")
            throw serviceError
        }
    }

    /// Creates a new family with input validation and enhanced error handling
    /// - Parameters:
    ///   - name: The name of the family
    ///   - description: Optional description
    /// - Returns: The created Family object
    /// - Throws: ServiceError for validation errors or network failures
    func createFamily(name: String, description: String?) async throws -> Family {
        // Validate input before making API call
        try validateFamilyInput(name: name, description: description)

        do {
            let request = CreateFamilyRequest(
                familyName: name,
                familyDescription: description
            )
            let response: CreateFamilyResponse = try await networkManager.post(
                endpoint: APIEndpoint.createFamily.path,
                body: request
            )
            print("📱 Created Family: \(response.family.familyName)")
            return response.family
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error creating family: \(serviceError)")
            throw serviceError
        }
    }

    /// Updates an existing family with input validation and enhanced error handling
    /// - Parameters:
    ///   - familyId: The ID of the family to update
    ///   - name: The new name of the family
    ///   - description: Optional new description
    /// - Returns: The updated Family object
    /// - Throws: ServiceError for validation errors or network failures
    func updateFamily(familyId: String, name: String, description: String?) async throws -> Family {
        // Validate input before making API call
        try validateFamilyInput(name: name, description: description)

        do {
            let request = UpdateFamilyRequest(
                familyName: name,
                familyDescription: description
            )
            let response: UpdateFamilyResponse = try await networkManager.put(
                endpoint: APIEndpoint.updateFamily(familyId: familyId).path,
                body: request
            )
            print("📱 Updated Family: \(response.family.familyName)")
            return response.family
        } catch {
            let serviceError = mapToServiceError(error)
            print("❌ Error updating family: \(serviceError)")
            throw serviceError
        }
    }

    // MARK: - Private Validation Methods

    /// Validates family input according to business rules
    /// - Parameters:
    ///   - name: The family name to validate
    ///   - description: The optional description to validate
    /// - Throws: ValidationError if inputs are invalid
    private func validateFamilyInput(name: String, description: String?) throws {
        // Validate family name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            throw ValidationError.emptyFamilyName
        }

        if trimmedName.count < 2 {
            throw ValidationError.familyNameTooShort
        }

        if trimmedName.count > 50 {
            throw ValidationError.familyNameTooLong
        }

        // Validate description if provided
        if let description {
            let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedDescription.count > 200 {
                throw ValidationError.familyDescriptionTooLong
            }
        }
    }
}
