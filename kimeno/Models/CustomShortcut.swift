//
//  CustomShortcut.swift
//  kimeno
//

import SwiftUI
import AppKit

struct CustomShortcut: Codable, Equatable, Sendable {
    var keyCode: UInt16
    var modifiers: UInt

    static nonisolated let defaultCapture = CustomShortcut(keyCode: 19, modifiers: 1179648)
    static nonisolated let defaultHistory = CustomShortcut(keyCode: 4, modifiers: 1179648)

    var displayString: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)

        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        if let keyString = Self.keyCodeToString(keyCode) {
            parts.append(keyString)
        }

        return parts.joined()
    }

    var keyboardShortcut: KeyboardShortcut? {
        guard let character = Self.keyCodeToCharacter(keyCode) else { return nil }

        var eventModifiers: SwiftUI.EventModifiers = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)

        if flags.contains(.command) { eventModifiers.insert(.command) }
        if flags.contains(.shift) { eventModifiers.insert(.shift) }
        if flags.contains(.option) { eventModifiers.insert(.option) }
        if flags.contains(.control) { eventModifiers.insert(.control) }

        return KeyboardShortcut(KeyEquivalent(character), modifiers: eventModifiers)
    }

    private static func keyCodeToCharacter(_ keyCode: UInt16) -> Character? {
        let keyCodeMap: [UInt16: Character] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
            8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
            16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 37: "l",
            38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "n", 46: "m", 47: "."
        ]
        return keyCodeMap[keyCode]
    }

    private static func keyCodeToString(_ keyCode: UInt16) -> String? {
        let keyCodeMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`",
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "ESC",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        return keyCodeMap[keyCode]
    }

    func matches(keyCode eventKeyCode: UInt16, modifiers eventModifiers: UInt) -> Bool {
        return eventKeyCode == keyCode && eventModifiers == modifiers
    }
}
