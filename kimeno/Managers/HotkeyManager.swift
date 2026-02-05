//
//  HotkeyManager.swift
//  kimeno
//

import AppKit
import ApplicationServices

@MainActor
class HotkeyManager: ObservableObject {
    private var globalMonitor: Any?
    private var permissionCheckTimer: Timer?

    @Published var hasAccessibilityPermission: Bool = false

    var onCapture: (@MainActor () -> Void)?
    var onHistory: (@MainActor () -> Void)?

    private var captureShortcut: CustomShortcut = .defaultCapture
    private var historyShortcut: CustomShortcut = .defaultHistory

    init() {
        checkAccessibilityPermission()
    }

    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Start polling for permission changes since there's no callback
        startPermissionPolling()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startPermissionPolling()
    }

    private func startPermissionPolling() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAccessibilityPermission()
                if self?.hasAccessibilityPermission == true {
                    self?.permissionCheckTimer?.invalidate()
                    self?.permissionCheckTimer = nil
                    // Restart monitoring now that we have permission
                    if self?.globalMonitor != nil || self?.onCapture != nil {
                        self?.startMonitoring()
                    }
                }
            }
        }
    }

    func updateShortcuts(capture: CustomShortcut, history: CustomShortcut) {
        captureShortcut = capture
        historyShortcut = history
        print("[HotkeyManager] updateShortcuts called - capture: keyCode=\(capture.keyCode), modifiers=\(capture.modifiers), globalMonitor exists: \(globalMonitor != nil)")
        if globalMonitor != nil {
            startMonitoring()
        }
    }

    func startMonitoring() {
        stopMonitoring()
        checkAccessibilityPermission()

        let captureShortcutCopy = captureShortcut
        let historyShortcutCopy = historyShortcut

        print("[HotkeyManager] Starting monitor with capture shortcut: keyCode=\(captureShortcutCopy.keyCode), modifiers=\(captureShortcutCopy.modifiers), hasPermission: \(hasAccessibilityPermission)")

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = event.keyCode
            let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control]).rawValue

            print("[HotkeyManager] Key event: keyCode=\(keyCode), modifiers=\(modifiers)")

            if captureShortcutCopy.matches(keyCode: keyCode, modifiers: modifiers) {
                print("[HotkeyManager] Capture shortcut matched!")
                Task { @MainActor in
                    self?.onCapture?()
                }
            } else if historyShortcutCopy.matches(keyCode: keyCode, modifiers: modifiers) {
                print("[HotkeyManager] History shortcut matched!")
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
