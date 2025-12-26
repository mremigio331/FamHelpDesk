import SwiftUI

@main
struct FamHelpDeskApp: App {
    @StateObject private var auth = AuthManager()
    @State private var userSession = UserSession.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isAuthenticated {
                    HomeView()
                } else {
                    WelcomeView()
                }
            }
            .environmentObject(auth)
            .environment(userSession)
        }
    }
}
