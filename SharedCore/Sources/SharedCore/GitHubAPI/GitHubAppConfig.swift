import Foundation

/// GitHub App Configuration
/// Loads from Secrets.xcconfig (build settings) or Info.plist
public struct GitHubAppConfig {
    public let appID: String
    public let clientID: String
    public let clientSecret: String?
    private let embeddedPrivateKey: String?
    
    public init(appID: String, clientID: String, clientSecret: String? = nil, embeddedPrivateKey: String? = nil) {
        self.appID = appID
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.embeddedPrivateKey = embeddedPrivateKey
    }
    
    /// Default configuration
    /// Loads from Info.plist (which gets values from Secrets.xcconfig via build settings)
    /// Falls back to Keychain if Info.plist values are not available
    public static var `default`: GitHubAppConfig {
        let bundle = Bundle.main
        let infoDict = bundle.infoDictionary ?? [:]
        
        var appID = ""
        if let appIDValue = infoDict["GITHUB_APP_ID"] {
            appID = String(describing: appIDValue)
        }
        
        var clientID = infoDict["GITHUB_CLIENT_ID"] as? String ?? ""
        var clientSecret = infoDict["GITHUB_CLIENT_SECRET"] as? String
        var privateKey = infoDict["GITHUB_PRIVATE_KEY"] as? String
        
        if let key = privateKey {
            privateKey = key
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\r", with: "\r")
        }
        
        if privateKey == nil || privateKey!.isEmpty {
            privateKey = KeychainManager.getGitHubAppPrivateKey()
        }
        
        if appID.isEmpty {
            appID = KeychainManager.retrieve(forKey: "github_app_id") ?? ""
        }
        if clientID.isEmpty {
            clientID = KeychainManager.retrieve(forKey: "github_client_id") ?? ""
        }
        if clientSecret == nil {
            clientSecret = KeychainManager.retrieve(forKey: "github_client_secret")
        }
        
        return GitHubAppConfig(
            appID: appID,
            clientID: clientID,
            clientSecret: clientSecret,
            embeddedPrivateKey: privateKey
        )
    }
    
    /// Check if configuration is valid
    /// - Returns: True if all required values are present
    public func isValid() -> Bool {
        return !appID.isEmpty && !clientID.isEmpty && hasPrivateKey()
    }
    
    /// Get private key (embedded or from Keychain fallback)
    /// - Returns: Private key if found, nil otherwise
    public func getPrivateKey() -> String? {
        if let embedded = embeddedPrivateKey, !embedded.isEmpty {
            return embedded
        }
        return KeychainManager.getGitHubAppPrivateKey()
    }
    
    /// Check if private key is available
    /// - Returns: True if private key exists (embedded or in Keychain)
    public func hasPrivateKey() -> Bool {
        if let embedded = embeddedPrivateKey, !embedded.isEmpty {
            return true
        }
        return KeychainManager.exists(key: KeychainManager.gitHubAppPrivateKeyKey)
    }
    
    /// Create GitHubAppAuth instance using private key
    /// - Returns: GitHubAppAuth instance if private key is available
    /// - Throws: Error if private key is not found
    public func createAuth() throws -> GitHubAppAuth {
        guard let privateKey = getPrivateKey() else {
            throw GitHubAppConfigError.privateKeyNotFound
        }
        return GitHubAppAuth(appID: appID, privateKey: privateKey)
    }
}

public enum GitHubAppConfigError: Error {
    case privateKeyNotFound
}

