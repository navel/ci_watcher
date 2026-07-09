import Foundation

public struct GitHubConnectionStatus: Codable, Equatable, Sendable {
    public let connected: Bool
    public let installationID: Int?
    public let githubLogin: String?
    public let githubAccountType: String?

    public init(
        connected: Bool,
        installationID: Int?,
        githubLogin: String?,
        githubAccountType: String?
    ) {
        self.connected = connected
        self.installationID = installationID
        self.githubLogin = githubLogin
        self.githubAccountType = githubAccountType
    }

    enum CodingKeys: String, CodingKey {
        case connected
        case installationID = "installation_id"
        case githubLogin = "github_login"
        case githubAccountType = "github_account_type"
    }
}

public struct BackendInstallationToken: Codable, Sendable {
    public let token: String
    public let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
    }
}

public struct AuthStartResponse: Codable, Sendable {
    public let authURL: String
    public let state: String

    enum CodingKeys: String, CodingKey {
        case authURL = "auth_url"
        case state
    }

    public var url: URL? {
        URL(string: authURL)
    }
}

public extension Notification.Name {
    static let ciwatcherAuthCallback = Notification.Name("CIWatcherAuthCallback")
}
