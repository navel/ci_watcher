import Foundation
import Security

/// Keychain Manager for storing sensitive data
/// Uses macOS/iOS Keychain for secure storage
public class KeychainManager {
    
    // Keychain service identifier
    private static let service = "dev.ciwatcher.app"
    
    /// Store a string value in Keychain
    /// - Parameters:
    ///   - value: The string to store
    ///   - key: The key identifier
    /// - Returns: True if successful, false otherwise
    @discardableResult
    public static func store(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        
        // Delete existing item first
        delete(key: key)
        
        // Create query
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Add to Keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            return true
        } else if status == errSecDuplicateItem {
            // Update if exists
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key
            ]
            let updateAttributes: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            return updateStatus == errSecSuccess
        }
        
        #if DEBUG
        if let errorMessage = SecCopyErrorMessageString(status, nil) {
            print("⚠️ Keychain error: \(status) - \(errorMessage)")
        }
        #endif
        return false
    }
    
    /// Retrieve a string value from Keychain
    /// - Parameter key: The key identifier
    /// - Returns: The stored string, or nil if not found
    public static func retrieve(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status != errSecSuccess {
            #if DEBUG
            if let errorMessage = SecCopyErrorMessageString(status, nil) {
                print("⚠️ Keychain retrieve error: \(status) - \(errorMessage)")
            }
            #endif
            return nil
        }
        
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    /// Delete a value from Keychain
    /// - Parameter key: The key identifier
    /// - Returns: True if successful, false otherwise
    @discardableResult
    public static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Check if a key exists in Keychain
    /// - Parameter key: The key identifier
    /// - Returns: True if key exists, false otherwise
    public static func exists(key: String) -> Bool {
        return retrieve(forKey: key) != nil
    }
}

// MARK: - GitHub App Specific Keys

extension KeychainManager {
    /// Key for GitHub App Private Key
    public static let gitHubAppPrivateKeyKey = "github_app_private_key"
    
    /// Store GitHub App Private Key
    public static func storeGitHubAppPrivateKey(_ privateKey: String) -> Bool {
        return store(privateKey, forKey: gitHubAppPrivateKeyKey)
    }
    
    /// Retrieve GitHub App Private Key
    public static func getGitHubAppPrivateKey() -> String? {
        return retrieve(forKey: gitHubAppPrivateKeyKey)
    }
    
    /// Delete GitHub App Private Key
    public static func deleteGitHubAppPrivateKey() -> Bool {
        return delete(key: gitHubAppPrivateKeyKey)
    }
    
    /// Store GitHub App ID
    public static func storeGitHubAppID(_ appID: String) -> Bool {
        return store(appID, forKey: "github_app_id")
    }
    
    /// Store GitHub Client ID
    public static func storeGitHubClientID(_ clientID: String) -> Bool {
        return store(clientID, forKey: "github_client_id")
    }
    
    /// Store GitHub Client Secret
    public static func storeGitHubClientSecret(_ clientSecret: String) -> Bool {
        return store(clientSecret, forKey: "github_client_secret")
    }
}

