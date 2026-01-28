//
//  DeletionState.swift
//  FamHelpDesk
//
//  Created on 1/25/26.
//

import Foundation

/// State model for tracking deletion flow progress
enum DeletionState {
    case idle
    case deleting
    case signingOut
    case completed
    case failed(ProfileDeletionError)
}
