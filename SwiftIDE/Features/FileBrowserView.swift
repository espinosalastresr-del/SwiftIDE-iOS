import SwiftUI

struct FileBrowserView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreateFile = false
    @State private var showCreateFolder = false
    @State private var showRename = false
    @State private var newName = ""
    @State private var targetDirectory: URL?
    @State private var nodeToRename: FileNode?
    @State private var clipboardURL: URL?
    @State private var clipboardIsCut = false
    
    var body: some View {
        List {
            if appState.workspaceManager.currentFileTree.isEmpty {
                ContentUnavailableView(
                    "Carpeta vacía",
                    systemImage: "folder",
                    description: Text("Crea un archivo o carpeta con el botón +.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(appState.workspaceManager.currentFileTree) { node in
                    FileNodeRow(
                        node: node,
                        depth: 0,
                        clipboardURL: $clipboardURL,
                        clipboardIsCut: $clipboardIsCut,
                        onRequestCreateFile: { dir in
                            targetDirectory = dir
                            newName = ""
                            showCreateFile = true
                        },
                        onRequestCreateFolder: { dir in
                            targetDirectory = dir
                            newName = ""
                            showCreateFolder = true
                        },
                        onRequestRename: { node in
                            nodeToRename = node
                            newName = node.name
                            showRename = true
                        }
                    )
                }
            }
        }
        .listStyle(.sidebar)
        .id(appState.fileTreeVersion) // force refresh when tree changes
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        targetDirectory = appState.currentProject?.rootURL
                        newName = ""
                        showCreateFile = true
                    } label: {
                        Label("Nuevo archivo", systemImage: "doc.badge.plus")
                    }
                    Button {
                        targetDirectory = appState.currentProject?.rootURL
                        newName = ""
                        showCreateFolder = true
                    } label: {
                        Label("Nueva carpeta", systemImage: "folder.badge.plus")
                    }
                    if clipboardURL != nil {
                        Divider()
                        Button {
                            pasteClipboard(into: appState.currentProject?.rootURL)
                        } label: {
                            Label("Pegar en raíz", systemImage: "doc.on.clipboard")
                        }
                    }
                    Divider()
                    Button {
                        Task { await appState.refreshFileTree() }
                    } label: {
                        Label("Actualizar", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Nuevo archivo", isPresented: $showCreateFile) {
            TextField("Nombre (ej: MyView.swift)", text: $newName)
            Button("Cancelar", role: .cancel) {}
            Button("Crear") { createFile() }
        }
        .alert("Nueva carpeta", isPresented: $showCreateFolder) {
            TextField("Nombre", text: $newName)
            Button("Cancelar", role: .cancel) {}
            Button("Crear") { createFolder() }
        }
        .alert("Renombrar", isPresented: $showRename) {
            TextField("Nuevo nombre", text: $newName)
            Button("Cancelar", role: .cancel) { nodeToRename = nil }
            Button("Renombrar") { renameNode() }
        }
    }
    
    private func createFile() {
        guard let dir = targetDirectory ?? appState.currentProject?.rootURL,
              !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let url = try await appState.fileSystem.createFile(named: name, in: dir)
                await appState.refreshFileTree()
                let doc = try await appState.workspaceManager.openFile(at: url)
                appState.openDocument(doc)
            } catch {
                print("Error creating file: \(error)")
            }
        }
    }
    
    private func createFolder() {
        guard let dir = targetDirectory ?? appState.currentProject?.rootURL,
              !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                _ = try await appState.fileSystem.createFolder(named: name, in: dir)
                await appState.refreshFileTree()
            } catch {
                print("Error creating folder: \(error)")
            }
        }
    }
    
    private func renameNode() {
        guard let node = nodeToRename,
              !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                _ = try await appState.fileSystem.rename(at: node.url, to: name)
                // Close document if it was open under old path
                if let open = appState.openDocuments.first(where: { $0.fileURL == node.url }) {
                    appState.closeDocument(open.id)
                }
                await appState.refreshFileTree()
            } catch {
                print("Error renaming: \(error)")
            }
            nodeToRename = nil
        }
    }
    
    private func pasteClipboard(into directory: URL?) {
        guard let src = clipboardURL, let dir = directory else { return }
        Task {
            do {
                if clipboardIsCut {
                    _ = try await appState.fileSystem.move(item: src, to: dir)
                    clipboardURL = nil
                    clipboardIsCut = false
                } else {
                    _ = try await appState.fileSystem.copy(item: src, to: dir)
                }
                await appState.refreshFileTree()
            } catch {
                print("Error paste: \(error)")
            }
        }
    }
}

