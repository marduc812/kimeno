//
//  CustomShortcutTests.swift
//  kimenoTests
//

import Testing
import AppKit
@testable import kimeno

struct CustomShortcutTests {

    @Test func defaultCaptureShortcutIsCommandShiftC() {
        let shortcut = CustomShortcut.defaultCapture

        // keyCode 8 = 'C'
        #expect(shortcut.keyCode == 8)
        // Command + Shift modifiers
        let flags = NSEvent.ModifierFlags(rawValue: shortcut.modifiers)
        #expect(flags.contains(.command))
        #expect(flags.contains(.shift))
    }

    @Test func defaultHistoryShortcutIsCommandShiftH() {
        let shortcut = CustomShortcut.defaultHistory

        // keyCode 4 = 'H'
        #expect(shortcut.keyCode == 4)
        // Command + Shift modifiers
        let flags = NSEvent.ModifierFlags(rawValue: shortcut.modifiers)
        #expect(flags.contains(.command))
        #expect(flags.contains(.shift))
    }

    @Test func displayStringShowsModifiersAndKey() {
        let shortcut = CustomShortcut.defaultCapture
        let display = shortcut.displayString

        #expect(display.contains("⌘")) // Command
        #expect(display.contains("⇧")) // Shift
        #expect(display.contains("C"))
    }

    @Test func displayStringShowsControlModifier() {
        let controlModifier = NSEvent.ModifierFlags.control.rawValue
        let shortcut = CustomShortcut(keyCode: 0, modifiers: controlModifier) // Ctrl+A

        #expect(shortcut.displayString.contains("⌃"))
    }

    @Test func displayStringShowsOptionModifier() {
        let optionModifier = NSEvent.ModifierFlags.option.rawValue
        let shortcut = CustomShortcut(keyCode: 0, modifiers: optionModifier) // Opt+A

        #expect(shortcut.displayString.contains("⌥"))
    }

    @Test func matchesReturnsTrueForMatchingInput() {
        let shortcut = CustomShortcut.defaultCapture

        let result = shortcut.matches(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)

        #expect(result == true)
    }

    @Test func matchesReturnsFalseForDifferentKeyCode() {
        let shortcut = CustomShortcut.defaultCapture

        let result = shortcut.matches(keyCode: 99, modifiers: shortcut.modifiers)

        #expect(result == false)
    }

    @Test func matchesReturnsFalseForDifferentModifiers() {
        let shortcut = CustomShortcut.defaultCapture

        let result = shortcut.matches(keyCode: shortcut.keyCode, modifiers: 0)

        #expect(result == false)
    }

    @Test func shortcutIsCodable() throws {
        let original = CustomShortcut(keyCode: 12, modifiers: 1179648)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CustomShortcut.self, from: data)

        #expect(decoded.keyCode == original.keyCode)
        #expect(decoded.modifiers == original.modifiers)
    }

    @Test func shortcutEquality() {
        let shortcut1 = CustomShortcut(keyCode: 8, modifiers: 1179648)
        let shortcut2 = CustomShortcut(keyCode: 8, modifiers: 1179648)
        let shortcut3 = CustomShortcut(keyCode: 4, modifiers: 1179648)

        #expect(shortcut1 == shortcut2)
        #expect(shortcut1 != shortcut3)
    }

    @Test func keyboardShortcutConversion() {
        let shortcut = CustomShortcut.defaultCapture

        let keyboardShortcut = shortcut.keyboardShortcut

        #expect(keyboardShortcut != nil)
    }

    @Test func specialKeysHaveDisplayStrings() {
        // Test some special keys
        let escapeShortcut = CustomShortcut(keyCode: 53, modifiers: 0)
        #expect(escapeShortcut.displayString.contains("ESC"))

        let returnShortcut = CustomShortcut(keyCode: 36, modifiers: 0)
        #expect(returnShortcut.displayString.contains("↩"))

        let spaceShortcut = CustomShortcut(keyCode: 49, modifiers: 0)
        #expect(spaceShortcut.displayString.contains("Space"))
    }
}
