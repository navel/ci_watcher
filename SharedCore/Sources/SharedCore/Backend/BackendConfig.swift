import Foundation

public struct BackendConfig: Sendable {
    public let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public static var `default`: BackendConfig? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "CIWATCHER_API_BASE_URL") as? String,
              !rawValue.isEmpty,
              let url = URL(string: rawValue) else {
            return nil
        }
        return BackendConfig(baseURL: url)
    }
}
