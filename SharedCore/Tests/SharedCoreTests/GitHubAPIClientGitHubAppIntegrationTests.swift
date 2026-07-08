import XCTest
@testable import SharedCore

/// Live API tests — run only when CIWATCHER_RUN_INTEGRATION_TESTS=1 is set.
@available(macOS 13.0, iOS 16.0, *)
final class GitHubAPIClientGitHubAppIntegrationTests: XCTestCase {
    
    override func setUpWithError() throws {
        try XCTSkipUnless(
            TestFixtures.integrationTestsEnabled,
            "Set CIWATCHER_RUN_INTEGRATION_TESTS=1 to run live GitHub API tests"
        )
    }
    
    func testWithGitHubAppCreation() async throws {
        let config = GitHubAppConfig.default
        
        guard config.hasPrivateKey() else {
            XCTSkip("Private key not configured")
            return
        }
        
        do {
            let client = try await GitHubAPIClient.withGitHubApp(config: config)
            XCTAssertNotNil(client)
            try await client.testConnection()
        } catch GitHubAPIError.unauthorized {
            XCTSkip("GitHub App not installed")
        } catch GitHubAPIError.invalidResponse {
            XCTSkip("No installations found")
        }
    }
}
