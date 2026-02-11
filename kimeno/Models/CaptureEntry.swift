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
    let sourceApplication: String?

    init(text: String, sourceApplication: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.text = text
        self.title = CaptureEntry.generateTitle(from: text)
        self.sourceApplication = sourceApplication
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        text = try container.decode(String.self, forKey: .text)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        sourceApplication = try container.decodeIfPresent(String.self, forKey: .sourceApplication)
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
