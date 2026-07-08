import Foundation

public struct CIRepository: Identifiable, Codable, Hashable {
    public let id: UUID
    public let owner: String
    public let name: String
    public let isPrivate: Bool
    public let source: CIRepositorySource
    
    public init(
        id: UUID = UUID(),
        owner: String,
        name: String,
        isPrivate: Bool,
        source: CIRepositorySource = .installation
    ) {
        self.id = id
        self.owner = owner
        self.name = name
        self.isPrivate = isPrivate
        self.source = source
    }
    
    public var fullName: String {
        "\(owner)/\(name)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case owner
        case name
        case isPrivate
        case source
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        owner = try container.decode(String.self, forKey: .owner)
        name = try container.decode(String.self, forKey: .name)
        isPrivate = try container.decode(Bool.self, forKey: .isPrivate)
        source = try container.decodeIfPresent(CIRepositorySource.self, forKey: .source) ?? .installation
    }
}


