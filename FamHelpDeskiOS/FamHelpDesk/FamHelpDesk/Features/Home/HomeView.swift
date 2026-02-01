import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var userSession = UserSession.shared
    @State private var familySession = FamilySession.shared
    @State private var showCreateFamily = false
    @State private var showSearch = false

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

            MyFamiliesCard(showCreateFamily: $showCreateFamily, onFindFamilies: {
                showSearch = true
            })
        }
        .refreshable {
            await refreshHomeData()
        }
        .sheet(isPresented: $showCreateFamily) {
            CreateFamilyView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSearch) {
            FamilySearchView()
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
