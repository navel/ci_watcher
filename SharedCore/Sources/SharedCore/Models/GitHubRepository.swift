import Foundation

public enum CIRepositorySource: String, Codable, Hashable {
    case installation
    case manual
}

public struct GitHubRepository: Codable, Hashable {
    public let owner: String
    public let name: String
    public let fullName: String
    public let isPrivate: Bool
    
    public init(owner: String, name: String, fullName: String, isPrivate: Bool) {
        self.owner = owner
        self.name = name
        self.fullName = fullName
        self.isPrivate = isPrivate
    }
}

struct GitHubRepositoryAPI: Codable {
    let name: String
    let fullName: String
    let `private`: Bool
    let owner: GitHubRepositoryOwnerAPI
    
    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case `private`
        case owner
    }
    
    func toGitHubRepository() -> GitHubRepository {
        GitHubRepository(
            owner: owner.login,
            name: name,
            fullName: fullName,
            isPrivate: `private`
        )
    }
}

struct GitHubRepositoryOwnerAPI: Codable {
    let login: String
}
