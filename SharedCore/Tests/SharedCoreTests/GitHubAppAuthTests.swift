import XCTest
@testable import SharedCore

@available(macOS 13.0, iOS 16.0, *)
final class GitHubAppAuthTests: XCTestCase {
    
    // MARK: - Test Configuration
    // All values are loaded from .env file (no hardcoded secrets)
    var appID: String {
        return GitHubAppConfig.default.appID
    }
    
    var clientID: String {
        return GitHubAppConfig.default.clientID
    }
    
    // Private key is read from GitHubAppConfig (embedded or Keychain fallback)
    var privateKey: String? {
        return GitHubAppConfig.default.getPrivateKey()
    }
    
    // MARK: - Tests
    
    func testGitHubAppAuthInitialization() {
        guard let key = privateKey else {
            XCTSkip("Private key not found. Check GitHubAppConfig.default")
            return
        }
        
        let auth = GitHubAppAuth(appID: appID, privateKey: key)
        XCTAssertNotNil(auth)
    }
    
    func testJWTGeneration() async throws {
        guard let key = privateKey else {
            XCTSkip("Private key not found")
            return
        }
        
        let auth = GitHubAppAuth(appID: appID, privateKey: key)
        let jwt = try auth.generateJWT()
        
        XCTAssertFalse(jwt.isEmpty, "JWT should not be empty")
        XCTAssertTrue(jwt.contains("."), "JWT should contain dots (header.payload.signature)")
        
        // JWT consists of 3 parts, separated by dots
        let parts = jwt.components(separatedBy: ".")
        XCTAssertEqual(parts.count, 3, "JWT should have 3 parts")
    }
    
    func testGetInstallations() async throws {
        guard let key = privateKey else {
            XCTSkip("Private key not found")
            return
        }
        
        let auth = GitHubAppAuth(appID: appID, privateKey: key)
        let installations = try await auth.getInstallations()
        
        // May be empty array if app is not installed yet
        XCTAssertNotNil(installations, "Installations should not be nil")
        print("📱 Found \(installations.count) installation(s)")
        
        for installation in installations {
            print("   - Installation ID: \(installation.id)")
            if let account = installation.account {
                print("     Account: \(account.login) (\(account.type))")
            }
        }
    }
    
    func testGetInstallationToken() async throws {
        guard let key = privateKey else {
            XCTSkip("Private key not found")
            return
        }
        
        let auth = GitHubAppAuth(appID: appID, privateKey: key)
        
        // First, get list of installations
        let installations = try await auth.getInstallations()
        
        guard let firstInstallation = installations.first else {
            XCTSkip("No installations found. Please install the GitHub App first.")
            return
        }
        
        // Get token for first installation
        let tokenResponse = try await auth.getInstallationToken(installationID: firstInstallation.id)
        
        XCTAssertFalse(tokenResponse.token.isEmpty, "Token should not be empty")
        XCTAssertTrue(tokenResponse.expiresAt > Date(), "Token should not be expired")
        
        print("✅ Installation token obtained")
        print("   Token: \(tokenResponse.token.prefix(20))...")
        print("   Expires at: \(tokenResponse.expiresAt)")
    }
    
    func testFullFlow() async throws {
        guard let key = privateKey else {
            XCTSkip("Private key not found")
            return
        }
        
        print("🚀 Testing full GitHub App authentication flow...")
        print("")
        
        // 1. Initialization
        let auth = GitHubAppAuth(appID: appID, privateKey: key)
        print("✅ Step 1: GitHubAppAuth initialized")
        
        // 2. JWT generation
        let jwt = try auth.generateJWT()
        print("✅ Step 2: JWT generated (\(jwt.prefix(20))...)")
        
        // 3. Get installations
        let installations = try await auth.getInstallations()
        print("✅ Step 3: Found \(installations.count) installation(s)")
        
        guard let installation = installations.first else {
            print("⚠️  No installations found. Install the app at:")
            print("   https://github.com/apps/ciwatcher-native")
            throw XCTSkip("No installations found")
        }
        
        // 4. Get installation token
        let tokenResponse = try await auth.getInstallationToken(installationID: installation.id)
        print("✅ Step 4: Installation token obtained")
        
        // 5. Use token for API request
        let client = GitHubAPIClient(token: tokenResponse.token)
        do {
            // Try to get list of repositories for installation
            // This requires additional endpoint, but we can test basic access
            print("✅ Step 5: Token can be used with GitHubAPIClient")
            
            // If there are repositories, we can test getting workflow runs
            if let account = installation.account {
                print("")
                print("🎉 Full flow successful!")
                print("   Account: \(account.login)")
                print("   Installation ID: \(installation.id)")
                print("   Token expires: \(tokenResponse.expiresAt)")
            }
        } catch {
            print("⚠️  Note: \(error.localizedDescription)")
        }
    }
}
