//
//  HotkeyManager.swift
//  kimeno
//

import AppKit

@MainActor
class HotkeyManager: ObservableObject {
    private var globalMonitor: Any?

    var onCapture: (@MainActor () -> Void)?
    var onHistory: (@MainActor () -> Void)?

    private var captureShortcut: CustomShortcut = .defaultCapture
    private var historyShortcut: CustomShortcut = .defaultHistory

    func updateShortcuts(capture: CustomShortcut, history: CustomShortcut) {
        captureShortcut = capture
        historyShortcut = history
        if globalMonitor != nil {
            startMonitoring()
        }
    }

    func startMonitoring() {
        stopMonitoring()

        let captureShortcutCopy = captureShortcut
        let historyShortcutCopy = historyShortcut

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = event.keyCode
            let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control]).rawValue

            if captureShortcutCopy.matches(keyCode: keyCode, modifiers: modifiers) {
                Task { @MainActor in
                    self?.onCapture?()
                }
            } else if historyShortcutCopy.matches(keyCode: keyCode, modifiers: modifiers) {
                Task { @MainActor in
                    self?.onHistory?()
                }
            }
        }
    }

    func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }
}
