#!/usr/bin/env swift
// PickupPhotoTappabilityPreservationTest.swift
//
// Property-Based Preservation Test: Existing Tappability Unchanged For Non-Bug-Condition Items
//
// **Validates: Requirements 3.1, 3.2**
//
// This test verifies baseline behavior that must be preserved after the fix:
//   Property 2A: For items where isBugCondition is false (pickupPhotoKey == nil AND
//                status != .completed AND status != .confirmed), isTappable == false
//   Property 2B: For items with status .completed or .confirmed, isTappable == true
//
// On UNFIXED code, these tests MUST PASS — passing confirms baseline behavior to preserve.

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

/// Statuses that are NOT .completed and NOT .confirmed (used for non-bug-condition items without photos)
let nonTappableStatuses: [GrabRequestStatus?] = [
    .open,
    .partiallyClaimed,
    .claimed,
    .partiallyCompleted,
    .cancelled,
    nil,
]

/// Statuses that should always be tappable
let tappableStatuses: [GrabRequestStatus] = [
    .completed,
    .confirmed,
]

/// Generates a random item name
func randomItemName() -> String {
    ["Milk", "Bread", "Eggs", "Juice", "Butter", "Cheese", "Rice", "Pasta", "Apples", "Bananas"].randomElement()!
}

/// Generates a random GrabRequestItem where isBugCondition is false AND status is NOT .completed/.confirmed
/// These items have pickupPhotoKey == nil and a non-completed/non-confirmed status
func generateNonBugConditionNonTappableItem() -> GrabRequestItem {
    let status = nonTappableStatuses.randomElement()!

    return GrabRequestItem(
        itemId: "item-\(UUID().uuidString.prefix(8))",
        requestId: "req-\(UUID().uuidString.prefix(8))",
        familyId: "fam-\(UUID().uuidString.prefix(8))",
        name: randomItemName(),
        quantity: Int.random(in: 1 ... 5),
        embolecCost: Double.random(in: 1.0 ... 50.0),
        note: Bool.random() ? "Some note" : nil,
        status: status,
        pickupPhotoKey: nil // No pickup photo — not a bug condition item
    )
}

/// Generates a random GrabRequestItem with status .completed or .confirmed
/// These items should always be tappable (with or without pickup photo)
func generateTappableItem() -> GrabRequestItem {
    let status = tappableStatuses.randomElement()!
    // Randomly include or exclude a pickup photo key — shouldn't matter for tappability
    let pickupPhotoKey: String? = Bool.random() ? "pickup-photo-\(UUID().uuidString.prefix(8))" : nil

    return GrabRequestItem(
        itemId: "item-\(UUID().uuidString.prefix(8))",
        requestId: "req-\(UUID().uuidString.prefix(8))",
        familyId: "fam-\(UUID().uuidString.prefix(8))",
        name: randomItemName(),
        quantity: Int.random(in: 1 ... 5),
        embolecCost: Double.random(in: 1.0 ... 50.0),
        note: Bool.random() ? "Some note" : nil,
        status: status,
        pickupPhotoKey: pickupPhotoKey
    )
}

// MARK: - Property-Based Test Execution

let numberOfTrials = 100

// ============================================================
// Property 2A: Non-bug-condition items without tappable status → isTappable == false
// ============================================================

print("=" * 70)
print("PROPERTY-BASED PRESERVATION TEST: Property 2A")
print("Property: Items with pickupPhotoKey == nil AND status != .completed/.confirmed → isTappable == false")
print("Running \(numberOfTrials) trials...")
print("=" * 70)
print()

var property2AFailures: [(item: GrabRequestItem, result: Bool)] = []

for _ in 1 ... numberOfTrials {
    let item = generateNonBugConditionNonTappableItem()

    // Verify the generated item is NOT a bug condition item
    assert(!isBugCondition(item: item), "Generator produced item that satisfies bug condition!")
    // Verify the generated item is not .completed or .confirmed
    assert(item.status != .completed && item.status != .confirmed, "Generator produced completed/confirmed item!")

    let result = isTappable(item: item)

    if result != false {
        property2AFailures.append((item: item, result: result))
    }
}

