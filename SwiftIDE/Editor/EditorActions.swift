import UIKit
import Combine

/// Puente entre el UITextView y la toolbar de SwiftUI para undo/redo.
@MainActor
final class EditorActions: ObservableObject {
    weak var textView: UITextView?
    
    @Published var canUndo = false
    @Published var canRedo = false
    
    func attach(_ textView: UITextView) {
        self.textView = textView
        refresh()
    }
    
    func refresh() {
        canUndo = textView?.undoManager?.canUndo ?? false
        canRedo = textView?.undoManager?.canRedo ?? false
    }
    
    func undo() {
        textView?.undoManager?.undo()
        // UITextView will fire textViewDidChange if content changes
        refresh()
    }
    
    func redo() {
        textView?.undoManager?.redo()
        refresh()
    }
}
