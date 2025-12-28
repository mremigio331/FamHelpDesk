import SwiftUI

struct CreateFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var familyName = ""
    @State private var familyDescription = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let familyService = FamilyService()
    private let familySession = FamilySession.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Family Name", text: $familyName)
                        .autocapitalization(.words)
                        .disabled(isCreating)
                } header: {
                    Text("Family Name")
                } footer: {
                    Text("Enter a name for your family (required)")
                }

                Section {
                    TextField("Description", text: $familyDescription, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .disabled(isCreating)
                } header: {
                    Text("Description")
                } footer: {
                    Text("Optional description for your family")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Create Family")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isCreating)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createFamily()
                    }
                    .disabled(familyName.isEmpty || isCreating)
                }
            }
            .overlay {
                if isCreating {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Creating Family...")
                                .font(.headline)
                        }
                        .padding(32)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    }
                }
            }
        }
    }

    private func createFamily() {
        guard !familyName.isEmpty else { return }

        Task { @MainActor in
            isCreating = true
            errorMessage = nil

            do {
                let _ = try await familyService.createFamily(
                    name: familyName.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: familyDescription.isEmpty ? nil : familyDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                )

                // Refresh families list
                await familySession.refresh()

                // Dismiss after successful creation
                dismiss()
            } catch {
                isCreating = false
                errorMessage = "Failed to create family: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

#Preview {
    CreateFamilyView()
}
