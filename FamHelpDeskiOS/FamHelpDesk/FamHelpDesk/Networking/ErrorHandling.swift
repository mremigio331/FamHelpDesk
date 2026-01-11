import Foundation

// MARK: - Unified Error Types

/// Protocol for errors that can be retried
protocol RetryableError: Error {
    var canRetry: Bool { get }
    var retryDelay: TimeInterval { get }
    var maxRetries: Int { get }
}

/// Comprehensive service error wrapper
enum ServiceError: Error, LocalizedError, RetryableError {
    case network(NetworkError)
    case validation(ValidationError)
    case offline(OfflineError)
    case business(BusinessError)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case let .network(error):
            error.localizedDescription
        case let .validation(error):
            error.localizedDescription
        case let .offline(error):
            error.localizedDescription
        case let .business(error):
            error.localizedDescription
        case let .unknown(error):
            "Unexpected error: \(error.localizedDescription)"
        }
    }

    var canRetry: Bool {
        switch self {
        case let .network(error):
            error.canRetry
        case .validation:
            false // Validation errors shouldn't be retried
        case .offline:
            true // Can retry when back online
        case .business:
            false // Business logic errors shouldn't be retried
        case .unknown:
            true // Unknown errors can be retried
        }
    }

    var retryDelay: TimeInterval {
        switch self {
        case let .network(error):
            error.retryDelay
        case .offline:
            2.0
        case .unknown:
            1.0
        default:
            0.0
        }
    }

    var maxRetries: Int {
        switch self {
        case let .network(error):
            error.maxRetries
        case .offline:
            5
        case .unknown:
            3
        default:
            0
        }
    }
}

/// Enhanced validation errors for all services
enum ValidationError: Error, LocalizedError {
    // Group validation
    case emptyGroupName
    case groupNameTooShort
    case groupNameTooLong
    case groupDescriptionTooLong

    // Family validation
    case emptyFamilyName
    case familyNameTooShort
    case familyNameTooLong
    case familyDescriptionTooLong

    // User profile validation
    case emptyDisplayName
    case displayNameTooShort
    case displayNameTooLong
    case invalidEmail
    case invalidProfileColor

    // Search validation
    case emptySearchQuery
    case searchQueryTooShort

    var errorDescription: String? {
        switch self {
        // Group validation
        case .emptyGroupName:
            "Group name cannot be empty"
        case .groupNameTooShort:
            "Group name must be at least 2 characters long"
        case .groupNameTooLong:
            "Group name cannot exceed 50 characters"
        case .groupDescriptionTooLong:
            "Group description cannot exceed 200 characters"
        // Family validation
        case .emptyFamilyName:
            "Family name cannot be empty"
        case .familyNameTooShort:
            "Family name must be at least 2 characters long"
        case .familyNameTooLong:
            "Family name cannot exceed 50 characters"
        case .familyDescriptionTooLong:
            "Family description cannot exceed 200 characters"
        // User profile validation
        case .emptyDisplayName:
            "Display name cannot be empty"
        case .displayNameTooShort:
            "Display name must be at least 2 characters long"
        case .displayNameTooLong:
            "Display name cannot exceed 50 characters"
        case .invalidEmail:
            "Please enter a valid email address"
        case .invalidProfileColor:
            "Please select a valid profile color"
        // Search validation
        case .emptySearchQuery:
            "Search query cannot be empty"
        case .searchQueryTooShort:
            "Search query must be at least 2 characters long"
        }
    }
}

/// Offline-specific errors
enum OfflineError: Error, LocalizedError {
    case noConnection
    case dataNotCached
    case syncRequired
    case conflictDetected

    var errorDescription: String? {
        switch self {
        case .noConnection:
            "No internet connection. Please check your network and try again."
        case .dataNotCached:
            "This data is not available offline. Please connect to the internet."
        case .syncRequired:
            "Your data needs to be synchronized. Please connect to the internet."
        case .conflictDetected:
            "Data conflict detected. Please resolve conflicts and try again."
        }
    }
}

/// Business logic errors
enum BusinessError: Error, LocalizedError {
    case insufficientPermissions
    case resourceNotFound
    case duplicateResource
    case operationNotAllowed
    case quotaExceeded

    var errorDescription: String? {
        switch self {
        case .insufficientPermissions:
            "You don't have permission to perform this action"
        case .resourceNotFound:
            "The requested resource was not found"
        case .duplicateResource:
            "This resource already exists"
        case .operationNotAllowed:
            "This operation is not allowed"
        case .quotaExceeded:
            "You have exceeded your quota for this operation"
        }
    }
}

// MARK: - Enhanced NetworkError with Retry Support

extension NetworkError: RetryableError {
    var canRetry: Bool {
        switch self {
        case .invalidURL, .decodingError, .malformedResponse:
            false // These are permanent errors
        case .invalidResponse, .noData:
            false // These are likely permanent
        case .unauthorized:
            true // Can retry after token refresh
        case let .serverError(statusCode, _):
            statusCode >= 500 // Retry on 5xx errors
        case .networkTimeout:
            true // Can retry timeouts
        case .tokenRefreshFailed, .authenticationFailure:
            false // These need user intervention
        case .noConnection:
            true // Can retry when connection is restored
        }
    }

