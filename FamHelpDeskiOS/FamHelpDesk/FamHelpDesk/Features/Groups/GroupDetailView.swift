import SwiftUI

struct GroupDetailView: View {
    let group: FamilyGroup

    var body: some View {
        List {
            // Group Information Section
            Section("Group Information") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "rectangle.3.group.fill")
                            .font(.title)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.groupName)
                                .font(.title2)
                                .fontWeight(.bold)

                            if let description = group.groupDescription, !description.isEmpty {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Divider()

                    HStack {
                        Text("Created")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(group.createdAt))
                    }

                    HStack {
                        Text("Group ID")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(group.groupId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 8)
            }

            // Members Section - Coming Soon
            Section("Members") {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    Text("Coming Soon")
                        .font(.headline)
                    Text("Group member management will be available here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle(group.groupName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GroupDetailView(
            group: FamilyGroup(
                groupId: "group123",
                familyId: "family123",
                groupName: "Family Activities",
                groupDescription: "Planning and organizing family activities and events",
                createdBy: "user123",
                creationDate: Date().timeIntervalSince1970
            )
        )
    }
}
