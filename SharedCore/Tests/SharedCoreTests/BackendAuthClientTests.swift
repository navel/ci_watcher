import XCTest
@testable import SharedCore

@available(macOS 13.0, iOS 16.0, *)
final class BackendAuthClientTests: XCTestCase {
    func testDecodesConnectionStatus() throws {
        let json = """
        {
          "connected": true,
          "installation_id": 123,
          "github_login": "octocat",
          "github_account_type": "User"
        }
        """.data(using: .utf8)!

        let status = try JSONDecoder().decode(GitHubConnectionStatus.self, from: json)
        XCTAssertTrue(status.connected)
        XCTAssertEqual(status.installationID, 123)
        XCTAssertEqual(status.githubLogin, "octocat")
        XCTAssertEqual(status.githubAccountType, "User")
    }

    func testDecodesAuthStartResponse() throws {
        let json = """
        {
          "auth_url": "https://github.com/apps/ciwatcher-native/installations/new?state=abc",
          "state": "abc"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AuthStartResponse.self, from: json)
        XCTAssertEqual(response.state, "abc")
        XCTAssertNotNil(response.url)
    }

    func testDeviceCredentialsAuthorizationHeader() {
        let credentials = DeviceCredentials(
            deviceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            deviceSecret: "super-secret-value"
        )
        XCTAssertEqual(
            credentials.authorizationHeaderValue,
            "00000000-0000-0000-0000-000000000001.super-secret-value"
        )
    }
}
