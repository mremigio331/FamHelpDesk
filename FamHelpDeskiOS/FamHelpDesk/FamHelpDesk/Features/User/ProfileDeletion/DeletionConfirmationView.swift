import SwiftUI

struct DeletionConfirmationView: View {
    let onBackToHome: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon for visual feedback
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            // Main title
            Text("Hate to See You Go")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                // Deletion request started message
                Text("Your profile deletion request has been started.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                // Email notification message
                Text("You will receive an email once the deletion is completed.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Back button
            Button(action: onBackToHome) {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("Back to Home")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    DeletionConfirmationView(onBackToHome: {
        print("Back to home tapped")
    })
}
