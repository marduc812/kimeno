//
//  OnboardingManager.swift
//  kimeno
//

import SwiftUI
import ScreenCaptureKit
import ApplicationServices

@MainActor
class OnboardingManager: ObservableObject {
    @Published var hasAccessibilityPermission = false
    @Published var hasScreenRecordingPermission = false
    @Published var showOnboarding = false

    private var permissionCheckTimer: Timer?
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    var allPermissionsGranted: Bool {
        hasAccessibilityPermission && hasScreenRecordingPermission
    }

    init() {
        checkAllPermissions()
        checkIfShouldShowOnboarding()
    }

    private func checkIfShouldShowOnboarding() {
        let hasCompleted = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        // Show onboarding if never completed OR if permissions are missing
        showOnboarding = !hasCompleted || !allPermissionsGranted
    }

    func checkAllPermissions() {
        checkAccessibilityPermission()
        checkScreenRecordingPermission()
    }

    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func checkScreenRecordingPermission() {
        // Check screen recording permission by trying to get shareable content
        Task {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                await MainActor.run {
                    self.hasScreenRecordingPermission = true
                }
            } catch {
                await MainActor.run {
                    self.hasScreenRecordingPermission = false
                }
            }
        }
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        startPermissionPolling()
    }

    func requestScreenRecordingPermission() {
        // Opening the screen recording preference pane
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
        startPermissionPolling()
    }

    private func startPermissionPolling() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAllPermissions()
            }
        }
    }

    func stopPermissionPolling() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
        stopPermissionPolling()
        showOnboarding = false
    }

    func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: hasCompletedOnboardingKey)
        showOnboarding = true
    }
}
