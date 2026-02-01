//
//  SeverityInfoRow.swift
//  FamHelpDesk
//
//  Created for iOS UX Improvements
//

import SwiftUI

/// A view component that displays information about a single severity level
struct SeverityInfoRow: View {
    let severity: SeverityInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(severity.name)
                .font(.subheadline)
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
    }
}

#Preview {
    SeverityInfoRow(severity: SeverityInfo.allSeverities[0])
        .padding()
}
