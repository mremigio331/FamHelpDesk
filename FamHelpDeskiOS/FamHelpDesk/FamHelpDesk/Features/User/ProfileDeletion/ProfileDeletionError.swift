//
//  ProfileDeletionError.swift
//  FamHelpDesk
//
//  Created on 1/25/26.
//

import Foundation

/// Error types specific to profile deletion operations
enum ProfileDeletionError: Error {
    case networkError(Error)
    case clientError(statusCode: Int, message: String?)
    case serverError(statusCode: Int)
    case authenticationRequired
    case unknownError

    /// User-facing error message for each error type
    var userFacingMessage: String {
        switch self {
        case .networkError:
            return "Unable to connect. Please check your internet connection and try again."
        case let .clientError(statusCode, message):
            if statusCode == 401 || statusCode == 403 {
                return "Authentication failed. Please sign in again."
            }
            return message ?? "Unable to delete profile. Please try again."
        case .serverError:
            return "Server error occurred. Please try again later."
        case .authenticationRequired:
            return "You must be signed in to delete your profile."
        case .unknownError:
            return "An unexpected error occurred. Please try again."
        }
    }
}
