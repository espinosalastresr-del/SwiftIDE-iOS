import Foundation

actor FileSystemService {
    private let fileManager = FileManager.default
    
    private var projectsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Projects", isDirectory: true)
    }
    
    func ensureProjectsDirectory() throws {
        if !fileManager.fileExists(atPath: projectsDirectory.path) {
            try fileManager.createDirectory(at: projectsDirectory, withIntermediateDirectories: true)
        }
    }
    
    func listProjects() throws -> [Project] {
        try ensureProjectsDirectory()
        let contents = try fileManager.contentsOfDirectory(
            at: projectsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        
        var projects: [Project] = []
        for url in contents {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { continue }
            
            let metaURL = url.appendingPathComponent(".swiftide/metadata.json")
            if let data = try? Data(contentsOf: metaURL),
               let meta = try? JSONDecoder().decode(ProjectMetadata.self, from: data) {
                var project = Project(name: meta.name, rootURL: url)
                project.createdAt = meta.createdAt
                project.modifiedAt = meta.modifiedAt
                projects.append(project)
            } else {
                projects.append(Project(name: url.lastPathComponent, rootURL: url))
            }
        }
        
        return projects.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    func createProject(name: String) throws -> Project {
        try ensureProjectsDirectory()
        let safeName = sanitize(name)
        let projectURL = projectsDirectory.appendingPathComponent(safeName, isDirectory: true)
        
        guard !fileManager.fileExists(atPath: projectURL.path) else {
            throw FileSystemError.alreadyExists
        }
        
        try fileManager.createDirectory(at: projectURL, withIntermediateDirectories: true)
        
        let folders = ["Models", "Views", "Resources", "Assets"]
        for folder in folders {
            try fileManager.createDirectory(
                at: projectURL.appendingPathComponent(folder, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        
        let mainContent = """
        //
        //  \(safeName).swift
        //  \(safeName)
        //
        
        import Foundation
        
        """
        try mainContent.write(to: projectURL.appendingPathComponent("\(safeName).swift"), atomically: true, encoding: .utf8)
        
        let contentView = """
        //
        //  ContentView.swift
        //  \(safeName)
        //
        
        import SwiftUI
        
        struct ContentView: View {
            var body: some View {
                Text("Hello, World!")
                    .padding()
            }
        }
        
        #Preview {
            ContentView()
        }
        """
        try contentView.write(to: projectURL.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)
        
        let metaDir = projectURL.appendingPathComponent(".swiftide", isDirectory: true)
        try fileManager.createDirectory(at: metaDir, withIntermediateDirectories: true)
        
        let meta = ProjectMetadata(name: safeName, createdAt: Date(), modifiedAt: Date())
        let data = try JSONEncoder().encode(meta)
        try data.write(to: metaDir.appendingPathComponent("metadata.json"))
        
        return Project(name: safeName, rootURL: projectURL)
    }
    
    func deleteProject(_ project: Project) throws {
        try fileManager.removeItem(at: project.rootURL)
    }
    
    func loadFileTree(at url: URL) throws -> [FileNode] {
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        
        var nodes: [FileNode] = []
        for itemURL in contents.sorted(by: { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }) {
            let type = FileNode.type(for: itemURL)
            var node = FileNode(name: itemURL.lastPathComponent, url: itemURL, type: type)
            
            if type == .folder {
                node.children = try? loadFileTree(at: itemURL)
            }
            nodes.append(node)
        }
        return nodes
    }
    
    func readFile(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }
    
    func writeFile(content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    func createFile(named name: String, in directory: URL, content: String = "") throws -> URL {
        let url = directory.appendingPathComponent(name)
        guard !fileManager.fileExists(atPath: url.path) else {
            throw FileSystemError.alreadyExists
        }
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    func createFolder(named name: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(name, isDirectory: true)
        guard !fileManager.fileExists(atPath: url.path) else {
            throw FileSystemError.alreadyExists
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    func rename(at url: URL, to newName: String) throws -> URL {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        try fileManager.moveItem(at: url, to: newURL)
        return newURL
    }
    
    func delete(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }
    
    func move(item url: URL, to directory: URL) throws -> URL {
        let dest = directory.appendingPathComponent(url.lastPathComponent)
        try fileManager.moveItem(at: url, to: dest)
        return dest
    }
    
    private func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name.components(separatedBy: invalid).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum FileSystemError: LocalizedError {
    case alreadyExists
    case notFound
    case invalidName
    
    var errorDescription: String? {
        switch self {
        case .alreadyExists: return "Ya existe un elemento con ese nombre."
        case .notFound: return "No se encontró el archivo o carpeta."
        case .invalidName: return "Nombre no válido."
        }
    }
}
