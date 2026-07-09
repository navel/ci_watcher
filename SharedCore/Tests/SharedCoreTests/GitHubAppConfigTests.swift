import XCTest
@testable import SharedCore

@available(macOS 13.0, iOS 16.0, *)
final class GitHubAppConfigTests: XCTestCase {
    private let testPrivateKey = TestFixtures.rsaPrivateKeyPEM

    func testGitHubAppConfigExplicitInit() {
        let config = GitHubAppConfig(
            appID: TestFixtures.testAppID,
            clientID: TestFixtures.testClientID,
            embeddedPrivateKey: testPrivateKey
        )

        XCTAssertTrue(config.isValid())
        XCTAssertTrue(config.hasPrivateKey())
        XCTAssertEqual(config.getPrivateKey(), testPrivateKey)
    }

    func testGitHubAppConfigHasPrivateKey() {
        let configWithoutKey = GitHubAppConfig(
            appID: TestFixtures.testAppID,
            clientID: TestFixtures.testClientID
        )
        XCTAssertFalse(configWithoutKey.hasPrivateKey())

        let configWithKey = GitHubAppConfig(
            appID: TestFixtures.testAppID,
            clientID: TestFixtures.testClientID,
            embeddedPrivateKey: testPrivateKey
        )
        XCTAssertTrue(configWithKey.hasPrivateKey())
    }

    func testGitHubAppConfigCreateAuth() throws {
        let configWithoutKey = GitHubAppConfig(
            appID: TestFixtures.testAppID,
            clientID: TestFixtures.testClientID
        )
        XCTAssertThrowsError(try configWithoutKey.createAuth())

        let configWithKey = GitHubAppConfig(
            appID: TestFixtures.testAppID,
            clientID: TestFixtures.testClientID,
            embeddedPrivateKey: testPrivateKey
        )
        XCTAssertNotNil(try configWithKey.createAuth())
    }
}
