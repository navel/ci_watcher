import Foundation

public enum BackendAuthError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case notConnected
    case apiError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend API URL."
        case .invalidResponse:
            return "Invalid response from backend API."
        case .notConnected:
            return "GitHub is not connected. Install CIWatcher on your repositories first."
        case .apiError(let message):
            return message
        }
    }
}

public final class BackendAuthClient: Sendable {
    private let baseURL: URL
    private let session: URLSession

    private static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }

    public init(baseURL: URL, session: URLSession? = nil) {
        self.baseURL = baseURL
        self.session = session ?? Self.makeDefaultSession()
    }

    public convenience init?(config: BackendConfig?) {
        guard let config else { return nil }
        self.init(baseURL: config.baseURL, session: nil)
    }

    public static func makeDefault() -> BackendAuthClient? {
        guard let config = BackendConfig.default else { return nil }
        return BackendAuthClient(baseURL: config.baseURL, session: nil)
    }

    public func startAuth(credentials: DeviceCredentials) async throws -> AuthStartResponse {
        let body = try JSONEncoder().encode(StartAuthRequest(
            deviceID: credentials.deviceID.uuidString,
            deviceSecret: credentials.deviceSecret
        ))
        return try await send(
            method: "POST",
            path: "/v1/auth/start",
            body: body,
            credentials: nil,
            responseType: AuthStartResponse.self
        )
    }

    public func fetchConnectionStatus(credentials: DeviceCredentials) async throws -> GitHubConnectionStatus {
        try await send(
            method: "GET",
            path: "/v1/me/installation",
            body: nil,
            credentials: credentials,
            responseType: GitHubConnectionStatus.self
        )
    }

    public func fetchInstallationToken(credentials: DeviceCredentials) async throws -> BackendInstallationToken {
        try await send(
            method: "POST",
            path: "/v1/auth/token",
            body: Data("{}".utf8),
            credentials: credentials,
            responseType: BackendInstallationToken.self
        )
    }

    public func disconnect(credentials: DeviceCredentials) async throws {
        _ = try await send(
            method: "DELETE",
            path: "/v1/auth",
            body: nil,
            credentials: credentials,
            responseType: EmptyResponse.self
        )
    }

    private struct StartAuthRequest: Encodable {
        let deviceID: String
        let deviceSecret: String

        enum CodingKeys: String, CodingKey {
            case deviceID = "device_id"
            case deviceSecret = "device_secret"
        }
    }

    private struct APIErrorResponse: Decodable {
        let error: String
    }

    private struct EmptyResponse: Decodable {}

    private func send<Response: Decodable>(
        method: String,
        path: String,
        body: Data?,
        credentials: DeviceCredentials?,
        responseType: Response.Type
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw BackendAuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let credentials {
            request.setValue("Bearer \(credentials.authorizationHeaderValue)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw BackendAuthError.apiError("Backend API timed out. Please try again.")
        } catch {
            throw BackendAuthError.apiError("Could not reach backend API: \(error.localizedDescription)")
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendAuthError.invalidResponse
        }

        if (200...299).contains(httpResponse.statusCode) {
            if data.isEmpty, Response.self == EmptyResponse.self {
                return EmptyResponse() as! Response
            }
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw BackendAuthError.apiError("Failed to decode backend response (HTTP \(httpResponse.statusCode)).")
            }
        }

        if httpResponse.statusCode == 409 {
            throw BackendAuthError.notConnected
        }

        if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            throw BackendAuthError.apiError(apiError.error)
        }

        if let body = String(data: data, encoding: .utf8), !body.isEmpty {
            throw BackendAuthError.apiError("Backend returned HTTP \(httpResponse.statusCode): \(body.prefix(200))")
        }

        throw BackendAuthError.apiError("Backend returned HTTP \(httpResponse.statusCode).")
    }
}
