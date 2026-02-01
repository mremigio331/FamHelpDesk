//
//  SeverityEducationSection.swift
//  FamHelpDesk
//
//  Created for iOS UX Improvements
//

import SwiftUI

/// A collapsible section that displays educational information about all severity levels
struct SeverityEducationSection: View {
    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(SeverityInfo.allSeverities) { severity in
                        SeverityInfoRow(severity: severity)

                        if severity.id != SeverityInfo.allSeverities.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.top, 8)
            },
            label: {
                Label("Severity Levels Guide", systemImage: "info.circle")
                    .font(.headline)
            }
        )
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

#Preview {
    SeverityEducationSection()
        .padding()
}
