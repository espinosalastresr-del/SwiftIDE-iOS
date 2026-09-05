import Foundation

struct CompletionItem: Identifiable, Hashable {
    let id: String
    let label: String
    let detail: String?
    let kind: CompletionKind
    let insertText: String
    
    enum CompletionKind: String {
        case keyword
        case type
        case function
        case variable
        case property
        case snippet
        case module
        
        var iconName: String {
            switch self {
            case .keyword: return "a.square"
            case .type: return "t.square"
            case .function: return "f.square"
            case .variable: return "v.square"
            case .property: return "p.square"
            case .snippet: return "curlybraces.square"
            case .module: return "shippingbox"
            }
        }
    }
    
    init(label: String, detail: String?, kind: CompletionKind, insertText: String) {
        self.id = "\(kind.rawValue):\(label):\(insertText)"
        self.label = label
        self.detail = detail
        self.kind = kind
        self.insertText = insertText
    }
}

/// Motor de autocompletado por capas (plan técnico):
/// keywords → Foundation/SwiftUI → símbolos del proyecto.
final class CompletionEngine {
    static let shared = CompletionEngine()
    
    private let keywords: [CompletionItem]
    private let commonTypes: [CompletionItem]
    private let foundationSymbols: [CompletionItem]
    private let swiftUISymbols: [CompletionItem]
    private let snippets: [CompletionItem]
    private var projectSymbols: [CompletionItem] = []
    
    private init() {
        keywords = [
            "func", "var", "let", "class", "struct", "enum", "protocol", "actor",
            "import", "return", "if", "else", "guard", "switch", "case", "for", "while",
            "do", "try", "catch", "throw", "throws", "async", "await", "in", "where",
            "extension", "typealias", "associatedtype", "static", "private", "public",
            "internal", "fileprivate", "open", "final", "lazy", "weak", "unowned",
            "override", "required", "convenience", "mutating", "nonmutating",
            "some", "any", "Self", "self", "super", "nil", "true", "false",
            "break", "continue", "default", "defer", "repeat", "init", "deinit"
        ].map { CompletionItem(label: $0, detail: "keyword", kind: .keyword, insertText: $0) }
        
        commonTypes = [
            "String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set",
            "Optional", "Result", "Error", "Data", "URL", "UUID", "Date", "CGFloat",
            "Any", "AnyObject", "Void", "Never", "Character", "Substring"
        ].map { CompletionItem(label: $0, detail: "Type", kind: .type, insertText: $0) }
        
        foundationSymbols = [
            CompletionItem(label: "print", detail: "Foundation", kind: .function, insertText: "print("),
            CompletionItem(label: "FileManager", detail: "Foundation", kind: .type, insertText: "FileManager"),
            CompletionItem(label: "UserDefaults", detail: "Foundation", kind: .type, insertText: "UserDefaults"),
            CompletionItem(label: "JSONDecoder", detail: "Foundation", kind: .type, insertText: "JSONDecoder"),
            CompletionItem(label: "JSONEncoder", detail: "Foundation", kind: .type, insertText: "JSONEncoder"),
            CompletionItem(label: "URLSession", detail: "Foundation", kind: .type, insertText: "URLSession"),
            CompletionItem(label: "DispatchQueue", detail: "Foundation", kind: .type, insertText: "DispatchQueue"),
            CompletionItem(label: "NotificationCenter", detail: "Foundation", kind: .type, insertText: "NotificationCenter"),
            CompletionItem(label: "Bundle", detail: "Foundation", kind: .type, insertText: "Bundle"),
            CompletionItem(label: "Task", detail: "Concurrency", kind: .type, insertText: "Task"),
        ]
        
        swiftUISymbols = [
            CompletionItem(label: "View", detail: "SwiftUI", kind: .type, insertText: "View"),
            CompletionItem(label: "Text", detail: "SwiftUI", kind: .function, insertText: "Text("),
            CompletionItem(label: "VStack", detail: "SwiftUI", kind: .function, insertText: "VStack"),
            CompletionItem(label: "HStack", detail: "SwiftUI", kind: .function, insertText: "HStack"),
            CompletionItem(label: "ZStack", detail: "SwiftUI", kind: .function, insertText: "ZStack"),
            CompletionItem(label: "List", detail: "SwiftUI", kind: .function, insertText: "List"),
            CompletionItem(label: "Button", detail: "SwiftUI", kind: .function, insertText: "Button"),
            CompletionItem(label: "Image", detail: "SwiftUI", kind: .function, insertText: "Image("),
            CompletionItem(label: "NavigationStack", detail: "SwiftUI", kind: .type, insertText: "NavigationStack"),
            CompletionItem(label: "Form", detail: "SwiftUI", kind: .function, insertText: "Form"),
            CompletionItem(label: "Section", detail: "SwiftUI", kind: .function, insertText: "Section"),
            CompletionItem(label: "Spacer", detail: "SwiftUI", kind: .function, insertText: "Spacer()"),
            CompletionItem(label: "Divider", detail: "SwiftUI", kind: .function, insertText: "Divider()"),
            CompletionItem(label: "ScrollView", detail: "SwiftUI", kind: .function, insertText: "ScrollView"),
            CompletionItem(label: "Toggle", detail: "SwiftUI", kind: .function, insertText: "Toggle"),
            CompletionItem(label: "TextField", detail: "SwiftUI", kind: .function, insertText: "TextField"),
            CompletionItem(label: "Slider", detail: "SwiftUI", kind: .function, insertText: "Slider"),
            CompletionItem(label: "Picker", detail: "SwiftUI", kind: .function, insertText: "Picker"),
            CompletionItem(label: "@State", detail: "SwiftUI", kind: .property, insertText: "@State"),
            CompletionItem(label: "@Binding", detail: "SwiftUI", kind: .property, insertText: "@Binding"),
            CompletionItem(label: "@ObservedObject", detail: "SwiftUI", kind: .property, insertText: "@ObservedObject"),
            CompletionItem(label: "@StateObject", detail: "SwiftUI", kind: .property, insertText: "@StateObject"),
            CompletionItem(label: "@EnvironmentObject", detail: "SwiftUI", kind: .property, insertText: "@EnvironmentObject"),
            CompletionItem(label: "@Published", detail: "Combine", kind: .property, insertText: "@Published"),
            CompletionItem(label: "@Environment", detail: "SwiftUI", kind: .property, insertText: "@Environment"),
            CompletionItem(label: "body", detail: "SwiftUI", kind: .property, insertText: "body"),
        ]
        
        snippets = [
            CompletionItem(label: "func", detail: "snippet", kind: .snippet, insertText: "func name() {\n    \n}"),
            CompletionItem(label: "struct", detail: "snippet", kind: .snippet, insertText: "struct Name {\n    \n}"),
            CompletionItem(label: "class", detail: "snippet", kind: .snippet, insertText: "class Name {\n    \n}"),
            CompletionItem(label: "enum", detail: "snippet", kind: .snippet, insertText: "enum Name {\n    case \n}"),
            CompletionItem(label: "if let", detail: "snippet", kind: .snippet, insertText: "if let value = optional {\n    \n}"),
            CompletionItem(label: "guard let", detail: "snippet", kind: .snippet, insertText: "guard let value = optional else {\n    return\n}"),
            CompletionItem(label: "for in", detail: "snippet", kind: .snippet, insertText: "for item in collection {\n    \n}"),
            CompletionItem(label: "View body", detail: "SwiftUI snippet", kind: .snippet, insertText: "var body: some View {\n    Text(\"Hello\")\n}"),
            CompletionItem(label: "mark", detail: "snippet", kind: .snippet, insertText: "// MARK: - "),
        ]
    }
    
