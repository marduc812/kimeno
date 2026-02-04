//
//  SelectionCoordinator.swift
//  kimeno
//

import AppKit

class SelectionCoordinator {
    var startPoint: NSPoint?
    var currentPoint: NSPoint?
    var isSelecting = false

    var onSelectionComplete: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private var registeredViews: [WeakViewRef] = []

    var selectionRect: NSRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        return NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    func register(view: SelectionView) {
        registeredViews.append(WeakViewRef(view: view))
    }

    func updateAllViews() {
        for weakRef in registeredViews {
            weakRef.view?.needsDisplay = true
        }
    }

    func completeSelection() {
        guard let rect = selectionRect, rect.width > 5, rect.height > 5 else {
            startPoint = nil
            currentPoint = nil
            isSelecting = false
            updateAllViews()
            return
        }
        let captureRect = rect
        onSelectionComplete?(captureRect)
    }

    func cancel() {
        onCancel?()
    }

    func cleanup() {
        registeredViews.removeAll()
        onSelectionComplete = nil
        onCancel = nil
    }
}

private class WeakViewRef {
    weak var view: SelectionView?
    init(view: SelectionView) {
        self.view = view
    }
}
