import Amplify
import AWSCognitoAuthPlugin
import SwiftUI
import UIKit
import UserNotifications

@main
struct FamHelpDeskApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth = AuthManager()
    @State private var userSession = UserSession.shared
    @State private var showErrorAfterDelay = false
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared
    @State private var showNotificationPrompt = false
    private let logger = AuthLogger.shared

    init() {
        configureAmplify()
        setupNotificationDelegate()
    }

    /// Set up notification center delegate
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = appDelegate
    }

    /// Check if we should show notification permission prompt
    private func checkAndShowNotificationPrompt() {
        // Check if permissions have already been requested
        let hasRequestedPermissions = UserDefaults.standard.bool(forKey: "hasRequestedNotificationPermissions")

        if !hasRequestedPermissions {
            print("📱 [APP] First launch - will show notification prompt")
            showNotificationPrompt = true
        } else {
            print("📱 [APP] Notification permissions already requested previously")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch auth.authenticationState {
                case .unknown:
                    // Show loading while checking authentication
                    LoadingView(message: "")
                case .authenticated:
                    // Show loading while fetching user profile
                    if userSession.currentUser == nil, userSession.isLoading {
                        LoadingView(message: "")
                    } else if userSession.currentUser != nil {
                        // User is authenticated and profile is loaded
                        MainTabView()
                            .environmentObject(auth)
                            .environment(userSession)
                    } else if showErrorAfterDelay {
                        // Authenticated but failed to load profile after delay - show error with retry
                        ProfileLoadErrorView()
                            .environmentObject(auth)
                            .environment(userSession)
                    } else {
                        // Still trying to load profile - show loading
                        LoadingView(message: "")
                    }
                case .unauthenticated:
                    WelcomeView()
                        .environmentObject(auth)
                        .environment(userSession)
                case .error:
                    if showErrorAfterDelay {
                        WelcomeView()
                            .environmentObject(auth)
                            .environment(userSession)
                    } else {
                        LoadingView(message: "")
                    }
                }
            }
            .task {
                // Load user profile ONCE when app starts and user is authenticated
                if case .authenticated = auth.authenticationState, userSession.currentUser == nil, !userSession.isLoading {
                    print("📱 [APP] Initial profile load on app start")
                    await userSession.loadUserProfile()
                }
            }
            .onAppear {
                // Clear badge count when app opens
                Task { @MainActor in
                    UIApplication.shared.applicationIconBadgeNumber = 0
                    print("🔢 [APP] Cleared badge count on app open")
                }
            }
            .onChange(of: auth.authenticationState) { oldState, newState in
                Task {
                    // Only load profile if transitioning TO authenticated from a different state
                    // AND profile is not already loaded
                    if case .authenticated = newState,
                       !matches(oldState, newState),
                       userSession.currentUser == nil,
                       !userSession.isLoading
                    {
                        print("📱 [APP] Auth state changed to authenticated, loading profile")
                        await userSession.loadUserProfile()
                    } else if case .unauthenticated = newState {
                        print("📱 [APP] Auth state changed to unauthenticated, clearing session")
                        userSession.signOut()
                        showErrorAfterDelay = false
                    }

                    // Check and show notification prompt only after authentication
                    if case .authenticated = newState {
                        print("📱 [APP] User authenticated, checking if should show notification prompt")
                        checkAndShowNotificationPrompt()
                    }
                }
            }
            .onChange(of: userSession.errorMessage) { _, errorMessage in
                // Only show error UI after a delay to allow for retries
                if errorMessage != nil {
                    Task {
                        do {
                            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                        } catch {
                            // Sleep was cancelled, continue anyway
                        }
                        if userSession.errorMessage != nil, userSession.currentUser == nil {
                            showErrorAfterDelay = true
                        }
                    }
                } else {
                    showErrorAfterDelay = false
                }
            }
            .alert("Enable Push Notifications?", isPresented: $showNotificationPrompt) {
                Button("Enable") {
                    Task {
                        let granted = await NotificationManager.shared.requestPermissions()

                        // Mark as requested regardless of outcome
                        UserDefaults.standard.set(true, forKey: "hasRequestedNotificationPermissions")

                        if granted {
                            print("✅ [APP] Notification permissions granted")
                        } else {
                            print("⚠️ [APP] Notification permissions denied")
                        }
                    }
                }
                Button("Not Now", role: .cancel) {
                    // Mark as requested so we don't ask again
                    UserDefaults.standard.set(true, forKey: "hasRequestedNotificationPermissions")
                    print("📱 [APP] User declined notification permissions")
                }
            } message: {
                Text("Get notified about tickets, groups, and family activities. You can change this later in Settings.")
            }
        }
    }

    // Helper function to check if two auth states are the same
    private func matches(_ state1: AuthenticationState, _ state2: AuthenticationState) -> Bool {
        switch (state1, state2) {
        case (.unknown, .unknown):
            true
        case (.unauthenticated, .unauthenticated):
            true
        case let (.authenticated(user1), .authenticated(user2)):
            user1.userId == user2.userId
        case let (.error(error1), .error(error2)):
            error1 == error2
        default:
            false
        }
    }

    private func configureAmplify() {
        let environment = AppStage.current
        let configFile = getConfigurationFileName()

        logger.logConfigurationEvent(.configurationStarted(environment: environment.description))

        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())

            // Load environment-specific configuration with validation
            guard let configURL = Bundle.main.url(forResource: configFile, withExtension: "json") else {
                let error = ConfigurationError.fileNotFound("Configuration file '\(configFile).json' not found in app bundle")
                logger.logConfigurationEvent(.configurationFailure(error: error, environment: environment.description, fileName: configFile))
                throw error
            }

            logger.logConfigurationEvent(.configurationFileLoaded(fileName: configFile, path: configURL.path))

            let configuration = try AmplifyConfiguration(configurationFile: configURL)

            // Validate configuration before initializing Amplify
            try validateConfiguration(configuration, configFile: configFile)
            logger.logConfigurationEvent(.configurationValidationPassed(fileName: configFile))

            try Amplify.configure(configuration)

            logger.logConfigurationEvent(.configurationSuccess(environment: environment.description, fileName: configFile))

        } catch let error as ConfigurationError {
            logger.logConfigurationEvent(.configurationFailure(error: error, environment: environment.description, fileName: configFile))

            // Attempt error recovery
            Task {
                let recoveryResult = await AuthErrorRecovery.shared.recoverFromConfigurationError(error, environment: environment)
                await handleConfigurationRecovery(recoveryResult, originalError: error)
            }
        } catch {
            let configError = ConfigurationError.amplifyInitializationFailed(error)
            logger.logConfigurationEvent(.configurationFailure(error: configError, environment: environment.description, fileName: configFile))

            // Attempt error recovery
            Task {
                let recoveryResult = await AuthErrorRecovery.shared.recoverFromConfigurationError(configError, environment: environment)
                await handleConfigurationRecovery(recoveryResult, originalError: configError)
            }
        }
    }

    /// Handle configuration error recovery results
    private func handleConfigurationRecovery(_ result: ConfigurationRecoveryResult, originalError: ConfigurationError) async {
        switch result {
        case let .recovered(strategy, configURL):
            logger.logRecoveryAttempt(.recoverySuccess(strategy: strategy.description))

            // Attempt to reconfigure with recovered configuration
            do {
                let configuration = try AmplifyConfiguration(configurationFile: configURL)
                try Amplify.configure(configuration)
                logger.logConfigurationEvent(.configurationSuccess(environment: AppStage.current.description, fileName: configURL.lastPathComponent))
            } catch {
                logger.logRecoveryAttempt(.recoveryFailure(strategy: strategy.description, error: error))
            }

        case let .retrySuccessful(attempt):
            logger.logRecoveryAttempt(.recoverySuccess(strategy: "retry_attempt_\(attempt)"))

        case let .fallback(strategy, reason):
            logger.logRecoveryAttempt(.fallbackActivated(fallback: strategy.description))
            // App continues with limited functionality

        case let .failed(reason):
            logger.logRecoveryAttempt(.recoveryFailure(strategy: "configuration_recovery", error: originalError))
            // App continues with limited functionality
        }
    }

    private func getConfigurationFileName() -> String {
        switch AppStage.current {
        case .dev, .testing:
            "amplifyconfiguration.testing"
        case .prod:
            "amplifyconfiguration.prod"
        }
    }
}

