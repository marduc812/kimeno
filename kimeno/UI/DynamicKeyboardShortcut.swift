//
//  DynamicKeyboardShortcut.swift
//  kimeno
//

import SwiftUI

struct DynamicKeyboardShortcut: ViewModifier {
    let shortcut: CustomShortcut

    func body(content: Content) -> some View {
        if let ks = shortcut.keyboardShortcut {
            content.keyboardShortcut(ks)
        } else {
            content
        }
    }
}
