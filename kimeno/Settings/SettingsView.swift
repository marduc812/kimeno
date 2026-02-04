//
//  SettingsView.swift
//  kimeno
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
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
