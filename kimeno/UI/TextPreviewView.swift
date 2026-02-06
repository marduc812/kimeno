//
//  TextPreviewView.swift
//  kimeno
//

import SwiftUI

struct TextPreviewView: View {
    @ObservedObject var manager: TextPreviewManager
    @State private var editableText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Captured Text")
                    .font(.headline)
                Spacer()
                Button(action: { manager.closePreviewWindow() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 12)

            // Text editor
            TextEditor(text: $editableText)
                .font(.system(size: 13))
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()
                .padding(.horizontal, 12)

            // Actions
            HStack {
                Spacer()
                Button("Copy") {
                    manager.copyText(editableText)
                }
                .keyboardShortcut("c", modifiers: .command)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 400, height: 300)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .onAppear {
            editableText = manager.currentText ?? ""
        }
        .onChange(of: manager.currentText) { _, newValue in
            editableText = newValue ?? ""
        }
        .onExitCommand {
            manager.closePreviewWindow()
        }
    }
}
