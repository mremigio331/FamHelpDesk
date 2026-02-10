import Foundation

/// Model representing a registered iOS device for push notifications
struct Device: Identifiable, Codable {
    let id: String
    let deviceId: String
    let environment: String
    let bundleId: String
    let enabled: Bool
    let createdDate: Int
    let lastUpdated: Int

    /// Formatted date string for display
    var formattedDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(createdDate))
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case environment
        case bundleId = "bundle_id"
        case enabled
        case createdDate = "created_date"
        case lastUpdated = "last_updated"
    }
}
