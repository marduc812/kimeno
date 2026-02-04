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
