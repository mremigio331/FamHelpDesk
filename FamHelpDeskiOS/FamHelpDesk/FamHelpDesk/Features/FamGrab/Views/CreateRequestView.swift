import SwiftUI

struct CreateRequestView: View {
    @Bindable var viewModel: FamGrabViewModel
    let familyId: String

    @State private var title = ""
    @State private var note = ""
    @State private var items: [NewItem] = [NewItem()]
    @State private var isSubmitting = false
    @Environment(\.dismiss) private var dismiss

    struct NewItem: Identifiable {
        let id = UUID()
        var name = ""
        var embolecCost: Double = 1
        var note = ""
    }

    private var totalCost: Double {
        items.reduce(0) { $0 + $1.embolecCost }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Request Details") {
                    TextField("Title (e.g., Party Supplies)", text: $title)

                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(3)
                }

                Section {
                    ForEach($items) { $item in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Item name", text: $item.name)

                            HStack {
                                Button {
                                    if item.embolecCost > 1 {
                                        item.embolecCost -= 1
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(item.embolecCost > 1 ? .red : .gray)
                                }
                                .buttonStyle(.borderless)
                                .disabled(item.embolecCost <= 1)

                                Text("\(item.embolecCost.embolecFormatted) E")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                    .frame(minWidth: 50)

                                Button {
                                    item.embolecCost += 1
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                }
                                .buttonStyle(.borderless)

                                Spacer()
                            }

                            TextField("Item note (optional)", text: $item.note)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteItem)

                    Button {
                        items.append(NewItem())
                    } label: {
                        Label("Add Item", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Items")
                } footer: {
                    HStack {
                        Spacer()
                        Text("Total: \(totalCost.embolecFormatted) Embolecs")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }

                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Create") {
                            Task { await submitRequest() }
                        }
                        .fontWeight(.semibold)
                        .disabled(!isFormValid)
                    }
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
    }

    private var isFormValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        guard !items.isEmpty else { return false }

        // Every item must have a non-empty name and a cost >= 1
        for item in items {
            if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
            if item.embolecCost < 1 {
                return false
            }
        }
        return true
    }

    private func deleteItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        if items.isEmpty {
            items.append(NewItem())
        }
    }

    private func submitRequest() async {
        isSubmitting = true
        viewModel.clearError()

        let requestItems = items
            .map { item in
                CreateGrabRequestItemBody(
                    name: item.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    embolecCost: item.embolecCost,
                    note: item.note.isEmpty ? nil : item.note.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

        let success = await viewModel.createRequest(
            familyId: familyId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            items: requestItems,
            note: note.isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        isSubmitting = false

        if success {
            dismiss()
        }
    }
}

#Preview {
    CreateRequestView(
        viewModel: FamGrabViewModel(),
        familyId: "family-123"
    )
}
