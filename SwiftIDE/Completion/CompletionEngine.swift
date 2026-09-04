import Foundation

struct CompletionItem: Identifiable, Hashable {
    let id = UUID()
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
    }
}

actor CompletionEngine {
    private let keywords: [CompletionItem] = [
        "func", "var", "let", "class", "struct", "enum", "protocol", "actor",
        "import", "return", "if", "else", "guard", "switch", "case", "for", "while",
        "do", "try", "catch", "throw", "throws", "async", "await", "in", "where",
        "extension", "typealias", "associatedtype", "static", "private", "public",
        "internal", "fileprivate", "open", "final", "lazy", "weak", "unowned",
        "override", "required", "convenience", "mutating", "nonmutating",
        "some", "any", "Self", "self", "super", "nil", "true", "false"
    ].map { CompletionItem(label: $0, detail: "Keyword", kind: .keyword, insertText: $0) }
    
    private let commonTypes: [CompletionItem] = [
        "String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set",
        "Optional", "Result", "Error", "Data", "URL", "UUID", "Date", "CGFloat",
        "Any", "AnyObject", "Void", "Never"
    ].map { CompletionItem(label: $0, detail: "Type", kind: .type, insertText: $0) }
    
    private let foundationSymbols: [CompletionItem] = [
        CompletionItem(label: "print", detail: "Foundation", kind: .function, insertText: "print()"),
        CompletionItem(label: "NSObject", detail: "Foundation", kind: .type, insertText: "NSObject"),
        CompletionItem(label: "NotificationCenter", detail: "Foundation", kind: .type, insertText: "NotificationCenter"),
        CompletionItem(label: "UserDefaults", detail: "Foundation", kind: .type, insertText: "UserDefaults"),
        CompletionItem(label: "FileManager", detail: "Foundation", kind: .type, insertText: "FileManager"),
        CompletionItem(label: "JSONDecoder", detail: "Foundation", kind: .type, insertText: "JSONDecoder"),
        CompletionItem(label: "JSONEncoder", detail: "Foundation", kind: .type, insertText: "JSONEncoder"),
        CompletionItem(label: "URLSession", detail: "Foundation", kind: .type, insertText: "URLSession"),
        CompletionItem(label: "DispatchQueue", detail: "Foundation", kind: .type, insertText: "DispatchQueue")
    ]
    
    private let swiftUISymbols: [CompletionItem] = [
        CompletionItem(label: "View", detail: "SwiftUI", kind: .type, insertText: "View"),
        CompletionItem(label: "Text", detail: "SwiftUI", kind: .type, insertText: "Text"),
        CompletionItem(label: "VStack", detail: "SwiftUI", kind: .type, insertText: "VStack"),
        CompletionItem(label: "HStack", detail: "SwiftUI", kind: .type, insertText: "HStack"),
        CompletionItem(label: "ZStack", detail: "SwiftUI", kind: .type, insertText: "ZStack"),
        CompletionItem(label: "List", detail: "SwiftUI", kind: .type, insertText: "List"),
        CompletionItem(label: "Button", detail: "SwiftUI", kind: .type, insertText: "Button"),
        CompletionItem(label: "Image", detail: "SwiftUI", kind: .type, insertText: "Image"),
        CompletionItem(label: "NavigationStack", detail: "SwiftUI", kind: .type, insertText: "NavigationStack"),
        CompletionItem(label: "NavigationView", detail: "SwiftUI", kind: .type, insertText: "NavigationView"),
        CompletionItem(label: "Form", detail: "SwiftUI", kind: .type, insertText: "Form"),
        CompletionItem(label: "Section", detail: "SwiftUI", kind: .type, insertText: "Section"),
        CompletionItem(label: "Spacer", detail: "SwiftUI", kind: .type, insertText: "Spacer"),
        CompletionItem(label: "Divider", detail: "SwiftUI", kind: .type, insertText: "Divider"),
        CompletionItem(label: "ScrollView", detail: "SwiftUI", kind: .type, insertText: "ScrollView"),
        CompletionItem(label: "GeometryReader", detail: "SwiftUI", kind: .type, insertText: "GeometryReader"),
        CompletionItem(label: "State", detail: "SwiftUI", kind: .property, insertText: "State"),
        CompletionItem(label: "Binding", detail: "SwiftUI", kind: .type, insertText: "Binding"),
        CompletionItem(label: "ObservedObject", detail: "SwiftUI", kind: .property, insertText: "ObservedObject"),
        CompletionItem(label: "StateObject", detail: "SwiftUI", kind: .property, insertText: "StateObject"),
        CompletionItem(label: "EnvironmentObject", detail: "SwiftUI", kind: .property, insertText: "EnvironmentObject"),
        CompletionItem(label: "Published", detail: "SwiftUI", kind: .property, insertText: "Published"),
        CompletionItem(label: "Preview", detail: "SwiftUI", kind: .type, insertText: "Preview")
    ]
    
    private var projectSymbols: [CompletionItem] = []
    
    func updateProjectSymbols(_ symbols: [CompletionItem]) {
        projectSymbols = symbols
    }
    
    func completions(for prefix: String, limit: Int = 30) -> [CompletionItem] {
        let lower = prefix.lowercased()
        guard !lower.isEmpty else { return [] }
        
        var results: [CompletionItem] = []
        
        func matches(_ item: CompletionItem) -> Bool {
            item.label.lowercased().hasPrefix(lower)
        }
        
        results.append(contentsOf: keywords.filter(matches))
        results.append(contentsOf: commonTypes.filter(matches))
        results.append(contentsOf: foundationSymbols.filter(matches))
        results.append(contentsOf: swiftUISymbols.filter(matches))
        results.append(contentsOf: projectSymbols.filter(matches))
        
        results.sort {
            if $0.label.count != $1.label.count {
                return $0.label.count < $1.label.count
            }
            return $0.label < $1.label
        }
        
        return Array(results.prefix(limit))
    }
}
