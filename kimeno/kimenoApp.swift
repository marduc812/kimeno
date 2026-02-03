//
//  kimenoApp.swift
//  kimeno
//
//  Created by marduc812 on 02.02.2026.
//

import SwiftUI
import AppKit
import ScreenCaptureKit
import UserNotifications
import Vision

@main
struct kimenoApp: App {
    @StateObject private var screenCapture = ScreenCaptureManager()
    
    init() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    var body: some Scene {
        MenuBarExtra("Kimeno", systemImage: "app.fill") {
            Button("Capture") {
                screenCapture.startAreaSelection()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            
            Button("History") {
                // Handle history action
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

// MARK: - Screen Capture Manager

@MainActor
class ScreenCaptureManager: ObservableObject {
    private var selectionWindows: [SelectionWindow] = []
    private var selectionCoordinator: SelectionCoordinator?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
    deinit {
        // Ensure cleanup on deallocation
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    func startAreaSelection() {
        // Close any existing selection windows first
        closeAllWindows()
        
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        
        // Create a coordinator to share selection state across all screens
        selectionCoordinator = SelectionCoordinator()
        
        selectionCoordinator?.onSelectionComplete = { [weak self] globalRect in
            guard let self = self else { return }
            // Store the rect before closing windows
            let rectToCapture = globalRect
            self.closeAllWindows()
            
            // Small delay to ensure windows are fully closed before capture
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                Task { @MainActor in
                    await self.captureArea(rect: rectToCapture)
                }
            }
        }
        
        selectionCoordinator?.onCancel = { [weak self] in
            self?.closeAllWindows()
        }
        
        // Create a selection window for each screen
        for screen in screens {
            let window = SelectionWindow(screen: screen, coordinator: selectionCoordinator!)
            selectionWindows.append(window)
        }
        
        // Add global ESC key monitor as backup (in case window doesn't have focus)
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                DispatchQueue.main.async {
                    self?.closeAllWindows()
                }
            }
        }
        
        // Add local ESC key monitor
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                DispatchQueue.main.async {
                    self?.closeAllWindows()
                }
                return nil
            }
            return event
        }
        
        // Activate the app and show windows
        NSApp.activate(ignoringOtherApps: true)
        
        // Show all windows
        for window in selectionWindows {
            window.orderFrontRegardless()
        }
        
        // Make the window under the mouse key, or main screen's window
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
        // Remove event monitors
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        // Cleanup coordinator
        selectionCoordinator?.cleanup()
        selectionCoordinator = nil
        
        // Close and release all windows
        for window in selectionWindows {
            window.orderOut(nil)
            window.close()
        }
        selectionWindows.removeAll()
    }
    
    func captureArea(rect: NSRect) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Find which screen contains the selection (use center point)
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
            
            // Convert global coordinates to screen-local coordinates
            // rect is in global screen coordinates (origin at bottom-left of primary screen)
            // We need to convert to the target screen's local coordinates
            let screenFrame = screen.frame
            let localRect = NSRect(
                x: rect.origin.x - screenFrame.origin.x,
                y: rect.origin.y - screenFrame.origin.y,
                width: rect.width,
                height: rect.height
            )
            
            // Convert from bottom-left origin to top-left origin for capture
            let captureRect = CGRect(
                x: localRect.origin.x * scaleFactor,
                y: (screenFrame.height - localRect.origin.y - localRect.height) * scaleFactor,
                width: localRect.width * scaleFactor,
                height: localRect.height * scaleFactor
            )
            
            // Configure the capture
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = Int(display.width) * Int(scaleFactor)
            config.height = Int(display.height) * Int(scaleFactor)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false
            
            // Capture the full screen
            let fullImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            
            // Crop to selected area
            guard let croppedImage = fullImage.cropping(to: captureRect) else {
                showAlert(message: "Failed to crop image")
                return
            }
            
            // Perform OCR and copy text to clipboard
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
        var extractedText = ""
        
        // Create a request handler
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        
        // Create a text recognition request
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("OCR error: \(error.localizedDescription)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            // Extract text from all observations
            let texts = observations.compactMap { observation -> String? in
                observation.topCandidates(1).first?.string
            }
            
            extractedText = texts.joined(separator: "\n")
        }
        
        // Configure for accurate recognition
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // Perform the request
        do {
            try requestHandler.perform([request])
        } catch {
            showAlert(message: "OCR failed: \(error.localizedDescription)")
            return
        }
        
        // Copy extracted text to clipboard
        if !extractedText.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(extractedText, forType: .string)
            showNotification(text: extractedText)
        } else {
            showNotification(text: nil)
        }
    }
    
    private func showNotification(text: String?) {
        let content = UNMutableNotificationContent()
        if let text = text {
            content.title = "Text Copied"
            // Show preview of the text (truncate if too long)
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

// MARK: - Selection Coordinator

class SelectionCoordinator {
    var startPoint: NSPoint?
    var currentPoint: NSPoint?
    var isSelecting = false
    
    var onSelectionComplete: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?
    
    // Use weak references to avoid retain cycles and crashes when views are deallocated
    private var registeredViews: [WeakViewRef] = []
    
    var selectionRect: NSRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        return NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }
    
    func register(view: SelectionView) {
        registeredViews.append(WeakViewRef(view: view))
    }
    
    func updateAllViews() {
        for weakRef in registeredViews {
            weakRef.view?.needsDisplay = true
        }
    }
    
    func completeSelection() {
        guard let rect = selectionRect, rect.width > 5, rect.height > 5 else {
            // Selection too small, reset
            startPoint = nil
            currentPoint = nil
            isSelecting = false
            updateAllViews()
            return
        }
        // Store rect locally before callback (in case coordinator is deallocated)
        let captureRect = rect
        onSelectionComplete?(captureRect)
    }
    
    func cancel() {
        onCancel?()
    }
    
    func cleanup() {
        registeredViews.removeAll()
        onSelectionComplete = nil
        onCancel = nil
    }
}

// Weak reference wrapper for SelectionView
private class WeakViewRef {
    weak var view: SelectionView?
    init(view: SelectionView) {
        self.view = view
    }
}

// MARK: - Selection Window

class SelectionWindow: NSWindow {
    private var selectionView: SelectionView!
    private weak var coordinator: SelectionCoordinator?
    let targetScreen: NSScreen
    
    init(screen: NSScreen, coordinator: SelectionCoordinator) {
        self.targetScreen = screen
        self.coordinator = coordinator
        
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        // Use a high window level to ensure we capture all events
        self.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isReleasedWhenClosed = false  // Prevent premature release
        self.hidesOnDeactivate = false
        
        // Create view with bounds starting at origin (0,0)
        selectionView = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size), 
                                       screen: screen, 
                                       coordinator: coordinator)
        coordinator.register(view: selectionView)
        
        self.contentView = selectionView
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    // Ensure the window can receive mouse events immediately
    override func mouseDown(with event: NSEvent) {
        // Forward to content view
        contentView?.mouseDown(with: event)
    }
}

