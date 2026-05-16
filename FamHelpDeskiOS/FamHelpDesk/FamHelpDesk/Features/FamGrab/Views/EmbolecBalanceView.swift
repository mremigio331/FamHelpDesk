import SwiftUI

struct EmbolecBalanceView: View {
    let balance: EmbolecBalance?

    var body: some View {
        VStack(spacing: 12) {
            if let balance {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Embolec Balance")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(balance.balance.embolecFormatted)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(balance.balance >= 0 ? .primary : .red)

                            Text("E")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(balance.totalEarned.embolecFormatted)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text(balance.totalSpent.embolecFormatted)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                    }
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Embolec Balance")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("--")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        EmbolecBalanceView(balance: EmbolecBalance(
            familyId: "fam-1",
            userId: "user-1",
            balance: 42.5,
            lastRefreshDate: Date().timeIntervalSince1970,
            totalEarned: 150.75,
            totalSpent: 108.25
        ))

        EmbolecBalanceView(balance: nil)
    }
    .padding()
}
