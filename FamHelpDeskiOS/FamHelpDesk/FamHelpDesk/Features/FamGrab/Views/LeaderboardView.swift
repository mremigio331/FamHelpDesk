import SwiftUI

struct LeaderboardView: View {
    @Bindable var viewModel: FamGrabViewModel
    let familyId: String

    var body: some View {
        Group {
            if viewModel.isLoadingLeaderboard, viewModel.leaderboard.isEmpty {
                ProgressView("Loading leaderboard...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.leaderboard.isEmpty {
                emptyView
            } else {
                leaderboardList
            }
        }
    }

    private var leaderboardList: some View {
        List {
            ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, entry in
                NavigationLink {
                    UserReviewHistoryView(
                        viewModel: viewModel,
                        userId: entry.id,
                        familyId: familyId,
                        displayName: entry.displayName
                    )
                } label: {
                    LeaderboardRow(rank: index + 1, entry: entry)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.loadLeaderboard(familyId: familyId)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Leaderboard Data")
                .font(.headline)

            Text("Complete some Grab Requests to see the leaderboard!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let rank: Int
    let entry: GrabLeaderboardEntry

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                if rank <= 3 {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .foregroundColor(rankColor)
                } else {
                    Text("\(rank)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(rankColor)
                }
            }

            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label("\(entry.fulfillmentCount) items fulfilled", systemImage: "checkmark.seal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 2) {
                    Text(entry.totalEarned.embolecFormatted)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("E")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                if entry.monthlyEarnings > 0 {
                    Text("+\(entry.monthlyEarnings.embolecFormatted) this month")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var rankColor: Color {
        switch rank {
        case 1: .yellow
        case 2: .gray
        case 3: .brown
        default: .secondary
        }
    }
}

#Preview {
    LeaderboardView(
        viewModel: FamGrabViewModel(),
        familyId: "family-123"
    )
}
