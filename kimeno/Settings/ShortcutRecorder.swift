//
//  ShortcutRecorder.swift
//  kimeno
//

import SwiftUI
import AppKit

struct ShortcutRecorderButton: View {
    @Binding var shortcut: CustomShortcut
    @State private var isRecording = false

    var body: some View {
        Button(action: {
            isRecording = true
        }) {
            HStack(spacing: 4) {
                if isRecording {
                    Text("Press keys...")
                        .foregroundColor(.accentColor)
                } else {
                    Text(shortcut.displayString)
                        .tracking(2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isRecording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .buttonStyle(.plain)
        .background(
            ShortcutRecorderHelper(isRecording: $isRecording, shortcut: $shortcut)
        )
    }
}

struct ShortcutRecorderHelper: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var shortcut: CustomShortcut

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onKeyEvent = { keyCode, modifiers in
            let flags = NSEvent.ModifierFlags(rawValue: modifiers)
            if flags.contains(.command) || flags.contains(.control) {
                shortcut = CustomShortcut(keyCode: keyCode, modifiers: modifiers)
                isRecording = false
            }
        }
        view.onCancel = {
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

class ShortcutRecorderNSView: NSView {
    var onKeyEvent: ((UInt16, UInt) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        let modifierKeys: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        if modifierKeys.contains(event.keyCode) {
            return
        }

        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control]).rawValue
        onKeyEvent?(event.keyCode, modifiers)
    }
}
