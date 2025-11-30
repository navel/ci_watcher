import Foundation
import SwiftJWT
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
    public func generateJWT() throws -> String {
        do {
            let keyData = try parsePEMPrivateKey(privateKey)
            let header = Header(typ: "JWT")
            
            let now = Date()
            let iatTime = Int64(now.addingTimeInterval(-60).timeIntervalSince1970)
            let expTime = Int64(now.addingTimeInterval(10 * 60).timeIntervalSince1970)
            
            let claims = GitHubAppClaims(
                iss: appID,
                iat: iatTime,
                exp: expTime
            )
            
            var jwt = JWT(header: header, claims: claims)
            
            let jwtSigner = JWTSigner.rs256(privateKey: keyData)
            let signedJWT = try jwt.sign(using: jwtSigner)
            return signedJWT
        } catch {
            if error is GitHubAppAuthError {
                throw error
            }
            throw GitHubAppAuthError.invalidPrivateKey
        }
    }
    
    // MARK: - Private Helpers
    
    private func parsePEMPrivateKey(_ pemString: String) throws -> Data {
        let isBase64Only = !pemString.contains("-----BEGIN") && !pemString.contains("-----END")
        
        var pemContent: String
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
            pemContent = decodedString
        } else {
            pemContent = pemString
        }
        
        var keyString = pemContent
            .replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\t", with: "")
        
        keyString = keyString.filter { char in
            char.isLetter || char.isNumber || char == "+" || char == "/" || char == "="
        }
        
        let remainder = keyString.count % 4
        if remainder > 0 {
            keyString += String(repeating: "=", count: 4 - remainder)
        }
        
        var keyData = Data(base64Encoded: keyString)
        if keyData == nil {
            keyData = Data(base64Encoded: keyString, options: .ignoreUnknownCharacters)
        }
        if keyData == nil {
            var testString = keyString.replacingOccurrences(of: "=", with: "")
            let testRemainder = testString.count % 4
            if testRemainder > 0 {
                testString += String(repeating: "=", count: 4 - testRemainder)
            }
            keyData = Data(base64Encoded: testString)
        }
        
        guard let decodedData = keyData else {
            throw GitHubAppAuthError.invalidPrivateKey
        }
        
        return decodedData
    }
    
    /// Get list of installations for the app
    public func getInstallations() async throws -> [Installation] {
        do {
        let jwt = try generateJWT()
        let endpoint = "/app/installations"
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw GitHubAppAuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
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
        let jwt = try generateJWT()
        let endpoint = "/app/installations/\(installationID)/access_tokens"
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw GitHubAppAuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
    
}

// MARK: - Models

/// JWT Claims for GitHub App
struct GitHubAppClaims: Claims {
    let iss: String  // Issuer (App ID)
    let iat: Int64   // Issued at (Unix timestamp in seconds)
    let exp: Int64   // Expiration (Unix timestamp in seconds)
}

public struct InstallationToken: Codable {
    public let token: String
    public let expiresAt: Date
    
    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
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

