import Foundation

public enum RepositoryAddError: LocalizedError {
    case invalidFormat
    case alreadyTracked
    case notFound
    case noAccess
    case notConnected
    
    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Enter repository as owner/name or GitHub URL, for example: https://github.com/apple/container"
        case .alreadyTracked:
            return "This repository is already being tracked."
        case .notFound:
            return "Repository not found. Check the name and your access."
        case .noAccess:
            return "Cannot read GitHub Actions for this repository. For private repositories, install the GitHub App on the repository."
        case .notConnected:
            return "Connect the GitHub App in settings to track private repositories."
        }
    }
}
