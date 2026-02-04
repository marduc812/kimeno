//
//  AboutSettingsView.swift
//  kimeno
//

import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("κ")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.accentColor)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text("Kimeno")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("A simple OCR tool for macOS.\nCapture any text on your screen.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Text("© 2026 Kimeno")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
