import Foundation

actor PersistenceService {
    private let fileManager = FileManager.default
    
    private var recoveryDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Recovery", isDirectory: true)
    }
    
    func ensureRecoveryDirectory() throws {
        if !fileManager.fileExists(atPath: recoveryDirectory.path) {
            try fileManager.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
        }
    }
    
    func saveRecoverySnapshot(for documentURL: URL, content: String) throws {
        try ensureRecoveryDirectory()
        let key = documentURL.path.replacingOccurrences(of: "/", with: "_")
        let snapshotURL = recoveryDirectory.appendingPathComponent(key + ".recover")
        
        let payload = RecoveryPayload(
            originalPath: documentURL.path,
            content: content,
            timestamp: Date()
        )
        let data = try JSONEncoder().encode(payload)
        try data.write(to: snapshotURL, options: .atomic)
    }
    
    func recoveryContent(for documentURL: URL) throws -> String? {
        try ensureRecoveryDirectory()
        let key = documentURL.path.replacingOccurrences(of: "/", with: "_")
        let snapshotURL = recoveryDirectory.appendingPathComponent(key + ".recover")
        
        guard fileManager.fileExists(atPath: snapshotURL.path) else { return nil }
        
        let data = try Data(contentsOf: snapshotURL)
        let payload = try JSONDecoder().decode(RecoveryPayload.self, from: data)
        
        if let attrs = try? fileManager.attributesOfItem(atPath: documentURL.path),
           let modDate = attrs[.modificationDate] as? Date,
           payload.timestamp <= modDate {
            return nil
        }
        
        return payload.content
    }
    
    func clearRecovery(for documentURL: URL) throws {
        let key = documentURL.path.replacingOccurrences(of: "/", with: "_")
        let snapshotURL = recoveryDirectory.appendingPathComponent(key + ".recover")
        if fileManager.fileExists(atPath: snapshotURL.path) {
            try fileManager.removeItem(at: snapshotURL)
        }
    }
    
    func clearAllRecovery() throws {
        try ensureRecoveryDirectory()
        let contents = try fileManager.contentsOfDirectory(at: recoveryDirectory, includingPropertiesForKeys: nil)
        for url in contents {
            try? fileManager.removeItem(at: url)
        }
    }
}

struct RecoveryPayload: Codable {
    let originalPath: String
    let content: String
    let timestamp: Date
}
