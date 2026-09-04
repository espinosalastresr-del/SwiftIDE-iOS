import Foundation

enum FileNodeType {
    case folder
    case swift
    case json
    case text
    case image
    case other
}

struct FileNode: Identifiable, Hashable {
    let id: UUID
    var name: String
    var url: URL
    var type: FileNodeType
    var children: [FileNode]?
    var isExpanded: Bool = false
    
    init(name: String, url: URL, type: FileNodeType, children: [FileNode]? = nil) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.type = type
        self.children = children
    }
    
    static func type(for url: URL) -> FileNodeType {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if isDirectory.boolValue {
            return .folder
        }
        
        switch url.pathExtension.lowercased() {
        case "swift": return .swift
        case "json": return .json
        case "txt", "md", "markdown", "plist": return .text
        case "png", "jpg", "jpeg", "gif", "heic", "webp": return .image
        default: return .other
        }
    }
}
