//
//  ProfileDeletionViewModel.swift
//  FamHelpDesk
//
//  Created on 1/25/26.
//

import Combine
import Foundation

/// ViewModel that manages UI state and coordinates profile deletion interactions
@MainActor
final class ProfileDeletionViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Indicates whether a deletion operation is in progress
    @Published var isLoading: Bool = false

    /// User-facing error message to display when deletion fails
    @Published var errorMessage: String?

    /// Controls whether to show the deletion confirmation view
    @Published var showDeletionConfirmation: Bool = false

    // MARK: - Dependencies

    private let deletionService: ProfileDeletionServiceProtocol

    // MARK: - Initialization

    /// Initialize the view model with a profile deletion service
    /// - Parameter deletionService: The service responsible for profile deletion operations
    init(deletionService: ProfileDeletionServiceProtocol) {
        self.deletionService = deletionService
    }

    // MARK: - Public Methods

    /// Initiates the profile deletion process
    /// Updates loading state and handles success/error outcomes
    func initiateProfileDeletion() async {
        print("🗑️ [PROFILE DELETION VM] User initiated profile deletion")
        isLoading = true
        errorMessage = nil

        print("🗑️ [PROFILE DELETION VM] Calling deletion service...")
        let result = await deletionService.deleteProfile()

        isLoading = false

        switch result {
        case .success:
            // Show confirmation view on successful deletion
            print("🗑️ [PROFILE DELETION VM] ✅ Deletion successful, showing confirmation view")
            showDeletionConfirmation = true
        case let .failure(error):
            // Display user-facing error message
            print("🗑️ [PROFILE DELETION VM] ❌ Deletion failed with error: \(error)")
            print("🗑️ [PROFILE DELETION VM] Setting error message: \(error.userFacingMessage)")
            errorMessage = error.userFacingMessage
        }
    }

    /// Retries the profile deletion after a previous failure
    /// Delegates to initiateProfileDeletion to avoid code duplication
    func retryDeletion() async {
        await initiateProfileDeletion()
    }
}
