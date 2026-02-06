//
//  OnboardingView.swift
//  kimeno
//

import SwiftUI
import ScreenCaptureKit

struct OnboardingView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @State private var currentStep = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("κ")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(.accentColor)
                Text("Welcome to Kimeno")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("Let's set up the required permissions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 30)

            Divider()
                .padding(.horizontal, 20)

            // Permission steps
            VStack(spacing: 16) {
                PermissionRow(
                    title: "Accessibility",
                    description: "Required for global keyboard shortcuts",
                    isGranted: onboardingManager.hasAccessibilityPermission,
                    action: { onboardingManager.requestAccessibilityPermission() }
                )

                PermissionRow(
                    title: "Screen Recording",
                    description: "Required to capture screen content",
                    isGranted: onboardingManager.hasScreenRecordingPermission,
                    action: { onboardingManager.requestScreenRecordingPermission() }
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)

            Spacer()

            Divider()
                .padding(.horizontal, 20)

            // Footer
            VStack(spacing: 12) {
                if onboardingManager.allPermissionsGranted {
                    Text("All permissions granted!")
                        .font(.subheadline)
                        .foregroundColor(.green)
                } else {
                    Text("Grant permissions to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    onboardingManager.completeOnboarding()
                }) {
                    Text(onboardingManager.allPermissionsGranted ? "Get Started" : "Skip for Now")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(onboardingManager.allPermissionsGranted ? .accentColor : .secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .frame(width: 400, height: 480)
        .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow))
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isGranted ? .green : .orange)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action button
            if !isGranted {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}
