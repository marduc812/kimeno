//
//  GeneralSettingsView.swift
//  kimeno
//

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

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

    let ocrAccuracyOptions = [
        ("fast", "Fast"),
        ("accurate", "Accurate")
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                if !showMenuBarIcon {
                    Text("Use your capture hotkey to interact with Kimeno. Re-launch the app to restore the icon.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Toggle("Copy text to clipboard automatically", isOn: $settings.autoCopyToClipboard)
                Toggle("Play sound on capture", isOn: $settings.playSound)
                Toggle("Line-aware text ordering", isOn: $settings.lineAwareOCR)
            }

            Section {
                Picker("Recognition language:", selection: $settings.recognitionLanguage) {
                    ForEach(languages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .pickerStyle(.menu)

                Picker("OCR accuracy:", selection: $settings.ocrAccuracy) {
                    ForEach(ocrAccuracyOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 10)
    }
}
