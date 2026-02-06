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
                Image(systemName: "text.viewfinder")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Text("Captured Text")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { manager.closePreviewWindow() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .opacity(0.5)
                .padding(.horizontal, 12)

            // Text editor
            TextEditor(text: $editableText)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)

            Divider()
                .opacity(0.5)
                .padding(.horizontal, 12)

            // Actions
            HStack {
                Spacer()
                Button {
                    manager.copyText(editableText)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut("c", modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 420, height: 320)
        .background {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                Color.primary.opacity(0.02)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
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
