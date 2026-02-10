import Combine
import Foundation
import UIKit
import UserNotifications

/// Manager for handling push notification permissions and device registration
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @Published var deviceToken: String?

    private let apiClient: APIClient
    private let notificationCenter: UNUserNotificationCenter

    override private init() {
        apiClient = APIClient.shared
        notificationCenter = UNUserNotificationCenter.current()
        super.init()

        // Check current authorization status
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Permission Management

    /// Request notification permissions from the user
    /// - Returns: Boolean indicating if permissions were granted
    func requestPermissions() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])

            await MainActor.run {
                self.isAuthorized = granted
            }

            if granted {
                print("📱 [NotificationManager] Notification permissions granted")
                // Register for remote notifications on the main thread
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("📱 [NotificationManager] Notification permissions denied")
            }

            return granted
        } catch {
            print("❌ [NotificationManager] Error requesting permissions: \(error)")
            await MainActor.run {
                self.isAuthorized = false
            }
            return false
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()

        await MainActor.run {
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Device Token Management

    /// Register device with backend API
    /// - Parameter token: APNs device token as Data
    func registerDevice(token: Data) async {
        // Convert token to hex string
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()

        await MainActor.run {
            self.deviceToken = tokenString
        }

        print("📱 [NotificationManager] Registering device with token: \(tokenString.prefix(8))...")

        // Determine environment (sandbox vs production)
        let environment = determineEnvironment()

        // Get bundle ID
        guard let bundleId = Bundle.main.bundleIdentifier else {
            print("❌ [NotificationManager] Could not get bundle identifier")
            return
        }

        // Generate device_id using identifierForVendor
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else {
            print("❌ [NotificationManager] Could not get device identifier")
            return
        }

        // Call backend API to register device
        do {
            let requestBody: [String: Any] = [
                "device_id": deviceId,
                "apns_token": tokenString,
                "environment": environment,
                "bundle_id": bundleId,
            ]

            let response: DeviceRegistrationResponse = try await apiClient.post("devices/register", body: requestBody)

            if response.success {
                // Store device_id in UserDefaults
                UserDefaults.standard.set(deviceId, forKey: "apns_device_id")
                print("✅ [NotificationManager] Device registered successfully: \(response.message)")
            } else {
                print("❌ [NotificationManager] Device registration failed: \(response.message)")
            }
        } catch {
            print("❌ [NotificationManager] Error registering device: \(error)")
        }
    }

    /// Unregister device from backend API
    func unregisterDevice() async {
        // Retrieve device_id from UserDefaults
        guard let deviceId = UserDefaults.standard.string(forKey: "apns_device_id") else {
            print("⚠️ [NotificationManager] No device_id found in UserDefaults")
            return
        }

        print("📱 [NotificationManager] Unregistering device: \(deviceId)")

        // Call backend API to unregister device
        do {
            // Create a custom delete request since APIClient doesn't have a generic delete method
            let url = URL(string: APIEnvironment.current.baseURL)!
                .appendingPathComponent("devices/\(deviceId)")

            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"

            // Add authorization token if available
            if let token = try? await AuthSessionManager.shared.getIDToken() {
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ..< 300).contains(httpResponse.statusCode)
            else {
                print("❌ [NotificationManager] Device unregistration failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }

            // Parse response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool,
               success
            {
                // Clear device_id from UserDefaults
                UserDefaults.standard.removeObject(forKey: "apns_device_id")

                await MainActor.run {
                    self.deviceToken = nil
                }

                print("✅ [NotificationManager] Device unregistered successfully")
            }
        } catch {
            print("❌ [NotificationManager] Error unregistering device: \(error)")
        }
    }

    // MARK: - Notification Handling

    /// Handle incoming notification and navigate to appropriate screen
    /// - Parameter notification: The notification to handle
    func handleNotification(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo

        print("📱 [NotificationManager] Handling notification with userInfo: \(userInfo)")

        // Parse notification payload
        guard let notificationType = userInfo["notification_type"] as? String else {
            print("⚠️ [NotificationManager] No notification_type in payload")
            return
        }

        // Extract data payload
        let data = userInfo["data"] as? [String: Any] ?? [:]

        // Create navigation payload
        let navigationPayload = NotificationNavigationPayload(
            notificationType: notificationType,
            ticketId: data["ticket_id"] as? String,
            groupId: data["group_id"] as? String,
            familyId: data["family_id"] as? String,
            queueId: data["queue_id"] as? String,
            userId: data["user_id"] as? String
        )

        // Post navigation event via NotificationCenter
        Foundation.NotificationCenter.default.post(
            name: Foundation.Notification.Name.navigateFromNotification,
            object: nil,
            userInfo: ["payload": navigationPayload]
        )

        print("✅ [NotificationManager] Posted navigation event for type: \(notificationType)")
    }

    // MARK: - Helper Methods

    /// Determine APNs environment (sandbox vs production)
    /// - Returns: "sandbox" or "production"
    private func determineEnvironment() -> String {
        #if DEBUG
            // Check for embedded.mobileprovision file (indicates sandbox)
            if let _ = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") {
                return "sandbox"
            }
            // Debug builds without provisioning profile are also sandbox
            return "sandbox"
        #else
            // Release builds are production
            return "production"
        #endif
    }
}

// MARK: - Response Models

struct DeviceRegistrationResponse: Codable {
    let success: Bool
    let deviceId: String?
    let message: String

    enum CodingKeys: String, CodingKey {
        case success
        case deviceId = "device_id"
        case message
    }
}

// MARK: - Navigation Models

/// Payload for notification-based navigation
struct NotificationNavigationPayload {
    let notificationType: String
    let ticketId: String?
    let groupId: String?
    let familyId: String?
    let queueId: String?
    let userId: String?
}

// MARK: - Notification Names

extension Foundation.Notification.Name {
    static let navigateFromNotification = Foundation.Notification.Name("navigateFromNotification")
}
