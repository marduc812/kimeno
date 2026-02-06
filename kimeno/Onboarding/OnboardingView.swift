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
            VStack(spacing: 10) {
                Text("κ")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text("Welcome to Kimeno")
                    .font(.system(size: 22, weight: .semibold))
                Text("Let's set up the required permissions")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 44)
            .padding(.bottom, 32)

            Divider()
                .opacity(0.5)
                .padding(.horizontal, 24)

            // Permission steps
            VStack(spacing: 16) {
                PermissionRow(
                    title: "Screen Recording",
                    description: "Required to capture screen content for OCR",
                    isGranted: onboardingManager.hasScreenRecordingPermission,
                    action: { onboardingManager.requestScreenRecordingPermission() }
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)

            Spacer()

            Divider()
                .opacity(0.5)
                .padding(.horizontal, 24)

            // Footer
            VStack(spacing: 14) {
                if onboardingManager.allPermissionsGranted {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("All permissions granted!")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("Grant permissions to continue")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Button(action: {
                    onboardingManager.completeOnboarding()
                }) {
                    Text(onboardingManager.allPermissionsGranted ? "Get Started" : "Skip for Now")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(onboardingManager.allPermissionsGranted ? .accentColor : .secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .frame(width: 420, height: 500)
        .background {
            ZStack {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                Color.primary.opacity(0.02)
            }
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Status icon
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(isGranted ? .green : .orange)
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
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
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}
