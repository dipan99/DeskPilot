//
//  XCUIElement+Waiting.swift
//  DeskPilotUITests
//

import XCTest

extension XCUIElement {
    @MainActor
    func waitAndClick(timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            waitForExistence(timeout: timeout),
            "Expected element to exist before clicking: \(self)",
            file: file,
            line: line
        )
        click()
    }

    @MainActor
    func waitAndTypeText(_ text: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        waitAndClick(timeout: timeout, file: file, line: line)
        typeText(text)
    }

    @MainActor
    func assertExists(timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            waitForExistence(timeout: timeout),
            "Expected element to exist: \(self)",
            file: file,
            line: line
        )
    }
}
