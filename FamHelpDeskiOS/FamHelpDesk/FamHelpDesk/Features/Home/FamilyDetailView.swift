import SwiftUI

struct FamilyDetailView: View {
    let family: Family
    @State private var familySession = FamilySession.shared
    @State private var navigationContext = NavigationContext.shared

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case members = "Members"
        case groups = "Groups"

        var systemImage: String {
            switch self {
            case .overview:
                "info.circle"
            case .members:
                "person.2"
            case .groups:
                "rectangle.3.group"
            }
        }
    }

    private var familyItem: MyFamilyItem? {
        familySession.myFamilies[family.familyId]
    }

    private var isAdmin: Bool {
        familyItem?.membership.isAdmin ?? false
    }

    private var selectedTab: Tab {
        get { navigationContext.selectedFamilyTab }
        set { navigationContext.selectedFamilyTab = newValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Tab", selection: Binding(
                get: { selectedTab },
                set: { navigationContext.selectedFamilyTab = $0 }
            )) {
                ForEach(availableTabs, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            // Tab Content
            TabView(selection: Binding(
                get: { selectedTab },
                set: { navigationContext.selectedFamilyTab = $0 }
            )) {
                ForEach(availableTabs, id: \.self) { tab in
                    Group {
                        switch tab {
                        case .overview:
                            overviewContent
                        case .members:
                            FamilyMembersView(family: family)
                        case .groups:
                            FamilyGroupsView(family: family)
                        }
                    }
                    .tag(tab)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle(family.familyName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Update navigation context when this view appears
            navigationContext.selectedFamily = family
        }
    }

    private var availableTabs: [Tab] {
        var tabs: [Tab] = [.overview]

        // Only show members and groups tabs if user is a member
        if let familyItem, familyItem.membership.status == "MEMBER" {
            tabs.append(.members)
            tabs.append(.groups)
        }

        return tabs
    }

    private var overviewContent: some View {
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
                        // User has some relationship with this family
                        HStack {
                            Text("Your Status")
                                .foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 4) {
                                switch item.membership.status {
                                case "MEMBER":
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Member")
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                case "AWAITING":
                                    Image(systemName: "clock.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("Request Pending")
                                        .fontWeight(.medium)
                                        .foregroundColor(.orange)
                                default:
                                    Image(systemName: "person.badge.plus")
                                        .foregroundColor(.blue)
                                    Text(item.membership.status)
                                        .fontWeight(.medium)
                                }
                            }
                        }

                        if item.membership.isAdmin {
                            HStack {
                                Text("Role")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Admin")
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }

                        if item.membership.status != "MEMBER" {
                            // Show message about limited access
                            VStack(alignment: .leading, spacing: 8) {
                                Divider()
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("Limited Access")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                                Text("You can only view basic family information until your membership is approved.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        // User is not a member and hasn't requested membership
                        HStack {
                            Text("Your Status")
                                .foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.gray)
                                Text("Not a member")
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Divider()
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("Limited Access")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                            Text("You can only view basic family information. Request membership to access members and groups.")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
        }
        .refreshable {
            await refreshFamilyData()
        }
    }

    private func refreshFamilyData() async {
        // Refresh family session to update membership status
        await familySession.refresh()
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
