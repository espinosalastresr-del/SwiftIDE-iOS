import SwiftUI

struct FileBrowserView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var expandedFolders: Set<String> = []
    @State private var showCreateFile = false
    @State private var showCreateFolder = false
    @State private var showRename = false
    @State private var newName = ""
    @State private var targetDirectory: URL?
    @State private var nodeToRename: FileNode?
    @State private var clipboardURL: URL?
    @State private var clipboardIsCut = false
    @State private var errorMessage: String?
    
    private var visibleRows: [(node: FileNode, depth: Int)] {
        var rows: [(FileNode, Int)] = []
        func walk(_ nodes: [FileNode], depth: Int) {
            for node in nodes {
                rows.append((node, depth))
                if node.type == .folder,
                   expandedFolders.contains(node.url.path),
                   let children = node.children {
                    walk(children, depth: depth + 1)
                }
            }
        }
        walk(appState.workspaceManager.currentFileTree, depth: 0)
        return rows
    }
    
    var body: some View {
        List {
            if visibleRows.isEmpty {
                ContentUnavailableView(
                    "Carpeta vacía",
                    systemImage: "folder",
                    description: Text("Crea un archivo o carpeta con el botón +.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(visibleRows, id: \.node.id) { row in
                    fileRow(row.node, depth: row.depth)
                }
            }
        }
        .listStyle(.plain)
        .id(appState.fileTreeVersion)
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
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    @ViewBuilder
    private func fileRow(_ node: FileNode, depth: Int) -> some View {
        let isFolder = node.type == .folder
        let isExpanded = expandedFolders.contains(node.url.path)
        let isCut = clipboardIsCut && clipboardURL == node.url
        
        Button {
            if isFolder {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isExpanded {
                        expandedFolders.remove(node.url.path)
                    } else {
                        expandedFolders.insert(node.url.path)
                    }
                }
            } else {
                openFile(node)
            }
        } label: {
            HStack(spacing: 6) {
                Color.clear.frame(width: CGFloat(depth) * 14)
                
                if isFolder {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                } else {
                    Color.clear.frame(width: 12)
                }
                
                Image(systemName: iconName(for: node, expanded: isExpanded))
                    .foregroundStyle(iconColor(for: node))
                    .frame(width: 20)
                
                Text(node.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(isCut ? .secondary : .primary)
                    .strikethrough(isCut)
                
                Spacer()
                
                // Indicate if this file is currently open
                if !isFolder && appState.openDocuments.contains(where: { $0.fileURL == node.url }) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !isFolder {
                Button { openFile(node) } label: {
                    Label("Abrir", systemImage: "doc")
                }
            }
            
            if isFolder {
                Button {
                    targetDirectory = node.url
                    newName = ""
                    showCreateFile = true
                } label: {
                    Label("Nuevo archivo aquí", systemImage: "doc.badge.plus")
                }
                Button {
                    targetDirectory = node.url
                    newName = ""
                    showCreateFolder = true
                } label: {
                    Label("Nueva carpeta aquí", systemImage: "folder.badge.plus")
                }
                if clipboardURL != nil {
                    Button { pasteClipboard(into: node.url) } label: {
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
            
            Button {
                nodeToRename = node
                newName = node.name
                showRename = true
            } label: {
                Label("Renombrar", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                deleteNode(node)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }
    
    private func iconName(for node: FileNode, expanded: Bool) -> String {
        switch node.type {
        case .folder: return expanded ? "folder.fill" : "folder"
        case .swift: return "swift"
        case .json: return "curlybraces"
        case .text: return "doc.text"
        case .image: return "photo"
        case .other: return "doc"
        }
    }
    
    private func iconColor(for node: FileNode) -> Color {
        switch node.type {
        case .folder: return .blue
        case .swift: return .orange
        case .json: return .green
        case .text: return .secondary
        case .image: return .purple
        case .other: return .secondary
        }
    }
    
    private func openFile(_ node: FileNode) {
        Task { @MainActor in
            do {
                let doc = try await appState.workspaceManager.openFile(at: node.url)
                appState.openDocument(doc)
                // EditorWorkspaceView observes activeDocumentID and switches view
            } catch {
                errorMessage = "No se pudo abrir: \(error.localizedDescription)"
            }
        }
    }
    
    private func createFile() {
        guard let dir = targetDirectory ?? appState.currentProject?.rootURL else { return }
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Task { @MainActor in
            do {
                let url = try await appState.fileSystem.createFile(named: name, in: dir)
                expandedFolders.insert(dir.path)
                await appState.refreshFileTree()
                let doc = try await appState.workspaceManager.openFile(at: url)
                appState.openDocument(doc)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func createFolder() {
        guard let dir = targetDirectory ?? appState.currentProject?.rootURL else { return }
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Task {
            do {
                _ = try await appState.fileSystem.createFolder(named: name, in: dir)
                expandedFolders.insert(dir.path)
                await appState.refreshFileTree()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func renameNode() {
        guard let node = nodeToRename else { return }
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Task {
            do {
                let newURL = try await appState.fileSystem.rename(at: node.url, to: name)
                if let open = appState.openDocuments.first(where: { $0.fileURL == node.url }) {
                    appState.closeDocument(open.id)
                }
                if expandedFolders.remove(node.url.path) != nil {
                    expandedFolders.insert(newURL.path)
                }
                await appState.refreshFileTree()
            } catch {
                errorMessage = error.localizedDescription
            }
            nodeToRename = nil
        }
    }
    
    private func deleteNode(_ node: FileNode) {
        Task {
            do {
                try await appState.fileSystem.delete(at: node.url)
                if let open = appState.openDocuments.first(where: { $0.fileURL == node.url }) {
                    appState.closeDocument(open.id)
                }
                expandedFolders.remove(node.url.path)
                if clipboardURL == node.url {
                    clipboardURL = nil
                    clipboardIsCut = false
                }
                await appState.refreshFileTree()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func pasteClipboard(into directory: URL?) {
        guard let src = clipboardURL else {
            errorMessage = "No hay nada en el portapapeles."
            return
        }
        guard let dir = directory else {
            errorMessage = "No hay carpeta destino."
            return
        }
        if src.path == dir.path || dir.path.hasPrefix(src.path + "/") {
            errorMessage = "No se puede pegar una carpeta dentro de sí misma."
            return
        }
        Task {
            do {
                if clipboardIsCut {
                    _ = try await appState.fileSystem.move(item: src, to: dir)
                    clipboardURL = nil
                    clipboardIsCut = false
                } else {
                    _ = try await appState.fileSystem.copy(item: src, to: dir)
                }
                expandedFolders.insert(dir.path)
                await appState.refreshFileTree()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
