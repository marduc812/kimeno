//
//  CaptureRow.swift
//  kimeno
//

import SwiftUI

struct CaptureRow: View {
    let entry: CaptureEntry
    let store: CaptureHistoryStore
    @State private var isHovered = false

    private var hasMoreText: Bool {
        entry.text.count > entry.title.count || entry.text.contains("\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(entry.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text(entry.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            if hasMoreText {
                Text(entry.text.components(separatedBy: .newlines).dropFirst().joined(separator: " "))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isHovered ? Color.primary.opacity(0.08) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            store.copyToClipboard(entry)
        }
        .contextMenu {
            Button("Copy") {
                store.copyToClipboard(entry)
            }
            Divider()
            Button("Delete", role: .destructive) {
                store.deleteCapture(id: entry.id)
            }
        }
    }
}
