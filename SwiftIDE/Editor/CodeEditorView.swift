import SwiftUI
import UIKit

struct CodeEditorView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isDirty: Bool
    var onTextChange: ((String) -> Void)?
    var editorActions: EditorActions?
    
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
        textView.allowsEditingTextAttributes = false
        textView.undoManager?.levelsOfUndo = 50
        
        let accessory = CompletionAccessoryView()
        accessory.onSelect = { [weak coordinator = context.coordinator] item in
            coordinator?.insertCompletion(item, in: textView)
        }
        accessory.onUndo = { [weak actions = editorActions] in
            actions?.undo()
        }
        accessory.onRedo = { [weak actions = editorActions] in
            actions?.redo()
        }
        textView.inputAccessoryView = accessory
        context.coordinator.accessory = accessory
        context.coordinator.editorActions = editorActions
        
        context.coordinator.isApplyingExternalText = true
        textView.text = text
        context.coordinator.recolor(textView)
        context.coordinator.isApplyingExternalText = false
        
        CompletionEngine.shared.indexSource(text)
        editorActions?.attach(textView)
        context.coordinator.syncAccessoryUndo(textView)
        
        return textView
    }
    
    func updateUIView(_ uiView: CodeTextView, context: Context) {
        context.coordinator.editorActions = editorActions
        context.coordinator.parent = self
        
        // Solo sincronizar texto externo cuando NO estamos editando.
        // No llamar editorActions.refresh() aquí: publicaba @Published y
        // provocaba un bucle infinito updateUIView → body → updateUIView.
        if !context.coordinator.isEditing,
           !context.coordinator.isApplyingExternalText,
           uiView.text != text {
            context.coordinator.isApplyingExternalText = true
            let selected = uiView.selectedRange
            uiView.text = text
            if selected.location <= (text as NSString).length {
                uiView.selectedRange = selected
            }
            context.coordinator.recolor(uiView)
            context.coordinator.isApplyingExternalText = false
            CompletionEngine.shared.indexSource(text)
        }
    }
    
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CodeEditorView
        var isEditing = false
        var isApplyingExternalText = false
        private let lexer = SwiftLexer()
        private var debounceWorkItem: DispatchWorkItem?
        private var completionWorkItem: DispatchWorkItem?
        weak var accessory: CompletionAccessoryView?
        weak var editorActions: EditorActions?
        
        init(_ parent: CodeEditorView) {
            self.parent = parent
        }
        
        /// Solo atributos de color. No toca UndoManager.
        func recolor(_ textView: CodeTextView) {
            let storage = textView.textStorage
            let fullLength = storage.length
            guard fullLength > 0 else {
                textView.setNeedsDisplay()
                return
            }
            
            let selectedRange = textView.selectedRange
            let fullRange = NSRange(location: 0, length: fullLength)
            let baseFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            
            storage.beginEditing()
            storage.setAttributes([
                .font: baseFont,
                .foregroundColor: SyntaxTheme.dark.plain
            ], range: fullRange)
            
            let tokens = lexer.tokenize(storage.string)
            for token in tokens {
                let end = token.range.location + token.range.length
                guard token.range.location >= 0, end <= fullLength else { continue }
                storage.addAttribute(
                    .foregroundColor,
                    value: SyntaxTheme.dark.color(for: token.type),
                    range: token.range
                )
            }
            storage.endEditing()
            
            if selectedRange.location <= fullLength {
                let maxLen = max(0, fullLength - selectedRange.location)
                textView.selectedRange = NSRange(
                    location: selectedRange.location,
                    length: min(selectedRange.length, maxLen)
                )
            }
            textView.setNeedsDisplay()
        }
        
        func syncAccessoryUndo(_ textView: UITextView) {
            accessory?.updateUndoRedo(
                canUndo: textView.undoManager?.canUndo ?? false,
                canRedo: textView.undoManager?.canRedo ?? false
            )
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
            editorActions?.attach(textView)
            refreshCompletions(in: textView)
            editorActions?.refresh()
            syncAccessoryUndo(textView)
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            accessory?.update(items: [])
        }
        
        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingExternalText else { return }
            
            let newText = textView.text ?? ""
            parent.text = newText
            parent.isDirty = true
            parent.onTextChange?(newText)
            
            // Actualizar botones de undo (solo si cambian valores)
            editorActions?.refresh()
            syncAccessoryUndo(textView)
            
            debounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.recolor(textView as! CodeTextView)
                CompletionEngine.shared.indexSource(newText)
            }
            debounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
            
            refreshCompletions(in: textView)
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            refreshCompletions(in: textView)
            // No publicar a SwiftUI en cada cambio de selección
            syncAccessoryUndo(textView)
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
            let (_, range) = CompletionEngine.wordPrefix(in: text, cursor: cursor)
            if textView.selectedRange != range {
                textView.selectedRange = range
            }
            textView.insertText(item.insertText)
        }
    }
}

// MARK: - Completion accessory

final class CompletionAccessoryView: UIView {
    var onSelect: ((CompletionItem) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    
    private var items: [CompletionItem] = []
    private let collectionView: UICollectionView
    private let emptyLabel = UILabel()
    private let undoButton = UIButton(type: .system)
    private let redoButton = UIButton(type: .system)
    
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
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
        
        configureIconButton(undoButton, systemName: "arrow.uturn.backward", action: #selector(undoTapped))
        configureIconButton(redoButton, systemName: "arrow.uturn.forward", action: #selector(redoTapped))
        undoButton.isEnabled = false
        redoButton.isEnabled = false
        
        let buttonStack = UIStackView(arrangedSubviews: [undoButton, redoButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 4
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buttonStack)
        
        let separator = UIView()
        separator.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)
        
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
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            buttonStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            buttonStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            buttonStack.widthAnchor.constraint(equalToConstant: 72),
            
            separator.leadingAnchor.constraint(equalTo: buttonStack.trailingAnchor, constant: 6),
            separator.centerYAnchor.constraint(equalTo: centerYAnchor),
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalToConstant: 24),
            
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: separator.trailingAnchor, constant: 4),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            emptyLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        
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
    
    private func configureIconButton(_ button: UIButton, systemName: String, action: Selector) {
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 34).isActive = true
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
    }
    
    @objc private func undoTapped() { onUndo?() }
    @objc private func redoTapped() { onRedo?() }
    
    func updateUndoRedo(canUndo: Bool, canRedo: Bool) {
        undoButton.isEnabled = canUndo
        redoButton.isEnabled = canRedo
        undoButton.alpha = canUndo ? 1.0 : 0.35
        redoButton.alpha = canRedo ? 1.0 : 0.35
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
        
        if glyphRange.location > 0 && layoutManager.numberOfGlyphs > 0 {
            let charIndex = layoutManager.characterIndexForGlyph(at: min(glyphRange.location, layoutManager.numberOfGlyphs - 1))
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
