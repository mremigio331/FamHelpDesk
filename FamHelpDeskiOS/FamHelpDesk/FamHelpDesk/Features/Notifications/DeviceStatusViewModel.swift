import Combine
import Foundation
import UIKit

/// ViewModel for managing device status and registration
@MainActor
final class DeviceStatusViewModel: ObservableObject {
    @Published var device: Device?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let networkManager: NetworkManager
    private let notificationManager: NotificationManager

    init(networkManager: NetworkManager? = nil, notificationManager: NotificationManager? = nil) {
        self.networkManager = networkManager ?? .shared
        self.notificationManager = notificationManager ?? .shared
    }

    // MARK: - Device Status

    /// Load current device status from backend
    func loadDeviceStatus() async {
        isLoading = true
        errorMessage = nil

        // Get device_id from UIDevice
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else {
            errorMessage = "Could not get device identifier"
            isLoading = false
            return
        }

        print("📱 [DeviceStatusViewModel] Loading device status for: \(deviceId)")

        do {
            // Call backend API GET /devices/{device_id}
            let fetchedDevice: Device = try await networkManager.get(endpoint: "/devices/\(deviceId)")
            device = fetchedDevice
            print("✅ [DeviceStatusViewModel] Device loaded successfully")
        } catch {
            print("❌ [DeviceStatusViewModel] Error loading device: \(error)")
            // Device not found is expected if not registered
            device = nil

            // Only show error if it's not a 404
            if let networkError = error as? NetworkError {
                switch networkError {
                case let .serverError(statusCode, _) where statusCode == 404:
                    // 404 is expected if device not registered
                    break
                default:
                    errorMessage = "Error loading device status"
                }
            } else {
                errorMessage = "Error loading device status"
            }
        }

        isLoading = false
    }

    // MARK: - Device Registration

    /// Trigger device registration flow
    func registerDevice() async {
        errorMessage = nil

        print("📱 [DeviceStatusViewModel] Triggering device registration")

        // Request permissions
        let granted = await notificationManager.requestPermissions()

        if !granted {
            errorMessage = "Notification permissions denied. Please enable in Settings."
            return
        }

        // The actual registration will happen when APNs provides the device token
        // via the AppDelegate callback, which will call NotificationManager.registerDevice()

        // Wait a moment and reload to check if registration succeeded
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        await loadDeviceStatus()
    }

    // MARK: - Device Unregistration

    /// Unregister current device from backend
    func unregisterDevice() async {
        errorMessage = nil

        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else {
            errorMessage = "Could not get device identifier"
            return
        }

        print("📱 [DeviceStatusViewModel] Unregistering device: \(deviceId)")

        do {
            // Call NotificationManager to handle unregistration
            await notificationManager.unregisterDevice()

            // Clear local device state
            device = nil

            print("✅ [DeviceStatusViewModel] Device unregistered successfully")
        } catch {
            print("❌ [DeviceStatusViewModel] Error unregistering device: \(error)")
            errorMessage = "Failed to unregister device"
        }
    }

    // MARK: - Device Enable/Disable

    /// Disable push notifications without unregistering
    func disableDevice() async {
        errorMessage = nil

        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else {
            errorMessage = "Could not get device identifier"
            return
        }

        print("📱 [DeviceStatusViewModel] Disabling device: \(deviceId)")

        do {
            // Call backend API to disable device
            let _: Device = try await networkManager.put(endpoint: "/devices/\(deviceId)/disable", body: EmptyBody())

            // Reload device status
            await loadDeviceStatus()

            print("✅ [DeviceStatusViewModel] Device disabled successfully")
        } catch {
            print("❌ [DeviceStatusViewModel] Error disabling device: \(error)")
            errorMessage = "Failed to disable device"
        }
    }

    /// Enable push notifications
    func enableDevice() async {
        errorMessage = nil

        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else {
            errorMessage = "Could not get device identifier"
            return
        }

        print("📱 [DeviceStatusViewModel] Enabling device: \(deviceId)")

        do {
            // Call backend API to enable device
            let _: Device = try await networkManager.put(endpoint: "/devices/\(deviceId)/enable", body: EmptyBody())

            // Reload device status
            await loadDeviceStatus()

            print("✅ [DeviceStatusViewModel] Device enabled successfully")
        } catch {
            print("❌ [DeviceStatusViewModel] Error enabling device: \(error)")
            errorMessage = "Failed to enable device"
        }
    }
}

// MARK: - Helper Types

private struct EmptyBody: Codable {}
