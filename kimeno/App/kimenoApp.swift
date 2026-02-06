//
//  kimenoApp.swift
//  kimeno
//
//  Created by marduc812 on 02.02.2026.
//

import SwiftUI
import UserNotifications

@main
struct kimenoApp: App {
    @StateObject private var screenCapture = ScreenCaptureManager()
    @StateObject private var historyStore = CaptureHistoryStore()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var hotkeyManager = HotkeyManager()
    @StateObject private var textPreviewManager = TextPreviewManager()
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var hasSetupHotkeys = false

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        MenuBarExtra {
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
                historyStore.addCapture(text: text)

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
    }

    @State private var onboardingWindow: NSWindow?

    private func showOnboardingWindow() {
        if onboardingWindow != nil { return }

        let onboardingView = OnboardingView(onboardingManager: onboardingManager)
        let hostingController = NSHostingController(rootView: onboardingView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Kimeno"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 480))
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

    private func setupHotkeys() {
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
