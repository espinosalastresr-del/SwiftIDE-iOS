import SwiftUI

struct EditorWorkspaceView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSearch = false
    @StateObject private var editorActions = EditorActions()
    
    var body: some View {
        Group {
            if appState.isShowingEditor, let doc = appState.activeDocument {
                editorView(for: doc)
            } else {
                fileBrowserView
            }
        }
    }
    
    // MARK: - File browser
    
    private var fileBrowserView: some View {
        NavigationStack {
            FileBrowserView()
                .navigationTitle(appState.currentProject?.name ?? "Proyecto")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            appState.currentProject = nil
                            appState.closeAllDocuments()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Proyectos")
                            }
                        }
                    }
                    
                    if appState.activeDocument != nil {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                appState.showEditor()
                            } label: {
                                Label("Editor", systemImage: "doc.text")
                            }
                        }
                    }
                }
        }
    }
    
    // MARK: - Editor
    
    private func editorView(for document: EditorDocument) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                if appState.openDocuments.count > 1 {
                    DocumentTabsView()
                }
                
                CodeEditorContainer(document: document, editorActions: editorActions)
            }
            .navigationTitle(document.fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.showFileBrowser()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Archivos")
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        editorActions.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!editorActions.canUndo)
                    
                    Button {
                        editorActions.redo()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!editorActions.canRedo)
                    
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    
                    Button {
                        Task { await appState.saveActiveDocument() }
                    } label: {
                        Image(systemName: saveIcon(for: document))
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                SearchReplaceView()
            }
            .alert("Error al guardar", isPresented: Binding(
                get: { appState.lastSaveError != nil },
                set: { if !$0 { appState.lastSaveError = nil } }
            )) {
                Button("OK") { appState.lastSaveError = nil }
            } message: {
                Text(appState.lastSaveError ?? "")
            }
        }
    }
    
    private func saveIcon(for document: EditorDocument) -> String {
        if appState.lastSaveOK { return "checkmark.circle.fill" }
        return document.isDirty ? "square.and.arrow.down.fill" : "square.and.arrow.down"
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
                        appState.isShowingEditor = true
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
    @ObservedObject var document: EditorDocument
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
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color(white: 0.2) : Color.clear)
        .cornerRadius(6)
        .onTapGesture(perform: onSelect)
    }
}

struct CodeEditorContainer: View {
    @ObservedObject var document: EditorDocument
    @EnvironmentObject var appState: AppState
    @ObservedObject var editorActions: EditorActions
    @State private var saveTask: Task<Void, Never>?
    
    var body: some View {
        CodeEditorView(
            text: $document.content,
            isDirty: $document.isDirty,
            onTextChange: { _ in
                document.markDirty()
                scheduleAutosave()
            },
            editorActions: editorActions
        )
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
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            do {
                try await appState.workspaceManager.save(document: document)
                try await appState.persistence.clearRecovery(for: document.fileURL)
            } catch {
                // Autosave silencioso; el guardado manual mostrará error
                print("Autosave failed: \(error)")
            }
        }
    }
}
