//
//  GeneralSettingsView.swift
//  kimeno
//

import SwiftUI

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
                Toggle("Line-aware text ordering", isOn: $settings.lineAwareOCR)
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
