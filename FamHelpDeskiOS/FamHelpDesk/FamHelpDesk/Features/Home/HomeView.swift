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
                    Text("Welcome, \(user.displayName)!")
                }
            }
        }
    }
}
