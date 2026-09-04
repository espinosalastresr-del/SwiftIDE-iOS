import UIKit

/// Applies syntax highlighting incrementally when possible.
final class SyntaxHighlighter {
    private let lexer = SwiftLexer()
    private let theme: SyntaxTheme
    
    init(theme: SyntaxTheme = .dark) {
        self.theme = theme
    }
    
    func highlight(text: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        
        // Base attributes
        let baseFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        attributed.addAttributes([
            .font: baseFont,
            .foregroundColor: theme.plain
        ], range: fullRange)
        
        let tokens = lexer.tokenize(text)
        for token in tokens {
            guard token.range.location + token.range.length <= fullRange.length else { continue }
            let color = theme.color(for: token.type)
            attributed.addAttribute(.foregroundColor, value: color, range: token.range)
        }
        
        return attributed
    }
    
    /// Highlights only a changed range + surrounding context (for future incremental use).
    func highlight(text: String, changedRange: NSRange) -> NSAttributedString {
        // For Phase 1 we re-highlight the whole document.
        // Architecture is ready for true incremental updates.
        return highlight(text: text)
    }
}
