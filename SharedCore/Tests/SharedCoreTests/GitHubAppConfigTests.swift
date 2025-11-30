import XCTest
@testable import SharedCore

@available(macOS 13.0, iOS 16.0, *)
final class GitHubAppConfigTests: XCTestCase {
    
    let testPrivateKey = """
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA3xKw7K...
-----END RSA PRIVATE KEY-----
"""
    
    override func tearDown() {
        // Clear Keychain after each test
        KeychainManager.deleteGitHubAppPrivateKey()
        super.tearDown()
    }
    
    func testKeychainStoreAndRetrieve() {
        // Test storing and retrieving from Keychain
        let testKey = "test_private_key"
        let testValue = "test_secret_value"
        
        // Store
        let stored = KeychainManager.store(testValue, forKey: testKey)
        XCTAssertTrue(stored, "Should be stored in Keychain")
        
        // Retrieve
        let retrieved = KeychainManager.retrieve(forKey: testKey)
        XCTAssertEqual(retrieved, testValue, "Should match stored value")
        
        // Delete
        KeychainManager.delete(key: testKey)
        
        // Check that it's deleted
        let afterDelete = KeychainManager.retrieve(forKey: testKey)
        XCTAssertNil(afterDelete, "Should be deleted from Keychain")
    }
    
    func testGitHubAppPrivateKeyStorage() {
        // Test storing GitHub App private key
        let keyContent = """
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA3xKw7K...
-----END RSA PRIVATE KEY-----
"""
        
        // Store
        let stored = KeychainManager.storeGitHubAppPrivateKey(keyContent)
        XCTAssertTrue(stored, "Private key should be stored")
        
        // Check existence
        let exists = KeychainManager.exists(key: KeychainManager.gitHubAppPrivateKeyKey)
        XCTAssertTrue(exists, "Key should exist in Keychain")
        
        // Retrieve
        let retrieved = KeychainManager.getGitHubAppPrivateKey()
        XCTAssertNotNil(retrieved, "Key should be available")
        XCTAssertEqual(retrieved, keyContent, "Key should match")
    }
    
    func testGitHubAppConfigDefault() {
        // Config should load from .env file
        // Values are loaded from .env, so we just check they exist
        let config = GitHubAppConfig.default
        XCTAssertFalse(config.appID.isEmpty, "App ID should be loaded from .env")
        XCTAssertFalse(config.clientID.isEmpty, "Client ID should be loaded from .env")
    }
    
    func testGitHubAppConfigHasPrivateKey() {
        let config = GitHubAppConfig.default
        
        // Clear Keychain before test
        KeychainManager.deleteGitHubAppPrivateKey()
        
        // Initially no key (if cleared)
        // But may already be saved for other tests, so check logic
        let hadKeyBefore = config.hasPrivateKey()
        
        // Store key
        KeychainManager.storeGitHubAppPrivateKey(testPrivateKey)
        
        // Now should exist
        XCTAssertTrue(config.hasPrivateKey(), "Key should exist now")
        
        // Restore previous state
        if !hadKeyBefore {
            KeychainManager.deleteGitHubAppPrivateKey()
        } else {
            // If key existed before test, leave it
        }
    }
    
    func testGitHubAppConfigCreateAuth() throws {
        let config = GitHubAppConfig.default
        
        // Store temporary key (may already be stored)
        let hadKeyBefore = config.hasPrivateKey()
        KeychainManager.storeGitHubAppPrivateKey(testPrivateKey)
        
        // Should work with key (although key is invalid, structure should be created)
        let auth = try? config.createAuth()
        XCTAssertNotNil(auth, "GitHubAppAuth should be created")
        
        // Restore state
        if !hadKeyBefore {
            KeychainManager.deleteGitHubAppPrivateKey()
            
            // Now without key should throw error
            XCTAssertThrowsError(try config.createAuth()) { error in
                XCTAssertTrue(error is GitHubAppConfigError)
                if case GitHubAppConfigError.privateKeyNotFound = error {
                    // Expected error
                } else {
                    XCTFail("Expected privateKeyNotFound error")
                }
            }
        }
    }
}

