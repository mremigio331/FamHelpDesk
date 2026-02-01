//
//  SeverityPickerWithInfo.swift
//  FamHelpDesk
//
//  Created for iOS UX Improvements
//

import SwiftUI

/// A custom severity picker that displays severity name and description for each option
/// Shows compact view by default, expands to show full details when interacted with
struct SeverityPickerWithInfo: View {
    @Binding var selectedSeverity: TicketSeverity
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Compact picker view
            if !isExpanded {
                Button(action: {
                    withAnimation {
                        isExpanded = true
                    }
                }) {
                    HStack {
                        Text(selectedSeverityName)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Expanded picker with descriptions
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Select Severity")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            withAnimation {
                                isExpanded = false
                            }
                        }) {
                            Image(systemName: "chevron.up")
                                .foregroundColor(.secondary)
                        }
                    }

                    ForEach(SeverityInfo.allSeverities) { severity in
                        Button(action: {
                            if let ticketSeverity = severityInfoToTicketSeverity(severity) {
                                selectedSeverity = ticketSeverity
                                withAnimation {
                                    isExpanded = false
                                }
                            }
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: isSelected(severity) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected(severity) ? .accentColor : .secondary)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(severity.name)
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)

                                    Text(severity.description)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    Text(severity.scope)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }

                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected(severity) ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private var selectedSeverityName: String {
        let severity = SeverityInfo.allSeverities.first { severityInfo in
            guard let ticketSeverity = severityInfoToTicketSeverity(severityInfo) else {
                return false
            }
            return selectedSeverity == ticketSeverity
        }
        return severity?.name ?? "Select Severity"
    }

    private func isSelected(_ severity: SeverityInfo) -> Bool {
        guard let ticketSeverity = severityInfoToTicketSeverity(severity) else {
            return false
        }
        return selectedSeverity == ticketSeverity
    }

    private func severityInfoToTicketSeverity(_ severity: SeverityInfo) -> TicketSeverity? {
        switch severity.id {
        case "SEV_1":
            .sev1
        case "SEV_2":
            .sev2
        case "SEV_2_5":
            .sev2_5
        case "SEV_3":
            .sev3
        case "SEV_4":
            .sev4
        case "SEV_5":
            .sev5
        default:
            nil
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedSeverity: TicketSeverity = .sev3

        var body: some View {
            Form {
                SeverityPickerWithInfo(selectedSeverity: $selectedSeverity)
            }
        }
    }

    return PreviewWrapper()
}
