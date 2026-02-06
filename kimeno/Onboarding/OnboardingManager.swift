//
//  OnboardingManager.swift
//  kimeno
//

import SwiftUI
import ScreenCaptureKit

@MainActor
class OnboardingManager: ObservableObject {
    @Published var hasScreenRecordingPermission = false
    @Published var showOnboarding = false

    private var permissionCheckTimer: Timer?
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    var allPermissionsGranted: Bool {
        hasScreenRecordingPermission
    }

    init() {
        checkAllPermissions()
    }

    private func updateOnboardingVisibility() {
        let hasCompleted = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        // Skip onboarding if all permissions are already granted
        if allPermissionsGranted {
            showOnboarding = false
        } else {
            // Show onboarding if never completed or permissions are missing
            showOnboarding = !hasCompleted
        }
    }

    func checkAllPermissions() {
        checkScreenRecordingPermission()
    }

    func checkScreenRecordingPermission() {
        // Check screen recording permission by trying to get shareable content
        Task {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                await MainActor.run {
                    self.hasScreenRecordingPermission = true
                    self.updateOnboardingVisibility()
                }
            } catch {
                await MainActor.run {
                    self.hasScreenRecordingPermission = false
                    self.updateOnboardingVisibility()
                }
            }
        }
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
