import Foundation
import Combine

@MainActor
final class EditorDocument: ObservableObject, Identifiable {
    let id: UUID
    let fileURL: URL
    @Published var content: String
    @Published var isDirty: Bool = false
    @Published var lastSavedContent: String
    
    var fileName: String {
        fileURL.lastPathComponent
    }
    
    var fileExtension: String {
        fileURL.pathExtension.lowercased()
    }
    
    var isSwiftFile: Bool {
        fileExtension == "swift"
    }
    
    init(fileURL: URL, content: String = "") {
        self.id = UUID()
        self.fileURL = fileURL
        self.content = content
        self.lastSavedContent = content
        self.isDirty = false
    }
    
    func markDirty() {
        isDirty = content != lastSavedContent
    }
    
    func markSaved() {
        lastSavedContent = content
        isDirty = false
    }
}
