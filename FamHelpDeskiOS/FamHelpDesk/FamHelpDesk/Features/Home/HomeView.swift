import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var userSession = UserSession.shared
    @State private var familySession = FamilySession.shared
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
        .refreshable {
            await refreshHomeData()
        }
        .sheet(isPresented: $showCreateFamily) {
            CreateFamilyView()
                .presentationDetents([.medium, .large])
        }
    }

    private func refreshHomeData() async {
        // Refresh user profile and families data
        async let userRefresh = userSession.refreshProfile()
        async let familiesRefresh = familySession.refresh()

        await userRefresh
        await familiesRefresh
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AuthManager())
    }
}
