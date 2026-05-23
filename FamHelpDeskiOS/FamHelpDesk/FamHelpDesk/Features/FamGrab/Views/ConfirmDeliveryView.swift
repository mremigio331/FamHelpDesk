import SwiftUI

struct ConfirmDeliveryView: View {
    @Bindable var viewModel: FamGrabViewModel
    let familyId: String
    let request: GrabRequest
    let selectedItems: [GrabRequestItem]

    @State private var tipAmount = ""
    @State private var selectedTipPercent: Int? = nil
    @State private var itemRatings: [String: Int] = [:]
    @State private var itemComments: [String: String] = [:]
    @State private var isConfirming = false
    @State private var itemPhotoUrls: [String: URL] = [:]
    @State private var isLoadingPhotos = false
    @Environment(\.dismiss) private var dismiss

    private var totalCost: Double {
        selectedItems.reduce(0) { $0 + $1.embolecCost }
    }

    private var computedTip: Double? {
        if let percent = selectedTipPercent {
            return totalCost * Double(percent) / 100.0
        }
        if let custom = Double(tipAmount), custom > 0 {
            return custom
        }
        return nil
    }

    private var distinctClaimerIds: [String] {
        Array(Set(selectedItems.compactMap { $0.claimerId?.id }))
    }

    private var hasMultipleClaimers: Bool {
        distinctClaimerIds.count > 1
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.green)

                        Text("Confirm Delivery")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Confirm \(selectedItems.count) item\(selectedItems.count == 1 ? "" : "s") from \"\(request.title)\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Delivery Photo
                    deliveryPhotoSection

                    // Items
                    itemsSection

                    // Cost Summary
                    costSummarySection

                    // Tip (Optional)
                    tipSection

                    // Rating (Optional)
                    ratingSection

                    // Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Confirm Delivery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await loadDeliveryPhotos()
            }
        }
    }

    // MARK: - Delivery Photo

    @ViewBuilder
    private var deliveryPhotoSection: some View {
        let itemsWithPhotos = selectedItems.filter { $0.proofPhotoKey != nil }
        if !itemsWithPhotos.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Delivery Photos")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if isLoadingPhotos {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .frame(height: 180)
                } else {
                    ForEach(itemsWithPhotos) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let photoUrl = itemPhotoUrls[item.itemId] {
                                AsyncImage(url: photoUrl) { phase in
                                    switch phase {
                                    case let .success(image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxHeight: 220)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    case .failure:
                                        Label("Failed to load photo", systemImage: "exclamationmark.triangle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    case .empty:
                                        ProgressView()
                                            .frame(height: 180)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Label("Photo unavailable", systemImage: "photo")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
        }
    }

    // MARK: - Items

    @ViewBuilder
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Items to Confirm")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(selectedItems) { item in
                HStack {
                    Text(item.name)
                        .font(.subheadline)
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(item.embolecCost.embolecFormatted) E")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
    }

    // MARK: - Cost Summary

    @ViewBuilder
    private var costSummarySection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Items Cost")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(totalCost.embolecFormatted) E")
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }

            if let tip = computedTip {
                HStack {
                    Text("Tip")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("+\(String(format: "%.2f", tip)) E")
                        .fontWeight(.medium)
                        .foregroundColor(.pink)
                }

                Divider()

                HStack {
                    Text("Total Transfer")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(String(format: "%.2f", totalCost + tip)) E")
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
    }

    // MARK: - Tip

    @ViewBuilder
    private var tipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tip")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("Optional")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Percentage buttons
            HStack(spacing: 8) {
                ForEach([25, 50, 75], id: \.self) { percent in
                    Button {
                        if selectedTipPercent == percent {
                            selectedTipPercent = nil
                            tipAmount = ""
                        } else {
                            selectedTipPercent = percent
                            tipAmount = ""
                        }
                    } label: {
                        Text("\(percent)%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedTipPercent == percent ? .pink : .secondary)
                }

                Button {
                    selectedTipPercent = nil
                } label: {
                    Text("Other")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(selectedTipPercent == nil && !tipAmount.isEmpty ? .pink : .secondary)
            }

            // Show computed tip for percentage
            if let percent = selectedTipPercent {
                let tipValue = totalCost * Double(percent) / 100.0
                Text("\(percent)% of \(totalCost.embolecFormatted) E = \(String(format: "%.2f", tipValue)) E")
                    .font(.caption)
                    .foregroundColor(.pink)
            }

            // Custom amount field (shown when no percentage selected or "Other" tapped)
            if selectedTipPercent == nil {
                HStack {
                    TextField("Custom amount", text: $tipAmount)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)

                    Text("E")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
            }

            if hasMultipleClaimers, let tip = computedTip, tip > 0 {
                let claimerCount = distinctClaimerIds.count
                let perClaimer = tip / Double(claimerCount)
                Label("Split among \(claimerCount) claimers: \(String(format: "%.2f", perClaimer)) E each", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
    }

    // MARK: - Rating

    @ViewBuilder
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rate Items")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("Optional")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(selectedItems) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.subheadline)

                    StarRatingView(rating: Binding(
                        get: { itemRatings[item.itemId] ?? 0 },
                        set: { itemRatings[item.itemId] = $0 }
                    ))

                    TextField("Leave a comment (optional)", text: Binding(
                        get: { itemComments[item.itemId] ?? "" },
                        set: { newValue in
                            itemComments[item.itemId] = String(newValue.prefix(200))
                        }
                    ), axis: .vertical)
                        .font(.caption)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2 ... 4)

                    Text("\(itemComments[item.itemId]?.count ?? 0)/200")
                        .font(.caption2)
                        .foregroundColor(
                            (itemComments[item.itemId]?.count ?? 0) >= 200 ? .red : .secondary
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await confirmDelivery() }
            } label: {
                if isConfirming {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Confirm & Transfer Embolecs")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isConfirming)

            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.secondary)

            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Load Photo

    private func loadDeliveryPhotos() async {
        let itemsWithPhotos = selectedItems.filter { $0.proofPhotoKey != nil }
        guard !itemsWithPhotos.isEmpty else { return }
        isLoadingPhotos = true
        for item in itemsWithPhotos {
            if let url = await viewModel.getPhotoUrl(familyId: familyId, requestId: request.requestId, itemId: item.itemId) {
                itemPhotoUrls[item.itemId] = url
            }
        }
        isLoadingPhotos = false
    }

    // MARK: - Confirm Action

    private func confirmDelivery() async {
        isConfirming = true
        viewModel.clearError()

        let tip = computedTip
        let itemIds = selectedItems.map(\.itemId)

        // Build item ratings
        var ratings: [ItemRating]?
        let validRatings = selectedItems.compactMap { item -> ItemRating? in
            guard let stars = itemRatings[item.itemId], stars >= 1 else { return nil }
            let comment = itemComments[item.itemId]?.trimmingCharacters(in: .whitespacesAndNewlines)
            return ItemRating(
                itemId: item.itemId,
                starRating: stars,
                comment: (comment?.isEmpty ?? true) ? nil : comment
            )
        }
        if !validRatings.isEmpty {
            ratings = validRatings
        }

        let success = await viewModel.confirmItems(
            familyId: familyId,
            requestId: request.requestId,
            itemIds: itemIds,
            tipAmount: tip,
            itemRatings: ratings
        )

        isConfirming = false

        if success {
            dismiss()
        }
    }
}
