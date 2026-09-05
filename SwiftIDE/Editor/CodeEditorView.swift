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
        textView.keyboardAppearance = .dark
        textView.tintColor = UIColor.systemBlue
        
        // Completion accessory
        let accessory = CompletionAccessoryView()
        accessory.onSelect = { [weak coordinator = context.coordinator] item in
            coordinator?.insertCompletion(item, in: textView)
        }
        textView.inputAccessoryView = accessory
        context.coordinator.accessory = accessory
        
        context.coordinator.applyHighlighting(to: textView, text: text)
        CompletionEngine.shared.indexSource(text)
        
        return textView
    }
    
    func updateUIView(_ uiView: CodeTextView, context: Context) {
        if uiView.text != text && !context.coordinator.isEditing {
            context.coordinator.applyHighlighting(to: uiView, text: text)
            CompletionEngine.shared.indexSource(text)
        }
    }
    
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CodeEditorView
        var isEditing = false
        private let highlighter = SyntaxHighlighter()
        private var debounceWorkItem: DispatchWorkItem?
        private var completionWorkItem: DispatchWorkItem?
        weak var accessory: CompletionAccessoryView?
        
        init(_ parent: CodeEditorView) {
            self.parent = parent
        }
        
        func applyHighlighting(to textView: CodeTextView, text: String) {
            let selectedRange = textView.selectedRange
            let attributed = highlighter.highlight(text: text)
            textView.attributedText = attributed
            textView.selectedRange = selectedRange
            textView.setNeedsDisplay() // line numbers
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
            refreshCompletions(in: textView)
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            accessory?.update(items: [])
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
                CompletionEngine.shared.indexSource(newText)
            }
            debounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
            
            refreshCompletions(in: textView)
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            refreshCompletions(in: textView)
        }
        
        private func refreshCompletions(in textView: UITextView) {
            completionWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                let text = textView.text ?? ""
                let cursor = textView.selectedRange.location
                let (prefix, _) = CompletionEngine.wordPrefix(in: text, cursor: cursor)
                let items = CompletionEngine.shared.completions(for: prefix)
                self.accessory?.update(items: items, prefix: prefix)
            }
            completionWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
        }
        
        func insertCompletion(_ item: CompletionItem, in textView: UITextView) {
            let text = textView.text ?? ""
            let cursor = textView.selectedRange.location
            let (prefix, range) = CompletionEngine.wordPrefix(in: text, cursor: cursor)
            
            let ns = text as NSString
            let newText = ns.replacingCharacters(in: range, with: item.insertText)
            let newCursor = range.location + (item.insertText as NSString).length
            
            textView.text = newText
            textView.selectedRange = NSRange(location: newCursor, length: 0)
            
            parent.text = newText
            parent.isDirty = true
            parent.onTextChange?(newText)
            
            applyHighlighting(to: textView as! CodeTextView, text: newText)
            CompletionEngine.shared.indexSource(newText)
            refreshCompletions(in: textView)
        }
    }
}

// MARK: - Completion accessory (barra sobre el teclado)

final class CompletionAccessoryView: UIView {
    var onSelect: ((CompletionItem) -> Void)?
    
    private var items: [CompletionItem] = []
    private let collectionView: UICollectionView
    private let emptyLabel = UILabel()
    
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        setup()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setup() {
        backgroundColor = UIColor(white: 0.14, alpha: 1)
        
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
        blur.frame = bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blur)
        
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CompletionCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)
        
        emptyLabel.text = "Escribe para ver sugerencias…"
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = UIColor.secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        
        // Top border
        let border = UIView()
        border.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        border.translatesAutoresizingMaskIntoConstraints = false
        addSubview(border)
        NSLayoutConstraint.activate([
            border.topAnchor.constraint(equalTo: topAnchor),
            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.trailingAnchor.constraint(equalTo: trailingAnchor),
            border.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
        ])
    }
    
    func update(items: [CompletionItem], prefix: String = "") {
        self.items = items
        emptyLabel.isHidden = !items.isEmpty
        if items.isEmpty && prefix.isEmpty {
            emptyLabel.text = "Escribe para ver sugerencias…"
        } else if items.isEmpty {
            emptyLabel.text = "Sin coincidencias"
        }
        collectionView.reloadData()
        if !items.isEmpty {
            collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .left, animated: false)
        }
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }
}

extension CompletionAccessoryView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! CompletionCell
        cell.configure(items[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelect?(items[indexPath.item])
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let item = items[indexPath.item]
        let font = UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        let w = (item.label as NSString).size(withAttributes: [.font: font]).width
        return CGSize(width: min(max(w + 28, 56), 200), height: 32)
    }
}

final class CompletionCell: UICollectionViewCell {
    private let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor(white: 0.22, alpha: 1)
        contentView.layer.cornerRadius = 8
        contentView.layer.cornerCurve = .continuous
        
        label.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(_ item: CompletionItem) {
        label.text = item.label
        switch item.kind {
        case .keyword:
            contentView.backgroundColor = UIColor(red: 0.45, green: 0.25, blue: 0.45, alpha: 1)
        case .type:
            contentView.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.55, alpha: 1)
        case .function:
            contentView.backgroundColor = UIColor(red: 0.25, green: 0.45, blue: 0.3, alpha: 1)
        case .snippet:
            contentView.backgroundColor = UIColor(red: 0.4, green: 0.35, blue: 0.2, alpha: 1)
        case .property:
            contentView.backgroundColor = UIColor(red: 0.35, green: 0.3, blue: 0.5, alpha: 1)
        default:
            contentView.backgroundColor = UIColor(white: 0.22, alpha: 1)
        }
    }
}

// MARK: - CodeTextView + line numbers

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
            let charIndex = layoutManager.characterIndexForGlyph(at: min(glyphRange.location, max(layoutManager.numberOfGlyphs - 1, 0)))
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
