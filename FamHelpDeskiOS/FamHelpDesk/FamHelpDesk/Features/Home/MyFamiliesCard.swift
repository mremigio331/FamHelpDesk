import SwiftUI

struct MyFamiliesCard: View {
    @State private var familySession = FamilySession.shared
    @Binding var showCreateFamily: Bool

    var body: some View {
        Section {
            if familySession.isFetching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let errorMessage = familySession.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Error", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if familySession.familiesArray.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("You are not part of any families yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(familySession.familiesArray, id: \.family.id) { item in
                    NavigationLink(value: item.family) {
                        FamilyRow(family: item.family, membership: item.membership)
                    }
                }
            }
        } header: {
            HStack {
                Label("My Families", systemImage: "person.3.fill")
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        showCreateFamily = true
                    } label: {
                        Label("Create", systemImage: "plus.circle.fill")
                            .font(.caption)
                    }

                    if !familySession.isFetching {
                        Button {
                            Task {
                                await familySession.refresh()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .task {
            if familySession.familiesArray.isEmpty && !familySession.isFetching {
                await familySession.fetchMyFamilies()
            }
        }
    }
}

struct FamilyRow: View {
    let family: Family
    let membership: FamilyMembership

    private var statusColor: Color {
        membership.status == "MEMBER" ? .green : .orange
    }

    private var statusText: String {
        membership.status == "MEMBER" ? "Member" : "Pending"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(family.familyName)
                    .font(.headline)
                Spacer()
                Text(statusText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }

            if let description = family.familyDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Text("Created: \(formatDate(family.createdAt))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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
        List {
            MyFamiliesCard(showCreateFamily: .constant(false))
        }
    }
    .environmentObject(AuthManager())
}
