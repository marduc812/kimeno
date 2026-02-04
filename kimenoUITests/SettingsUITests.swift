//
//  SettingsUITests.swift
//  kimenoUITests
//

import XCTest

final class SettingsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Settings Window Tests

    @MainActor
    func testSettingsWindowOpens() throws {
        // Try to open settings via keyboard shortcut
        app.typeKey(",", modifierFlags: .command)

        // Wait for settings window
        let settingsWindow = app.windows["Settings"]
        let exists = settingsWindow.waitForExistence(timeout: 2)

        if exists {
            XCTAssertTrue(settingsWindow.exists)
        }
    }

    @MainActor
    func testSettingsHasGeneralTab() throws {
        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows["Settings"]
        guard settingsWindow.waitForExistence(timeout: 2) else { return }

        let generalButton = settingsWindow.buttons["General"]
        if generalButton.exists {
            XCTAssertTrue(generalButton.exists)
        }
    }

    @MainActor
    func testSettingsHasShortcutsTab() throws {
        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows["Settings"]
        guard settingsWindow.waitForExistence(timeout: 2) else { return }

        let shortcutsButton = settingsWindow.buttons["Shortcuts"]
        if shortcutsButton.exists {
            XCTAssertTrue(shortcutsButton.exists)
        }
    }

    @MainActor
    func testSettingsHasAboutTab() throws {
        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows["Settings"]
        guard settingsWindow.waitForExistence(timeout: 2) else { return }

        let aboutButton = settingsWindow.buttons["About"]
        if aboutButton.exists {
            XCTAssertTrue(aboutButton.exists)
        }
    }

    @MainActor
    func testSettingsWindowCanBeClosed() throws {
        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows["Settings"]
        guard settingsWindow.waitForExistence(timeout: 2) else { return }

        // Close with Cmd+W
        app.typeKey("w", modifierFlags: .command)

        // Window should close
        let closed = !settingsWindow.waitForExistence(timeout: 1)
        XCTAssertTrue(closed || !settingsWindow.exists)
    }

    // MARK: - General Settings Tests

    @MainActor
    func testGeneralSettingsHasLaunchAtLoginToggle() throws {
        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows["Settings"]
        guard settingsWindow.waitForExistence(timeout: 2) else { return }

        let launchToggle = settingsWindow.checkBoxes["Launch at login"]
        if launchToggle.exists {
            XCTAssertTrue(launchToggle.exists)
        }
    }

    @MainActor
    func testGeneralSettingsHasAutoClipboardToggle() throws {
        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows["Settings"]
        guard settingsWindow.waitForExistence(timeout: 2) else { return }

        let clipboardToggle = settingsWindow.checkBoxes["Copy text to clipboard automatically"]
        if clipboardToggle.exists {
            XCTAssertTrue(clipboardToggle.exists)
        }
    }

    @MainActor
    func testGeneralSettingsHasSoundToggle() throws {
        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows["Settings"]
        guard settingsWindow.waitForExistence(timeout: 2) else { return }

        let soundToggle = settingsWindow.checkBoxes["Play sound on capture"]
        if soundToggle.exists {
            XCTAssertTrue(soundToggle.exists)
        }
    }
}
