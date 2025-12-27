import SwiftUI

struct FamilyDetailView: View {
    let family: Family
    @State private var familySession = FamilySession.shared

    private var familyItem: MyFamilyItem? {
        familySession.myFamilies[family.familyId]
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .font(.title)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(family.familyName)
                                .font(.title2)
                                .fontWeight(.bold)

                            if let description = family.familyDescription, !description.isEmpty {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Divider()

                    if let item = familyItem {
                        HStack {
                            Text("Your Status")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(item.membership.status == "MEMBER" ? "Member" : "Pending")
                                .fontWeight(.medium)
                        }
                    }

                    HStack {
                        Text("Created")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(family.createdAt))
                    }

                    HStack {
                        Text("Family ID")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(family.familyId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Groups") {
                VStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    Text("Coming Soon")
                        .font(.headline)
                    Text("Groups for this family will be displayed here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            Section("Members") {
                VStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    Text("Coming Soon")
                        .font(.headline)
                    Text("Family members will be displayed here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            Section("Tickets") {
                VStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    Text("Coming Soon")
                        .font(.headline)
                    Text("Support tickets for this family will be displayed here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Family Details")
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

#Preview {
    NavigationStack {
        FamilyDetailView(
            family: Family(
                familyId: "123",
                familyName: "Smith Family",
                familyDescription: "Our family group",
                createdBy: "user123",
                creationDate: Date().timeIntervalSince1970
            )
        )
    }
}
