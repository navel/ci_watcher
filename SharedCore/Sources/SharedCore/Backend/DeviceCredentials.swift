import Foundation
import Security

public struct DeviceCredentials: Sendable {
    public let deviceID: UUID
    public let deviceSecret: String

    public init(deviceID: UUID, deviceSecret: String) {
        self.deviceID = deviceID
        self.deviceSecret = deviceSecret
    }

    public var authorizationHeaderValue: String {
        "\(deviceID.uuidString).\(deviceSecret)"
    }

    public static func loadOrCreate() -> DeviceCredentials {
        if let credentials = loadFromUserDefaults() {
            return credentials
        }

        let deviceID = UUID()
        let deviceSecret = generateSecret()
        saveToUserDefaults(deviceID: deviceID, deviceSecret: deviceSecret)
        return DeviceCredentials(deviceID: deviceID, deviceSecret: deviceSecret)
    }

    private enum Keys {
        static let deviceID = "CIWatcher.BackendDeviceID"
        static let deviceSecret = "CIWatcher.BackendDeviceSecret"
    }

    private static var defaults: UserDefaults {
        UserDefaults.standard
    }

    private static func loadFromUserDefaults() -> DeviceCredentials? {
        guard let idString = defaults.string(forKey: Keys.deviceID),
              let secret = defaults.string(forKey: Keys.deviceSecret),
              let deviceID = UUID(uuidString: idString) else {
            return nil
        }
        return DeviceCredentials(deviceID: deviceID, deviceSecret: secret)
    }

    private static func saveToUserDefaults(deviceID: UUID, deviceSecret: String) {
        defaults.set(deviceID.uuidString, forKey: Keys.deviceID)
        defaults.set(deviceSecret, forKey: Keys.deviceSecret)
    }

    private static func generateSecret() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            return Data(bytes).base64EncodedString()
        }
        return UUID().uuidString + UUID().uuidString
    }
}