    func updateProjectSymbols(_ symbols: [CompletionItem]) {
        projectSymbols = symbols
    }
    
    /// Extrae símbolos simples del texto del proyecto (func/struct/class/enum/var/let).
    func indexSource(_ text: String) {
        var found: [CompletionItem] = []
        let patterns: [(String, CompletionItem.CompletionKind)] = [
            (#"func\s+(\w+)"#, .function),
            (#"struct\s+(\w+)"#, .type),
            (#"class\s+(\w+)"#, .type),
            (#"enum\s+(\w+)"#, .type),
            (#"protocol\s+(\w+)"#, .type),
            (#"actor\s+(\w+)"#, .type),
            (#"(?:var|let)\s+(\w+)"#, .variable),
        ]
        for (pattern, kind) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            regex.enumerateMatches(in: text, range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 1,
                      let r = Range(match.range(at: 1), in: text) else { return }
                let name = String(text[r])
                let insert = kind == .function ? "\(name)(" : name
                found.append(CompletionItem(label: name, detail: "project", kind: kind, insertText: insert))
            }
        }
        // unique by label+kind
        var seen = Set<String>()
        projectSymbols = found.filter { seen.insert($0.id).inserted }
    }
    
    func completions(for prefix: String, limit: Int = 40) -> [CompletionItem] {
        let lower = prefix.lowercased()
        guard !lower.isEmpty else { return Array(snippets.prefix(8)) }
        
        var results: [CompletionItem] = []
        
        func matches(_ item: CompletionItem) -> Bool {
            item.label.lowercased().hasPrefix(lower) ||
            item.label.lowercased().contains(lower)
        }
        
        // Priority order per plan
        results.append(contentsOf: projectSymbols.filter(matches))
        results.append(contentsOf: keywords.filter(matches))
        results.append(contentsOf: commonTypes.filter(matches))
        results.append(contentsOf: swiftUISymbols.filter(matches))
        results.append(contentsOf: foundationSymbols.filter(matches))
        results.append(contentsOf: snippets.filter(matches))
        
        // Prefer prefix matches, then shorter labels
        results.sort { a, b in
            let ap = a.label.lowercased().hasPrefix(lower)
            let bp = b.label.lowercased().hasPrefix(lower)
            if ap != bp { return ap && !bp }
            if a.label.count != b.label.count { return a.label.count < b.label.count }
            return a.label < b.label
        }
        
        // Dedupe by label
        var seen = Set<String>()
        var unique: [CompletionItem] = []
        for item in results {
            if seen.insert(item.label).inserted {
                unique.append(item)
            }
            if unique.count >= limit { break }
        }
        return unique
    }
    
    /// Current word prefix before cursor.
    static func wordPrefix(in text: String, cursor: Int) -> (prefix: String, range: NSRange) {
        let ns = text as NSString
        let safeCursor = max(0, min(cursor, ns.length))
        var start = safeCursor
        while start > 0 {
            let c = ns.character(at: start - 1)
            let isIdent = (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 95 || c == 64
            if !isIdent { break }
            start -= 1
        }
        let length = safeCursor - start
        let range = NSRange(location: start, length: length)
        let prefix = ns.substring(with: range)
        return (prefix, range)
    }
}
