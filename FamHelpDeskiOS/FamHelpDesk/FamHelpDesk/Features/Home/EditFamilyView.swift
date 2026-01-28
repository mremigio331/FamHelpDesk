import SwiftUI

struct EditFamilyView: View {
    let family: Family
    @Environment(\.dismiss) private var dismiss
    @State private var familyName: String
    @State private var familyDescription: String
    @State private var isPrivate: Bool
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let familyService = FamilyService()
    private let familySession = FamilySession.shared

    init(family: Family) {
        self.family = family
        _familyName = State(initialValue: family.familyName)
        _familyDescription = State(initialValue: family.familyDescription ?? "")
        _isPrivate = State(initialValue: family.isPrivate)
    }

    private var isFormValid: Bool {
        let trimmedName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty &&
            trimmedName.count >= 2 &&
            trimmedName.count <= 50 &&
            familyDescription.count <= 200
    }

    private var hasChanges: Bool {
        let trimmedName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = familyDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalDescription = family.familyDescription ?? ""

        return trimmedName != family.familyName ||
            trimmedDescription != originalDescription ||
            isPrivate != family.isPrivate
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation toolbar with back button and save
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.blue)

                Spacer()

                Text("Edit Family")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(isUpdating ? "Saving..." : "Save") {
                    Task {
                        await updateFamily()
                    }
                }
                .foregroundColor(isFormValid && hasChanges && !isUpdating ? .blue : .gray)
                .fontWeight(.semibold)
                .disabled(!isFormValid || !hasChanges || isUpdating)
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
                        .textInputAutocapitalization(.words)
                        .disabled(isUpdating)
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
                        .textInputAutocapitalization(.sentences)
                        .disabled(isUpdating)
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
                        .disabled(isUpdating)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Private families are only visible to members.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    HStack {
                        Text("Family ID")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(family.familyId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)

                        Button(action: {
                            UIPasteboard.general.string = family.familyId
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    HStack {
                        Text("Created")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(family.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Family Information")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .interactiveDismissDisabled(isUpdating)
            .overlay {
                if isUpdating {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Updating Family...")
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

    @MainActor
    private func updateFamily() async {
        isUpdating = true
        errorMessage = nil

        let trimmedName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = familyDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDescription = trimmedDescription.isEmpty ? nil : trimmedDescription

        do {
            let updatedFamily = try await familyService.updateFamily(
                familyId: family.familyId,
                name: trimmedName,
                description: finalDescription,
                isPrivate: isPrivate
            )

            // Update the family in cache for immediate UI update
            familySession.updateFamilyInCache(updatedFamily)

            // Dismiss after successful update
            dismiss()
        } catch {
            isUpdating = false
            errorMessage = "Failed to update family: \(error.localizedDescription)"
            showError = true
        }
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
    EditFamilyView(
        family: Family(
            familyId: "123",
            familyName: "Smith Family",
            familyDescription: "Our family group for managing household tasks and activities",
            createdBy: "user123",
            creationDate: Date().timeIntervalSince1970,
            isPrivate: false
        )
    )
}
