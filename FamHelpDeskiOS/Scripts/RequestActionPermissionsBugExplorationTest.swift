#!/usr/bin/env swift
// RequestActionPermissionsBugExplorationTest.swift
//
// Property-Based Exploration Test: Bug Condition - Unauthorized Users See Action Buttons
//
// **Validates: Requirements 1.1, 1.2, 1.3, 1.4**
//
// This test generates combinations of (userId, requestorId, claimerId, status, buttonType)
// where the bug condition holds (unauthorized user viewing buttons they shouldn't see).
//
// It asserts that buttons are NOT visible for unauthorized users (expected behavior).
// On UNFIXED code, this test MUST FAIL — failure confirms the bug exists because
// the current actionsSection renders buttons unconditionally to all users.

import Foundation

// MARK: - Minimal Model Replicas (for test isolation)

enum GrabRequestStatus: String, CaseIterable {
    case open = "OPEN"
    case partiallyClaimed = "PARTIALLY_CLAIMED"
    case claimed = "CLAIMED"
    case partiallyCompleted = "PARTIALLY_COMPLETED"
    case completed = "COMPLETED"
    case confirmed = "CONFIRMED"
    case cancelled = "CANCELLED"
}

enum ActionButtonType: String, CaseIterable {
    case completeWithPhoto = "Complete with Photo"
    case completeWithoutPhoto = "Complete without Photo"
    case cancelRequest = "Cancel Request"
}

struct EntityRef {
    let id: String
    let name: String?
}

struct GrabRequest {
    let requestId: String
    let familyId: String
    let title: String
    let requestorId: EntityRef
    let claimerId: EntityRef?
    let status: GrabRequestStatus
}

// MARK: - Current (UNFIXED) actionsSection Visibility Logic

/// Models the CURRENT (buggy) actionsSection logic from GrabRequestDetailView.swift.
/// This replicates what the unfixed code actually does — shows buttons without role checks.
func isButtonVisibleInCurrentCode(request: GrabRequest, currentUserId: String, buttonType: ActionButtonType) -> Bool {
    switch request.status {
    case .open:
        // Only case that correctly checks isRequestor
        if buttonType == .cancelRequest {
            return request.requestorId.id == currentUserId
        }
        return false

    case .claimed:
        // BUG: Complete buttons shown to ALL users (no isClaimer check)
        if buttonType == .completeWithPhoto || buttonType == .completeWithoutPhoto {
            return true // No role check in current code
        }
        // BUG: Cancel button shown to ALL users (no isRequestor check)
        if buttonType == .cancelRequest {
            return true // No role check in current code
        }
        return false

    case .completed:
        // BUG: Cancel button shown to ALL users (no isRequestor check)
        if buttonType == .cancelRequest {
            return true // No role check in current code
        }
        return false

    case .partiallyClaimed, .partiallyCompleted:
        // BUG: Cancel button shown to ALL users (no isRequestor check)
        if buttonType == .cancelRequest {
            return true // No role check in current code
        }
        return false

    case .confirmed, .cancelled:
        return false
    }
}

// MARK: - Bug Condition Predicate

/// Returns true if the input satisfies the bug condition:
/// An unauthorized user would see a button they shouldn't have access to.
///
/// Matches the design pseudocode:
///   IF buttonType IN [completeWithPhoto, completeWithoutPhoto] THEN
///     RETURN request.status == .claimed AND request.claimerId?.id != currentUserId
///   IF buttonType == cancelRequest THEN
///     RETURN request.status IN [.claimed, .completed, .partiallyClaimed, .partiallyCompleted]
///            AND request.requestorId.id != currentUserId
func isBugCondition(request: GrabRequest, currentUserId: String, buttonType: ActionButtonType) -> Bool {
    switch buttonType {
    case .completeWithPhoto, .completeWithoutPhoto:
        return request.status == .claimed
            && request.claimerId?.id != currentUserId

    case .cancelRequest:
        let applicableStatuses: [GrabRequestStatus] = [.claimed, .completed, .partiallyClaimed, .partiallyCompleted]
        return applicableStatuses.contains(request.status)
            && request.requestorId.id != currentUserId
    }
}

// MARK: - Random Generators

func randomUserId() -> String {
    "user-\(UUID().uuidString.prefix(8))"
}

