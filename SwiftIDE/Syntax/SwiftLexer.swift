import Foundation

/// Lexer orientado a Swift (fase 1). Preparado para evolucionar hacia SwiftSyntax.
final class SwiftLexer {
    
    /// Keywords de control / declaración (rosa/magenta en Xcode dark).
    private static let keywords: Set<String> = [
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func",
        "import", "init", "inout", "internal", "let", "open", "operator", "private",
        "protocol", "public", "rethrows", "static", "struct", "subscript", "typealias",
        "var", "break", "case", "continue", "default", "defer", "do", "else", "fallthrough",
        "for", "guard", "if", "in", "repeat", "return", "switch", "where", "while",
        "as", "any", "catch", "is", "super", "self", "Self", "throw",
        "throws", "try", "async", "await", "actor", "isolated", "nonisolated",
        "borrowing", "consuming", "package", "some", "each", "macro",
        "final", "lazy", "weak", "unowned", "override", "required", "convenience",
        "mutating", "nonmutating", "indirect", "optional", "dynamic", "infix",
        "prefix", "postfix", "precedencegroup", "didSet", "willSet", "get", "set",
        "_", "#available", "#selector", "#keyPath"
    ]
    
    /// Literales / valores especiales
    private static let literals: Set<String> = ["true", "false", "nil"]
    
    /// Tipos built-in y de frameworks frecuentes
    private static let types: Set<String> = [
        "Int", "Int8", "Int16", "Int32", "Int64",
        "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
        "Float", "Double", "Bool", "String", "Character", "Substring",
        "Array", "Dictionary", "Set", "Optional", "Result", "Range", "ClosedRange",
        "Error", "Any", "AnyObject", "AnyClass", "Void", "Never",
        "CGFloat", "CGPoint", "CGSize", "CGRect", "CGVector",
        "Data", "URL", "URLRequest", "UUID", "Date", "DateFormatter",
        "Codable", "Encodable", "Decodable", "Hashable", "Equatable", "Identifiable",
        "Comparable", "Sequence", "Collection", "Publisher", "ObservableObject",
        // SwiftUI
        "View", "Text", "Image", "Button", "List", "Form", "Section",
        "VStack", "HStack", "ZStack", "LazyVStack", "LazyHStack",
        "NavigationStack", "NavigationView", "NavigationLink",
        "ScrollView", "GeometryReader", "Spacer", "Divider", "Group",
        "Color", "Font", "Shape", "Path", "Canvas",
        "State", "Binding", "ObservedObject", "StateObject", "EnvironmentObject",
        "Environment", "Published", "AppStorage", "SceneStorage",
        "WindowGroup", "Scene", "App", "Preview",
        // UIKit common
        "UIView", "UIViewController", "UILabel", "UIButton", "UITextView",
        "UIColor", "UIFont", "UIImage", "UITableView", "UICollectionView",
        "NSObject", "NSString", "NSArray", "NSDictionary", "NSNumber",
        "DispatchQueue", "Task", "TaskGroup", "AsyncStream"
    ]
    
