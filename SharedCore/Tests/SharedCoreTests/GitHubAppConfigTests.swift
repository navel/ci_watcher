import XCTest
@testable import SharedCore

@available(macOS 13.0, iOS 16.0, *)
final class GitHubAppConfigTests: XCTestCase {
    
    private let testPrivateKey = TestFixtures.rsaPrivateKeyPEM
    private let testKeychainKey = "test_private_key_\(UUID().uuidString)"
    
    override func tearDown() {
        KeychainManager.delete(key: testKeychainKey)
        KeychainManager.deleteGitHubAppPrivateKey()
        super.tearDown()
    }
    
    func testKeychainStoreAndRetrieve() {
        let testValue = "test_secret_value"
        
        XCTAssertTrue(KeychainManager.store(testValue, forKey: testKeychainKey))
        XCTAssertEqual(KeychainManager.retrieve(forKey: testKeychainKey), testValue)
        
        KeychainManager.delete(key: testKeychainKey)
        XCTAssertNil(KeychainManager.retrieve(forKey: testKeychainKey))
    }
    
    func testGitHubAppPrivateKeyStorage() {
        XCTAssertTrue(KeychainManager.storeGitHubAppPrivateKey(testPrivateKey))
        XCTAssertTrue(KeychainManager.exists(key: KeychainManager.gitHubAppPrivateKeyKey))
        XCTAssertEqual(KeychainManager.getGitHubAppPrivateKey(), testPrivateKey)
    }
    
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
        KeychainManager.deleteGitHubAppPrivateKey()
        
        let configWithoutKey = GitHubAppConfig(
            appID: TestFixtures.testAppID,
            clientID: TestFixtures.testClientID
        )
        XCTAssertFalse(configWithoutKey.hasPrivateKey())
        
        KeychainManager.storeGitHubAppPrivateKey(testPrivateKey)
        XCTAssertTrue(GitHubAppConfig.default.hasPrivateKey())
    }
    
    func testGitHubAppConfigCreateAuth() throws {
        KeychainManager.deleteGitHubAppPrivateKey()
        
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
