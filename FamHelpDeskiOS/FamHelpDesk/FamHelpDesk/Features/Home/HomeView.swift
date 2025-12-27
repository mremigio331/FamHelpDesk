import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var userSession = UserSession.shared

    var body: some View {
        List {
            Section("Welcome") {
                if userSession.isFetching {
                    ProgressView()
                } else if let user = userSession.currentUser {
                    Text("Hello, \(user.displayName)!")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }

            MyFamiliesCard()
        }
        .navigationDestination(for: Family.self) { family in
            FamilyDetailView(family: family)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AuthManager())
    }
}
