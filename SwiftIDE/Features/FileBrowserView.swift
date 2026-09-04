import SwiftUI

struct FileBrowserView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreateFile = false
    @State private var showCreateFolder = false
    @State private var newName = ""
    @State private var targetDirectory: URL?
    
    var body: some View {
        List {
            ForEach(appState.workspaceManager.currentFileTree) { node in
                FileNodeRow(node: node, depth: 0)
            }
        }
        .listStyle(.sidebar)
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
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Nuevo archivo", isPresented: $showCreateFile) {
            TextField("Nombre (ej: MyView.swift)", text: $newName)
            Button("Cancelar", role: .cancel) {}
            Button("Crear") {
                createFile()
            }
        }
        .alert("Nueva carpeta", isPresented: $showCreateFolder) {
            TextField("Nombre", text: $newName)
            Button("Cancelar", role: .cancel) {}
            Button("Crear") {
                createFolder()
            }
        }
    }
    
    private func createFile() {
        guard let dir = targetDirectory ?? appState.currentProject?.rootURL,
              !newName.isEmpty else { return }
        Task {
            do {
                let url = try await appState.fileSystem.createFile(named: newName, in: dir)
                if let project = appState.currentProject {
                    await appState.workspaceManager.loadFileTree(for: project)
                }
                let doc = try await appState.workspaceManager.openFile(at: url)
                appState.openDocument(doc)
            } catch {
                print("Error creating file: \(error)")
            }
        }
    }
    
    private func createFolder() {
        guard let dir = targetDirectory ?? appState.currentProject?.rootURL,
              !newName.isEmpty else { return }
        Task {
            do {
                _ = try await appState.fileSystem.createFolder(named: newName, in: dir)
                if let project = appState.currentProject {
                    await appState.workspaceManager.loadFileTree(for: project)
                }
            } catch {
                print("Error creating folder: \(error)")
            }
        }
    }
}

struct FileNodeRow: View {
    @EnvironmentObject var appState: AppState
    let node: FileNode
    let depth: Int
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                if node.type == .folder {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                } else {
                    Color.clear.frame(width: 12)
                }
                
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .frame(width: 18)
                
                Text(node.name)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.leading, CGFloat(depth) * 12)
            .contentShape(Rectangle())
            .onTapGesture {
                if node.type == .folder {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } else {
                    openFile()
                }
            }
            .contextMenu {
                if node.type != .folder {
                    Button {
                        openFile()
                    } label: {
                        Label("Abrir", systemImage: "doc")
                    }
                }
                Button(role: .destructive) {
                    deleteNode()
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            }
            
            if node.type == .folder && isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileNodeRow(node: child, depth: depth + 1)
                }
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
                appState.openDocument(doc)
            } catch {
                print("Error opening file: \(error)")
            }
        }
    }
    
    private func deleteNode() {
        Task {
            try? await appState.fileSystem.delete(at: node.url)
            if let project = appState.currentProject {
                await appState.workspaceManager.loadFileTree(for: project)
            }
        }
    }
}
