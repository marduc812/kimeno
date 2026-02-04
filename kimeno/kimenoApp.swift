//
//  kimenoApp.swift
//  kimeno
//
//  Created by marduc812 on 02.02.2026.
//

import SwiftUI
import AppKit
import ScreenCaptureKit
import UserNotifications
import Vision
import Carbon.HIToolbox
import Combine
import ServiceManagement

// MARK: - Global Hotkey Manager

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
        // Restart monitoring with new shortcuts if already monitoring
        if globalMonitor != nil {
            startMonitoring()
        }
    }
    
    func startMonitoring() {
        stopMonitoring()
        
        // Capture shortcuts as values to avoid accessing self in the closure
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

@main
struct kimenoApp: App {
    @StateObject private var screenCapture = ScreenCaptureManager()
    @StateObject private var historyStore = CaptureHistoryStore()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var hotkeyManager = HotkeyManager()
    @State private var hasSetupHotkeys = false
    
    init() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    var body: some Scene {
        MenuBarExtra {
            MenuContentView(
                screenCapture: screenCapture,
                historyStore: historyStore,
                settingsManager: settingsManager,
                hotkeyManager: hotkeyManager,
                hasSetupHotkeys: $hasSetupHotkeys,
                performCapture: performCapture,
                performShowHistory: performShowHistory
            )
        } label: {
            Text("κ")
                .font(.system(size: 14, weight: .medium))
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: screenCapture.lastExtractedText) { _, newText in
            if let text = newText {
                historyStore.addCapture(text: text)
                screenCapture.lastExtractedText = nil
            }
        }
        .onChange(of: settingsManager.captureShortcut) { _, newValue in
            hotkeyManager.updateShortcuts(capture: newValue, history: settingsManager.historyShortcut)
        }
        .onChange(of: settingsManager.historyShortcut) { _, newValue in
            hotkeyManager.updateShortcuts(capture: settingsManager.captureShortcut, history: newValue)
        }
    }
    
    private func performCapture() {
        historyStore.closeHistoryWindow()
        settingsManager.closeSettingsWindow()
        screenCapture.startAreaSelection()
    }
    
    private func performShowHistory() {
        settingsManager.closeSettingsWindow()
        historyStore.showHistoryWindow()
    }
}

// MARK: - Menu Content View

struct MenuContentView: View {
    @ObservedObject var screenCapture: ScreenCaptureManager
    @ObservedObject var historyStore: CaptureHistoryStore
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @Binding var hasSetupHotkeys: Bool
    let performCapture: () -> Void
    let performShowHistory: () -> Void
    
    var body: some View {
        Group {
            Button("Capture", action: performCapture)
                .modifier(DynamicKeyboardShortcut(shortcut: settingsManager.captureShortcut))
            
            Button("History", action: performShowHistory)
                .modifier(DynamicKeyboardShortcut(shortcut: settingsManager.historyShortcut))
            
            Divider()
            
            Button("Settings...") {
                historyStore.closeHistoryWindow()
                settingsManager.showSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .onAppear {
            setupHotkeysIfNeeded()
        }
    }
    
    private func setupHotkeysIfNeeded() {
        guard !hasSetupHotkeys else { return }
        hasSetupHotkeys = true
        
        hotkeyManager.updateShortcuts(capture: settingsManager.captureShortcut, history: settingsManager.historyShortcut)
        hotkeyManager.onCapture = { [weak historyStore, weak settingsManager, weak screenCapture] in
            historyStore?.closeHistoryWindow()
            settingsManager?.closeSettingsWindow()
            screenCapture?.startAreaSelection()
        }
        hotkeyManager.onHistory = { [weak settingsManager, weak historyStore] in
            settingsManager?.closeSettingsWindow()
            historyStore?.showHistoryWindow()
        }
        hotkeyManager.startMonitoring()
    }
}

// MARK: - Capture History Model

struct CaptureEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let text: String
    let timestamp: Date
    
    init(text: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.text = text
        // Generate title from first line or first few words
        self.title = CaptureEntry.generateTitle(from: text)
    }
    
    private static func generateTitle(from text: String) -> String {
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        if trimmed.count <= 50 {
            return trimmed.isEmpty ? "Untitled" : trimmed
        }
        return String(trimmed.prefix(47)) + "..."
    }
}

// MARK: - History Store

@MainActor
class CaptureHistoryStore: ObservableObject {
    @Published var captures: [CaptureEntry] = []
    private var historyWindow: NSWindow?
    
    private let storageKey = "captureHistory"
    private let maxEntries = 100
    
    init() {
        loadHistory()
    }
    
    func addCapture(text: String) {
        let entry = CaptureEntry(text: text)
        captures.insert(entry, at: 0)
        
        // Keep only the most recent entries
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
        // Toggle - close if already visible
        if let existingWindow = historyWindow, existingWindow.isVisible {
            closeHistoryWindow()
            return
        }
        
        let historyView = HistoryView(store: self)
        let hostingController = NSHostingController(rootView: historyView)
        
        // Create a simple borderless window
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.borderless]
        window.isReleasedWhenClosed = false
        window.level = .popUpMenu
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        
        // Position below the mouse cursor (which should be near the menu bar icon)
        let mouseLocation = NSEvent.mouseLocation
        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 400
        
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main {
            let menuBarHeight: CGFloat = 24
            
            // Center the panel horizontally on the mouse position
            var x = mouseLocation.x - panelWidth / 2
            
            // Keep within screen bounds
            x = max(screen.visibleFrame.minX + 10, x)
            x = min(screen.visibleFrame.maxX - panelWidth - 10, x)
            
            // Position just below the menu bar
            let y = screen.frame.maxY - menuBarHeight - panelHeight - 5
            
            window.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }
        
        self.historyWindow = window
        
        // Set up click-outside monitor
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            let clickLocation = NSEvent.mouseLocation
            if let window = self.historyWindow, !window.frame.contains(clickLocation) {
                DispatchQueue.main.async {
                    self.closeHistoryWindow()
                }
            }
        }
        
        window.orderFrontRegardless()
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

// MARK: - Settings Manager

@MainActor
// MARK: - Custom Shortcut

struct CustomShortcut: Codable, Equatable, Sendable {
    var keyCode: UInt16
    var modifiers: UInt
    
    // Default capture shortcut: Cmd+Shift+C (keyCode 8 = 'C')
    // Command = 1048576, Shift = 131072, combined = 1179648
    static nonisolated let defaultCapture = CustomShortcut(keyCode: 8, modifiers: 1179648)
    
    // Default history shortcut: Cmd+Shift+H (keyCode 4 = 'H')
    static nonisolated let defaultHistory = CustomShortcut(keyCode: 4, modifiers: 1179648)
    
    var displayString: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        
        if let keyString = Self.keyCodeToString(keyCode) {
            parts.append(keyString)
        }
        
        return parts.joined()
    }
    
    // Convert to SwiftUI KeyboardShortcut for native menu display
    var keyboardShortcut: KeyboardShortcut? {
        guard let character = Self.keyCodeToCharacter(keyCode) else { return nil }
        
        var eventModifiers: SwiftUI.EventModifiers = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        
        if flags.contains(.command) { eventModifiers.insert(.command) }
        if flags.contains(.shift) { eventModifiers.insert(.shift) }
        if flags.contains(.option) { eventModifiers.insert(.option) }
        if flags.contains(.control) { eventModifiers.insert(.control) }
        
        return KeyboardShortcut(KeyEquivalent(character), modifiers: eventModifiers)
    }
    
    private static func keyCodeToCharacter(_ keyCode: UInt16) -> Character? {
        let keyCodeMap: [UInt16: Character] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
            8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
            16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 37: "l",
            38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "n", 46: "m", 47: "."
        ]
        return keyCodeMap[keyCode]
    }
    
    private static func keyCodeToString(_ keyCode: UInt16) -> String? {
        let keyCodeMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`",
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "ESC",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        return keyCodeMap[keyCode]
    }
    
    func matches(keyCode eventKeyCode: UInt16, modifiers eventModifiers: UInt) -> Bool {
        return eventKeyCode == keyCode && eventModifiers == modifiers
    }
}

// MARK: - Dynamic Keyboard Shortcut Modifier

struct DynamicKeyboardShortcut: ViewModifier {
    let shortcut: CustomShortcut
    
    func body(content: Content) -> some View {
        if let ks = shortcut.keyboardShortcut {
            content.keyboardShortcut(ks)
        } else {
            content
        }
    }
}

class SettingsManager: ObservableObject {
    @AppStorage("autoCopyToClipboard") var autoCopyToClipboard = true
    @AppStorage("playSound") var playSound = true
    @AppStorage("recognitionLanguage") var recognitionLanguage = "en-US"
    
    var launchAtLogin: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            objectWillChange.send()
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }
    
    @Published var captureShortcut: CustomShortcut {
        didSet { saveShortcuts() }
    }
    @Published var historyShortcut: CustomShortcut {
        didSet { saveShortcuts() }
    }
    
    private var settingsWindow: NSWindow?
    
    init() {
        // Load shortcuts from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "captureShortcut"),
           let shortcut = try? JSONDecoder().decode(CustomShortcut.self, from: data) {
            captureShortcut = shortcut
        } else {
            captureShortcut = .defaultCapture
        }
        
        if let data = UserDefaults.standard.data(forKey: "historyShortcut"),
           let shortcut = try? JSONDecoder().decode(CustomShortcut.self, from: data) {
            historyShortcut = shortcut
        } else {
            historyShortcut = .defaultHistory
        }
    }
    
    private func saveShortcuts() {
        if let data = try? JSONEncoder().encode(captureShortcut) {
            UserDefaults.standard.set(data, forKey: "captureShortcut")
        }
        if let data = try? JSONEncoder().encode(historyShortcut) {
            UserDefaults.standard.set(data, forKey: "historyShortcut")
        }
    }
    
    func resetToDefaults() {
        captureShortcut = .defaultCapture
        historyShortcut = .defaultHistory
    }
    
    func showSettingsWindow() {
        // If window exists and is visible, bring it to front
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView(settings: self)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 450, height: 320))
        window.center()
        window.isReleasedWhenClosed = false
        
        self.settingsWindow = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeSettingsWindow() {
        settingsWindow?.close()
        settingsWindow = nil
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar with icons
            HStack(spacing: 0) {
                Spacer()
                
                SettingsTabButton(
                    title: "General",
                    icon: "gearshape",
                    isSelected: selectedTab == 0
                ) {
                    selectedTab = 0
                }
                
                SettingsTabButton(
                    title: "Shortcuts",
                    icon: "keyboard",
                    isSelected: selectedTab == 1
                ) {
                    selectedTab = 1
                }
                
                SettingsTabButton(
                    title: "About",
                    icon: "info.circle",
                    isSelected: selectedTab == 2
                ) {
                    selectedTab = 2
                }
                
                Spacer()
            }
            .padding(.top, 12)
            
            Divider()
                .padding(.top, 8)
            
            // Tab content
            VStack {
                if selectedTab == 0 {
                    GeneralSettingsView(settings: settings)
                } else if selectedTab == 1 {
                    ShortcutsSettingsView(settings: settings)
                } else {
                    AboutSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .frame(width: 450, height: 320)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Settings Tab Button

struct SettingsTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 11))
            }
            .frame(width: 80, height: 50)
            .contentShape(Rectangle())
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsManager
    
    let languages = [
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("de-DE", "German"),
        ("fr-FR", "French"),
        ("es-ES", "Spanish"),
        ("it-IT", "Italian"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("zh-Hans", "Chinese (Simplified)"),
        ("zh-Hant", "Chinese (Traditional)"),
        ("ja-JP", "Japanese"),
        ("ko-KR", "Korean")
    ]
    
    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Copy text to clipboard automatically", isOn: $settings.autoCopyToClipboard)
                Toggle("Play sound on capture", isOn: $settings.playSound)
            }
            
            Section {
                Picker("Recognition language:", selection: $settings.recognitionLanguage) {
                    ForEach(languages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 10)
    }
}

// MARK: - Shortcuts Settings Tab

struct ShortcutsSettingsView: View {
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        Form {
            Section(header: Text("Customizable Shortcuts")) {
                HStack {
                    Text("Capture screen area")
                    Spacer()
                    ShortcutRecorderButton(shortcut: $settings.captureShortcut)
                }
                
                HStack {
                    Text("Open History")
                    Spacer()
                    ShortcutRecorderButton(shortcut: $settings.historyShortcut)
                }
            }
            
            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 10)
    }
}

// MARK: - Shortcut Recorder Button

struct ShortcutRecorderButton: View {
    @Binding var shortcut: CustomShortcut
    @State private var isRecording = false
    
    var body: some View {
        Button(action: {
            isRecording = true
        }) {
            HStack(spacing: 4) {
                if isRecording {
                    Text("Press keys...")
                        .foregroundColor(.accentColor)
                } else {
                    Text(shortcut.displayString)
                        .tracking(2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isRecording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .buttonStyle(.plain)
        .background(
            ShortcutRecorderHelper(isRecording: $isRecording, shortcut: $shortcut)
        )
    }
}

// MARK: - Shortcut Recorder Helper (NSViewRepresentable for key capture)

struct ShortcutRecorderHelper: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var shortcut: CustomShortcut
    
    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onKeyEvent = { keyCode, modifiers in
            // Only accept shortcuts with at least Command or Control
            let flags = NSEvent.ModifierFlags(rawValue: modifiers)
            if flags.contains(.command) || flags.contains(.control) {
                shortcut = CustomShortcut(keyCode: keyCode, modifiers: modifiers)
                isRecording = false
            }
        }
        view.onCancel = {
            isRecording = false
        }
        return view
    }
    
    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

class ShortcutRecorderNSView: NSView {
    var onKeyEvent: ((UInt16, UInt) -> Void)?
    var onCancel: (() -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        // Escape cancels recording
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        
        // Ignore modifier-only key presses
        let modifierKeys: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63] // Various modifier key codes
        if modifierKeys.contains(event.keyCode) {
            return
        }
        
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control]).rawValue
        onKeyEvent?(event.keyCode, modifiers)
    }
}

// MARK: - About Settings Tab

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("κ")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.accentColor)
                .padding(.top, 8)
            
            VStack(spacing: 4) {
                Text("Kimeno")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("A simple OCR tool for macOS.\nCapture any text on your screen.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Text("© 2026 Kimeno")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - History View

struct HistoryView: View {
    @ObservedObject var store: CaptureHistoryStore
    @State private var selectedEntry: CaptureEntry?
    @State private var searchText = ""
    
    var filteredCaptures: [CaptureEntry] {
        if searchText.isEmpty {
            return store.captures
        }
        return store.captures.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                Text("\(store.captures.count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            
            Divider()
                .padding(.horizontal, 12)
            
            if filteredCaptures.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    if searchText.isEmpty {
                        Text("κ")
                            .font(.system(size: 56, weight: .light))
                            .foregroundColor(.secondary.opacity(0.5))
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48, weight: .thin))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    
                    VStack(spacing: 4) {
                        Text(searchText.isEmpty ? "No captures yet" : "No matches found")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        if searchText.isEmpty {
                            Text("Use ⌘⇧C to capture text from screen")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredCaptures) { entry in
                            CaptureRow(entry: entry, store: store)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
            
            // Bottom toolbar - only show when there are captures
            if !store.captures.isEmpty {
                Divider()
                    .padding(.horizontal, 12)
                
                HStack {
                    Spacer()
                    Button("Clear All") {
                        store.clearHistory()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .font(.system(size: 11))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 320, height: 400)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Visual Effect View (for blur background)

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct CaptureRow: View {
    let entry: CaptureEntry
    let store: CaptureHistoryStore
    @State private var isHovered = false
    
    // Only show preview if there's more text than the title
    private var hasMoreText: Bool {
        entry.text.count > entry.title.count || entry.text.contains("\n")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(entry.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text(entry.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            
            if hasMoreText {
                // Show additional lines beyond the title
                Text(entry.text.components(separatedBy: .newlines).dropFirst().joined(separator: " "))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isHovered ? Color.primary.opacity(0.08) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            store.copyToClipboard(entry)
        }
        .contextMenu {
            Button("Copy") {
                store.copyToClipboard(entry)
            }
            Divider()
            Button("Delete", role: .destructive) {
                store.deleteCapture(id: entry.id)
            }
        }
    }
}

// MARK: - Screen Capture Manager

@MainActor
class ScreenCaptureManager: ObservableObject {
    @Published var lastExtractedText: String?
    
    private var selectionWindows: [SelectionWindow] = []
    private var selectionCoordinator: SelectionCoordinator?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
    deinit {
        // Ensure cleanup on deallocation
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    func startAreaSelection() {
        // Close any existing selection windows first
        closeAllWindows()
        
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        
        // Create a coordinator to share selection state across all screens
        selectionCoordinator = SelectionCoordinator()
        
        selectionCoordinator?.onSelectionComplete = { [weak self] globalRect in
            guard let self = self else { return }
            // Store the rect before closing windows
            let rectToCapture = globalRect
            self.closeAllWindows()
            
            // Small delay to ensure windows are fully closed before capture
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                Task { @MainActor in
                    await self.captureArea(rect: rectToCapture)
                }
            }
        }
        
        selectionCoordinator?.onCancel = { [weak self] in
            self?.closeAllWindows()
        }
        
        // Create a selection window for each screen
        for screen in screens {
            let window = SelectionWindow(screen: screen, coordinator: selectionCoordinator!)
            selectionWindows.append(window)
        }
        
        // Add global ESC key monitor as backup (in case window doesn't have focus)
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                DispatchQueue.main.async {
                    self?.closeAllWindows()
                }
            }
        }
        
        // Add local ESC key monitor
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                DispatchQueue.main.async {
                    self?.closeAllWindows()
                }
                return nil
            }
            return event
        }
        
        // Activate the app and show windows
        NSApp.activate(ignoringOtherApps: true)
        
        // Show all windows
        for window in selectionWindows {
            window.orderFrontRegardless()
        }
        
        // Make the window under the mouse key, or main screen's window
        let mouseLocation = NSEvent.mouseLocation
        if let windowUnderMouse = selectionWindows.first(where: { $0.targetScreen.frame.contains(mouseLocation) }) {
            windowUnderMouse.makeKeyAndOrderFront(nil)
            windowUnderMouse.makeFirstResponder(windowUnderMouse.contentView)
        } else if let mainWindow = selectionWindows.first(where: { $0.targetScreen == NSScreen.main }) {
            mainWindow.makeKeyAndOrderFront(nil)
            mainWindow.makeFirstResponder(mainWindow.contentView)
        } else {
            selectionWindows.first?.makeKeyAndOrderFront(nil)
        }
    }
    
    private func closeAllWindows() {
        // Remove event monitors
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        // Cleanup coordinator
        selectionCoordinator?.cleanup()
        selectionCoordinator = nil
        
        // Close and release all windows
        for window in selectionWindows {
            window.orderOut(nil)
            window.close()
        }
        selectionWindows.removeAll()
    }
    
    func captureArea(rect: NSRect) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Find which screen contains the selection (use center point)
            let centerPoint = NSPoint(x: rect.midX, y: rect.midY)
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(centerPoint) }) ?? NSScreen.main else {
                showAlert(message: "No screen found for selection")
                return
            }
            
            guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) ?? content.displays.first else {
                showAlert(message: "No display found")
                return
            }
            
            let scaleFactor = screen.backingScaleFactor
            
            // Convert global coordinates to screen-local coordinates
            // rect is in global screen coordinates (origin at bottom-left of primary screen)
            // We need to convert to the target screen's local coordinates
            let screenFrame = screen.frame
            let localRect = NSRect(
                x: rect.origin.x - screenFrame.origin.x,
                y: rect.origin.y - screenFrame.origin.y,
                width: rect.width,
                height: rect.height
            )
            
            // Convert from bottom-left origin to top-left origin for capture
            let captureRect = CGRect(
                x: localRect.origin.x * scaleFactor,
                y: (screenFrame.height - localRect.origin.y - localRect.height) * scaleFactor,
                width: localRect.width * scaleFactor,
                height: localRect.height * scaleFactor
            )
            
            // Configure the capture
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = Int(display.width) * Int(scaleFactor)
            config.height = Int(display.height) * Int(scaleFactor)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false
            
            // Capture the full screen
            let fullImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            
            // Crop to selected area
            guard let croppedImage = fullImage.cropping(to: captureRect) else {
                showAlert(message: "Failed to crop image")
                return
            }
            
            // Perform OCR and copy text to clipboard
            extractTextFromImage(croppedImage)
            
        } catch {
            if error.localizedDescription.contains("permission") ||
               error.localizedDescription.contains("denied") {
                showPermissionAlert()
            } else {
                showAlert(message: "Capture failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func extractTextFromImage(_ image: CGImage) {
        // Read settings from UserDefaults
        let autoCopyToClipboard = UserDefaults.standard.object(forKey: "autoCopyToClipboard") as? Bool ?? true
        let playSound = UserDefaults.standard.object(forKey: "playSound") as? Bool ?? true
        let recognitionLanguage = UserDefaults.standard.string(forKey: "recognitionLanguage") ?? "en-US"
        
        var extractedText = ""
        
        // Create a request handler
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        
        // Create a text recognition request
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("OCR error: \(error.localizedDescription)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            // Extract text from all observations
            let texts = observations.compactMap { observation -> String? in
                observation.topCandidates(1).first?.string
            }
            
            extractedText = texts.joined(separator: "\n")
        }
        
        // Configure for accurate recognition
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [recognitionLanguage]
        
        // Perform the request
        do {
            try requestHandler.perform([request])
        } catch {
            showAlert(message: "OCR failed: \(error.localizedDescription)")
            return
        }
        
        // Copy extracted text to clipboard if enabled
        if !extractedText.isEmpty {
            if autoCopyToClipboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(extractedText, forType: .string)
            }
            lastExtractedText = extractedText
            
            // Play sound if enabled
            if playSound {
                NSSound(named: .init("Funk"))?.play()
            }
            
            showNotification(text: extractedText)
        } else {
            showNotification(text: nil)
        }
    }
    
    private func showNotification(text: String?) {
        let content = UNMutableNotificationContent()
        if let text = text {
            content.title = "Text Copied"
            // Show preview of the text (truncate if too long)
            let preview = text.count > 100 ? String(text.prefix(100)) + "..." : text
            content.body = preview
        } else {
            content.title = "No Text Found"
            content.body = "No text was detected in the selected area"
        }
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Screenshot Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Please grant screen recording permission in System Settings > Privacy & Security > Screen Recording"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Selection Coordinator

class SelectionCoordinator {
    var startPoint: NSPoint?
    var currentPoint: NSPoint?
    var isSelecting = false
    
    var onSelectionComplete: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?
    
    // Use weak references to avoid retain cycles and crashes when views are deallocated
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
            // Selection too small, reset
            startPoint = nil
            currentPoint = nil
            isSelecting = false
            updateAllViews()
            return
        }
        // Store rect locally before callback (in case coordinator is deallocated)
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

// Weak reference wrapper for SelectionView
private class WeakViewRef {
    weak var view: SelectionView?
    init(view: SelectionView) {
        self.view = view
    }
}

// MARK: - Selection Window

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
        
        // Use a high window level to ensure we capture all events
        self.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isReleasedWhenClosed = false  // Prevent premature release
        self.hidesOnDeactivate = false
        
        // Create view with bounds starting at origin (0,0)
        selectionView = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size), 
                                       screen: screen, 
                                       coordinator: coordinator)
        coordinator.register(view: selectionView)
        
        self.contentView = selectionView
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    // Ensure the window can receive mouse events immediately
    override func mouseDown(with event: NSEvent) {
        // Forward to content view
        contentView?.mouseDown(with: event)
    }
}

// MARK: - Selection View

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
        // Become first responder when added to window
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
        // When mouse enters this view's screen, make its window key
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
    }
    
    // Convert local view coordinates to global screen coordinates
    private func localToGlobal(_ point: NSPoint) -> NSPoint {
        return NSPoint(
            x: point.x + screen.frame.origin.x,
            y: point.y + screen.frame.origin.y
        )
    }
    
    // Convert global screen coordinates to local view coordinates
    private func globalToLocal(_ point: NSPoint) -> NSPoint {
        return NSPoint(
            x: point.x - screen.frame.origin.x,
            y: point.y - screen.frame.origin.y
        )
    }
    
    // Get the portion of the global selection rect that intersects this screen, in local coordinates
    private var localSelectionRect: NSRect? {
        guard let globalRect = coordinator?.selectionRect else { return nil }
        
        // Convert global rect to local coordinates
        let localRect = NSRect(
            x: globalRect.origin.x - screen.frame.origin.x,
            y: globalRect.origin.y - screen.frame.origin.y,
            width: globalRect.width,
            height: globalRect.height
        )
        
        return localRect
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Draw semi-transparent overlay
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()
        
        // Draw selection rectangle if it intersects this screen
        if let rect = localSelectionRect, rect.width > 0, rect.height > 0 {
            // Clip to bounds for the clear area
            let visibleRect = rect.intersection(bounds)
            if !visibleRect.isNull && visibleRect.width > 0 && visibleRect.height > 0 {
                // Clear the selection area to show the screen beneath
                NSColor.clear.setFill()
                visibleRect.fill(using: .copy)
            }
            
            // Draw border around selection (full rect, may extend beyond bounds)
            NSColor.white.setStroke()
            let borderPath = NSBezierPath(rect: rect)
            borderPath.lineWidth = 2
            borderPath.stroke()
            
            // Draw dashed inner border
            NSColor.black.setStroke()
            let innerPath = NSBezierPath(rect: rect.insetBy(dx: 1, dy: 1))
            innerPath.lineWidth = 1
            innerPath.setLineDash([4, 4], count: 2, phase: 0)
            innerPath.stroke()
            
            // Draw size label (only on the screen where selection started or main screen)
            if let globalRect = coordinator?.selectionRect {
                let labelPoint = NSPoint(x: globalRect.midX, y: globalRect.maxY + 8)
                if screen.frame.contains(labelPoint) || screen == NSScreen.main {
                    drawSizeLabel(for: rect, globalRect: globalRect)
                }
            }
        }
        
        // Draw instructions only on main screen
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
        
        // Background for label
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4).fill()
        
        // Draw text
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
        if event.keyCode == 53 { // ESC key
            coordinator?.cancel()
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
}

// MARK: - NSScreen Extension

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
}
