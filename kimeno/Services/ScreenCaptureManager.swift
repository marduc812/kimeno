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

        // Perform capture on background thread
        do {
            let croppedImage: CGImage = try await Task.detached(priority: .userInitiated) {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                guard let display = content.displays.first(where: { $0.displayID == screenDisplayID }) ?? content.displays.first else {
                    throw CaptureError.noDisplay
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

                guard let cropped = fullImage.cropping(to: captureRect) else {
                    throw CaptureError.cropFailed
                }

                return cropped
            }.value

            await extractTextFromImage(croppedImage)

        } catch CaptureError.noDisplay {
            showAlert(message: "No display found")
        } catch CaptureError.cropFailed {
            showAlert(message: "Failed to crop image")
        } catch {
            if error.localizedDescription.contains("permission") ||
               error.localizedDescription.contains("denied") {
                showPermissionAlert()
            } else {
                showAlert(message: "Capture failed: \(error.localizedDescription)")
            }
        }
    }

    private enum CaptureError: Error {
        case noDisplay
        case cropFailed
    }

    private func extractTextFromImage(_ image: CGImage) async {
        let autoCopyToClipboard = UserDefaults.standard.object(forKey: "autoCopyToClipboard") as? Bool ?? true
        let playSound = UserDefaults.standard.object(forKey: "playSound") as? Bool ?? true
        let recognitionLanguage = UserDefaults.standard.string(forKey: "recognitionLanguage") ?? "en-US"
        let lineAwareOCR = UserDefaults.standard.object(forKey: "lineAwareOCR") as? Bool ?? true

        // Perform OCR on background thread
        let extractedText: String? = await Task.detached(priority: .userInitiated) {
            let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])

            var resultText: String?

            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("OCR error: \(error.localizedDescription)")
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

                if lineAwareOCR {
                    // Line-aware mode: group text by lines and read left-to-right
                    let textItems: [(text: String, minX: CGFloat, minY: CGFloat, maxY: CGFloat)] = observations.compactMap { observation in
                        guard let text = observation.topCandidates(1).first?.string else { return nil }
                        let box = observation.boundingBox
                        return (text, box.minX, box.minY, box.maxY)
                    }

                    // Group observations into lines based on vertical overlap
                    var lines: [[(text: String, minX: CGFloat)]] = []

                    for item in textItems {
                        let itemMidY = (item.minY + item.maxY) / 2

                        // Find an existing line that this item belongs to (vertical overlap)
                        var foundLineIndex: Int?
                        for (index, line) in lines.enumerated() {
                            // Check if this item's midpoint falls within the Y range of items in this line
                            if let firstItem = textItems.first(where: { $0.text == line[0].text && $0.minX == line[0].minX }) {
                                let lineMidY = (firstItem.minY + firstItem.maxY) / 2
                                let lineHeight = firstItem.maxY - firstItem.minY
                                // Items are on same line if their midpoints are within half a line height
                                if abs(itemMidY - lineMidY) < lineHeight * 0.5 {
                                    foundLineIndex = index
                                    break
                                }
                            }
                        }

                        if let index = foundLineIndex {
                            lines[index].append((item.text, item.minX))
                        } else {
                            lines.append([(item.text, item.minX)])
                        }
                    }

                    // Sort lines by Y position (top to bottom - Vision uses bottom-left origin)
                    let sortedLines = lines.sorted { line1, line2 in
                        guard let item1 = textItems.first(where: { $0.text == line1[0].text && $0.minX == line1[0].minX }),
                              let item2 = textItems.first(where: { $0.text == line2[0].text && $0.minX == line2[0].minX }) else {
                            return false
                        }
                        return item1.minY > item2.minY
                    }

                    // Sort items within each line by X position (left to right) and join
                    let lineTexts = sortedLines.map { line in
                        line.sorted { $0.minX < $1.minX }
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

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = [recognitionLanguage]

            do {
                try requestHandler.perform([request])
            } catch {
                print("OCR failed: \(error.localizedDescription)")
                return nil
            }

            return resultText
        }.value

        // Update UI on main thread
        if let text = extractedText, !text.isEmpty {
            if autoCopyToClipboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            lastExtractedText = text

            if playSound {
                NSSound(named: .init("Funk"))?.play()
            }

            showNotification(text: text)
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
