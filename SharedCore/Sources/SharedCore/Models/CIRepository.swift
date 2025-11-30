import Foundation

public struct CIRepository: Identifiable, Codable, Hashable {
    public let id: UUID
    public let owner: String
    public let name: String
    public let isPrivate: Bool
    
    public init(id: UUID = UUID(), owner: String, name: String, isPrivate: Bool) {
        self.id = id
        self.owner = owner
        self.name = name
        self.isPrivate = isPrivate
    }
    
    public var fullName: String {
        "\(owner)/\(name)"
    }
}


