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
                        .font(.largeTitle)
                        .bold()
                }

                Text("Sign up or sign in to continue")
                    .foregroundColor(.secondary)

                VStack(spacing: 12) {
                    Button {
                        signIn()
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle")
                            Text("Sign In")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)

                    Button {
                        signUp()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Create Account")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)

                    // Testing Helper Section (Debug builds only)
                    #if DEBUG
                        VStack(spacing: 8) {
                            Divider()

                            Text("Testing Helpers")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                Button {
                                    forceSignOut()
                                } label: {
                                    HStack {
                                        Image(systemName: "trash.circle")
                                        Text("Force Sign Out")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                                .disabled(isLoading)

                                Button {
                                    testAuthFlow()
                                } label: {
                                    HStack {
                                        Image(systemName: "testtube.2")
                                        Text("Test Auth")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.blue)
                                .disabled(isLoading)
                            }
                        }
                        .padding(.top, 8)
                    #endif

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("")
        }
    }

    // MARK: - Actions

    @MainActor
    private func signIn() {
        errorMessage = nil
        isLoading = true

        Task {
            do {
                try await auth.signIn()
            } catch {
                errorMessage = "Sign in failed"
            }
            isLoading = false
        }
    }

    @MainActor
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

    @MainActor
    private func forceSignOut() {
        errorMessage = nil
        isLoading = true

        Task {
            await auth.forceSignOut()
            errorMessage = "Force sign out completed"
            isLoading = false
        }
    }

    @MainActor
    private func testAuthFlow() {
        errorMessage = nil
        isLoading = true

        Task {
            await AuthTestHelper.testAuthenticationFlow()
            errorMessage = "Auth test completed - check console"
            isLoading = false
        }
    }
}

// MARK: - Dev Login Form

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

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }

            HStack {
                Spacer()
                Button {
                    signIn()
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Sign In")
                    }
                }
                .disabled(isLoading || username.isEmpty || password.isEmpty)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @MainActor
    private func signIn() {
        errorMessage = nil
        isLoading = true

        Task {
            do {
                try await auth.signIn()
            } catch {
                errorMessage = "Sign in failed"
            }
            isLoading = false
        }
    }
}
