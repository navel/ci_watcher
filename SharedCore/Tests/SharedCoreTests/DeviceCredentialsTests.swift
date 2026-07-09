import XCTest
@testable import SharedCore

@available(macOS 13.0, iOS 16.0, *)
final class DeviceCredentialsTests: XCTestCase {
    private let deviceIDKey = "CIWatcher.BackendDeviceID"
    private let deviceSecretKey = "CIWatcher.BackendDeviceSecret"

    override func setUp() {
        super.setUp()
        clearStoredCredentials()
    }

    override func tearDown() {
        clearStoredCredentials()
        super.tearDown()
    }

    private func clearStoredCredentials() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: deviceIDKey)
        defaults.removeObject(forKey: deviceSecretKey)
    }

    func testLoadOrCreateStoresInUserDefaults() {
        let credentials = DeviceCredentials.loadOrCreate()
        let reload = DeviceCredentials.loadOrCreate()

        XCTAssertEqual(credentials.deviceID, reload.deviceID)
        XCTAssertEqual(credentials.deviceSecret, reload.deviceSecret)
        XCTAssertEqual(UserDefaults.standard.string(forKey: deviceIDKey), credentials.deviceID.uuidString)
        XCTAssertEqual(UserDefaults.standard.string(forKey: deviceSecretKey), credentials.deviceSecret)
    }
}
