//
//  SelectionView.swift
//  kimeno
//

import AppKit

class SelectionView: NSView {
    private weak var coordinator: SelectionCoordinator?
    private let screen: NSScreen

    init(frame frameRect: NSRect, screen: NSScreen, coordinator: SelectionCoordinator) {
        self.screen = screen
        self.coordinator = coordinator
        super.init(frame: frameRect)
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
    }

    private func localToGlobal(_ point: NSPoint) -> NSPoint {
        return NSPoint(
            x: point.x + screen.frame.origin.x,
            y: point.y + screen.frame.origin.y
        )
    }

    private func globalToLocal(_ point: NSPoint) -> NSPoint {
        return NSPoint(
            x: point.x - screen.frame.origin.x,
            y: point.y - screen.frame.origin.y
        )
    }

    private var localSelectionRect: NSRect? {
        guard let globalRect = coordinator?.selectionRect else { return nil }

        let localRect = NSRect(
            x: globalRect.origin.x - screen.frame.origin.x,
            y: globalRect.origin.y - screen.frame.origin.y,
            width: globalRect.width,
            height: globalRect.height
        )

        return localRect
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()

        if let rect = localSelectionRect, rect.width > 0, rect.height > 0 {
            let visibleRect = rect.intersection(bounds)
            if !visibleRect.isNull && visibleRect.width > 0 && visibleRect.height > 0 {
                NSColor.clear.setFill()
                visibleRect.fill(using: .copy)
            }

            NSColor.white.setStroke()
            let borderPath = NSBezierPath(rect: rect)
            borderPath.lineWidth = 2
            borderPath.stroke()

            NSColor.black.setStroke()
            let innerPath = NSBezierPath(rect: rect.insetBy(dx: 1, dy: 1))
            innerPath.lineWidth = 1
            innerPath.setLineDash([4, 4], count: 2, phase: 0)
            innerPath.stroke()

            if let globalRect = coordinator?.selectionRect {
                let labelPoint = NSPoint(x: globalRect.midX, y: globalRect.maxY + 8)
                if screen.frame.contains(labelPoint) || screen == NSScreen.main {
                    drawSizeLabel(for: rect, globalRect: globalRect)
                }
            }
        }

        if screen == NSScreen.main {
            drawInstructions()
        }
    }

    private func drawSizeLabel(for rect: NSRect, globalRect: NSRect) {
        let sizeText = "\(Int(globalRect.width)) × \(Int(globalRect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]

        let textSize = sizeText.size(withAttributes: attributes)
        let padding: CGFloat = 6
        let labelRect = NSRect(
            x: rect.midX - textSize.width / 2 - padding,
            y: rect.maxY + 8,
            width: textSize.width + padding * 2,
            height: textSize.height + padding
        )

        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4).fill()

        let textPoint = NSPoint(
            x: labelRect.origin.x + padding,
            y: labelRect.origin.y + padding / 2
        )
        sizeText.draw(at: textPoint, withAttributes: attributes)
    }

    private func drawInstructions() {
        let text = "Click and drag to select area • Press ESC to cancel"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white
        ]

        let textSize = text.size(withAttributes: attributes)
        let padding: CGFloat = 12
        let labelRect = NSRect(
            x: bounds.midX - textSize.width / 2 - padding,
            y: bounds.maxY - 60,
            width: textSize.width + padding * 2,
            height: textSize.height + padding
        )

        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 6, yRadius: 6).fill()

        let textPoint = NSPoint(
            x: labelRect.origin.x + padding,
            y: labelRect.origin.y + padding / 2
        )
        text.draw(at: textPoint, withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let globalPoint = localToGlobal(localPoint)

        coordinator?.startPoint = globalPoint
        coordinator?.currentPoint = globalPoint
        coordinator?.isSelecting = true
        coordinator?.updateAllViews()
    }

    override func mouseDragged(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let globalPoint = localToGlobal(localPoint)

        coordinator?.currentPoint = globalPoint
        coordinator?.updateAllViews()
    }

    override func mouseUp(with event: NSEvent) {
        coordinator?.completeSelection()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            coordinator?.cancel()
        }
    }

    override var acceptsFirstResponder: Bool { true }

    // Accept mouse clicks immediately without requiring app activation first
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
