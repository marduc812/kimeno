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
                Text("History")
                    .font(.headline)
                Spacer()
                Text("\(store.captures.count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()
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
                    .padding(.vertical, 4)
                }
            }

            if !store.captures.isEmpty {
                Divider()
                    .padding(.horizontal, 12)

                HStack {
                    Spacer()
                    Button("Clear All") {
                        store.clearHistory()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .font(.system(size: 11))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 320, height: 400)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .onExitCommand {
            store.closeHistoryWindow()
        }
    }
}

struct HistoryEmptyState: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if searchText.isEmpty {
                Text("κ")
                    .font(.system(size: 56, weight: .light))
                    .foregroundColor(.secondary.opacity(0.5))
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundColor(.secondary.opacity(0.5))
            }

            VStack(spacing: 4) {
                Text(searchText.isEmpty ? "No captures yet" : "No matches found")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                if searchText.isEmpty {
                    Text("Use ⌘⇧C to capture text from screen")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
