//
//  SeverityInfo.swift
//  FamHelpDesk
//
//  Created for iOS UX Improvements
//

import Foundation

/// Represents information about a ticket severity level
struct SeverityInfo: Identifiable {
    let id: String
    let name: String
    let description: String
    let scope: String

    /// All available severity levels in the system
    static let allSeverities: [SeverityInfo] = [
        SeverityInfo(
            id: "SEV_1",
            name: "SEV 1",
            description: "Affects the entire family",
            scope: "All members/groups are impacted; urgent for the whole family"
        ),
        SeverityInfo(
            id: "SEV_2",
            name: "SEV 2",
            description: "Affects multiple groups",
            scope: "More than one household or sub-group, but not everyone"
        ),
        SeverityInfo(
            id: "SEV_2_5",
            name: "SEV 2.5",
            description: "Affects multiple groups (non-urgent)",
            scope: "Can wait until family business hours; not urgent, but broad impact"
        ),
        SeverityInfo(
            id: "SEV_3",
            name: "SEV 3",
            description: "Affects a single group",
            scope: "Just one household or sub-group within the family"
        ),
        SeverityInfo(
            id: "SEV_4",
            name: "SEV 4",
            description: "Affects an individual",
            scope: "Impacts a single family member"
        ),
        SeverityInfo(
            id: "SEV_5",
            name: "SEV 5",
            description: "Minor/personal",
            scope: "Trivial or non-urgent issue"
        ),
    ]

    /// Looks up severity information by ID or name
    /// - Parameter severity: The severity ID (e.g., "SEV_1") or name (e.g., "SEV 1")
    /// - Returns: The matching SeverityInfo, or nil if not found
    static func info(for severity: String) -> SeverityInfo? {
        allSeverities.first { $0.id == severity || $0.name == severity }
    }
}