// MARK: - Selection View

class SelectionView: NSView {
    private weak var coordinator: SelectionCoordinator?
    private let screen: NSScreen
    
    init(frame frameRect: NSRect, screen: NSScreen, coordinator: SelectionCoordinator) {
        self.screen = screen
        self.coordinator = coordinator
        super.init(frame: frameRect)
        setupTrackingArea()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Become first responder when added to window
        window?.makeFirstResponder(self)
    }
    
    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        // When mouse enters this view's screen, make its window key
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
    }
    
    // Convert local view coordinates to global screen coordinates
    private func localToGlobal(_ point: NSPoint) -> NSPoint {
        return NSPoint(
            x: point.x + screen.frame.origin.x,
            y: point.y + screen.frame.origin.y
        )
    }
    
    // Convert global screen coordinates to local view coordinates
    private func globalToLocal(_ point: NSPoint) -> NSPoint {
        return NSPoint(
            x: point.x - screen.frame.origin.x,
            y: point.y - screen.frame.origin.y
        )
    }
    
    // Get the portion of the global selection rect that intersects this screen, in local coordinates
    private var localSelectionRect: NSRect? {
        guard let globalRect = coordinator?.selectionRect else { return nil }
        
        // Convert global rect to local coordinates
        let localRect = NSRect(
            x: globalRect.origin.x - screen.frame.origin.x,
            y: globalRect.origin.y - screen.frame.origin.y,
            width: globalRect.width,
            height: globalRect.height
        )
        
        return localRect
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Draw semi-transparent overlay
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()
        
        // Draw selection rectangle if it intersects this screen
        if let rect = localSelectionRect, rect.width > 0, rect.height > 0 {
            // Clip to bounds for the clear area
            let visibleRect = rect.intersection(bounds)
            if !visibleRect.isNull && visibleRect.width > 0 && visibleRect.height > 0 {
                // Clear the selection area to show the screen beneath
                NSColor.clear.setFill()
                visibleRect.fill(using: .copy)
            }
            
            // Draw border around selection (full rect, may extend beyond bounds)
            NSColor.white.setStroke()
            let borderPath = NSBezierPath(rect: rect)
            borderPath.lineWidth = 2
            borderPath.stroke()
            
            // Draw dashed inner border
            NSColor.black.setStroke()
            let innerPath = NSBezierPath(rect: rect.insetBy(dx: 1, dy: 1))
            innerPath.lineWidth = 1
            innerPath.setLineDash([4, 4], count: 2, phase: 0)
            innerPath.stroke()
            
            // Draw size label (only on the screen where selection started or main screen)
            if let globalRect = coordinator?.selectionRect {
                let labelPoint = NSPoint(x: globalRect.midX, y: globalRect.maxY + 8)
                if screen.frame.contains(labelPoint) || screen == NSScreen.main {
                    drawSizeLabel(for: rect, globalRect: globalRect)
                }
            }
        }
        
        // Draw instructions only on main screen
        if screen == NSScreen.main {
            drawInstructions()
        }
    }
    
    private func drawSizeLabel(for rect: NSRect, globalRect: NSRect) {
        let sizeText = "\(Int(globalRect.width)) × \(Int(globalRect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        
        let textSize = sizeText.size(withAttributes: attributes)
        let padding: CGFloat = 6
        let labelRect = NSRect(
            x: rect.midX - textSize.width / 2 - padding,
            y: rect.maxY + 8,
            width: textSize.width + padding * 2,
            height: textSize.height + padding
        )
        
        // Background for label
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4).fill()
        
        // Draw text
        let textPoint = NSPoint(
            x: labelRect.origin.x + padding,
            y: labelRect.origin.y + padding / 2
        )
        sizeText.draw(at: textPoint, withAttributes: attributes)
    }
    
    private func drawInstructions() {
        let text = "Click and drag to select area • Press ESC to cancel"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let padding: CGFloat = 12
        let labelRect = NSRect(
            x: bounds.midX - textSize.width / 2 - padding,
            y: bounds.maxY - 60,
            width: textSize.width + padding * 2,
            height: textSize.height + padding
        )
        
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 6, yRadius: 6).fill()
        
        let textPoint = NSPoint(
            x: labelRect.origin.x + padding,
            y: labelRect.origin.y + padding / 2
        )
        text.draw(at: textPoint, withAttributes: attributes)
    }
    
    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let globalPoint = localToGlobal(localPoint)
        
        coordinator?.startPoint = globalPoint
        coordinator?.currentPoint = globalPoint
        coordinator?.isSelecting = true
        coordinator?.updateAllViews()
    }
    
    override func mouseDragged(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let globalPoint = localToGlobal(localPoint)
        
        coordinator?.currentPoint = globalPoint
        coordinator?.updateAllViews()
    }
    
    override func mouseUp(with event: NSEvent) {
        coordinator?.completeSelection()
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            coordinator?.cancel()
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
}

// MARK: - NSScreen Extension

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
}
