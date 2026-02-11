//
//  CaptureHistoryStore.swift
//  kimeno
//

import SwiftUI

@MainActor
class CaptureHistoryStore: ObservableObject {
    @Published var captures: [CaptureEntry] = []
    private var historyWindow: NSPanel?

    private let storageKey = "captureHistory"
    private let maxEntries = 100

    init() {
        loadHistory()
    }

    func addCapture(text: String, sourceApplication: String? = nil) {
        let entry = CaptureEntry(text: text, sourceApplication: sourceApplication)
        captures.insert(entry, at: 0)

        if captures.count > maxEntries {
            captures = Array(captures.prefix(maxEntries))
        }

        saveHistory()
    }

    func deleteCapture(at offsets: IndexSet) {
        captures.remove(atOffsets: offsets)
        saveHistory()
    }

    func deleteCapture(id: UUID) {
        captures.removeAll { $0.id == id }
        saveHistory()
    }

    func clearHistory() {
        captures.removeAll()
        saveHistory()
    }

    func copyToClipboard(_ entry: CaptureEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)

        let playSound = UserDefaults.standard.object(forKey: "playSound") as? Bool ?? true
        if playSound {
            NSSound(named: .init("Tink"))?.play()
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            captures = try JSONDecoder().decode([CaptureEntry].self, from: data)
        } catch {
            print("Failed to load history: \(error)")
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(captures)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save history: \(error)")
        }
    }

    private var clickOutsideMonitor: Any?

    func showHistoryWindow() {
        if let existingWindow = historyWindow, existingWindow.isVisible {
            closeHistoryWindow()
            return
        }

        let historyView = HistoryView(store: self)
        let hostingController = NSHostingController(rootView: historyView)

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
        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 400

        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main {
            let menuBarHeight: CGFloat = 24

            var x = mouseLocation.x - panelWidth / 2
            x = max(screen.visibleFrame.minX + 10, x)
            x = min(screen.visibleFrame.maxX - panelWidth - 10, x)

            let y = screen.frame.maxY - menuBarHeight - panelHeight - 5

            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }

        self.historyWindow = panel

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            let clickLocation = NSEvent.mouseLocation
            if let historyPanel = self.historyWindow, !historyPanel.frame.contains(clickLocation) {
                DispatchQueue.main.async {
                    self.closeHistoryWindow()
                }
            }
        }

        panel.orderFrontRegardless()
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeHistoryWindow() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        historyWindow?.close()
        historyWindow = nil
    }
}
