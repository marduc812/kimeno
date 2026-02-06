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
