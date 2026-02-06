//
//  TextPreviewManager.swift
//  kimeno
//

import SwiftUI

@MainActor
class TextPreviewManager: ObservableObject {
    @Published var currentText: String?

    private var previewWindow: NSPanel?

    func showPreviewWindow(text: String) {
        // Close existing window if any
        closePreviewWindow()

        currentText = text

        let previewView = TextPreviewView(manager: self)
        let hostingController = NSHostingController(rootView: previewView)

        let panel = KeyablePanel(contentViewController: hostingController)
        panel.styleMask = [.borderless, .nonactivatingPanel]
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false

        let mouseLocation = NSEvent.mouseLocation
        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = 300

        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main {
            let menuBarHeight: CGFloat = 24

            var x = mouseLocation.x - panelWidth / 2
            x = max(screen.visibleFrame.minX + 10, x)
            x = min(screen.visibleFrame.maxX - panelWidth - 10, x)

            let y = screen.frame.maxY - menuBarHeight - panelHeight - 5

            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }

        self.previewWindow = panel

        panel.orderFrontRegardless()
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    func closePreviewWindow() {
        // Resign first responder to release keyboard focus before closing
        previewWindow?.makeFirstResponder(nil)
        previewWindow?.close()
        previewWindow = nil
        currentText = nil
    }

    func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        let playSound = UserDefaults.standard.object(forKey: "playSound") as? Bool ?? true
        if playSound {
            NSSound(named: .init("Tink"))?.play()
        }

        closePreviewWindow()
    }
}
