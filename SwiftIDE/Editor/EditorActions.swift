import UIKit
import Combine

/// Puente entre el UITextView y la toolbar de SwiftUI para undo/redo.
@MainActor
final class EditorActions: ObservableObject {
    weak var textView: UITextView?
    
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    
    func attach(_ textView: UITextView) {
        self.textView = textView
        refresh()
    }
    
    /// Solo publica si el valor cambió (evita bucles infinitos de SwiftUI).
    func refresh() {
        let newUndo = textView?.undoManager?.canUndo ?? false
        let newRedo = textView?.undoManager?.canRedo ?? false
        if canUndo != newUndo {
            canUndo = newUndo
        }
        if canRedo != newRedo {
            canRedo = newRedo
        }
    }
    
    func undo() {
        textView?.undoManager?.undo()
        refresh()
    }
    
    func redo() {
        textView?.undoManager?.redo()
        refresh()
    }
}
