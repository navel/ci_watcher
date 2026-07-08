import Foundation

enum GitHubRepositoryReferenceParser {
    static func parse(_ input: String) throws -> (owner: String, name: String) {
        var trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        
        if trimmed.lowercased().hasSuffix(".git") {
            trimmed = String(trimmed.dropLast(4))
        }
        
        if trimmed.contains("://") || trimmed.lowercased().hasPrefix("github.com/") {
            guard let reference = parseGitHubURL(trimmed) else {
                throw RepositoryAddError.invalidFormat
            }
            return reference
        }
        
        let parts = trimmed.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2,
              !parts[0].isEmpty,
              !parts[1].isEmpty else {
            throw RepositoryAddError.invalidFormat
        }
        
        return (String(parts[0]), String(parts[1]))
    }
    
    private static func parseGitHubURL(_ string: String) -> (owner: String, name: String)? {
        var urlString = string
        if !urlString.contains("://") {
            urlString = "https://\(urlString)"
        }
        
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased(),
              host == "github.com" || host == "www.github.com" else {
            return nil
        }
        
        let pathParts = url.path
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
        
        guard pathParts.count >= 2 else {
            return nil
        }
        
        return (pathParts[0], pathParts[1])
    }
}
