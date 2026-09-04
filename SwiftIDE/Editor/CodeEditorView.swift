import SwiftUI
import UIKit

struct CodeEditorView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isDirty: Bool
    var onTextChange: ((String) -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> CodeTextView {
        let textView = CodeTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = SyntaxTheme.dark.background
        textView.textColor = SyntaxTheme.dark.plain
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.spellCheckingType = .no
        textView.keyboardDismissMode = .interactive
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 8)
        textView.layoutManager.allowsNonContiguousLayout = true
        
        context.coordinator.applyHighlighting(to: textView, text: text)
        
        return textView
    }
    
    func updateUIView(_ uiView: CodeTextView, context: Context) {
        if uiView.text != text && !context.coordinator.isEditing {
            context.coordinator.applyHighlighting(to: uiView, text: text)
        }
    }
    
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CodeEditorView
        var isEditing = false
        private let highlighter = SyntaxHighlighter()
        private var debounceWorkItem: DispatchWorkItem?
        
        init(_ parent: CodeEditorView) {
            self.parent = parent
        }
        
        func applyHighlighting(to textView: CodeTextView, text: String) {
            let selectedRange = textView.selectedRange
            let attributed = highlighter.highlight(text: text)
            textView.attributedText = attributed
            textView.selectedRange = selectedRange
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
        }
        
        func textViewDidChange(_ textView: UITextView) {
            let newText = textView.text ?? ""
            parent.text = newText
            parent.isDirty = true
            parent.onTextChange?(newText)
            
            debounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.applyHighlighting(to: textView as! CodeTextView, text: newText)
            }
            debounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        }
    }
}

/// Custom UITextView with line numbers support (basic for Phase 1).
final class CodeTextView: UITextView {
    private let lineNumberWidth: CGFloat = 44
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        textContainer.lineFragmentPadding = 0
        textContainer.exclusionPaths = []
        contentMode = .redraw
    }
    
    override var textContainerInset: UIEdgeInsets {
        get {
            var insets = super.textContainerInset
            insets.left = lineNumberWidth
            return insets
        }
        set {
            var insets = newValue
            insets.left = lineNumberWidth
            super.textContainerInset = insets
        }
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        drawLineNumbers()
    }
    
    private func drawLineNumbers() {
        let layoutManager = self.layoutManager
        let textStorage = self.textStorage
        
        let theme = SyntaxTheme.dark
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: theme.lineNumber
        ]
        
        let visibleRect = CGRect(origin: contentOffset, size: bounds.size)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        
        var lineNumber = 1
        let nsText = textStorage.string as NSString
        let fullLength = nsText.length
        
        if glyphRange.location > 0 {
            let charIndex = layoutManager.characterIndexForGlyph(at: 0)
            let prefix = nsText.substring(to: min(charIndex, fullLength))
            lineNumber = prefix.components(separatedBy: .newlines).count
        }
        
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (rect, usedRect, textContainer, glyphRange, stop) in
            let numberStr = "\(lineNumber)" as NSString
            let size = numberStr.size(withAttributes: attrs)
            let x = self.lineNumberWidth - size.width - 8
            let y = rect.origin.y + (rect.height - size.height) / 2 - self.contentOffset.y + self.textContainerInset.top
            
            numberStr.draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
            lineNumber += 1
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }
}
