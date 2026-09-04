import SwiftUI

struct EditorWorkspaceView: View {
    @EnvironmentObject var appState: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showSearch = false
    @State private var searchQuery = ""
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar - File Browser
            FileBrowserView()
                .navigationTitle(appState.currentProject?.name ?? "Proyecto")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            appState.currentProject = nil
                            appState.closeAllDocuments()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
        } detail: {
            // Editor area
            VStack(spacing: 0) {
                // Tabs
                if !appState.openDocuments.isEmpty {
                    DocumentTabsView()
                }
                
                // Editor or empty state
                if let doc = appState.activeDocument {
                    CodeEditorContainer(document: doc)
                } else {
                    ContentUnavailableView(
                        "Ningún archivo abierto",
                        systemImage: "doc.text",
                        description: Text("Selecciona un archivo en el explorador para empezar a editar.")
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if appState.activeDocument != nil {
                        Button {
                            showSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        
                        Button {
                            saveActiveDocument()
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                SearchReplaceView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    private func saveActiveDocument() {
        guard let doc = appState.activeDocument else { return }
        Task {
            try? await appState.workspaceManager.save(document: doc)
        }
    }
}

struct DocumentTabsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(appState.openDocuments) { doc in
                    DocumentTab(
                        document: doc,
                        isActive: doc.id == appState.activeDocumentID
                    ) {
                        appState.activeDocumentID = doc.id
                    } onClose: {
                        appState.closeDocument(doc.id)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .background(Color(white: 0.12))
    }
}

struct DocumentTab: View {
    let document: EditorDocument
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            if document.isDirty {
                Circle()
                    .fill(.orange)
                    .frame(width: 7, height: 7)
            }
            
            Text(document.fileName)
                .font(.caption)
                .lineLimit(1)
            
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color(white: 0.2) : Color.clear)
        .cornerRadius(6)
        .onTapGesture {
            onSelect()
        }
    }
}

struct CodeEditorContainer: View {
    @ObservedObject var document: EditorDocument
    @EnvironmentObject var appState: AppState
    @State private var saveTask: Task<Void, Never>?
    
    var body: some View {
        CodeEditorView(text: $document.content, isDirty: $document.isDirty) { newText in
            document.markDirty()
            scheduleAutosave()
        }
        .id(document.id)
        .onAppear {
            Task {
                if let recovered = try? await appState.persistence.recoveryContent(for: document.fileURL),
                   recovered != document.content {
                    document.content = recovered
                    document.isDirty = true
                }
            }
        }
        .onChange(of: document.content) { _, _ in
            Task {
                try? await appState.persistence.saveRecoverySnapshot(
                    for: document.fileURL,
                    content: document.content
                )
            }
        }
    }
    
    private func scheduleAutosave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            try? await appState.workspaceManager.save(document: document)
            try? await appState.persistence.clearRecovery(for: document.fileURL)
        }
    }
}
