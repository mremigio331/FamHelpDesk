import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var userSession = UserSession.shared
    @State private var showProfile = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Top Bar
                CustomNavigationBar(showProfile: $showProfile)
                
                // Main Content
                HomeView()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showProfile) {
                UserProfileDetailView()
            }
        }
    }
}

struct CustomNavigationBar: View {
    @State private var userSession = UserSession.shared
    @Binding var showProfile: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Logo placeholder (you can replace with actual logo image)
            Image(systemName: "ticket.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            Text("Fam Help Desk")
                .font(.headline)
            
            Spacer()
            
            // Profile button
            Button {
                showProfile = true
            } label: {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay {
                        if let user = userSession.currentUser {
                            Text(user.displayName.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "person.fill")
                                .foregroundColor(.blue)
                        }
                    }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
}