/// Generates a random GrabRequest and currentUserId combination where the bug condition holds.
func generateBugConditionInput() -> (request: GrabRequest, currentUserId: String, buttonType: ActionButtonType) {
    // Pick a random bug scenario
    let scenario = Int.random(in: 0 ..< 4)

    switch scenario {
    case 0:
        // Non-claimer viewing .claimed request sees "Complete with Photo"
        let requestorId = randomUserId()
        let claimerId = randomUserId()
        let currentUserId = randomUserId() // Different from claimer
        // Ensure currentUserId != claimerId
        let finalUserId = (currentUserId == claimerId) ? "\(currentUserId)-diff" : currentUserId

        let request = GrabRequest(
            requestId: "req-\(UUID().uuidString.prefix(8))",
            familyId: "fam-\(UUID().uuidString.prefix(8))",
            title: ["Groceries", "Pharmacy", "Hardware Store", "Pet Supplies"].randomElement()!,
            requestorId: EntityRef(id: requestorId, name: "Requestor"),
            claimerId: EntityRef(id: claimerId, name: "Claimer"),
            status: .claimed
        )
        return (request, finalUserId, .completeWithPhoto)

    case 1:
        // Non-claimer viewing .claimed request sees "Complete without Photo"
        let requestorId = randomUserId()
        let claimerId = randomUserId()
        let currentUserId = randomUserId()
        let finalUserId = (currentUserId == claimerId) ? "\(currentUserId)-diff" : currentUserId

        let request = GrabRequest(
            requestId: "req-\(UUID().uuidString.prefix(8))",
            familyId: "fam-\(UUID().uuidString.prefix(8))",
            title: ["Groceries", "Pharmacy", "Hardware Store", "Pet Supplies"].randomElement()!,
            requestorId: EntityRef(id: requestorId, name: "Requestor"),
            claimerId: EntityRef(id: claimerId, name: "Claimer"),
            status: .claimed
        )
        return (request, finalUserId, .completeWithoutPhoto)

    case 2:
        // Non-requestor viewing .claimed request sees "Cancel Request"
        let requestorId = randomUserId()
        let claimerId = randomUserId()
        let currentUserId = randomUserId()
        let finalUserId = (currentUserId == requestorId) ? "\(currentUserId)-diff" : currentUserId

        let request = GrabRequest(
            requestId: "req-\(UUID().uuidString.prefix(8))",
            familyId: "fam-\(UUID().uuidString.prefix(8))",
            title: ["Groceries", "Pharmacy", "Hardware Store", "Pet Supplies"].randomElement()!,
            requestorId: EntityRef(id: requestorId, name: "Requestor"),
            claimerId: EntityRef(id: claimerId, name: "Claimer"),
            status: .claimed
        )
        return (request, finalUserId, .cancelRequest)

    default:
        // Non-requestor viewing .completed, .partiallyClaimed, or .partiallyCompleted sees "Cancel Request"
        let requestorId = randomUserId()
        let claimerId = randomUserId()
        let currentUserId = randomUserId()
        let finalUserId = (currentUserId == requestorId) ? "\(currentUserId)-diff" : currentUserId

        let status: GrabRequestStatus = [.completed, .partiallyClaimed, .partiallyCompleted].randomElement()!

        let request = GrabRequest(
            requestId: "req-\(UUID().uuidString.prefix(8))",
            familyId: "fam-\(UUID().uuidString.prefix(8))",
            title: ["Groceries", "Pharmacy", "Hardware Store", "Pet Supplies"].randomElement()!,
            requestorId: EntityRef(id: requestorId, name: "Requestor"),
            claimerId: EntityRef(id: claimerId, name: "Claimer"),
            status: status
        )
        return (request, finalUserId, .cancelRequest)
    }
}

// MARK: - Property-Based Test Execution

let numberOfTrials = 100
var failures: [(request: GrabRequest, currentUserId: String, buttonType: ActionButtonType, isVisible: Bool)] = []

print(String(repeating: "=", count: 70))
print("PROPERTY-BASED EXPLORATION TEST: Bug Condition")
print("Property: Unauthorized users should NOT see action buttons")
print("  - Non-claimer should NOT see Complete buttons on .claimed request")
print("  - Non-requestor should NOT see Cancel button on .claimed/.completed/.partiallyClaimed/.partiallyCompleted")
print("Running \(numberOfTrials) trials...")
print(String(repeating: "=", count: 70))
print()

