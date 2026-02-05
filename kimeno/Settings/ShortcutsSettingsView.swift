//
//  ShortcutsSettingsView.swift
//  kimeno
//

import SwiftUI

struct ShortcutsSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var hotkeyManager: HotkeyManager

    var body: some View {
        Form {
            if !hotkeyManager.hasAccessibilityPermission {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Accessibility Permission Required")
                                .font(.headline)
                        }
                        Text("Global keyboard shortcuts require Accessibility permission to work.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Open System Settings") {
                            hotkeyManager.openAccessibilitySettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
            }

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
        .onAppear {
            hotkeyManager.checkAccessibilityPermission()
        }
    }
}
