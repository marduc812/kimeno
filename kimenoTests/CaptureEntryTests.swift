//
//  CaptureEntryTests.swift
//  kimenoTests
//

import Testing
import Foundation
@testable import kimeno

struct CaptureEntryTests {

    @Test func entryCreatesWithUniqueID() {
        let entry1 = CaptureEntry(text: "Test 1")
        let entry2 = CaptureEntry(text: "Test 2")

        #expect(entry1.id != entry2.id)
    }

    @Test func entryStoresTextCorrectly() {
        let testText = "Hello, World!"
        let entry = CaptureEntry(text: testText)

        #expect(entry.text == testText)
    }

    @Test func entryGeneratesTitleFromFirstLine() {
        let text = "First line\nSecond line\nThird line"
        let entry = CaptureEntry(text: text)

        #expect(entry.title == "First line")
    }

    @Test func entryTruncatesLongTitle() {
        let longText = String(repeating: "A", count: 100)
        let entry = CaptureEntry(text: longText)

        #expect(entry.title.count == 50) // 47 chars + "..."
        #expect(entry.title.hasSuffix("..."))
    }

    @Test func entryHandlesEmptyText() {
        let entry = CaptureEntry(text: "")

        #expect(entry.title == "Untitled")
    }

    @Test func entryHandlesWhitespaceOnlyText() {
        let entry = CaptureEntry(text: "   \n   ")

        #expect(entry.title == "Untitled")
    }

    @Test func entryHasTimestamp() {
        let beforeCreation = Date()
        let entry = CaptureEntry(text: "Test")
        let afterCreation = Date()

        #expect(entry.timestamp >= beforeCreation)
        #expect(entry.timestamp <= afterCreation)
    }

    @Test func entryIsHashable() {
        let entry1 = CaptureEntry(text: "Test")
        let entry2 = CaptureEntry(text: "Test")

        var set = Set<CaptureEntry>()
        set.insert(entry1)
        set.insert(entry2)

        #expect(set.count == 2) // Different IDs, so both should be in the set
    }

    @Test func entryIsCodable() throws {
        let original = CaptureEntry(text: "Test text for encoding")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CaptureEntry.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.text == original.text)
        #expect(decoded.title == original.title)
    }
}
