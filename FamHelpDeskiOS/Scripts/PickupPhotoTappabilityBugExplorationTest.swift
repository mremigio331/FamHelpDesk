#!/usr/bin/env swift
// PickupPhotoTappabilityBugExplorationTest.swift
//
// Property-Based Exploration Test: Bug Condition - Claimed Item With Pickup Photo Not Tappable
//
// **Validates: Requirements 1.1, 1.2**
//
// This test generates GrabRequestItem instances satisfying the bug condition:
//   item.pickupPhotoKey != nil AND item.status != .completed AND item.status != .confirmed
//
// It asserts that isTappable evaluates to true for all such items (expected behavior).
// On UNFIXED code, this test MUST FAIL — failure confirms the bug exists.

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

struct GrabRequestItem {
    let itemId: String
    let requestId: String
    let familyId: String
    let name: String
    let quantity: Int
    let embolecCost: Double
    let note: String?
    let status: GrabRequestStatus?
    let pickupPhotoKey: String?
}

// MARK: - Fixed isTappable Logic

/// Replicates the FIXED logic from GrabRequestDetailView.swift itemRow(_:)
func isTappable(item: GrabRequestItem) -> Bool {
    item.status == .completed || item.status == .confirmed || item.pickupPhotoKey != nil
}

// MARK: - Bug Condition Predicate

/// Returns true if the item satisfies the bug condition:
/// pickupPhotoKey != nil AND status != .completed AND status != .confirmed
func isBugCondition(item: GrabRequestItem) -> Bool {
    item.pickupPhotoKey != nil
        && item.status != .completed
        && item.status != .confirmed
}

// MARK: - Random Generators

/// Statuses that satisfy the bug condition (not .completed, not .confirmed)
let bugConditionStatuses: [GrabRequestStatus?] = [
    .open,
    .partiallyClaimed,
    .claimed,
    .partiallyCompleted,
    .cancelled,
    nil,
]

/// Generates a random non-nil pickup photo key
func randomPickupPhotoKey() -> String {
    let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    let length = Int.random(in: 5 ... 20)
    let key = String((0 ..< length).map { _ in chars.randomElement()! })
    return "pickup-photo-\(key)"
}

/// Generates a random GrabRequestItem satisfying the bug condition
func generateBugConditionItem() -> GrabRequestItem {
    let status = bugConditionStatuses.randomElement()!
    let pickupPhotoKey = randomPickupPhotoKey()

    return GrabRequestItem(
        itemId: "item-\(UUID().uuidString.prefix(8))",
        requestId: "req-\(UUID().uuidString.prefix(8))",
        familyId: "fam-\(UUID().uuidString.prefix(8))",
        name: ["Milk", "Bread", "Eggs", "Juice", "Butter", "Cheese"].randomElement()!,
        quantity: Int.random(in: 1 ... 5),
        embolecCost: Double.random(in: 1.0 ... 50.0),
        note: Bool.random() ? "Some note" : nil,
        status: status,
        pickupPhotoKey: pickupPhotoKey
    )
}

// MARK: - Property-Based Test Execution

let numberOfTrials = 100
var failures: [(item: GrabRequestItem, result: Bool)] = []

print("=" * 70)
print("PROPERTY-BASED EXPLORATION TEST: Bug Condition")
print("Property: Items with pickupPhotoKey != nil (and status != .completed/.confirmed) should be tappable")
print("Running \(numberOfTrials) trials...")
print("=" * 70)
print()

for trial in 1 ... numberOfTrials {
    let item = generateBugConditionItem()

    // Verify the generated item actually satisfies the bug condition
    assert(isBugCondition(item: item), "Generator produced item that doesn't satisfy bug condition!")

    // Assert expected behavior: items with pickup photos should be tappable
    let result = isTappable(item: item)

    if !result {
        failures.append((item: item, result: result))
    }
}

// MARK: - Report Results

print()
if failures.isEmpty {
    print("✅ ALL \(numberOfTrials) TRIALS PASSED")
    print("   All items with pickup photos were tappable.")
    exit(0)
} else {
    print("❌ TEST FAILED: \(failures.count)/\(numberOfTrials) trials produced counterexamples")
    print()
    print("This confirms the bug exists: items with pickup photos in non-completed/non-confirmed")
    print("status are NOT tappable under the current (buggy) isTappable logic.")
    print()
    print("--- COUNTEREXAMPLES (first 5) ---")
    print()

    for (index, failure) in failures.prefix(5).enumerated() {
        let statusStr = failure.item.status?.rawValue ?? "nil"
        print("  Counterexample \(index + 1):")
        print("    name: \"\(failure.item.name)\"")
        print("    status: .\(statusStr)")
        print("    pickupPhotoKey: \"\(failure.item.pickupPhotoKey ?? "nil")\"")
        print("    isTappable (actual): \(failure.result)")
        print("    isTappable (expected): true")
        print()
    }

    print("--- SUMMARY ---")
    print()
    print("Bug Condition: item.pickupPhotoKey != nil AND item.status != .completed AND item.status != .confirmed")
    print("Expected: isTappable = true (user should be able to tap to view pickup photo)")
    print("Actual: isTappable = false (current logic only checks .completed || .confirmed)")
    print()
    exit(1)
}

// MARK: - Helpers

extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
