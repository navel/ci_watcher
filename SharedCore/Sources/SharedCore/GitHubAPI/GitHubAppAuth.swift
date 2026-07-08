import Foundation
import JWTKit
import Security

/// GitHub App Authentication
/// Handles JWT generation and installation access token retrieval
public class GitHubAppAuth {
    private let appID: String
    private let privateKey: String
    private let baseURL = "https://api.github.com"
    
    public init(appID: String, privateKey: String) {
        self.appID = appID
        self.privateKey = privateKey
    }
    
    /// Generate JWT token for GitHub App authentication
    /// JWT is valid for 10 minutes
    public func generateJWT() async throws -> String {
        do {
            let pemString = try normalizedPEMString(privateKey)
            let rsaPrivateKey = try Insecure.RSA.PrivateKey(pem: pemString)
            let keys = await JWTKeyCollection().add(
                rsa: rsaPrivateKey,
                digestAlgorithm: .sha256
            )
            
            let now = Date()
            let payload = GitHubAppPayload(
                iss: IssuerClaim(value: appID),
                iat: IssuedAtClaim(value: now.addingTimeInterval(-60)),
                exp: ExpirationClaim(value: now.addingTimeInterval(10 * 60))
            )
            
            return try await keys.sign(payload)
        } catch {
            if error is GitHubAppAuthError {
                throw error
            }
            throw GitHubAppAuthError.invalidPrivateKey
        }
    }
    
    // MARK: - Private Helpers
    
    private func normalizedPEMString(_ pemString: String) throws -> String {
        let isBase64Only = !pemString.contains("-----BEGIN") && !pemString.contains("-----END")
        
        if isBase64Only {
            let cleanedBase64 = pemString
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\t", with: "")
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\r", with: "")
            
            guard let decodedPEM = Data(base64Encoded: cleanedBase64),
                  let decodedString = String(data: decodedPEM, encoding: .utf8) else {
                throw GitHubAppAuthError.invalidPrivateKey
            }
            return decodedString
        }
        
        return pemString
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\r")
    }
    
    /// Get list of installations for the app
    public func getInstallations() async throws -> [Installation] {
        do {
        let jwt = try await generateJWT()
        let endpoint = "/app/installations"
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw GitHubAppAuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAppAuthError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw GitHubAppAuthError.unauthorized
            }
            throw GitHubAppAuthError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([Installation].self, from: data)
        } catch let error as GitHubAppAuthError {
            throw error
        } catch {
            throw GitHubAppAuthError.networkError(error)
        }
    }
    
    /// Get installation access token for a specific installation
    /// - Parameter installationID: The installation ID
    /// - Returns: Installation access token
    public func getInstallationToken(installationID: Int) async throws -> InstallationToken {
        let jwt = try await generateJWT()
        let endpoint = "/app/installations/\(installationID)/access_tokens"
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw GitHubAppAuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubAppAuthError.invalidResponse
            }
            
            guard httpResponse.statusCode == 201 else {
                if httpResponse.statusCode == 401 {
                    throw GitHubAppAuthError.unauthorized
                }
                throw GitHubAppAuthError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(InstallationToken.self, from: data)
        } catch let error as GitHubAppAuthError {
            throw error
        } catch {
            throw GitHubAppAuthError.networkError(error)
        }
    }
    
    /// Get repositories accessible by a specific installation
    /// - Parameter installationID: The installation ID
    /// - Returns: List of repositories accessible by the installation
    public func getInstallationRepositories(installationID: Int) async throws -> InstallationRepositoriesResponse {
        // First, get the installation token
        let tokenResponse = try await getInstallationToken(installationID: installationID)
        
        // Then use the installation token to get repositories
        // The endpoint /installation/repositories uses the installation token context
        let endpoint = "/installation/repositories"
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw GitHubAppAuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(tokenResponse.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubAppAuthError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    throw GitHubAppAuthError.unauthorized
                }
                throw GitHubAppAuthError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            // Don't use keyDecodingStrategy here because we have explicit CodingKeys
            do {
                let apiResponse = try decoder.decode(InstallationRepositoriesAPIResponse.self, from: data)
                return apiResponse.toInstallationRepositoriesResponse()
            } catch {
                throw GitHubAppAuthError.networkError(error)
            }
        } catch let error as GitHubAppAuthError {
            throw error
        } catch {
            throw GitHubAppAuthError.networkError(error)
        }
    }
    
}

// MARK: - Models

/// JWT payload for GitHub App authentication
struct GitHubAppPayload: JWTPayload {
    var iss: IssuerClaim
    var iat: IssuedAtClaim
    var exp: ExpirationClaim
    
    func verify(using algorithm: some JWTAlgorithm) async throws {
        try exp.verifyNotExpired()
    }
}

public struct InstallationToken: Codable {
    public let token: String
    public let expiresAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = try container.decode(String.self, forKey: .token)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
    }
}

public struct Installation: Codable {
    public let id: Int
    public let account: InstallationAccount?
    
    enum CodingKeys: String, CodingKey {
        case id
        case account
    }
}

public struct InstallationAccount: Codable {
    public let login: String
    public let type: String
}

// MARK: - Installation Repositories

public struct InstallationRepositoriesResponse: Codable {
    public let totalCount: Int
    public let repositories: [InstallationRepository]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case repositories
    }
}

public struct InstallationRepository: Codable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let `private`: Bool
    public let owner: InstallationRepositoryOwner
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case `private`
        case owner
    }
}

public struct InstallationRepositoryOwner: Codable {
    public let login: String
}

// API Response Models
struct InstallationRepositoriesAPIResponse: Codable {
    let totalCount: Int
    let repositories: [InstallationRepositoryAPI]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case repositories
    }
    
    func toInstallationRepositoriesResponse() -> InstallationRepositoriesResponse {
        InstallationRepositoriesResponse(
            totalCount: totalCount,
            repositories: repositories.map { repo in
                InstallationRepository(
                    id: repo.id,
                    name: repo.name,
                    fullName: repo.fullName,
                    private: repo.private,
                    owner: InstallationRepositoryOwner(login: repo.owner.login)
                )
            }
        )
    }
}

struct InstallationRepositoryAPI: Codable {
    let id: Int
    let name: String
    let fullName: String
    let `private`: Bool
    let owner: InstallationRepositoryOwnerAPI
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case `private`
        case owner
    }
}

struct InstallationRepositoryOwnerAPI: Codable {
    let login: String
}

public enum GitHubAppAuthError: Error, LocalizedError {
    case invalidPrivateKey
    case invalidURL
    case invalidResponse
    case unauthorized
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidPrivateKey:
            return "Invalid private key. Please check your GitHub App configuration."
        case .invalidURL:
            return "Invalid API URL. Please contact support."
        case .invalidResponse:
            return "Invalid response from GitHub API. Please try again later."
        case .unauthorized:
            return "Unauthorized. Please check your GitHub App credentials."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

