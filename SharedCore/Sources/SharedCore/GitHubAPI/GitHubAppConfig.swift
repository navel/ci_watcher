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
    
    /// Default configuration from Info.plist (values come from Secrets.xcconfig via build settings).
    public static var `default`: GitHubAppConfig {
        let infoDict = Bundle.main.infoDictionary ?? [:]
        
        var appID = ""
        if let appIDValue = infoDict["GITHUB_APP_ID"] {
            appID = String(describing: appIDValue)
        }
        
        let clientID = infoDict["GITHUB_CLIENT_ID"] as? String ?? ""
        let clientSecret = infoDict["GITHUB_CLIENT_SECRET"] as? String
        var privateKey = infoDict["GITHUB_PRIVATE_KEY"] as? String
        
        if let key = privateKey {
            privateKey = key
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\r", with: "\r")
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
    
    /// Get private key from build configuration.
    /// - Returns: Private key if found, nil otherwise
    public func getPrivateKey() -> String? {
        guard let embedded = embeddedPrivateKey, !embedded.isEmpty else {
            return nil
        }
        return embedded
    }
    
    /// Check if private key is available in build configuration.
    public func hasPrivateKey() -> Bool {
        guard let embedded = embeddedPrivateKey, !embedded.isEmpty else {
            return false
        }
        return true
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
