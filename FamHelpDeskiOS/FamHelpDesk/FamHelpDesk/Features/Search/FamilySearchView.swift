import SwiftUI

struct FamilySearchView: View {
    @State private var searchText = ""
    @State private var families: [Family] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let searchService = SearchService()
    private let membershipService = MembershipService()
    @State private var familySession = FamilySession.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText, onSearchButtonClicked: performSearch)
                    .padding()

                // Content
                if isLoading {
                    FamilyLoadingSkeletonView()
                } else if families.isEmpty, !searchText.isEmpty {
                    EmptySearchView()
                } else if families.isEmpty {
                    InitialSearchView()
                } else {
                    FamilySearchResultsList(families: families, onRefresh: refreshSearchData)
                }

                Spacer()
            }
            .navigationTitle("Find Families")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
        .task {
            await loadAllFamilies()
        }
    }

    private func performSearch() {
        Task {
            await searchFamilies()
        }
    }

    @MainActor
    private func loadAllFamilies() async {
        isLoading = true
        do {
            // Load both all families and user's families to determine membership status
            async let allFamiliesTask = searchService.getAllFamilies()
            async let myFamiliesTask = familySession.fetchMyFamilies()

            // Wait for both requests to complete
            families = try await allFamiliesTask
            await myFamiliesTask
        } catch {
            errorMessage = "Failed to load families: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }

    @MainActor
    private func searchFamilies() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await loadAllFamilies()
            return
        }

        isLoading = true
        do {
            // Load both search results and user's families to determine membership status
            async let searchTask = searchService.searchFamilies(query: searchText)
            async let myFamiliesTask = familySession.fetchMyFamilies()

            // Wait for both requests to complete
            families = try await searchTask
            await myFamiliesTask
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }
    
    @MainActor
    private func refreshSearchData() async {
        // Refresh both search results and family membership data
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await loadAllFamilies()
        } else {
            await searchFamilies()
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let onSearchButtonClicked: () -> Void

    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search families...", text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        onSearchButtonClicked()
                    }

                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        onSearchButtonClicked()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            if !text.isEmpty {
                Button("Search") {
                    onSearchButtonClicked()
                }
                .foregroundColor(.blue)
            }
        }
    }
}

struct FamilySearchResultsList: View {
    let families: [Family]
    @State private var familySession = FamilySession.shared
    let onRefresh: () async -> Void

    var body: some View {
        List(families) { family in
            FamilySearchItem(family: family)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await onRefresh()
        }
    }
}

struct FamilySearchItem: View {
    let family: Family
    @State private var familySession = FamilySession.shared
    @State private var membershipService = MembershipService()
    @State private var isRequestingMembership = false
    @State private var showError = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Family Info
            VStack(alignment: .leading, spacing: 4) {
                Text(family.familyName)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let description = family.familyDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text("Created \(formatDate(family.creationDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Membership Status and Actions
            HStack {
                membershipStatusView
                Spacer()
                membershipActionButton
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    @ViewBuilder
    private var membershipStatusView: some View {
        if let myFamily = familySession.myFamilies[family.familyId] {
            let status = myFamily.membership.status
            switch status {
            case "MEMBER":
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Member")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            case "AWAITING":
                HStack(spacing: 4) {
                    Image(systemName: "clock.circle.fill")
                        .foregroundColor(.orange)
                    Text("Request Pending")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            default:
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(.blue)
                    Text("Not a member")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "person.badge.plus")
                    .foregroundColor(.blue)
                Text("Not a member")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var membershipActionButton: some View {
        if let myFamily = familySession.myFamilies[family.familyId] {
            let status = myFamily.membership.status
            switch status {
            case "MEMBER":
                // Already a member - show view button
                Button(action: {
                    NavigationContext.shared.navigateToFamily(family)
                }) {
                    Text("View")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            case "AWAITING":
                // Request is pending - show pending status
                Text("Pending")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            default:
                // Other status - show request button
                Button(action: requestMembership) {
                    if isRequestingMembership {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                    } else {
                        Text("Request to Join")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .cornerRadius(8)
                .disabled(isRequestingMembership)
            }
        } else {
            // Not a member - show request membership button
            Button(action: requestMembership) {
                if isRequestingMembership {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                } else {
                    Text("Request to Join")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .cornerRadius(8)
            .disabled(isRequestingMembership)
        }
    }

    private func requestMembership() {
        Task {
            await performMembershipRequest()
        }
    }

    @MainActor
    private func performMembershipRequest() async {
        isRequestingMembership = true
        do {
            try await membershipService.requestFamilyMembership(familyId: family.familyId)
            // Refresh family data to update membership status
            await familySession.fetchMyFamilies()
        } catch {
            errorMessage = "Failed to request membership: \(error.localizedDescription)"
            showError = true
        }
        isRequestingMembership = false
    }

    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct FamilyLoadingSkeletonView: View {
    var body: some View {
        List {
            ForEach(0 ..< 6, id: \.self) { _ in
                FamilySkeletonItem()
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct FamilySkeletonItem: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Family Info Skeleton
            VStack(alignment: .leading, spacing: 8) {
                // Family name skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color.white.opacity(0.6), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: isAnimating ? 200 : -200)
                            .animation(
                                Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                                value: isAnimating
                            )
                    )
                    .clipped()

                // Description skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color.white.opacity(0.4), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: isAnimating ? 200 : -200)
                            .animation(
                                Animation.linear(duration: 1.5).repeatForever(autoreverses: false).delay(0.2),
                                value: isAnimating
                            )
                    )
                    .clipped()

                // Date skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 12)
                    .frame(width: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color.white.opacity(0.3), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: isAnimating ? 120 : -120)
                            .animation(
                                Animation.linear(duration: 1.5).repeatForever(autoreverses: false).delay(0.4),
                                value: isAnimating
                            )
                    )
                    .clipped()
            }

            // Bottom row skeleton
            HStack {
                // Status skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color.white.opacity(0.4), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: isAnimating ? 80 : -80)
                            .animation(
                                Animation.linear(duration: 1.5).repeatForever(autoreverses: false).delay(0.6),
                                value: isAnimating
                            )
                    )
                    .clipped()

                Spacer()

                // Button skeleton
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 100, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color.white.opacity(0.5), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: isAnimating ? 100 : -100)
                            .animation(
                                Animation.linear(duration: 1.5).repeatForever(autoreverses: false).delay(0.8),
                                value: isAnimating
                            )
                    )
                    .clipped()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .onAppear {
            isAnimating = true
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading families...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No families found")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Try adjusting your search terms")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct InitialSearchView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "house.and.flag")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Discover Families")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Search for families to join or browse all available families")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    FamilySearchView()
}
