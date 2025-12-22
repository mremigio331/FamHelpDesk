import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        NavigationStack {
            List {
                Section("Welcome") {
                    if let userName = auth.userDisplayName {
                        Text("Welcome, \(userName)!")
                    } else {
                        Text("Welcome!")
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