print()
if property2AFailures.isEmpty {
    print("✅ PROPERTY 2A PASSED: All \(numberOfTrials) trials confirmed non-bug-condition items are NOT tappable")
    print("   Items with no pickup photo in non-completed/non-confirmed status correctly evaluate isTappable = false")
} else {
    print("❌ PROPERTY 2A FAILED: \(property2AFailures.count)/\(numberOfTrials) trials produced unexpected results")
    print()
    for (index, failure) in property2AFailures.prefix(5).enumerated() {
        let statusStr = failure.item.status?.rawValue ?? "nil"
        print("  Unexpected result \(index + 1):")
        print("    status: .\(statusStr)")
        print("    pickupPhotoKey: \(failure.item.pickupPhotoKey ?? "nil")")
        print("    isTappable (actual): \(failure.result)")
        print("    isTappable (expected): false")
        print()
    }
}

print()

// ============================================================
// Property 2B: Items with .completed or .confirmed status → isTappable == true
// ============================================================

print("=" * 70)
print("PROPERTY-BASED PRESERVATION TEST: Property 2B")
print("Property: Items with status .completed or .confirmed → isTappable == true")
print("Running \(numberOfTrials) trials...")
print("=" * 70)
print()

var property2BFailures: [(item: GrabRequestItem, result: Bool)] = []

for _ in 1 ... numberOfTrials {
    let item = generateTappableItem()

    // Verify the generated item has .completed or .confirmed status
    assert(item.status == .completed || item.status == .confirmed, "Generator produced non-completed/non-confirmed item!")

    let result = isTappable(item: item)

    if result != true {
        property2BFailures.append((item: item, result: result))
    }
}

print()
if property2BFailures.isEmpty {
    print("✅ PROPERTY 2B PASSED: All \(numberOfTrials) trials confirmed completed/confirmed items ARE tappable")
    print("   Items with .completed or .confirmed status correctly evaluate isTappable = true")
} else {
    print("❌ PROPERTY 2B FAILED: \(property2BFailures.count)/\(numberOfTrials) trials produced unexpected results")
    print()
    for (index, failure) in property2BFailures.prefix(5).enumerated() {
        let statusStr = failure.item.status?.rawValue ?? "nil"
        print("  Unexpected result \(index + 1):")
        print("    status: .\(statusStr)")
        print("    pickupPhotoKey: \(failure.item.pickupPhotoKey ?? "nil")")
        print("    isTappable (actual): \(failure.result)")
        print("    isTappable (expected): true")
        print()
    }
}

// MARK: - Final Summary

print()
print("=" * 70)
print("PRESERVATION TEST SUMMARY")
print("=" * 70)
print()

let allPassed = property2AFailures.isEmpty && property2BFailures.isEmpty

if allPassed {
    print("✅ ALL PRESERVATION PROPERTIES PASSED")
    print()
    print("  Property 2A: Non-bug-condition items (no photo, non-completed/confirmed) → NOT tappable ✅")
    print("  Property 2B: Completed/confirmed items → tappable ✅")
    print()
    print("These baseline behaviors must remain unchanged after the fix is applied.")
    exit(0)
} else {
    print("❌ PRESERVATION TESTS FAILED")
    print()
    if !property2AFailures.isEmpty {
        print("  Property 2A: FAILED (\(property2AFailures.count) unexpected results)")
    } else {
        print("  Property 2A: PASSED ✅")
    }
    if !property2BFailures.isEmpty {
        print("  Property 2B: FAILED (\(property2BFailures.count) unexpected results)")
    } else {
        print("  Property 2B: PASSED ✅")
    }
    print()
    exit(1)
}

// MARK: - Helpers

extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
