import SwiftUI

struct EmptyFamiliesView: View {
    var onFindFamilies: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Families Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Join a family to start managing tickets and collaborating with your family members.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onFindFamilies) {
                Label("Find Families", systemImage: "magnifyingglass")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    EmptyFamiliesView(onFindFamilies: {
        print("Find families tapped")
    })
}
