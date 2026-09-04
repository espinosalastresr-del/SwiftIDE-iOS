import SwiftUI

struct SearchReplaceView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var query = ""
    @State private var replacement = ""
    @State private var caseSensitive = false
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    
    private let searchService = SearchService()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Buscar") {
                    TextField("Texto a buscar", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    Toggle("Mayúsculas/minúsculas", isOn: $caseSensitive)
                }
                
                Section("Reemplazar") {
                    TextField("Reemplazar con", text: $replacement)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section {
                    Button("Buscar") {
                        performSearch()
                    }
                    .disabled(query.isEmpty || appState.activeDocument == nil)
                    
                    Button("Reemplazar todo") {
                        performReplaceAll()
                    }
                    .disabled(query.isEmpty || appState.activeDocument == nil)
                }
                
                if !results.isEmpty {
                    Section("Resultados (\(results.count))") {
                        ForEach(results) { result in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Línea \(result.lineNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(result.lineContent.trimmingCharacters(in: .whitespaces))
                                    .font(.system(.footnote, design: .monospaced))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Buscar y Reemplazar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func performSearch() {
        guard let doc = appState.activeDocument else { return }
        isSearching = true
        Task {
            results = await searchService.search(in: doc.content, query: query, caseSensitive: caseSensitive)
            isSearching = false
        }
    }
    
    private func performReplaceAll() {
        guard let doc = appState.activeDocument else { return }
        Task {
            let newContent = await searchService.replace(
                in: doc.content,
                query: query,
                replacement: replacement,
                caseSensitive: caseSensitive,
                replaceAll: true
            )
            await MainActor.run {
                doc.content = newContent
                doc.markDirty()
            }
            results = await searchService.search(in: newContent, query: query, caseSensitive: caseSensitive)
        }
    }
}