    var retryDelay: TimeInterval {
        switch self {
        case .networkTimeout:
            2.0
        case let .serverError(statusCode, _):
            statusCode >= 500 ? 1.0 : 0.0
        case .unauthorized:
            0.5
        default:
            1.0
        }
    }

    var maxRetries: Int {
        switch self {
        case .networkTimeout:
            3
        case let .serverError(statusCode, _):
            statusCode >= 500 ? 3 : 0
        case .unauthorized:
            1
        default:
            0
        }
    }
}

// MARK: - Loading States

enum LoadingState: Equatable {
    case idle
    case loading
    case refreshing
    case retrying(attempt: Int, maxAttempts: Int)
    case success
    case error(String)

    var isLoading: Bool {
        switch self {
        case .loading, .refreshing, .retrying:
            true
        default:
            false
        }
    }

    var canRetry: Bool {
        switch self {
        case .error:
            true
        case let .retrying(attempt, maxAttempts):
            attempt < maxAttempts
        default:
            false
        }
    }
}

// MARK: - Operation State

struct OperationState {
    var loadingState: LoadingState = .idle
    var error: ServiceError?
    var retryCount: Int = 0
    var lastAttempt: Date?

    mutating func setLoading() {
        loadingState = .loading
        error = nil
    }

    mutating func setRefreshing() {
        loadingState = .refreshing
        error = nil
    }

    mutating func setRetrying() {
        retryCount += 1
        loadingState = .retrying(attempt: retryCount, maxAttempts: 3)
        lastAttempt = Date()
    }

    mutating func setSuccess() {
        loadingState = .success
        error = nil
        retryCount = 0
        lastAttempt = nil
    }

    mutating func setError(_ serviceError: ServiceError) {
        loadingState = .error(serviceError.localizedDescription)
        error = serviceError
        lastAttempt = Date()
    }

    mutating func reset() {
        loadingState = .idle
        error = nil
        retryCount = 0
        lastAttempt = nil
    }
}

// MARK: - Retry Helper

actor RetryHelper {
    private var activeOperations: [String: Task<Void, Never>] = [:]

    func executeWithRetry<T>(
        operationId: String,
        operation: @escaping () async throws -> T,
        onStateChange: @escaping (LoadingState) -> Void
    ) async throws -> T {
        // Cancel any existing operation with the same ID
        activeOperations[operationId]?.cancel()

        let task = Task<Void, Never> {
            await performRetryOperation(
                operationId: operationId,
                operation: operation,
                onStateChange: onStateChange
            )
        }

        activeOperations[operationId] = task

        return try await operation()
    }

    private func performRetryOperation(
        operationId: String,
        operation: @escaping () async throws -> some Any,
        onStateChange: @escaping (LoadingState) -> Void
    ) async {
        var retryCount = 0
        let maxRetries = 3

        while retryCount <= maxRetries {
            do {
                if retryCount == 0 {
                    await MainActor.run { onStateChange(.loading) }
                } else {
                    await MainActor.run { onStateChange(.retrying(attempt: retryCount, maxAttempts: maxRetries)) }
                }

                _ = try await operation()
                await MainActor.run { onStateChange(.success) }
                break

            } catch {
                let serviceError = mapToServiceError(error)

                if serviceError.canRetry, retryCount < maxRetries {
                    retryCount += 1
                    let delay = calculateBackoffDelay(attempt: retryCount, baseDelay: serviceError.retryDelay)

                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    await MainActor.run { onStateChange(.error(serviceError.localizedDescription)) }
                    break
                }
            }
        }

        activeOperations.removeValue(forKey: operationId)
    }

    private func calculateBackoffDelay(attempt: Int, baseDelay: TimeInterval) -> TimeInterval {
        baseDelay * pow(2.0, Double(attempt - 1))
    }

    func cancelOperation(_ operationId: String) {
        activeOperations[operationId]?.cancel()
        activeOperations.removeValue(forKey: operationId)
    }
}

// MARK: - Error Mapping Helper

func mapToServiceError(_ error: Error) -> ServiceError {
    if let serviceError = error as? ServiceError {
        serviceError
    } else if let networkError = error as? NetworkError {
        .network(networkError)
    } else if let validationError = error as? ValidationError {
        .validation(validationError)
    } else if let offlineError = error as? OfflineError {
        .offline(offlineError)
    } else if let businessError = error as? BusinessError {
        .business(businessError)
    } else {
        .unknown(error)
    }
}

// MARK: - Success Feedback

enum SuccessType {
    case created(String)
    case updated(String)
    case deleted(String)
    case acknowledged(String)
    case joined(String)
    case left(String)

    var message: String {
        switch self {
        case let .created(item):
            "\(item) created successfully"
        case let .updated(item):
            "\(item) updated successfully"
        case let .deleted(item):
            "\(item) deleted successfully"
        case let .acknowledged(item):
            "\(item) acknowledged"
        case let .joined(item):
            "Joined \(item) successfully"
        case let .left(item):
            "Left \(item) successfully"
        }
    }
}

struct SuccessState {
    let type: SuccessType
    let timestamp: Date

    init(_ type: SuccessType) {
        self.type = type
        timestamp = Date()
    }
}
