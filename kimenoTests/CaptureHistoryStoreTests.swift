//
//  CaptureHistoryStoreTests.swift
//  kimenoTests
//

import Testing
import Foundation
@testable import kimeno

@MainActor
struct CaptureHistoryStoreTests {

    @Test func storeStartsEmpty() {
        let store = CaptureHistoryStore()
        // Clear any persisted data for clean test
        UserDefaults.standard.removeObject(forKey: "captureHistory")
        let freshStore = CaptureHistoryStore()

        #expect(freshStore.captures.isEmpty)
    }

    @Test func addCaptureInsertsAtBeginning() {
        let store = CaptureHistoryStore()
        store.captures.removeAll()

        store.addCapture(text: "First")
        store.addCapture(text: "Second")

        #expect(store.captures.count == 2)
        #expect(store.captures[0].text == "Second")
        #expect(store.captures[1].text == "First")
    }

    @Test func deleteCaptureByID() {
        let store = CaptureHistoryStore()
        store.captures.removeAll()

        store.addCapture(text: "Test")
        let id = store.captures[0].id

        store.deleteCapture(id: id)

        #expect(store.captures.isEmpty)
    }

    @Test func deleteCaptureByOffsets() {
        let store = CaptureHistoryStore()
        store.captures.removeAll()

        store.addCapture(text: "First")
        store.addCapture(text: "Second")
        store.addCapture(text: "Third")

        store.deleteCapture(at: IndexSet(integer: 1))

        #expect(store.captures.count == 2)
        #expect(store.captures[0].text == "Third")
        #expect(store.captures[1].text == "First")
    }

    @Test func clearHistoryRemovesAll() {
        let store = CaptureHistoryStore()
        store.captures.removeAll()

        store.addCapture(text: "First")
        store.addCapture(text: "Second")

        store.clearHistory()

        #expect(store.captures.isEmpty)
    }

    @Test func maxEntriesLimit() {
        let store = CaptureHistoryStore()
        store.captures.removeAll()

        // Add more than 100 entries
        for i in 0..<110 {
            store.addCapture(text: "Entry \(i)")
        }

        #expect(store.captures.count == 100)
        // Most recent should be first
        #expect(store.captures[0].text == "Entry 109")
    }
}
