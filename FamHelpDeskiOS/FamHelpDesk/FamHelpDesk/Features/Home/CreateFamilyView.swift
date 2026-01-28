import SwiftUI

struct CreateFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var familyName = ""
    @State private var familyDescription = ""
    @State private var isPrivate = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let familyService = FamilyService()
    private let familySession = FamilySession.shared

    private var isFormValid: Bool {
        let trimmedName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty &&
            trimmedName.count >= 2 &&
            trimmedName.count <= 50 &&
            familyDescription.count <= 200
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation toolbar with back button and create
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.blue)

                Spacer()

                Text("Create Family")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(isCreating ? "Creating..." : "Create") {
                    createFamily()
                }
                .foregroundColor(isFormValid && !isCreating ? .blue : .gray)
                .fontWeight(.semibold)
                .disabled(!isFormValid || isCreating)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(uiColor: .separator)),
                alignment: .bottom
            )

            Form {
                Section {
                    TextField("Family Name", text: $familyName)
                        .autocapitalization(.words)
                        .disabled(isCreating)
                } header: {
                    Text("Family Name")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Family name must be 2-50 characters long.")
                        if familyName.count > 50 {
                            Text("Name is too long (\(familyName.count)/50)")
                                .foregroundColor(.red)
                        } else if !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, familyName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                            Text("Name is too short (minimum 2 characters)")
                                .foregroundColor(.red)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Section {
                    TextField("Description", text: $familyDescription, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .disabled(isCreating)
                } header: {
                    Text("Description")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optional description for your family (max 200 characters).")
                        if familyDescription.count > 200 {
                            Text("Description is too long (\(familyDescription.count)/200)")
                                .foregroundColor(.red)
                        } else if !familyDescription.isEmpty {
                            Text("\(familyDescription.count)/200 characters")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Section {
                    Toggle("Private Family", isOn: $isPrivate)
                        .disabled(isCreating)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Private families are only visible to members.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .interactiveDismissDisabled(isCreating)
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
        .navigationBarHidden(true)
    }

    private func createFamily() {
        guard isFormValid else { return }

        Task { @MainActor in
            isCreating = true
            errorMessage = nil

            do {
                let trimmedName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedDescription = familyDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalDescription = trimmedDescription.isEmpty ? nil : trimmedDescription

                let _ = try await familyService.createFamily(
                    name: trimmedName,
                    description: finalDescription,
                    isPrivate: isPrivate
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
