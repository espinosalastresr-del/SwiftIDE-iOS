import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var currentProject: Project?
    @Published var openDocuments: [EditorDocument] = []
    @Published var activeDocumentID: UUID?
    @Published var isFileBrowserVisible: Bool = true
    @Published var showProjectPicker: Bool = false
    /// Bumped whenever the file tree should refresh the UI.
    @Published var fileTreeVersion: Int = 0
    
    let workspaceManager = WorkspaceManager()
    let fileSystem = FileSystemService()
    let persistence = PersistenceService()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Forward WorkspaceManager changes so views observing AppState update.
        workspaceManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    var activeDocument: EditorDocument? {
        openDocuments.first { $0.id == activeDocumentID }
    }
    
    func openProject(_ project: Project) {
        currentProject = project
        openDocuments = []
        activeDocumentID = nil
        showProjectPicker = false
    }
    
    func openDocument(_ document: EditorDocument) {
        if let existing = openDocuments.first(where: { $0.fileURL == document.fileURL }) {
            activeDocumentID = existing.id
            return
        }
        openDocuments.append(document)
        activeDocumentID = document.id
    }
    
    func closeDocument(_ id: UUID) {
        openDocuments.removeAll { $0.id == id }
        if activeDocumentID == id {
            activeDocumentID = openDocuments.last?.id
        }
    }
    
    func closeOtherDocuments(except id: UUID) {
        openDocuments = openDocuments.filter { $0.id == id }
        activeDocumentID = id
    }
    
    func closeAllDocuments() {
        openDocuments = []
        activeDocumentID = nil
    }
    
    func refreshFileTree() async {
        guard let project = currentProject else { return }
        await workspaceManager.loadFileTree(for: project)
        fileTreeVersion += 1
    }
}