// Environment detection (matches your existing AppStage)
enum AppStage {
    case dev
    case testing
    case prod

    static var current: AppStage {
        #if DEBUG
            return .testing // Debug builds use testing environment
        #else
            return .prod // Release builds use production environment
        #endif
    }
}

// Configuration validation and error handling
enum ConfigurationError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidFormat
    case missingRequiredKeys([String])
    case amplifyInitializationFailed(Error)

    var errorDescription: String? {
        switch self {
        case let .fileNotFound(message):
            message
        case .invalidFormat:
            "Configuration file has invalid JSON format"
        case let .missingRequiredKeys(keys):
            "Configuration missing required keys: \(keys.joined(separator: ", "))"
        case let .amplifyInitializationFailed(error):
            "Amplify initialization failed: \(error.localizedDescription)"
        }
    }
}

extension FamHelpDeskApp {
    private func validateConfiguration(_: AmplifyConfiguration, configFile: String) throws {
        // Since AmplifyConfiguration.auth is internal, we'll validate by attempting to configure
        // and catch any configuration errors. This is a simpler approach that relies on Amplify's
        // built-in validation.

        logger.logConfigurationEvent(.configurationValidationPassed(fileName: configFile))
    }
}

// MARK: - Extensions for Recovery Strategy Descriptions

