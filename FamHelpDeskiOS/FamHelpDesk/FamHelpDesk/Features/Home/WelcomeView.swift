import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDevForm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "ticket")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                    Text("FamHelpDesk")
                        .font(.largeTitle).bold()
                }
                Text("Sign up or sign in to continue")
                    .foregroundColor(.secondary)

                VStack(spacing: 12) {
                    Button(action: signIn) {
                        HStack { Image(systemName: "person.crop.circle"); Text("Sign In") }
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)

                    Button(action: signUp) {
                        HStack { Image(systemName: "plus.circle"); Text("Create Account") }
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)

                    if let error = errorMessage {
                        Text(error).foregroundColor(.red)
                    }
                }
                .padding(.horizontal)

                Spacer()

                DisclosureGroup(isExpanded: $showDevForm) {
                    DevLoginForm()
                } label: {
                    Text("Developer login (username/password)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .padding()
            .navigationTitle("")
        }
    }

    private func signIn() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await auth.hostedUISignIn()
            } catch {
                errorMessage = "Sign in failed"
            }
            isLoading = false
        }
    }

    private func signUp() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await auth.hostedUISignUp()
            } catch {
                errorMessage = "Sign up failed"
            }
            isLoading = false
        }
    }
}

private struct DevLoginForm: View {
    @EnvironmentObject var auth: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Password", text: $password)
            if let error = errorMessage { Text(error).foregroundColor(.red) }
            HStack {
                Spacer()
                Button(action: signIn) {
                    if isLoading { ProgressView() } else { Text("Sign In") }
                }
                .disabled(isLoading || username.isEmpty || password.isEmpty)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func signIn() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await auth.signIn(username: username, password: password)
            } catch {
                errorMessage = "Sign in failed"
            }
            isLoading = false
        }
    }
}
