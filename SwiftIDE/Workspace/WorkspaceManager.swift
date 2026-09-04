import Foundation

@MainActor
final class WorkspaceManager: ObservableObject {
    @Published var projects: [Project] = []
    @Published var currentFileTree: [FileNode] = []
    
    private let fileSystem = FileSystemService()
    
    func refreshProjects() async {
        do {
            projects = try await fileSystem.listProjects()
        } catch {
            print("Error loading projects: \(error)")
        }
    }
    
    func createProject(name: String) async throws -> Project {
        let project = try await fileSystem.createProject(name: name)
        await refreshProjects()
        return project
    }
    
    func loadFileTree(for project: Project) async {
        do {
            currentFileTree = try await fileSystem.loadFileTree(at: project.rootURL)
        } catch {
            print("Error loading file tree: \(error)")
            currentFileTree = []
        }
    }
    
    func openFile(at url: URL) async throws -> EditorDocument {
        let content = try await fileSystem.readFile(at: url)
        return EditorDocument(fileURL: url, content: content)
    }
    
    func save(document: EditorDocument) async throws {
        try await fileSystem.writeFile(content: document.content, to: document.fileURL)
        document.markSaved()
    }
}
