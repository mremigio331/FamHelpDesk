import SwiftUI

@main
struct FamHelpDeskApp: App {
    @StateObject private var auth = AuthManager()

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
        }
    }
}
