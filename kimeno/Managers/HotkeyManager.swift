//
//  HotkeyManager.swift
//  kimeno
//

import AppKit
import Carbon

// Global callback function for Carbon event handler (must be at file scope)
private func hotkeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event else { return OSStatus(eventNotHandledErr) }

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
        HotkeyManager.handleHotkey(id: hotkeyID.id, signature: hotkeyID.signature)
    }

    return noErr
}

@MainActor
class HotkeyManager: ObservableObject {
    private var captureHotkeyRef: EventHotKeyRef?
    private var historyHotkeyRef: EventHotKeyRef?
    private var escapeHotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    @Published var hasAccessibilityPermission: Bool = true // Not needed for Carbon hotkeys

    var onCapture: (@MainActor () -> Void)?
    var onHistory: (@MainActor () -> Void)?
    var onEscape: (@MainActor () -> Void)?

    private var captureShortcut: CustomShortcut = .defaultCapture
    private var historyShortcut: CustomShortcut = .defaultHistory

    // Signature "KIMO" for main hotkeys
    private static let mainSignature = OSType(0x4B494D4F)
    private static let captureHotkeyID = EventHotKeyID(signature: mainSignature, id: 1)
    private static let historyHotkeyID = EventHotKeyID(signature: mainSignature, id: 2)
    private static let escapeHotkeyID = EventHotKeyID(signature: mainSignature, id: 3)

    private static weak var sharedInstance: HotkeyManager?

    init() {
        HotkeyManager.sharedInstance = self
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

        // Re-register hotkeys with new shortcuts
        startMonitoring()
    }

    private func setupEventHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventSpec,
            nil,
            &eventHandler
        )

        print("[HotkeyManager] Installed event handler, status=\(status)")
    }

    static func handleHotkey(id: UInt32, signature: OSType) {
        Task { @MainActor in
            guard let manager = sharedInstance else {
                print("[HotkeyManager] No shared instance!")
                return
            }

            // Only handle our hotkeys (signature "KIMO")
            guard signature == mainSignature else { return }

            switch id {
            case 1:
                print("[HotkeyManager] Capture hotkey triggered")
                manager.onCapture?()
            case 2:
                print("[HotkeyManager] History hotkey triggered")
                manager.onHistory?()
            case 3:
                print("[HotkeyManager] Escape hotkey triggered")
                manager.onEscape?()
            default:
                print("[HotkeyManager] Unknown hotkey id: \(id)")
            }
        }
    }

    func startMonitoring() {
        stopMonitoring()

        HotkeyManager.sharedInstance = self

        // Register capture hotkey
        let captureStatus = RegisterEventHotKey(
            UInt32(captureShortcut.keyCode),
            carbonModifiers(from: captureShortcut.modifiers),
            Self.captureHotkeyID,
            GetApplicationEventTarget(),
            0,
            &captureHotkeyRef
        )

        print("[HotkeyManager] Registered capture hotkey: keyCode=\(captureShortcut.keyCode), status=\(captureStatus)")

        // Register history hotkey
        let historyStatus = RegisterEventHotKey(
            UInt32(historyShortcut.keyCode),
            carbonModifiers(from: historyShortcut.modifiers),
            Self.historyHotkeyID,
            GetApplicationEventTarget(),
            0,
            &historyHotkeyRef
        )

        print("[HotkeyManager] Registered history hotkey: keyCode=\(historyShortcut.keyCode), status=\(historyStatus)")
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

    // MARK: - Escape Hotkey (for selection mode)

    func registerEscapeHotkey() {
        unregisterEscapeHotkey()

        let status = RegisterEventHotKey(
            UInt32(53), // Escape key
            0,          // No modifiers
            Self.escapeHotkeyID,
            GetApplicationEventTarget(),
            0,
            &escapeHotkeyRef
        )

        print("[HotkeyManager] Registered escape hotkey, status=\(status)")
    }

    func unregisterEscapeHotkey() {
        if let ref = escapeHotkeyRef {
            UnregisterEventHotKey(ref)
            escapeHotkeyRef = nil
            print("[HotkeyManager] Unregistered escape hotkey")
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
