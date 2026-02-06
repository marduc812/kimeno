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
        VStack(alignment: .leading, spacing: 4) {
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
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            if isHovered {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                    )
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            store.copyToClipboard(entry)
        }
        .contextMenu {
            Button {
                store.copyToClipboard(entry)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive) {
                store.deleteCapture(id: entry.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
