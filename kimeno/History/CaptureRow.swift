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

    private func relativeTime(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "<1 min" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        if days < 30 { return "\(days)d" }
        let months = days / 30
        if months < 12 { return "\(months)mo" }
        return "\(months / 12)y"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text(relativeTime(from: entry.timestamp))
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
        .popover(isPresented: $isHovered, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.text)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Text(entry.timestamp, format: .dateTime.year().month().day().hour().minute())
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(width: 240, alignment: .leading)
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
