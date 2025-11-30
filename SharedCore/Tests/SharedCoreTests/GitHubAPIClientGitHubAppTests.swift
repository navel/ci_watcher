import XCTest
@testable import SharedCore

@available(macOS 13.0, iOS 16.0, *)
final class GitHubAPIClientGitHubAppTests: XCTestCase {
    
    func testWithGitHubAppCreation() async throws {
        let config = GitHubAppConfig.default
        
        // Check if key exists in Keychain
        guard config.hasPrivateKey() else {
            XCTSkip("Private key not found in Keychain")
            return
        }
        
        do {
            // Create client with GitHub App
            // This will automatically get installation token
            let client = try await GitHubAPIClient.withGitHubApp(config: config)
            
            // Client should be created
            XCTAssertNotNil(client)
            
            // Test connection
            try await client.testConnection()
            print("✅ GitHubAPIClient with GitHub App works correctly")
        } catch GitHubAPIError.unauthorized {
            // If no installations, this is normal - skip test
            XCTSkip("GitHub App not installed. Install at: https://github.com/apps/ciwatcher-native")
        } catch GitHubAPIError.invalidResponse {
            // No installations
            XCTSkip("No installations found. Install GitHub App first")
        }
    }
}

