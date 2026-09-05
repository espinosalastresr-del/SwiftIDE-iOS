import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var currentProject: Project?
    @Published var openDocuments: [EditorDocument] = []
    @Published var activeDocumentID: UUID?
    @Published var isFileBrowserVisible: Bool = true
    @Published var showProjectPicker: Bool = false
    /// When true, workspace shows the editor instead of the file browser.
    @Published var isShowingEditor: Bool = false
    /// Bumped whenever the file tree should refresh the UI.
    @Published var fileTreeVersion: Int = 0
    @Published var lastSaveError: String?
    @Published var lastSaveOK: Bool = false
    
    let workspaceManager = WorkspaceManager()
    let fileSystem = FileSystemService()
    let persistence = PersistenceService()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
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
        isShowingEditor = false
        showProjectPicker = false
    }
    
    func openDocument(_ document: EditorDocument) {
        // Comparar por path: URL == puede fallar entre instancias distintas
        if let existing = openDocuments.first(where: { $0.fileURL.path == document.fileURL.path }) {
            activeDocumentID = existing.id
        } else {
            openDocuments.append(document)
            activeDocumentID = document.id
        }
        // Siempre navegar al editor (también si el archivo ya estaba abierto)
        isShowingEditor = true
    }
    
    func closeDocument(_ id: UUID) {
        openDocuments.removeAll { $0.id == id }
        if activeDocumentID == id {
            activeDocumentID = openDocuments.last?.id
        }
        if openDocuments.isEmpty {
            isShowingEditor = false
        }
    }
    
    func closeOtherDocuments(except id: UUID) {
        openDocuments = openDocuments.filter { $0.id == id }
        activeDocumentID = id
    }
    
    func closeAllDocuments() {
        openDocuments = []
        activeDocumentID = nil
        isShowingEditor = false
    }
    
    func showFileBrowser() {
        isShowingEditor = false
    }
    
    func showEditor() {
        guard activeDocument != nil else { return }
        isShowingEditor = true
    }
    
    func saveActiveDocument() async {
        guard let doc = activeDocument else { return }
        do {
            try await workspaceManager.save(document: doc)
            try await persistence.clearRecovery(for: doc.fileURL)
            lastSaveOK = true
            lastSaveError = nil
            // Reset flag shortly so UI can show feedback again later
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                lastSaveOK = false
            }
        } catch {
            lastSaveError = error.localizedDescription
            lastSaveOK = false
        }
    }
    
    func refreshFileTree() async {
        guard let project = currentProject else { return }
        await workspaceManager.loadFileTree(for: project)
        fileTreeVersion += 1
    }
}
