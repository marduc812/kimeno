//
//  ScreenCaptureManager.swift
//  kimeno
//

import SwiftUI
import ScreenCaptureKit
import UserNotifications
import Vision

@MainActor
class ScreenCaptureManager: ObservableObject {
    @Published var lastExtractedText: String?

    private var selectionWindows: [SelectionWindow] = []
    private var selectionCoordinator: SelectionCoordinator?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?

    deinit {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
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

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                Task { @MainActor in
                    await self.captureArea(rect: rectToCapture)
                }
            }
        }

        selectionCoordinator?.onCancel = { [weak self] in
            self?.closeAllWindows()
        }

        for screen in screens {
            let window = SelectionWindow(screen: screen, coordinator: selectionCoordinator!)
            selectionWindows.append(window)
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                DispatchQueue.main.async {
                    self?.closeAllWindows()
                }
            }
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                DispatchQueue.main.async {
                    self?.closeAllWindows()
                }
                return nil
            }
            return event
        }

        NSApp.activate(ignoringOtherApps: true)

        for window in selectionWindows {
            window.orderFrontRegardless()
        }

        let mouseLocation = NSEvent.mouseLocation
        if let windowUnderMouse = selectionWindows.first(where: { $0.targetScreen.frame.contains(mouseLocation) }) {
            windowUnderMouse.makeKeyAndOrderFront(nil)
            windowUnderMouse.makeFirstResponder(windowUnderMouse.contentView)
        } else if let mainWindow = selectionWindows.first(where: { $0.targetScreen == NSScreen.main }) {
            mainWindow.makeKeyAndOrderFront(nil)
            mainWindow.makeFirstResponder(mainWindow.contentView)
        } else {
            selectionWindows.first?.makeKeyAndOrderFront(nil)
        }
    }

    private func closeAllWindows() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
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

    func captureArea(rect: NSRect) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            let centerPoint = NSPoint(x: rect.midX, y: rect.midY)
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(centerPoint) }) ?? NSScreen.main else {
                showAlert(message: "No screen found for selection")
                return
            }

            guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) ?? content.displays.first else {
                showAlert(message: "No display found")
                return
            }

            let scaleFactor = screen.backingScaleFactor

            let screenFrame = screen.frame
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
                showAlert(message: "Failed to crop image")
                return
            }

            extractTextFromImage(croppedImage)

        } catch {
            if error.localizedDescription.contains("permission") ||
               error.localizedDescription.contains("denied") {
                showPermissionAlert()
            } else {
                showAlert(message: "Capture failed: \(error.localizedDescription)")
            }
        }
    }

    private func extractTextFromImage(_ image: CGImage) {
        let autoCopyToClipboard = UserDefaults.standard.object(forKey: "autoCopyToClipboard") as? Bool ?? true
        let playSound = UserDefaults.standard.object(forKey: "playSound") as? Bool ?? true
        let recognitionLanguage = UserDefaults.standard.string(forKey: "recognitionLanguage") ?? "en-US"

        var extractedText = ""

        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("OCR error: \(error.localizedDescription)")
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            let texts = observations.compactMap { observation -> String? in
                observation.topCandidates(1).first?.string
            }

            extractedText = texts.joined(separator: "\n")
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [recognitionLanguage]

        do {
            try requestHandler.perform([request])
        } catch {
            showAlert(message: "OCR failed: \(error.localizedDescription)")
            return
        }

        if !extractedText.isEmpty {
            if autoCopyToClipboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(extractedText, forType: .string)
            }
            lastExtractedText = extractedText

            if playSound {
                NSSound(named: .init("Funk"))?.play()
            }

            showNotification(text: extractedText)
        } else {
            showNotification(text: nil)
        }
    }

    private func showNotification(text: String?) {
        let content = UNMutableNotificationContent()
        if let text = text {
            content.title = "Text Copied"
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
