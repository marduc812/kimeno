//
//  ScreenCaptureManager.swift
//  kimeno
//

import SwiftUI
import ScreenCaptureKit
import UserNotifications
import Vision
import Carbon

@MainActor
class ScreenCaptureManager: ObservableObject {
    @Published var lastExtractedText: String?

    private var selectionWindows: [SelectionWindow] = []
    private var selectionCoordinator: SelectionCoordinator?
    private var localEventMonitor: Any?
    private var escapeHotkeyRef: EventHotKeyRef?

    private static let escapeHotkeyID = EventHotKeyID(signature: OSType(0x4B494D45), id: 9999) // "KIME" + 9999
    private static weak var sharedInstance: ScreenCaptureManager?

    deinit {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let hotkeyRef = escapeHotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
        }
    }

    func startAreaSelection() {
        closeAllWindows()

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        selectionCoordinator = SelectionCoordinator()

        selectionCoordinator?.onSelectionComplete = { [weak self] globalRect in
            guard let self = self else { return }
            let rectToCapture = globalRect
            self.closeAllWindows()

            // Minimal delay for windows to close - 50ms is enough
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.captureArea(rect: rectToCapture)
            }
        }

        selectionCoordinator?.onCancel = { [weak self] in
            self?.closeAllWindows()
        }

        for screen in screens {
            let window = SelectionWindow(screen: screen, coordinator: selectionCoordinator!)
            selectionWindows.append(window)
        }

        // Register global Escape hotkey using Carbon API (works in sandbox)
        registerEscapeHotkey()

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                DispatchQueue.main.async {
                    self?.closeAllWindows()
                }
                return nil
            }
            return event
        }

        // Force app activation
        NSApp.activate(ignoringOtherApps: true)

        for window in selectionWindows {
            window.orderFrontRegardless()
        }

        // Determine which window should be key based on mouse location
        let mouseLocation = NSEvent.mouseLocation
        let keyWindow: SelectionWindow?
        if let windowUnderMouse = selectionWindows.first(where: { $0.targetScreen.frame.contains(mouseLocation) }) {
            keyWindow = windowUnderMouse
        } else if let mainWindow = selectionWindows.first(where: { $0.targetScreen == NSScreen.main }) {
            keyWindow = mainWindow
        } else {
            keyWindow = selectionWindows.first
        }

        // Make the window key and force first responder
        if let window = keyWindow {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(window.contentView)
        }
    }

    // MARK: - Escape Hotkey (Carbon API)

    private func registerEscapeHotkey() {
        unregisterEscapeHotkey()

        ScreenCaptureManager.sharedInstance = self

        // Install event handler if not already installed
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hotkeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )

                if hotkeyID.id == 9999 {
                    DispatchQueue.main.async {
                        ScreenCaptureManager.sharedInstance?.closeAllWindows()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )

        // Register Escape key (keyCode 53) with no modifiers
        let hotkeyID = Self.escapeHotkeyID
        RegisterEventHotKey(
            UInt32(53), // Escape key
            0,          // No modifiers
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &escapeHotkeyRef
        )
    }

    private func unregisterEscapeHotkey() {
        if let hotkeyRef = escapeHotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            escapeHotkeyRef = nil
        }
    }

    private func closeAllWindows() {
        // Unregister escape hotkey
        unregisterEscapeHotkey()

        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }

        selectionCoordinator?.cleanup()
        selectionCoordinator = nil

        for window in selectionWindows {
            window.orderOut(nil)
            window.close()
        }
        selectionWindows.removeAll()
    }

    func captureArea(rect: NSRect) {
        // Gather screen info on main thread
        let centerPoint = NSPoint(x: rect.midX, y: rect.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(centerPoint) }) ?? NSScreen.main else {
            showAlert(message: "No screen found for selection")
            return
        }

        let scaleFactor = screen.backingScaleFactor
        let screenFrame = screen.frame
        let screenDisplayID = screen.displayID

        let localRect = NSRect(
            x: rect.origin.x - screenFrame.origin.x,
            y: rect.origin.y - screenFrame.origin.y,
            width: rect.width,
            height: rect.height
        )

        let captureRect = CGRect(
            x: localRect.origin.x * scaleFactor,
            y: (screenFrame.height - localRect.origin.y - localRect.height) * scaleFactor,
            width: localRect.width * scaleFactor,
            height: localRect.height * scaleFactor
        )

        // Read settings on main thread before dispatching
        let autoCopyToClipboard = UserDefaults.standard.object(forKey: "autoCopyToClipboard") as? Bool ?? true
        let playSound = UserDefaults.standard.object(forKey: "playSound") as? Bool ?? true
        let recognitionLanguage = UserDefaults.standard.string(forKey: "recognitionLanguage") ?? "en-US"
        let lineAwareOCR = UserDefaults.standard.object(forKey: "lineAwareOCR") as? Bool ?? true
        let ocrAccuracy = UserDefaults.standard.string(forKey: "ocrAccuracy") ?? "accurate"

        // Perform entire capture and OCR pipeline on background thread
        // Use .utility priority (below default) to avoid priority inversion with SCScreenshotManager
        Task.detached(priority: .utility) { [weak self] in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                guard let display = content.displays.first(where: { $0.displayID == screenDisplayID }) ?? content.displays.first else {
                    await self?.handleCaptureError(.noDisplay)
                    return
                }

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = Int(display.width) * Int(scaleFactor)
                config.height = Int(display.height) * Int(scaleFactor)
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.showsCursor = false

                let fullImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )

                guard let croppedImage = fullImage.cropping(to: captureRect) else {
                    await self?.handleCaptureError(.cropFailed)
                    return
                }

                // Perform OCR
                let extractedText = self?.performOCR(
                    on: croppedImage,
                    language: recognitionLanguage,
                    lineAware: lineAwareOCR,
                    accuracy: ocrAccuracy
                )

                // Update UI on main thread
                await self?.handleCaptureResult(
                    text: extractedText,
                    autoCopy: autoCopyToClipboard,
                    playSound: playSound
                )

            } catch {
                await self?.handleCaptureError(.general(error))
            }
        }
    }

    private enum CaptureError {
        case noDisplay
        case cropFailed
        case general(Error)
    }

    private func handleCaptureError(_ error: CaptureError) {
        switch error {
        case .noDisplay:
            showAlert(message: "No display found")
        case .cropFailed:
            showAlert(message: "Failed to crop image")
        case .general(let err):
            if err.localizedDescription.contains("permission") ||
               err.localizedDescription.contains("denied") {
                showPermissionAlert()
            } else {
                showAlert(message: "Capture failed: \(err.localizedDescription)")
            }
        }
    }

    private func handleCaptureResult(text: String?, autoCopy: Bool, playSound: Bool) {
        if let text = text, !text.isEmpty {
            if autoCopy {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            lastExtractedText = text

            if playSound {
                NSSound(named: .init("Funk"))?.play()
            }

            showNotification(text: text, autoCopied: autoCopy)
        } else {
            showNotification(text: nil, autoCopied: false)
        }
    }

    private nonisolated func performOCR(on image: CGImage, language: String, lineAware: Bool, accuracy: String) -> String? {
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])

        var resultText: String?

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("OCR error: \(error.localizedDescription)")
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            if lineAware {
                // Line-aware mode: group text by lines and read left-to-right
                // Store full item data with index for O(1) lookups
                struct TextItem {
                    let text: String
                    let minX: CGFloat
                    let midY: CGFloat
                    let height: CGFloat
                }

                let textItems: [TextItem] = observations.compactMap { observation in
                    guard let text = observation.topCandidates(1).first?.string else { return nil }
                    let box = observation.boundingBox
                    return TextItem(
                        text: text,
                        minX: box.minX,
                        midY: (box.minY + box.maxY) / 2,
                        height: box.maxY - box.minY
                    )
                }

                // Group observations into lines - O(n) with stored midY/height
                var lines: [(items: [(text: String, minX: CGFloat)], midY: CGFloat, height: CGFloat)] = []

                for item in textItems {
                    // Find an existing line that this item belongs to
                    var foundLineIndex: Int?
                    for (index, line) in lines.enumerated() {
                        // Items are on same line if their midpoints are within half a line height
                        if abs(item.midY - line.midY) < line.height * 0.5 {
                            foundLineIndex = index
                            break
                        }
                    }

                    if let index = foundLineIndex {
                        lines[index].items.append((item.text, item.minX))
                    } else {
                        lines.append(([(item.text, item.minX)], item.midY, item.height))
                    }
                }

                // Sort lines by Y position (top to bottom - Vision uses bottom-left origin)
                let sortedLines = lines.sorted { $0.midY > $1.midY }

                // Sort items within each line by X position (left to right) and join
                let lineTexts = sortedLines.map { line in
                    line.items.sorted { $0.minX < $1.minX }
                        .map { $0.text }
                        .joined(separator: " ")
                }

                resultText = lineTexts.joined(separator: "\n")
            } else {
                // Column-based mode: original Vision ordering
                let texts = observations.compactMap { observation -> String? in
                    observation.topCandidates(1).first?.string
                }
                resultText = texts.joined(separator: "\n")
            }
        }

        // Set recognition level based on user preference
        request.recognitionLevel = accuracy == "fast" ? .fast : .accurate
        request.usesLanguageCorrection = accuracy == "accurate"
        request.recognitionLanguages = [language]

        do {
            try requestHandler.perform([request])
        } catch {
            print("OCR failed: \(error.localizedDescription)")
            return nil
        }

        return resultText
    }

    private func showNotification(text: String?, autoCopied: Bool) {
        let content = UNMutableNotificationContent()
        if let text = text {
            content.title = autoCopied ? "Text Copied" : "Text Captured"
            let preview = text.count > 100 ? String(text.prefix(100)) + "..." : text
            content.body = preview
        } else {
            content.title = "No Text Found"
            content.body = "No text was detected in the selected area"
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Screenshot Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Please grant screen recording permission in System Settings > Privacy & Security > Screen Recording"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