    func tokenize(_ text: String) -> [SwiftToken] {
        var tokens: [SwiftToken] = []
        let nsText = text as NSString
        let length = nsText.length
        var i = 0
        
        while i < length {
            let char = nsText.character(at: i)
            
            // Whitespace
            if char == 32 || char == 10 || char == 9 || char == 13 {
                i += 1
                continue
            }
            
            // Single-line comment //
            if char == 47 && i + 1 < length && nsText.character(at: i + 1) == 47 {
                let start = i
                i += 2
                while i < length && nsText.character(at: i) != 10 { i += 1 }
                tokens.append(SwiftToken(type: .comment, range: NSRange(location: start, length: i - start)))
                continue
            }
            
            // Multi-line comment /* */
            if char == 47 && i + 1 < length && nsText.character(at: i + 1) == 42 {
                let start = i
                i += 2
                while i + 1 < length {
                    if nsText.character(at: i) == 42 && nsText.character(at: i + 1) == 47 {
                        i += 2
                        break
                    }
                    i += 1
                }
                tokens.append(SwiftToken(type: .comment, range: NSRange(location: start, length: i - start)))
                continue
            }
            
            // String (simple + multiline """)
            if char == 34 {
                let start = i
                // Multiline """
                if i + 2 < length,
                   nsText.character(at: i + 1) == 34,
                   nsText.character(at: i + 2) == 34 {
                    i += 3
                    while i + 2 < length {
                        if nsText.character(at: i) == 34,
                           nsText.character(at: i + 1) == 34,
                           nsText.character(at: i + 2) == 34 {
                            i += 3
                            break
                        }
                        i += 1
                    }
                    tokens.append(SwiftToken(type: .string, range: NSRange(location: start, length: i - start)))
                    continue
                }
                // Normal string
                i += 1
                var escaped = false
                while i < length {
                    let c = nsText.character(at: i)
                    if escaped {
                        escaped = false
                    } else if c == 92 {
                        escaped = true
                    } else if c == 34 {
                        i += 1
                        break
                    } else if c == 10 {
                        break // unclosed
                    }
                    i += 1
                }
                tokens.append(SwiftToken(type: .string, range: NSRange(location: start, length: i - start)))
                continue
            }
            
            // Attribute @...
            if char == 64 {
                let start = i
                i += 1
                while i < length && isIdentifierChar(nsText.character(at: i)) { i += 1 }
                tokens.append(SwiftToken(type: .attribute, range: NSRange(location: start, length: i - start)))
                continue
            }
            
            // Directive #...
            if char == 35 {
                let start = i
                i += 1
                while i < length && isIdentifierChar(nsText.character(at: i)) { i += 1 }
                tokens.append(SwiftToken(type: .directive, range: NSRange(location: start, length: i - start)))
                continue
            }
            
            // Number
            if (char >= 48 && char <= 57) ||
               (char == 46 && i + 1 < length && nsText.character(at: i + 1) >= 48 && nsText.character(at: i + 1) <= 57) {
                let start = i
                i += 1
                while i < length {
                    let c = nsText.character(at: i)
                    if (c >= 48 && c <= 57) || c == 46 || c == 95 ||
                       c == 120 || c == 88 || c == 98 || c == 66 || c == 111 || c == 79 ||
                       (c >= 97 && c <= 102) || (c >= 65 && c <= 70) ||
                       c == 101 || c == 69 || c == 112 || c == 80 || c == 43 || c == 45 {
                        i += 1
                    } else {
                        break
                    }
                }
                tokens.append(SwiftToken(type: .number, range: NSRange(location: start, length: i - start)))
                continue
            }
            
            // Identifier / Keyword / Type / Function
            if isIdentifierStart(char) {
                let start = i
                i += 1
                while i < length && isIdentifierChar(nsText.character(at: i)) { i += 1 }
                let range = NSRange(location: start, length: i - start)
                let word = nsText.substring(with: range)
                
                // Lookahead: word(  => function call / declaration name
                var j = i
                while j < length {
                    let c = nsText.character(at: j)
                    if c == 32 || c == 9 { j += 1; continue }
                    break
                }
                let followedByParen = j < length && nsText.character(at: j) == 40
                
                let type = classifyIdentifier(word, followedByParen: followedByParen, previousTokens: tokens)
                tokens.append(SwiftToken(type: type, range: range))
                continue
            }
            
            // Operators & punctuation
            if isOperatorChar(char) {
                let start = i
                i += 1
                // Keep multi-char operators together
                while i < length && isOperatorChar(nsText.character(at: i)) {
                    // Don't glue `{` `}` `(` `)` `[` `]` into long ops
                    let c = nsText.character(at: i)
                    if c == 40 || c == 41 || c == 91 || c == 93 || c == 123 || c == 125 { break }
                    i += 1
                }
                tokens.append(SwiftToken(type: .operator, range: NSRange(location: start, length: i - start)))
                continue
            }
            
            i += 1
        }
        
        return tokens
    }
    
    private func classifyIdentifier(
        _ word: String,
        followedByParen: Bool,
        previousTokens: [SwiftToken]
    ) -> SwiftTokenType {
        if Self.literals.contains(word) {
            return word == "nil" ? .nil : .boolean
        }
        if Self.keywords.contains(word) {
            return .keyword
        }
        if Self.types.contains(word) {
            return .type
        }
        // Types convention: UpperCamelCase
        if let first = word.first, first.isUppercase {
            return .type
        }
        // func name(...) or call
        if followedByParen {
            return .function
        }
        return .variable
    }
    
    private func isIdentifierStart(_ c: unichar) -> Bool {
        (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95
    }
    
    private func isIdentifierChar(_ c: unichar) -> Bool {
        isIdentifierStart(c) || (c >= 48 && c <= 57)
    }
    
    private func isOperatorChar(_ c: unichar) -> Bool {
        // Include braces/parens so they get subtle operator color
        let ops = CharacterSet(charactersIn: "+-*/%=<>!&|^~?.:,;()[]{}")
        return ops.contains(Unicode.Scalar(c)!)
    }
}
