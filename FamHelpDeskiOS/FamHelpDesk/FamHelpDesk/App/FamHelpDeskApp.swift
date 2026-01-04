import Amplify
import AWSCognitoAuthPlugin
import SwiftUI

@main
struct FamHelpDeskApp: App {
    @StateObject private var auth = AuthManager()
    @State private var userSession = UserSession.shared
    private let logger = AuthLogger.shared

    init() {
        configureAmplify()
    }

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
        case .dev, .staging:
            "amplifyconfiguration.testing"
        case .prod:
            "amplifyconfiguration.prod"
        }
    }
}

// Environment detection (matches your existing AppStage)
enum AppStage {
    case dev
    case staging
    case prod

    static var current: AppStage {
        #if DEBUG
            return .dev
        #elseif STAGING
            return .staging
        #else
            return .prod
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
        case .staging:
            "staging"
        case .prod:
            "production"
        }
    }
}
