//
//  SettingsView.swift
//  kimeno
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 4) {
                Spacer()

                SettingsTabButton(
                    title: "General",
                    icon: "gearshape",
                    isSelected: selectedTab == 0
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = 0
                    }
                }

                SettingsTabButton(
                    title: "Shortcuts",
                    icon: "keyboard",
                    isSelected: selectedTab == 1
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = 1
                    }
                }

                SettingsTabButton(
                    title: "About",
                    icon: "info.circle",
                    isSelected: selectedTab == 2
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = 2
                    }
                }

                Spacer()
            }
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .opacity(0.5)

            // Content
            VStack {
                if selectedTab == 0 {
                    GeneralSettingsView(settings: settings)
                } else if selectedTab == 1 {
                    ShortcutsSettingsView(settings: settings, hotkeyManager: hotkeyManager)
                } else {
                    AboutSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 460, height: 420)
        .background {
            ZStack {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                Color.primary.opacity(0.02)
            }
        }
    }
}