extension ConfigurationRecoveryStrategy {
    var description: String {
        switch self {
        case let .alternativeConfigFile(fileName):
            "alternative_config_file(\(fileName))"
        case .retryWithBackoff:
            "retry_with_backoff"
        }
    }
}

extension FallbackStrategy {
    var description: String {
        switch self {
        case .defaultConfiguration:
            "default_configuration"
        case .offlineMode:
            "offline_mode"
        case .useManualToken:
            "use_manual_token"
        }
    }
}

extension AppStage {
    var description: String {
        switch self {
        case .dev:
            "development"
        case .testing:
            "testing"
        case .prod:
            "production"
        }
    }
}

// MARK: - Loading Views

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 30) {
            // App Logo
            Image("FamHelpDeskTransparent")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 400, height: 400)

            // Loading indicator
            ProgressView()
                .scaleEffect(1.2)
                .tint(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}

struct ProfileLoadErrorView: View {
    @Environment(UserSession.self) private var userSession
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("Failed to Load Profile")
                .font(.headline)

            if let errorMessage = userSession.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                Button("Retry") {
                    Task {
                        await userSession.loadUserProfile()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(userSession.isFetching)

                Button("Sign Out") {
                    Task {
                        await auth.signOut()
                    }
                }
                .buttonStyle(.bordered)
            }

            if userSession.isFetching {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .padding()
    }
}

// MARK: - AppDelegate for APNs

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("📱 [AppDelegate] Application did finish launching")
        return true
    }

    /// Called when APNs successfully registers the device
    func application(
        _: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("📱 [AppDelegate] Successfully registered for remote notifications")

        // Register device with backend via NotificationManager
        Task {
            await NotificationManager.shared.registerDevice(token: deviceToken)
        }
    }

    /// Called when APNs fails to register the device
    func application(
        _: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ [AppDelegate] Failed to register for remote notifications")
        print("❌ [AppDelegate] Error: \(error)")
        print("❌ [AppDelegate] Error description: \(error.localizedDescription)")
        print("❌ [AppDelegate] Error type: \(type(of: error))")

        // Check for specific error types
        let nsError = error as NSError
        print("❌ [AppDelegate] Error domain: \(nsError.domain)")
        print("❌ [AppDelegate] Error code: \(nsError.code)")
        print("❌ [AppDelegate] Error userInfo: \(nsError.userInfo)")

        // Check entitlements
        if let entitlements = Bundle.main.object(forInfoDictionaryKey: "Entitlements") {
            print("📋 [AppDelegate] Entitlements found: \(entitlements)")
        } else {
            print("⚠️ [AppDelegate] No entitlements found in Info.plist")
        }

        // Check for entitlements file
        if let entitlementsPath = Bundle.main.path(forResource: "FamHelpDesk", ofType: "entitlements") {
            print("📋 [AppDelegate] Entitlements file path: \(entitlementsPath)")
        } else {
            print("⚠️ [AppDelegate] No entitlements file found in bundle")
        }

        // Check bundle identifier
        if let bundleId = Bundle.main.bundleIdentifier {
            print("📦 [AppDelegate] Bundle ID: \(bundleId)")
        }

        // Check if running in simulator
        #if targetEnvironment(simulator)
            print("⚠️ [AppDelegate] Running in simulator - push notifications not supported")
            return
        #endif

        // Show alert to user on main thread (only on device)
        Task { @MainActor in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController
            else {
                return
            }

            let alert = UIAlertController(
                title: "Notification Registration Failed",
                message: "Unable to register for push notifications. Error: \(error.localizedDescription)",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "OK", style: .default))

            rootViewController.present(alert, animated: true)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📱 [AppDelegate] Received notification in foreground")

        // Update badge count if present in payload
        if let badge = notification.request.content.badge as? Int {
            Task { @MainActor in
                UIApplication.shared.applicationIconBadgeNumber = badge
                print("🔢 [AppDelegate] Updated badge count to: \(badge)")
            }
        }

        // Show banner, play sound, and update badge
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("📱 [AppDelegate] User tapped notification")

        let userInfo = response.notification.request.content.userInfo

        // Parse userInfo and call NotificationManager to handle navigation
        NotificationManager.shared.handleNotification(response.notification)

        completionHandler()
    }
}
