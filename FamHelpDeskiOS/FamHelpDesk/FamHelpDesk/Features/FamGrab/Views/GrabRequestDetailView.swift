import SwiftUI

struct GrabRequestDetailView: View {
    @Bindable var viewModel: FamGrabViewModel
    let familyId: String
    let requestId: String

    @State private var showConfirmDelivery = false
    @State private var showDeliveryPhoto = false
    @State private var showCancelAlert = false
    @State private var showCompleteItemSheet = false
    @State private var showConfirmItemSheet = false
    @State private var showItemDetail = false
    @State private var showPickupPhotoSheet = false
    @State private var completingItem: GrabRequestItem?
    @State private var confirmingItem: GrabRequestItem?
    @State private var selectedDetailItem: GrabRequestItem?
    @State private var pickupPhotoItem: GrabRequestItem?
    @State private var isPerformingAction = false
    @State private var userSession = UserSession.shared
    @Environment(\.dismiss) private var dismiss

    private var request: GrabRequest? {
        viewModel.currentRequest
    }

    private var currentUserId: String {
        userSession.currentUser?.userId ?? ""
    }

    private var isRequestor: Bool {
        guard let request else { return false }
        return request.requestorId.id == currentUserId
    }

    var body: some View {
        Group {
            if let request {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection(request)
                        itemsSection(request)
                        if request.proofPhotoKey != nil {
                            photoSection(request)
                        }
                        actionsSection(request)
                    }
                    .padding()
                }
            } else {
                ProgressView("Loading request...")
            }
        }
        .navigationTitle("Request Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadRequest(familyId: familyId, requestId: requestId)
        }
        .sheet(isPresented: $showConfirmDelivery) {
            if let request {
                ConfirmDeliveryView(
                    viewModel: viewModel,
                    familyId: familyId,
                    request: request,
                    selectedItems: completedItems(from: request)
                )
            }
        }
        .sheet(isPresented: $showDeliveryPhoto) {
            if let request {
                DeliveryPhotoView(
                    viewModel: viewModel,
                    familyId: familyId,
                    request: request,
                    mode: request.status == .claimed ? .upload : .view
                )
            }
        }
        .sheet(isPresented: $showCompleteItemSheet) {
            if let item = completingItem, let request {
                CompleteItemSheet(
                    viewModel: viewModel,
                    familyId: familyId,
                    requestId: request.requestId,
                    item: item
                )
            }
        }
        .sheet(isPresented: $showConfirmItemSheet) {
            if let item = confirmingItem, let request {
                ConfirmDeliveryView(
                    viewModel: viewModel,
                    familyId: familyId,
                    request: request,
                    selectedItems: [item]
                )
            }
        }
        .sheet(isPresented: $showItemDetail) {
            if let item = selectedDetailItem, let request {
                ItemDetailSheet(
                    viewModel: viewModel,
                    familyId: familyId,
                    requestId: request.requestId,
                    item: item
                )
            }
        }
        .sheet(isPresented: $showPickupPhotoSheet) {
            if let item = pickupPhotoItem, let request {
                PickupPhotoSheet(
                    viewModel: viewModel,
                    familyId: familyId,
                    requestId: request.requestId,
                    item: item
                )
            }
        }
        .alert("Cancel Request", isPresented: $showCancelAlert) {
            Button("Cancel Request", role: .destructive) {
                Task {
                    await performCancel()
                }
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this request? This action cannot be undone.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func headerSection(_ request: GrabRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(request.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                StatusBadge(status: request.status)
            }

            Label(request.requestorId.name ?? request.requestorId.id, systemImage: "person.fill")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Label("\(request.embolecCost.embolecFormatted) Embolecs", systemImage: "dollarsign.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.orange)

                if let tip = request.tipAmount, tip > 0 {
                    Label("+\(String(format: "%.2f", tip)) tip", systemImage: "heart.fill")
                        .font(.subheadline)
                        .foregroundColor(.pink)
                }
            }

            if let note = request.note, !note.isEmpty {
                Text(note)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
    }

    @ViewBuilder
    private func itemsSection(_ request: GrabRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items")
                .font(.headline)

            if let items = request.items, !items.isEmpty {
                ForEach(items) { item in
                    itemRow(item)

                    if item.id != request.items?.last?.id {
                        Divider()
                    }
                }
            } else {
                Text("No items listed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
    }

    @ViewBuilder
    private func itemRow(_ item: GrabRequestItem) -> some View {
        let isTappable = item.status == .completed || item.status == .confirmed || item.pickupPhotoKey != nil

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)

                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                if isTappable {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Per-item status badge and claimer name
            HStack(spacing: 8) {
                if let itemStatus = item.status {
                    ItemStatusBadge(status: itemStatus)
                }

                if item.pickupPhotoKey != nil {
                    Image(systemName: "camera.fill")
                        .font(.caption2)
                        .foregroundColor(.indigo)
                        .padding(4)
                        .background(Color.indigo.opacity(0.15))
                        .clipShape(Circle())
                        .accessibilityLabel("Pickup photo added")
                }

                if let claimerId = item.claimerId {
                    Label(claimerId.name ?? claimerId.id, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(item.embolecCost.embolecFormatted) E")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }

            // Per-item action buttons
            itemActionButtons(item)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if isTappable {
                selectedDetailItem = item
                showItemDetail = true
            }
        }
    }

    @ViewBuilder
    private func itemActionButtons(_ item: GrabRequestItem) -> some View {
        let itemStatus = item.status ?? .open

        // "Claim" button: shown for OPEN items, hidden from requestor
        if itemStatus == .open, !isRequestor {
            Button {
                Task { await performClaimItem(item) }
            } label: {
                Label("Claim (\(item.embolecCost.embolecFormatted) E)", systemImage: "hand.raised.fill")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
            .disabled(isPerformingAction)
        }

        // "Mark Complete" button: shown for items claimed by current user with status CLAIMED
        if itemStatus == .claimed, item.claimerId?.id == currentUserId {
            Button {
                completingItem = item
                showCompleteItemSheet = true
            } label: {
                Label("Mark Complete", systemImage: "checkmark.circle")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.small)
            .disabled(isPerformingAction)
        }

        // "Add Pickup Photo" button: shown for items claimed by current user without a pickup photo
        if itemStatus == .claimed, item.claimerId?.id == currentUserId, item.pickupPhotoKey == nil {
            Button {
                pickupPhotoItem = item
                showPickupPhotoSheet = true
            } label: {
                Label("Add Pickup Photo", systemImage: "camera.fill")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .controlSize(.small)
            .disabled(isPerformingAction)
        }

        // "Confirm" button: shown for items with status COMPLETED, visible only to requestor
        if itemStatus == .completed, isRequestor {
            Button {
                confirmingItem = item
                showConfirmItemSheet = true
            } label: {
                Label("Confirm", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.small)
            .disabled(isPerformingAction)
        }
    }

    @ViewBuilder
    private func photoSection(_: GrabRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delivery Photo")
                .font(.headline)

            Button {
                showDeliveryPhoto = true
            } label: {
                HStack {
                    Image(systemName: "photo.fill")
                        .foregroundColor(.blue)
                    Text("View Delivery Photo")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
    }

    @ViewBuilder
    private func actionsSection(_ request: GrabRequest) -> some View {
        VStack(spacing: 12) {
            switch request.status {
            case .open:
                if isRequestor {
                    Button(role: .destructive) {
                        showCancelAlert = true
                    } label: {
                        Label("Cancel Request", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

            case .claimed:
                Button {
                    showDeliveryPhoto = true
                } label: {
                    Label("Complete with Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPerformingAction)

                Button {
                    Task { await performComplete(photoKey: nil) }
                } label: {
                    Label("Complete without Photo", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isPerformingAction)

                Button(role: .destructive) {
                    showCancelAlert = true
                } label: {
                    Label("Cancel Request", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

            case .completed:
                Button(role: .destructive) {
                    showCancelAlert = true
                } label: {
                    Label("Cancel Request", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

            case .confirmed, .cancelled:
                EmptyView()

            case .partiallyClaimed, .partiallyCompleted:
                Button(role: .destructive) {
                    showCancelAlert = true
                } label: {
                    Label("Cancel Request", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func performClaimItem(_ item: GrabRequestItem) async {
        isPerformingAction = true
        _ = await viewModel.claimItems(familyId: familyId, requestId: requestId, itemIds: [item.itemId])
        isPerformingAction = false
    }

    private func performCompleteItem(_ item: GrabRequestItem) async {
        isPerformingAction = true
        _ = await viewModel.completeItems(familyId: familyId, requestId: requestId, itemIds: [item.itemId])
        isPerformingAction = false
    }

    private func performConfirmItem(_ item: GrabRequestItem) async {
        isPerformingAction = true
        _ = await viewModel.confirmItems(familyId: familyId, requestId: requestId, itemIds: [item.itemId])
        isPerformingAction = false
    }

    private func performComplete(photoKey: String?) async {
        isPerformingAction = true
        _ = await viewModel.completeRequest(familyId: familyId, requestId: requestId, proofPhotoKey: photoKey)
        isPerformingAction = false
    }

    private func performCancel() async {
        isPerformingAction = true
        let success = await viewModel.cancelRequest(familyId: familyId, requestId: requestId)
        isPerformingAction = false
        if success {
            dismiss()
        }
    }

    // MARK: - Helpers

    private func completedItems(from request: GrabRequest) -> [GrabRequestItem] {
        (request.items ?? []).filter { $0.status == .completed }
    }
}

// MARK: - Item Status Badge

struct ItemStatusBadge: View {
    let status: GrabRequestStatus

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: status.systemImage)
                .font(.system(size: 9))
            Text(status.displayName)
                .font(.system(size: 10))
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(statusColor.opacity(0.15))
        .foregroundColor(statusColor)
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .open: .blue
        case .partiallyClaimed: .orange.opacity(0.7)
        case .claimed: .orange
        case .partiallyCompleted: .purple.opacity(0.7)
        case .completed: .purple
        case .confirmed: .green
        case .cancelled: .red
        }
    }
}

#Preview {
    NavigationStack {
        GrabRequestDetailView(
            viewModel: FamGrabViewModel(),
            familyId: "family-123",
            requestId: "request-456"
        )
    }
}