for trial in 1 ... numberOfTrials {
    let (request, currentUserId, buttonType) = generateBugConditionInput()

    // Verify the generated input actually satisfies the bug condition
    assert(isBugCondition(request: request, currentUserId: currentUserId, buttonType: buttonType),
           "Generator produced input that doesn't satisfy bug condition!")

    // Check what the CURRENT (unfixed) code does
    let isVisible = isButtonVisibleInCurrentCode(request: request, currentUserId: currentUserId, buttonType: buttonType)

    // EXPECTED BEHAVIOR: button should NOT be visible for unauthorized users
    // If the button IS visible, that's a counterexample proving the bug
    if isVisible {
        failures.append((request: request, currentUserId: currentUserId, buttonType: buttonType, isVisible: isVisible))
    }
}

// MARK: - Report Results

print()
if failures.isEmpty {
    print("✅ ALL \(numberOfTrials) TRIALS PASSED")
    print("   No unauthorized users saw action buttons.")
    print("   (This would mean the bug is already fixed)")
    exit(0)
} else {
    print("❌ TEST FAILED: \(failures.count)/\(numberOfTrials) trials produced counterexamples")
    print()
    print("This confirms the bug exists: unauthorized users CAN see action buttons")
    print("they should not have access to under the current (buggy) actionsSection logic.")
    print()
    print("--- COUNTEREXAMPLES (first 10) ---")
    print()

    for (index, failure) in failures.prefix(10).enumerated() {
        let claimerStr = failure.request.claimerId?.id ?? "nil"
        print("  Counterexample \(index + 1):")
        print("    currentUserId: \"\(failure.currentUserId)\"")
        print("    requestorId: \"\(failure.request.requestorId.id)\"")
        print("    claimerId: \"\(claimerStr)\"")
        print("    status: .\(failure.request.status.rawValue)")
        print("    buttonType: \"\(failure.buttonType.rawValue)\"")
        print("    isVisible (actual): \(failure.isVisible)")
        print("    isVisible (expected): false")

        // Describe the specific violation
        switch failure.buttonType {
        case .completeWithPhoto:
            print("    violation: Non-claimer sees \"Complete with Photo\" button")
        case .completeWithoutPhoto:
            print("    violation: Non-claimer sees \"Complete without Photo\" button")
        case .cancelRequest:
            print("    violation: Non-requestor sees \"Cancel Request\" button")
        }
        print()
    }

    // Categorize failures
    let completeWithPhotoFailures = failures.filter { $0.buttonType == .completeWithPhoto }.count
    let completeWithoutPhotoFailures = failures.filter { $0.buttonType == .completeWithoutPhoto }.count
    let cancelClaimedFailures = failures.filter { $0.buttonType == .cancelRequest && $0.request.status == .claimed }.count
    let cancelCompletedFailures = failures.filter { $0.buttonType == .cancelRequest && $0.request.status == .completed }.count
    let cancelPartialFailures = failures.filter { $0.buttonType == .cancelRequest && ($0.request.status == .partiallyClaimed || $0.request.status == .partiallyCompleted) }.count

    print("--- FAILURE BREAKDOWN ---")
    print()
    print("  Complete with Photo (non-claimer, .claimed): \(completeWithPhotoFailures) failures")
    print("  Complete without Photo (non-claimer, .claimed): \(completeWithoutPhotoFailures) failures")
    print("  Cancel Request (non-requestor, .claimed): \(cancelClaimedFailures) failures")
    print("  Cancel Request (non-requestor, .completed): \(cancelCompletedFailures) failures")
    print("  Cancel Request (non-requestor, .partiallyClaimed/.partiallyCompleted): \(cancelPartialFailures) failures")
    print()

    print("--- ROOT CAUSE ---")
    print()
    print("The actionsSection function in GrabRequestDetailView.swift renders buttons")
    print("without checking user roles in the .claimed, .completed, .partiallyClaimed,")
    print("and .partiallyCompleted cases:")
    print("  - .claimed: Complete buttons have no isClaimer check")
    print("  - .claimed: Cancel button has no isRequestor check")
    print("  - .completed: Cancel button has no isRequestor check")
    print("  - .partiallyClaimed/.partiallyCompleted: Cancel button has no isRequestor check")
    print("  - Only .open correctly wraps Cancel in 'if isRequestor'")
    print()
    exit(1)
}
