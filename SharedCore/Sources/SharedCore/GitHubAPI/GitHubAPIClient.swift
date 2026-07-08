import Foundation

public enum GitHubAPIError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimitExceeded
    case networkError(Error)
    case decodingError(Error)
}

public class GitHubAPIClient {
    private let baseURL = "https://api.github.com"
    private let token: String?
    private let session: URLSession
    
    public static let publicAccess = GitHubAPIClient(token: nil)
    
    public init(token: String) {
        self.token = token
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        // Disable caching to ensure we always get fresh data
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }
    
    private init(token: String?) {
        self.token = token
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }
    
    /// Create GitHubAPIClient using GitHub App installation token
    /// - Parameters:
    ///   - config: GitHub App configuration
    ///   - installationID: Installation ID (if nil, will use first available installation)
    /// - Returns: GitHubAPIClient with installation token
    /// - Throws: Error if authentication fails or no installation found
    public static func withGitHubApp(
        config: GitHubAppConfig,
        installationID: Int? = nil
    ) async throws -> GitHubAPIClient {
        let auth = try config.createAuth()
        
        // Get installations
        let installations = try await auth.getInstallations()
        
        guard let installation = installations.first(where: { installationID == nil || $0.id == installationID }) else {
            if let id = installationID {
                throw GitHubAPIError.invalidResponse // Installation not found
            } else {
                throw GitHubAPIError.unauthorized // No installations
            }
        }
        
        // Get installation token
        let tokenResponse = try await auth.getInstallationToken(installationID: installation.id)
        
        return GitHubAPIClient(token: tokenResponse.token)
    }
    
    private func makeRequest(
        endpoint: String,
        method: String = "GET"
    ) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw GitHubAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubAPIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return data
            case 401:
                throw GitHubAPIError.unauthorized
            case 403:
                // Check if it's rate limit
                if let rateLimitRemaining = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
                   rateLimitRemaining == "0" {
                    throw GitHubAPIError.rateLimitExceeded
                }
                throw GitHubAPIError.unauthorized
            default:
                throw GitHubAPIError.invalidResponse
            }
        } catch let error as GitHubAPIError {
            throw error
        } catch {
            throw GitHubAPIError.networkError(error)
        }
    }
    
    public func getRepository(
        owner: String,
        repo: String
    ) async throws -> GitHubRepository {
        let endpoint = "/repos/\(owner)/\(repo)"
        let data = try await makeRequest(endpoint: endpoint)
        
        do {
            let apiResponse = try JSONDecoder().decode(GitHubRepositoryAPI.self, from: data)
            return apiResponse.toGitHubRepository()
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }
    
    public func getWorkflowRuns(
        owner: String,
        repo: String,
        perPage: Int = 30,
        page: Int = 1
    ) async throws -> WorkflowRunsResponse {
        let endpoint = "/repos/\(owner)/\(repo)/actions/runs?per_page=\(perPage)&page=\(page)"
        
        let data = try await makeRequest(endpoint: endpoint)
        
        do {
            // Don't use keyDecodingStrategy here because we have explicit CodingKeys
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(WorkflowRunsAPIResponse.self, from: data)
            return apiResponse.toWorkflowRunsResponse()
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }
    
    public func getWorkflowRunJobs(
        owner: String,
        repo: String,
        runId: Int
    ) async throws -> WorkflowJobsResponse {
        let endpoint = "/repos/\(owner)/\(repo)/actions/runs/\(runId)/jobs"
        
        let data = try await makeRequest(endpoint: endpoint)
        
        do {
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(WorkflowJobsAPIResponse.self, from: data)
            return apiResponse.toWorkflowJobsResponse()
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }
    
    public func testConnection() async throws {
        // Test with a simple API call to verify token
        let endpoint = "/user"
        _ = try await makeRequest(endpoint: endpoint)
    }
}


