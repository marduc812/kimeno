//
//  kimenoApp.swift
//  kimeno
//
//  Created by marduc812 on 02.02.2026.
//

import SwiftUI
import UserNotifications

extension Notification.Name {
    static let appShouldShowMenu = Notification.Name("appShouldShowMenu")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var onCapture: (() -> Void)?
    var onHistory: (() -> Void)?
    var onSettings: (() -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .appShouldShowMenu, object: nil)
        return false
    }

    @objc func menuCapture() { onCapture?() }
    @objc func menuHistory() { onHistory?() }
    @objc func menuSettings() { onSettings?() }
}

@main
struct kimenoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var screenCapture = ScreenCaptureManager()
    @StateObject private var historyStore = CaptureHistoryStore()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var hotkeyManager = HotkeyManager()
    @StateObject private var textPreviewManager = TextPreviewManager()
    @StateObject private var onboardingManager = OnboardingManager()
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @State private var hasSetupHotkeys = false

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuContentView(
                screenCapture: screenCapture,
                historyStore: historyStore,
                settingsManager: settingsManager,
                hotkeyManager: hotkeyManager,
                textPreviewManager: textPreviewManager
            )
        } label: {
            Text("κ")
                .font(.system(size: 14, weight: .medium))
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: screenCapture.lastExtractedText) { _, newText in
            if let text = newText {
                // Always add to history
                historyStore.addCapture(text: text, sourceApplication: screenCapture.lastSourceApp)

                // Show preview window if auto-copy is disabled
                let autoCopy = UserDefaults.standard.object(forKey: "autoCopyToClipboard") as? Bool ?? true
                if !autoCopy {
                    textPreviewManager.showPreviewWindow(text: text)
                }
                screenCapture.lastExtractedText = nil
            }
        }
        .onChange(of: settingsManager.captureShortcut) { _, newValue in
            hotkeyManager.updateShortcuts(capture: newValue, history: settingsManager.historyShortcut)
        }
        .onChange(of: settingsManager.historyShortcut) { _, newValue in
            hotkeyManager.updateShortcuts(capture: settingsManager.captureShortcut, history: newValue)
        }
        .onChange(of: hasSetupHotkeys, initial: true) { _, _ in
            if !hasSetupHotkeys {
                hasSetupHotkeys = true
                setupHotkeys()
                setupAppDelegate()
                NotificationCenter.default.addObserver(
                    forName: .appShouldShowMenu,
                    object: nil,
                    queue: .main
                ) { _ in
                    showPopupMenu()
                }
                // Show onboarding if needed
                if onboardingManager.showOnboarding {
                    showOnboardingWindow()
                }
            }
        }
        .onChange(of: onboardingManager.showOnboarding) { _, showOnboarding in
            if !showOnboarding {
                closeOnboardingWindow()
                // Restart hotkey monitoring after permissions are granted
                hotkeyManager.checkAccessibilityPermission()
                hotkeyManager.startMonitoring()
            }
        }
        .onChange(of: screenCapture.needsPermission) { _, needsPermission in
            if needsPermission {
                // Reset the flag and show onboarding
                screenCapture.needsPermission = false
                onboardingManager.resetOnboarding()
                showOnboardingWindow()
            }
        }
    }

    @State private var onboardingWindow: NSWindow?

    private func showOnboardingWindow() {
        if onboardingWindow != nil { return }

        let onboardingView = OnboardingView(onboardingManager: onboardingManager)
        let hostingController = NSHostingController(rootView: onboardingView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Kimeno"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 420, height: 500))
        window.center()
        window.isReleasedWhenClosed = false

        self.onboardingWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeOnboardingWindow() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    private func setupAppDelegate() {
        appDelegate.onCapture = {
            self.textPreviewManager.closePreviewWindow()
            self.historyStore.closeHistoryWindow()
            self.settingsManager.closeSettingsWindow()
            self.screenCapture.startAreaSelection()
        }
        appDelegate.onHistory = {
            self.textPreviewManager.closePreviewWindow()
            self.settingsManager.closeSettingsWindow()
            NSApp.activate(ignoringOtherApps: true)
            self.historyStore.showHistoryWindow()
        }
        appDelegate.onSettings = {
            self.textPreviewManager.closePreviewWindow()
            self.historyStore.closeHistoryWindow()
            NSApp.activate(ignoringOtherApps: true)
            self.settingsManager.showSettingsWindow(hotkeyManager: self.hotkeyManager)
        }
    }

    private func showPopupMenu() {
        // Try to click the menu bar button first (when icon is visible)
        for window in NSApp.windows {
            guard let contentView = window.contentView else { continue }
            for subview in contentView.subviews {
                if let button = subview as? NSStatusBarButton {
                    button.performClick(nil)
                    return
                }
            }
        }

        // Fallback: show a native popup menu at the mouse location
        NSApp.activate(ignoringOtherApps: true)

        let menu = NSMenu()

        let captureItem = NSMenuItem(title: "Capture", action: #selector(AppDelegate.menuCapture), keyEquivalent: "")
        captureItem.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)
        captureItem.target = appDelegate
        menu.addItem(captureItem)

        let historyItem = NSMenuItem(title: "History", action: #selector(AppDelegate.menuHistory), keyEquivalent: "")
        historyItem.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil)
        historyItem.target = appDelegate
        menu.addItem(historyItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(AppDelegate.menuSettings), keyEquivalent: "")
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        settingsItem.target = appDelegate
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)

        // Show at mouse location in screen coordinates
        let mouseLocation = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: mouseLocation, in: nil)
    }

    private func setupHotkeys() {
        // Connect screenCapture to hotkeyManager for escape key handling
        screenCapture.setHotkeyManager(hotkeyManager)

        hotkeyManager.updateShortcuts(capture: settingsManager.captureShortcut, history: settingsManager.historyShortcut)
        hotkeyManager.onCapture = {
            self.textPreviewManager.closePreviewWindow()
            self.historyStore.closeHistoryWindow()
            self.settingsManager.closeSettingsWindow()
            self.screenCapture.startAreaSelection()
        }
        hotkeyManager.onHistory = {
            self.textPreviewManager.closePreviewWindow()
            self.settingsManager.closeSettingsWindow()
            self.historyStore.showHistoryWindow()
        }
        hotkeyManager.startMonitoring()
    }

}

struct MenuContentView: View {
    @ObservedObject var screenCapture: ScreenCaptureManager
    @ObservedObject var historyStore: CaptureHistoryStore
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var textPreviewManager: TextPreviewManager

    var body: some View {
        Group {
            Button {
                DispatchQueue.main.async {
                    textPreviewManager.closePreviewWindow()
                    historyStore.closeHistoryWindow()
                    settingsManager.closeSettingsWindow()
                    screenCapture.startAreaSelection()
                }
            } label: {
                Label("Capture", systemImage: "text.viewfinder")
            }
            .modifier(DynamicKeyboardShortcut(shortcut: settingsManager.captureShortcut))

            Button {
                DispatchQueue.main.async {
                    textPreviewManager.closePreviewWindow()
                    NSApp.activate(ignoringOtherApps: true)
                    settingsManager.closeSettingsWindow()
                    historyStore.showHistoryWindow()
                }
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .modifier(DynamicKeyboardShortcut(shortcut: settingsManager.historyShortcut))

            Divider()

            Button {
                DispatchQueue.main.async {
                    textPreviewManager.closePreviewWindow()
                    NSApp.activate(ignoringOtherApps: true)
                    historyStore.closeHistoryWindow()
                    settingsManager.showSettingsWindow(hotkeyManager: hotkeyManager)
                }
            } label: {
                Label("Settings...", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
