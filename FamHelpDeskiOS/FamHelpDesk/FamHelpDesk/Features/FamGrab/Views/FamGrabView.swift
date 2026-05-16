import SwiftUI

struct FamGrabView: View {
    let familyId: String

    @State private var viewModel = FamGrabViewModel()
    @State private var selectedTab: GrabTab = .openRequests
    @State private var showCreateRequest = false

    enum GrabTab: String, CaseIterable {
        case openRequests = "Open"
        case myRequests = "My Requests"
        case leaderboard = "Leaderboard"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Balance Section
            VStack(spacing: 12) {
                if viewModel.isLoadingBalance, viewModel.balance == nil {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
                } else {
                    EmbolecBalanceView(balance: viewModel.balance)
                }

                Button {
                    showCreateRequest = true
                } label: {
                    Label("New Request", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Tab Picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(GrabTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Tab Content
            TabView(selection: $selectedTab) {
                GrabRequestListView(
                    viewModel: viewModel,
                    familyId: familyId,
                    filterStatus: .open,
                    userRole: nil
                )
                .tag(GrabTab.openRequests)

                GrabRequestListView(
                    viewModel: viewModel,
                    familyId: familyId,
                    filterStatus: nil,
                    userRole: "requestor"
                )
                .tag(GrabTab.myRequests)

                LeaderboardView(
                    viewModel: viewModel,
                    familyId: familyId
                )
                .tag(GrabTab.leaderboard)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .sheet(isPresented: $showCreateRequest) {
            CreateRequestView(viewModel: viewModel, familyId: familyId)
        }
        .task {
            await viewModel.loadBalance(familyId: familyId)
            await viewModel.loadRequests(familyId: familyId, status: .open, refresh: true)
            await viewModel.loadLeaderboard(familyId: familyId)
        }
        .onChange(of: selectedTab) { _, newTab in
            Task {
                switch newTab {
                case .openRequests:
                    await viewModel.loadRequests(familyId: familyId, status: .open, refresh: true)
                case .myRequests:
                    await viewModel.loadRequests(familyId: familyId, userRole: "requestor", refresh: true)
                case .leaderboard:
                    if viewModel.leaderboard.isEmpty {
                        await viewModel.loadLeaderboard(familyId: familyId)
                    }
                }
            }
        }
    }
}

#Preview {
    FamGrabView(familyId: "family-123")
}