struct FileNodeRow: View {
    @EnvironmentObject var appState: AppState
    let node: FileNode
    let depth: Int
    @Binding var clipboardURL: URL?
    @Binding var clipboardIsCut: Bool
    var onRequestCreateFile: (URL) -> Void
    var onRequestCreateFolder: (URL) -> Void
    var onRequestRename: (FileNode) -> Void
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if node.type == .folder, let children = node.children {
                ForEach(children) { child in
                    FileNodeRow(
                        node: child,
                        depth: depth + 1,
                        clipboardURL: $clipboardURL,
                        clipboardIsCut: $clipboardIsCut,
                        onRequestCreateFile: onRequestCreateFile,
                        onRequestCreateFolder: onRequestCreateFolder,
                        onRequestRename: onRequestRename
                    )
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .frame(width: 18)
                
                Text(node.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(clipboardIsCut && clipboardURL == node.url ? .secondary : .primary)
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if node.type != .folder {
                    openFile()
                }
            }
        }
        // Hide disclosure chevron for files
        .accentColor(node.type == .folder ? .secondary : .clear)
        .contextMenu {
            if node.type != .folder {
                Button { openFile() } label: {
                    Label("Abrir", systemImage: "doc")
                }
            }
            
            if node.type == .folder {
                Button { onRequestCreateFile(node.url) } label: {
                    Label("Nuevo archivo aquí", systemImage: "doc.badge.plus")
                }
                Button { onRequestCreateFolder(node.url) } label: {
                    Label("Nueva carpeta aquí", systemImage: "folder.badge.plus")
                }
                if clipboardURL != nil {
                    Button { pasteIntoFolder() } label: {
                        Label("Pegar aquí", systemImage: "doc.on.clipboard")
                    }
                }
            }
            
            Divider()
            
            Button {
                clipboardURL = node.url
                clipboardIsCut = false
            } label: {
                Label("Copiar", systemImage: "doc.on.doc")
            }
            
            Button {
                clipboardURL = node.url
                clipboardIsCut = true
            } label: {
                Label("Cortar", systemImage: "scissors")
            }
            
            Button { onRequestRename(node) } label: {
                Label("Renombrar", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) { deleteNode() } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }
    
    private var iconName: String {
        switch node.type {
        case .folder: return isExpanded ? "folder.fill" : "folder"
        case .swift: return "swift"
        case .json: return "curlybraces"
        case .text: return "doc.text"
        case .image: return "photo"
        case .other: return "doc"
        }
    }
    
    private var iconColor: Color {
        switch node.type {
        case .folder: return .blue
        case .swift: return .orange
        case .json: return .green
        case .text: return .secondary
        case .image: return .purple
        case .other: return .secondary
        }
    }
    
    private func openFile() {
        Task {
            do {
                let doc = try await appState.workspaceManager.openFile(at: node.url)
                await MainActor.run {
                    appState.openDocument(doc)
                }
            } catch {
                print("Error opening file: \(error)")
            }
        }
    }
    
    private func deleteNode() {
        Task {
            try? await appState.fileSystem.delete(at: node.url)
            // Close if open
            if let open = appState.openDocuments.first(where: { $0.fileURL == node.url }) {
                await MainActor.run { appState.closeDocument(open.id) }
            }
            await appState.refreshFileTree()
        }
    }
    
    private func pasteIntoFolder() {
        guard let src = clipboardURL else { return }
        Task {
            do {
                if clipboardIsCut {
                    _ = try await appState.fileSystem.move(item: src, to: node.url)
                    await MainActor.run {
                        clipboardURL = nil
                        clipboardIsCut = false
                    }
                } else {
                    _ = try await appState.fileSystem.copy(item: src, to: node.url)
                }
                await appState.refreshFileTree()
            } catch {
                print("Error paste: \(error)")
            }
        }
    }
}
