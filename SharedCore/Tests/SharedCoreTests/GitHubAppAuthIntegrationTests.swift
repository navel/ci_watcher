import XCTest
@testable import SharedCore

/// Live API tests — run only when CIWATCHER_RUN_INTEGRATION_TESTS=1 is set.
@available(macOS 13.0, iOS 16.0, *)
final class GitHubAppAuthIntegrationTests: XCTestCase {
    
    private var appID: String { GitHubAppConfig.default.appID }
    private var privateKey: String? { GitHubAppConfig.default.getPrivateKey() }
    
    override func setUpWithError() throws {
        try XCTSkipUnless(
            TestFixtures.integrationTestsEnabled,
            "Set CIWATCHER_RUN_INTEGRATION_TESTS=1 to run live GitHub API tests"
        )
    }
    
    func testGetInstallations() async throws {
        guard let key = privateKey else {
            XCTSkip("Private key not configured")
            return
        }
        
        let auth = GitHubAppAuth(appID: appID, privateKey: key)
        let installations = try await auth.getInstallations()
        XCTAssertNotNil(installations)
    }
    
    func testGetInstallationToken() async throws {
        guard let key = privateKey else {
            XCTSkip("Private key not configured")
            return
        }
        
        let auth = GitHubAppAuth(appID: appID, privateKey: key)
        let installations = try await auth.getInstallations()
        
        guard let installation = installations.first else {
            XCTSkip("No installations found. Install at https://github.com/apps/ciwatcher-native")
            return
        }
        
        let tokenResponse = try await auth.getInstallationToken(installationID: installation.id)
        XCTAssertFalse(tokenResponse.token.isEmpty)
        if let expiresAt = tokenResponse.expiresAt {
            XCTAssertTrue(expiresAt > Date())
        }
    }
    
    func testFullFlow() async throws {
        guard let key = privateKey else {
            XCTSkip("Private key not configured")
            return
        }
        
        let auth = GitHubAppAuth(appID: appID, privateKey: key)
        _ = try await auth.generateJWT()
        
        let installations = try await auth.getInstallations()
        guard let installation = installations.first else {
            XCTSkip("No installations found")
            return
        }
        
        let tokenResponse = try await auth.getInstallationToken(installationID: installation.id)
        let client = GitHubAPIClient(token: tokenResponse.token)
        XCTAssertNotNil(client)
    }
}
