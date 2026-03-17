//
//  TypingService.swift
//  MiniMe
//

import AppKit
import ApplicationServices
import AVFoundation
import Combine

class TypingService: ObservableObject {
    static let shared = TypingService()
    private init() {}

    private var tickPlayers: [AVAudioPlayer] = []

    private func playTick() {
        let soundEnabled = UserDefaults.standard.object(forKey: "typeItCountdownSound") as? Bool ?? true
        guard soundEnabled,
              let url = Bundle.main.url(forResource: "countdown", withExtension: "mp3") else { return }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = 0.7
        player.prepareToPlay()
        player.play()
        tickPlayers.append(player)
    }

    @Published var countdown: Int? = nil

    func typeText(_ text: String, closeAction: (() -> Void)? = nil) {
        guard AXIsProcessTrusted() else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "MiniMe needs Accessibility permission to simulate typing. Please grant it in System Settings → Privacy & Security → Accessibility."
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn,
                   let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }

        closeAction?()

        let stored = UserDefaults.standard.integer(forKey: "typeItCountdownDuration")
        let duration = (1...10).contains(stored) ? stored : 5

        countdown = duration
        playTick()
        for i in 1..<duration {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i)) {
                self.countdown = duration - i
                self.playTick()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration)) {
            self.countdown = nil
        }
        // Clean up players after they've had time to finish
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration) + 2.0) {
            self.tickPlayers.removeAll()
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + Double(duration)) {
            self.performTyping(text)
        }
    }

    func typeFromSelection() {
        guard AXIsProcessTrusted() else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "MiniMe needs Accessibility permission to simulate typing. Please grant it in System Settings → Privacy & Security → Accessibility."
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn,
                   let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }

        // Save current clipboard, simulate Cmd+C, read selection, restore clipboard
        let previousContents = NSPasteboard.general.string(forType: .string)

        let source = CGEventSource(stateID: .hidSystemState)
        let cDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        cDown?.flags = .maskCommand
        let cUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        cUp?.flags = .maskCommand
        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let selected = NSPasteboard.general.string(forType: .string) ?? ""

            // Restore previous clipboard
            NSPasteboard.general.clearContents()
            if let prev = previousContents {
                NSPasteboard.general.setString(prev, forType: .string)
            }

            guard !selected.isEmpty else { return }
            self.typeText(selected)
        }
    }

    // Maps characters to (keyCode, needsShift) for US keyboard layout.
    // Citrix reads the virtual key code, not the unicode string override,
    // so we must use correct key codes per character.
    private static let charToKeyCode: [Character: (CGKeyCode, Bool)] = [
        "a":(0x00,false),"b":(0x0B,false),"c":(0x08,false),"d":(0x02,false),
        "e":(0x0E,false),"f":(0x03,false),"g":(0x05,false),"h":(0x04,false),
        "i":(0x22,false),"j":(0x26,false),"k":(0x28,false),"l":(0x25,false),
        "m":(0x2E,false),"n":(0x2D,false),"o":(0x1F,false),"p":(0x23,false),
        "q":(0x0C,false),"r":(0x0F,false),"s":(0x01,false),"t":(0x11,false),
        "u":(0x20,false),"v":(0x09,false),"w":(0x0D,false),"x":(0x07,false),
        "y":(0x10,false),"z":(0x06,false),
        "A":(0x00,true),"B":(0x0B,true),"C":(0x08,true),"D":(0x02,true),
        "E":(0x0E,true),"F":(0x03,true),"G":(0x05,true),"H":(0x04,true),
        "I":(0x22,true),"J":(0x26,true),"K":(0x28,true),"L":(0x25,true),
        "M":(0x2E,true),"N":(0x2D,true),"O":(0x1F,true),"P":(0x23,true),
        "Q":(0x0C,true),"R":(0x0F,true),"S":(0x01,true),"T":(0x11,true),
        "U":(0x20,true),"V":(0x09,true),"W":(0x0D,true),"X":(0x07,true),
        "Y":(0x10,true),"Z":(0x06,true),
        "0":(0x1D,false),"1":(0x12,false),"2":(0x13,false),"3":(0x14,false),
        "4":(0x15,false),"5":(0x17,false),"6":(0x16,false),"7":(0x1A,false),
        "8":(0x1C,false),"9":(0x19,false),
        ")":(0x1D,true),"!":(0x12,true),"@":(0x13,true),"#":(0x14,true),
        "$":(0x15,true),"%":(0x17,true),"^":(0x16,true),"&":(0x1A,true),
        "*":(0x1C,true),"(":(0x19,true),
        " ":(0x31,false),"\n":(0x24,false),"\t":(0x30,false),
        "-":(0x1B,false),"_":(0x1B,true),"=":(0x18,false),"+":(0x18,true),
        "[":(0x21,false),"{":(0x21,true),"]":(0x1E,false),"}":(0x1E,true),
        "\\":(0x2A,false),"|":(0x2A,true),";":(0x29,false),":":(0x29,true),
        "'":(0x27,false),"\"":(0x27,true),",":(0x2B,false),"<":(0x2B,true),
        ".":(0x2F,false),">":(0x2F,true),"/":(0x2C,false),"?":(0x2C,true),
        "`":(0x32,false),"~":(0x32,true),
    ]

    private func performTyping(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        for char in text {
            if let (keyCode, needsShift) = Self.charToKeyCode[char] {
                let flags: CGEventFlags = needsShift ? .maskShift : []
                guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
                      let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
                else { continue }
                keyDown.flags = flags
                keyUp.flags   = flags
                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            } else {
                // Fallback for unmapped characters (e.g. accented, emoji)
                var unichar = UniChar(char.unicodeScalars.first!.value & 0xFFFF)
                guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                      let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
                else { continue }
                keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unichar)
                keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unichar)
                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
    }
}
