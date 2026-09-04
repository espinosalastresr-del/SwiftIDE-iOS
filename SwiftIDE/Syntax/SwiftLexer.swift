import Foundation

/// Simple but effective incremental-friendly lexer for Swift.
/// Designed to be replaced later by SwiftSyntax-based analysis.
final class SwiftLexer {
    
    private static let keywords: Set<String> = [
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func",
        "import", "init", "inout", "internal", "let", "open", "operator", "private",
        "protocol", "public", "rethrows", "static", "struct", "subscript", "typealias",
        "var", "break", "case", "continue", "default", "defer", "do", "else", "fallthrough",
        "for", "guard", "if", "in", "repeat", "return", "switch", "where", "while",
        "as", "any", "catch", "false", "is", "nil", "super", "self", "Self", "throw",
        "throws", "true", "try", "async", "await", "actor", "isolated", "nonisolated",
        "borrowing", "consuming", "package", "some", "each", "repeat", "macro"
    ]
    
    private static let types: Set<String> = [
        "Int", "Int8", "Int16", "Int32", "Int64",
        "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
        "Float", "Double", "Bool", "String", "Character",
        "Array", "Dictionary", "Set", "Optional", "Result",
        "Error", "Any", "AnyObject", "AnyClass", "Void",
        "CGFloat", "CGPoint", "CGSize", "CGRect",
        "Data", "URL", "UUID", "Date", "Range", "ClosedRange"
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
            
            // Single-line comment
            if char == 47 && i + 1 < length && nsText.character(at: i + 1) == 47 { // //
                let start = i
                i += 2
                while i < length && nsText.character(at: i) != 10 {
                    i += 1
                }
                tokens.append(SwiftToken(type: .comment, range: NSRange(location: start, length: i - start)))
                continue
            }
            
            // Multi-line comment
            if char == 47 && i + 1 < length && nsText.character(at: i + 1) == 42 { // /*
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
            
            // String
            if char == 34 { // "
                let start = i
                i += 1
                var escaped = false
                while i < length {
                    let c = nsText.character(at: i)
                    if escaped {
                        escaped = false
                    } else if c == 92 { // \
                        escaped = true
                    } else if c == 34 {
                        i += 1
                        break
                    }
                    i += 1
                }
                tokens.append(SwiftToken(type: .string, range: NSRange(location: start, length: i - start)))
                continue
            }
            
            // Attribute
            if char == 64 { // @
                let start = i
                i += 1
                while i < length {
                    let c = nsText.character(at: i)
                    if !isIdentifierChar(c) { break }
                    i += 1
                }
                tokens.append(SwiftToken(type: .attribute, range: NSRange(location: start, length: i - start)))
                continue
            }
            
            // Directive
            if char == 35 { // #
                let start = i
                i += 1
                while i < length {
                    let c = nsText.character(at: i)
                    if !isIdentifierChar(c) { break }
                    i += 1
                }
                tokens.append(SwiftToken(type: .directive, range: NSRange(location: start, length: i - start)))
                continue
            }
            
            // Number
            if (char >= 48 && char <= 57) || (char == 46 && i + 1 < length && nsText.character(at: i + 1) >= 48 && nsText.character(at: i + 1) <= 57) {
                let start = i
                i += 1
                while i < length {
                    let c = nsText.character(at: i)
                    if !((c >= 48 && c <= 57) || c == 46 || c == 95 || c == 120 || c == 88 || (c >= 97 && c <= 102) || (c >= 65 && c <= 70)) {
                        break
                    }
                    i += 1
                }
                tokens.append(SwiftToken(type: .number, range: NSRange(location: start, length: i - start)))
                continue
            }
            
            // Identifier / Keyword / Type
            if isIdentifierStart(char) {
                let start = i
                i += 1
                while i < length {
                    let c = nsText.character(at: i)
                    if !isIdentifierChar(c) { break }
                    i += 1
                }
                let word = nsText.substring(with: NSRange(location: start, length: i - start))
                let type = classifyIdentifier(word)
                tokens.append(SwiftToken(type: type, range: NSRange(location: start, length: i - start)))
                continue
            }
            
            // Operators
            if isOperatorChar(char) {
                let start = i
                i += 1
                while i < length && isOperatorChar(nsText.character(at: i)) {
                    i += 1
                }
                tokens.append(SwiftToken(type: .operator, range: NSRange(location: start, length: i - start)))
                continue
            }
            
            // Default: skip single char
            i += 1
        }
        
        return tokens
    }
    
    private func classifyIdentifier(_ word: String) -> SwiftTokenType {
        if word == "true" || word == "false" { return .boolean }
        if word == "nil" { return .nil }
        if Self.keywords.contains(word) { return .keyword }
        if Self.types.contains(word) { return .type }
        if word.first?.isUppercase == true { return .type }
        return .variable
    }
    
    private func isIdentifierStart(_ c: unichar) -> Bool {
        (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95
    }
    
    private func isIdentifierChar(_ c: unichar) -> Bool {
        isIdentifierStart(c) || (c >= 48 && c <= 57)
    }
    
    private func isOperatorChar(_ c: unichar) -> Bool {
        let operators = CharacterSet(charactersIn: "+-*/%=<>!&|^~?.:")
        return operators.contains(Unicode.Scalar(c)!)
    }
}
