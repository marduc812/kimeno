//
//  SelectionWindow.swift
//  kimeno
//

import AppKit

class SelectionWindow: NSWindow {
    private var selectionView: SelectionView!
    private weak var coordinator: SelectionCoordinator?
    let targetScreen: NSScreen

    init(screen: NSScreen, coordinator: SelectionCoordinator) {
        self.targetScreen = screen
        self.coordinator = coordinator

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false

        selectionView = SelectionView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            screen: screen,
            coordinator: coordinator
        )
        coordinator.register(view: selectionView)

        self.contentView = selectionView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func mouseDown(with event: NSEvent) {
        contentView?.mouseDown(with: event)
    }
}
