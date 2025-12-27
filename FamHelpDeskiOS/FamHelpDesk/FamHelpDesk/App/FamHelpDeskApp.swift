import SwiftUI

@main
struct FamHelpDeskApp: App {
    @StateObject private var auth = AuthManager()
    @State private var userSession = UserSession.shared

    var body: some Scene {
        WindowGroup {
            if auth.isAuthenticated {
                MainTabView()
                    .environmentObject(auth)
                    .environment(userSession)
            } else {
                WelcomeView()
                    .environmentObject(auth)
                    .environment(userSession)
            }
        }
    }
}
