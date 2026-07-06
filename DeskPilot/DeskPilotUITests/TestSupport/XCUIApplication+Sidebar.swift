//
//  XCUIApplication+Sidebar.swift
//  DeskPilotUITests
//

import XCTest

extension XCUIApplication {
    @MainActor
    func openSidebarSection(_ section: SidebarSection, timeout: TimeInterval = 5) {
        let identifier = "sidebar_\(section.rawValue)"
        let row = cells.containing(.staticText, identifier: identifier).element
        let label = staticTexts[identifier]
        let element = row.exists ? row : label

        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Expected sidebar section '\(section.rawValue)' to exist."
        )

        element.click()
    }
}

enum SidebarSection: String, CaseIterable {
    case dashboard = "Dashboard"
    case assistant = "Assistant"
    case files = "Files"
    case calendar = "Calendar"
    case tasks = "Tasks"
    case notes = "Notes"
    case settings = "Settings"
    case weather = "Weather"
}
