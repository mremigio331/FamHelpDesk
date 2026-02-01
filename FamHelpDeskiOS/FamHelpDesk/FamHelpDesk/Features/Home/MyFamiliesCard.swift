import SwiftUI

struct MyFamiliesCard: View {
    @State private var familySession = FamilySession.shared
    @Binding var showCreateFamily: Bool
    var onFindFamilies: (() -> Void)?

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
                EmptyFamiliesView(onFindFamilies: {
                    onFindFamilies?()
                })
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(familySession.familiesArray.sorted { $0.family.familyName.localizedCaseInsensitiveCompare($1.family.familyName) == .orderedAscending }, id: \.family.id) { item in
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
            if familySession.familiesArray.isEmpty, !familySession.isFetching {
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
                HStack(spacing: 6) {
                    if family.isPrivate {
                        Text("Private")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                    }
                    Text(statusText)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(4)
                }
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
            MyFamiliesCard(showCreateFamily: .constant(false), onFindFamilies: {
                print("Find families tapped")
            })
        }
    }
    .environmentObject(AuthManager())
}
