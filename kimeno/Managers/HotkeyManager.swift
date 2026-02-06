//
//  HotkeyManager.swift
//  kimeno
//

import AppKit
import Carbon

@MainActor
class HotkeyManager: ObservableObject {
    private var captureHotkeyRef: EventHotKeyRef?
    private var historyHotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    @Published var hasAccessibilityPermission: Bool = true // Not needed for Carbon hotkeys

    var onCapture: (@MainActor () -> Void)?
    var onHistory: (@MainActor () -> Void)?

    private var captureShortcut: CustomShortcut = .defaultCapture
    private var historyShortcut: CustomShortcut = .defaultHistory

    private static let captureHotkeyID = EventHotKeyID(signature: OSType(0x4B494D4F), id: 1) // "KIMO" + 1
    private static let historyHotkeyID = EventHotKeyID(signature: OSType(0x4B494D4F), id: 2) // "KIMO" + 2

    init() {
        setupEventHandler()
    }

    deinit {
        // Note: Can't call stopMonitoring() directly in deinit for @MainActor class
        // The refs will be cleaned up when the process exits
    }

    func checkAccessibilityPermission() {
        // Carbon hotkeys don't require accessibility permission
        hasAccessibilityPermission = true
    }

    func requestAccessibilityPermission() {
        // Not needed for Carbon hotkeys, but keep for screen recording
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func updateShortcuts(capture: CustomShortcut, history: CustomShortcut) {
        captureShortcut = capture
        historyShortcut = history
        print("[HotkeyManager] updateShortcuts - capture: keyCode=\(capture.keyCode), modifiers=\(capture.modifiers)")

        // Re-register hotkeys with new shortcuts
        startMonitoring()
    }

    private func setupEventHandler() {
        // Set up the Carbon event handler
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotkeyID = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotkeyID
            )

            guard err == noErr else { return err }

            DispatchQueue.main.async {
                HotkeyManager.handleHotkey(id: hotkeyID.id)
            }

            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventSpec,
            nil,
            &eventHandler
        )
    }

    private static var sharedInstance: HotkeyManager?

    private static func handleHotkey(id: UInt32) {
        Task { @MainActor in
            guard let manager = sharedInstance else { return }

            switch id {
            case 1:
                print("[HotkeyManager] Capture hotkey triggered")
                manager.onCapture?()
            case 2:
                print("[HotkeyManager] History hotkey triggered")
                manager.onHistory?()
            default:
                break
            }
        }
    }

    func startMonitoring() {
        stopMonitoring()

        HotkeyManager.sharedInstance = self

        // Register capture hotkey
        var captureID = Self.captureHotkeyID
        let captureModifiers = carbonModifiers(from: captureShortcut.modifiers)

        let captureStatus = RegisterEventHotKey(
            UInt32(captureShortcut.keyCode),
            captureModifiers,
            captureID,
            GetApplicationEventTarget(),
            0,
            &captureHotkeyRef
        )

        print("[HotkeyManager] Registered capture hotkey: keyCode=\(captureShortcut.keyCode), modifiers=\(captureModifiers), status=\(captureStatus)")

        // Register history hotkey
        var historyID = Self.historyHotkeyID
        let historyModifiers = carbonModifiers(from: historyShortcut.modifiers)

        let historyStatus = RegisterEventHotKey(
            UInt32(historyShortcut.keyCode),
            historyModifiers,
            historyID,
            GetApplicationEventTarget(),
            0,
            &historyHotkeyRef
        )

        print("[HotkeyManager] Registered history hotkey: keyCode=\(historyShortcut.keyCode), modifiers=\(historyModifiers), status=\(historyStatus)")
    }

    func stopMonitoring() {
        if let ref = captureHotkeyRef {
            UnregisterEventHotKey(ref)
            captureHotkeyRef = nil
        }
        if let ref = historyHotkeyRef {
            UnregisterEventHotKey(ref)
            historyHotkeyRef = nil
        }
    }

    private func carbonModifiers(from cocoaModifiers: UInt) -> UInt32 {
        var carbonMods: UInt32 = 0
        let flags = NSEvent.ModifierFlags(rawValue: cocoaModifiers)

        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }

        return carbonMods
    }
}
