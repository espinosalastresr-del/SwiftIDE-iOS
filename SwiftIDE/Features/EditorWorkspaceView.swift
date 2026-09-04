import SwiftUI

struct EditorWorkspaceView: View {
    @EnvironmentObject var appState: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showSearch = false
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
            editorDetail
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: appState.activeDocumentID) { _, newID in
            if newID != nil {
                // Force detail column on iPhone after opening a file
                withAnimation {
                    columnVisibility = .detailOnly
                }
            }
        }
    }
    
    @ViewBuilder
    private var editorDetail: some View {
        Group {
            if let doc = appState.activeDocument {
                VStack(spacing: 0) {
                    if appState.openDocuments.count > 1 {
                        DocumentTabsView()
                    }
                    CodeEditorContainer(document: doc)
                }
            } else {
                ContentUnavailableView(
                    "Ningún archivo abierto",
                    systemImage: "doc.text",
                    description: Text("Toca un archivo en el explorador para editarlo.")
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(appState.activeDocument?.fileName ?? "Editor")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if appState.activeDocument != nil {
                    Button { showSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    Button { saveActiveDocument() } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
            // Allow going back to sidebar on compact devices
            ToolbarItem(placement: .topBarLeading) {
                if appState.activeDocument != nil {
                    Button {
                        withAnimation { columnVisibility = .all }
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            SearchReplaceView()
        }
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
    @State private var saveTask: Task<Void, Never>?
    
    var body: some View {
        CodeEditorView(text: $document.content, isDirty: $document.isDirty) { _ in
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
