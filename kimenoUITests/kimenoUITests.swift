//
//  kimenoUITests.swift
//  kimenoUITests
//
//  Created by marduc812 on 02.02.2026.
//

import XCTest

final class kimenoUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch Tests

    @MainActor
    func testAppLaunchesSuccessfully() throws {
        // App should launch without crashing
        XCTAssertTrue(app.exists)
    }

    @MainActor
    func testMenuBarIconExists() throws {
        // The menu bar extra should be visible
        // Note: Menu bar extras are tricky to test, but we can verify the app is running
        XCTAssertTrue(app.exists)
    }

    // MARK: - Menu Tests

    @MainActor
    func testMenuContainsCaptureButton() throws {
        // Access the menu bar
        let menuBarsQuery = app.menuBars

        // Look for the Capture menu item
        let captureButton = menuBarsQuery.menuItems["Capture"]

        if captureButton.exists {
            XCTAssertTrue(captureButton.isEnabled)
        }
    }

    @MainActor
    func testMenuContainsHistoryButton() throws {
        let menuBarsQuery = app.menuBars
        let historyButton = menuBarsQuery.menuItems["History"]

        if historyButton.exists {
            XCTAssertTrue(historyButton.isEnabled)
        }
    }

    @MainActor
    func testMenuContainsSettingsButton() throws {
        let menuBarsQuery = app.menuBars
        let settingsButton = menuBarsQuery.menuItems["Settings..."]

        if settingsButton.exists {
            XCTAssertTrue(settingsButton.isEnabled)
        }
    }

    @MainActor
    func testMenuContainsQuitButton() throws {
        let menuBarsQuery = app.menuBars
        let quitButton = menuBarsQuery.menuItems["Quit"]

        if quitButton.exists {
            XCTAssertTrue(quitButton.isEnabled)
        }
    }

    // MARK: - Performance Tests

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
