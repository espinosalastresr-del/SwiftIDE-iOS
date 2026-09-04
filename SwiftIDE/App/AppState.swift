import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var currentProject: Project?
    @Published var openDocuments: [EditorDocument] = []
    @Published var activeDocumentID: UUID?
    @Published var isFileBrowserVisible: Bool = true
    @Published var showProjectPicker: Bool = false
    
    let workspaceManager = WorkspaceManager()
    let fileSystem = FileSystemService()
    let persistence = PersistenceService()
    
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
}
