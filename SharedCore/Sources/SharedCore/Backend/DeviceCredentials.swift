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
        if let idString = KeychainManager.retrieve(forKey: Keys.deviceID),
           let secret = KeychainManager.retrieve(forKey: Keys.deviceSecret),
           let deviceID = UUID(uuidString: idString) {
            return DeviceCredentials(deviceID: deviceID, deviceSecret: secret)
        }

        let deviceID = UUID()
        let deviceSecret = generateSecret()
        _ = KeychainManager.store(deviceID.uuidString, forKey: Keys.deviceID)
        _ = KeychainManager.store(deviceSecret, forKey: Keys.deviceSecret)
        return DeviceCredentials(deviceID: deviceID, deviceSecret: deviceSecret)
    }

    private enum Keys {
        static let deviceID = "backend_device_id"
        static let deviceSecret = "backend_device_secret"
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
