import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreateSheet = false
    @State private var newProjectName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            List {
                if appState.workspaceManager.projects.isEmpty {
                    ContentUnavailableView(
                        "Sin proyectos",
                        systemImage: "folder.badge.plus",
                        description: Text("Crea tu primer proyecto Swift para empezar a programar en el iPhone.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(appState.workspaceManager.projects) { project in
                        Button {
                            Task {
                                appState.openProject(project)
                                await appState.workspaceManager.loadFileTree(for: project)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "folder.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(project.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: deleteProjects)
                }
            }
            .navigationTitle("SwiftIDE")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                createProjectSheet
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .refreshable {
                await appState.workspaceManager.refreshProjects()
            }
        }
    }
    
    private var createProjectSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre del proyecto", text: $newProjectName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Se creará una estructura básica con ContentView.swift y carpetas Models, Views, Resources.")
                }
            }
            .navigationTitle("Nuevo Proyecto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        showCreateSheet = false
                        newProjectName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        createProject()
                    }
                    .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func createProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isCreating = true
        Task {
            do {
                let project = try await appState.workspaceManager.createProject(name: name)
                appState.openProject(project)
                await appState.workspaceManager.loadFileTree(for: project)
                showCreateSheet = false
                newProjectName = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
    
    private func deleteProjects(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let project = appState.workspaceManager.projects[index]
                try? await appState.fileSystem.deleteProject(project)
            }
            await appState.workspaceManager.refreshProjects()
        }
    }
}
