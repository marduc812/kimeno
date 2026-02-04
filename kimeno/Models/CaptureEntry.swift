//
//  CaptureEntry.swift
//  kimeno
//

import Foundation

struct CaptureEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let text: String
    let timestamp: Date

    init(text: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.text = text
        self.title = CaptureEntry.generateTitle(from: text)
    }

    private static func generateTitle(from text: String) -> String {
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        if trimmed.count <= 50 {
            return trimmed.isEmpty ? "Untitled" : trimmed
        }
        return String(trimmed.prefix(47)) + "..."
    }
}
