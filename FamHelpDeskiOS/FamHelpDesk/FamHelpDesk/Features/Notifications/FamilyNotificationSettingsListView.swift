import SwiftUI

struct FamilyNotificationSettingsListView: View {
    @State private var familySession = FamilySession.shared

    var body: some View {
        Group {
            if familySession.isFetching {
                ProgressView("Loading families...")
            } else if familySession.familiesArray.isEmpty {
                ContentUnavailableView(
                    "No Families",
                    systemImage: "person.3",
                    description: Text("You are not a member of any families yet")
                )
            } else {
                List {
                    ForEach(familySession.familiesArray, id: \.family.familyId) { familyItem in
                        NavigationLink(destination: FamilyNotificationSettingsView(
                            familyId: familyItem.family.familyId,
                            familyName: familyItem.family.familyName
                        )) {
                            HStack {
                                Image(systemName: "person.3.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(familyItem.family.familyName)
                                        .font(.body)
                                        .fontWeight(.medium)

                                    if let description = familyItem.family.familyDescription, !description.isEmpty {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Family Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if familySession.familiesArray.isEmpty {
                await familySession.fetchMyFamilies()
            }
        }
        .refreshable {
            await familySession.refresh()
        }
    }
}

#Preview {
    NavigationStack {
        FamilyNotificationSettingsListView()
    }
}
