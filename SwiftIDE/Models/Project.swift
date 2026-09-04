import Foundation

struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var rootURL: URL
    var createdAt: Date
    var modifiedAt: Date
    
    init(name: String, rootURL: URL) {
        self.id = UUID()
        self.name = name
        self.rootURL = rootURL
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

struct ProjectMetadata: Codable {
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    var version: Int = 1
}
