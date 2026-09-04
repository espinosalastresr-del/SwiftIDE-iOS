import Foundation

enum FileNodeType: String {
    case folder
    case swift
    case json
    case text
    case image
    case other
}

struct FileNode: Identifiable, Hashable {
    /// Stable ID based on path so List updates correctly after refresh.
    var id: String { url.path }
    var name: String
    var url: URL
    var type: FileNodeType
    var children: [FileNode]?
    
    init(name: String, url: URL, type: FileNodeType, children: [FileNode]? = nil) {
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
        case "txt", "md", "markdown", "plist", "yml", "yaml": return .text
        case "png", "jpg", "jpeg", "gif", "heic", "webp": return .image
        default: return .other
        }
    }
}
