//
//  HistoryView.swift
//  kimeno
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: CaptureHistoryStore
    @State private var selectedEntry: CaptureEntry?
    @State private var searchText = ""

    var filteredCaptures: [CaptureEntry] {
        if searchText.isEmpty {
            return store.captures
        }
        return store.captures.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Text("History")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(store.captures.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 12))
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            Divider()
                .opacity(0.5)
                .padding(.horizontal, 12)

            if filteredCaptures.isEmpty {
                HistoryEmptyState(searchText: searchText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredCaptures) { entry in
                            CaptureRow(entry: entry, store: store)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }

            if !store.captures.isEmpty {
                Divider()
                    .opacity(0.5)
                    .padding(.horizontal, 12)

                HStack {
                    Spacer()
                    Button {
                        store.clearHistory()
                    } label: {
                        Label("Clear All", systemImage: "trash")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .frame(width: 320, height: 420)
        .background {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                Color.primary.opacity(0.02)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        .onExitCommand {
            store.closeHistoryWindow()
        }
    }
}

struct HistoryEmptyState: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            if searchText.isEmpty {
                Text("κ")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.secondary.opacity(0.4), .secondary.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 6) {
                Text(searchText.isEmpty ? "No captures yet" : "No matches found")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                if searchText.isEmpty {
                    Text("Use ⌘⇧C to capture text from screen")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
