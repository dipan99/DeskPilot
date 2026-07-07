//
//  NavigationUITests.swift
//  DeskPilotUITests
//

import XCTest

final class NavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesToDashboardByDefault() throws {
        let app = XCTContext.runActivity(named: "Launch DeskPilot") { _ in
            launchDeskPilot()
        }

        XCTContext.runActivity(named: "Verify Dashboard is selected by default") { _ in
            app.staticTexts["Dashboard_title"].assertExists()
            attachScreenshot(named: "Default Dashboard", app: app)
        }
    }

    @MainActor
    func testSidebarNavigationShowsEachSection() throws {
        let app = XCTContext.runActivity(named: "Launch DeskPilot") { _ in
            launchDeskPilot()
        }

        let expectations: [(section: SidebarSection, element: XCUIElement)] = [
            (.dashboard, app.staticTexts["Dashboard_title"]),
            (.assistant, app.textFields["assistantInput"]),
            (.files, app.staticTexts["Files_title"]),
            (.calendar, app.staticTexts["Calendar_title"]),
            (.tasks, app.staticTexts["Tasks_title"]),
            (.notes, app.staticTexts["Notes_title"]),
            (.settings, app.staticTexts["Settings_title"])
        ]

        for expectation in expectations {
            XCTContext.runActivity(named: "Navigate to \(expectation.section.rawValue)") { _ in
                app.openSidebarSection(expectation.section)
                expectation.element.assertExists()
            }
        }

        XCTContext.runActivity(named: "Capture final navigation state") { _ in
            attachScreenshot(named: "Final Sidebar Navigation State", app: app)
        }
    }
}
