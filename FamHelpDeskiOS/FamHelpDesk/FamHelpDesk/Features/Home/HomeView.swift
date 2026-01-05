import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var userSession = UserSession.shared
    @State private var showCreateFamily = false

    var body: some View {
        List {
            Section {
                if userSession.isFetching {
                    ProgressView()
                } else if let user = userSession.currentUser {
                    Text("Hello, \(user.displayName)!")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }

            MyFamiliesCard(showCreateFamily: $showCreateFamily)
        }
        .navigationDestination(for: Family.self) { family in
            FamilyDetailView(family: family)
        }
        .sheet(isPresented: $showCreateFamily) {
            CreateFamilyView()
                .presentationDetents([.medium, .large])
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AuthManager())
    }
}
