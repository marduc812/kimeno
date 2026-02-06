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
            }
        }
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
            Button("Capture") {
                DispatchQueue.main.async {
                    textPreviewManager.closePreviewWindow()
                    historyStore.closeHistoryWindow()
                    settingsManager.closeSettingsWindow()
                    screenCapture.startAreaSelection()
                }
            }
            .modifier(DynamicKeyboardShortcut(shortcut: settingsManager.captureShortcut))

            Button("History") {
                DispatchQueue.main.async {
                    textPreviewManager.closePreviewWindow()
                    NSApp.activate(ignoringOtherApps: true)
                    settingsManager.closeSettingsWindow()
                    historyStore.showHistoryWindow()
                }
            }
            .modifier(DynamicKeyboardShortcut(shortcut: settingsManager.historyShortcut))

            Divider()

            Button("Settings...") {
                DispatchQueue.main.async {
                    textPreviewManager.closePreviewWindow()
                    NSApp.activate(ignoringOtherApps: true)
                    historyStore.closeHistoryWindow()
                    settingsManager.showSettingsWindow(hotkeyManager: hotkeyManager)
                }
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
