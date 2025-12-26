import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var userSession = UserSession.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Welcome") {
                    if userSession.isFetching {
                        ProgressView()
                    } else if let user = userSession.currentUser {
                        Text("Welcome, \(user.displayName)!")
                    }
                }
                Section("Actions") {
                    Button("Sign Out") { auth.signOut() }
                }
            }
            .navigationTitle("Fam Help Desk")
        }
    }
}
