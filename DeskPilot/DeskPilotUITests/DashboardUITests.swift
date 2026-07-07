//
//  DashboardUITests.swift
//  DeskPilotUITests
//

import XCTest

final class DashboardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDashboardRefreshButtonAndSummaryExist() throws {
        let app = XCTContext.runActivity(named: "Launch DeskPilot") { _ in
            launchDeskPilot(resetState: true)
        }

        XCTContext.runActivity(named: "Verify Dashboard summary and refresh controls") { _ in
            app.staticTexts["Dashboard_title"].assertExists()
            app.buttons["dashboardRefreshButton"].assertExists()
            dashboardSummary(in: app).assertExists()
        }

        XCTContext.runActivity(named: "Refresh Dashboard") { _ in
            app.buttons["dashboardRefreshButton"].waitAndClick(timeout: 10)
            dashboardSummary(in: app).assertExists(timeout: 10)
            attachScreenshot(named: "Dashboard After Refresh", app: app)
        }
    }

    @MainActor
    func testDashboardCardsOpenTheirSections() throws {
        let app = XCTContext.runActivity(named: "Launch DeskPilot") { _ in
            launchDeskPilot(resetState: true)
        }

        let cards: [(buttonIdentifier: String, expectedTitleIdentifier: String, sectionName: String)] = [
            ("dashboardOpenNotesButton", "Notes_title", "Notes"),
            ("dashboardOpenCalendarButton", "Calendar_title", "Calendar"),
            ("dashboardOpenTasksButton", "Tasks_title", "Tasks"),
            ("dashboardOpenFilesButton", "Files_title", "Files")
        ]

        app.staticTexts["Dashboard_title"].assertExists()

        for card in cards {
            XCTContext.runActivity(named: "Open \(card.sectionName) from Dashboard") { _ in
                let button = app.buttons[card.buttonIdentifier]
                scrollToElement(button, in: app)
                button.waitAndClick(timeout: 10)
                app.staticTexts[card.expectedTitleIdentifier].assertExists(timeout: 10)
            }

            XCTContext.runActivity(named: "Return to Dashboard") { _ in
                app.openSidebarSection(.dashboard)
                app.staticTexts["Dashboard_title"].assertExists()
            }
        }
    }

    @MainActor
    private func dashboardSummary(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["dashboardAISummary"]
    }

    @MainActor
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollView = app.scrollViews["dashboardScrollView"]
        scrollView.assertExists()

        for _ in 0..<6 where !element.isHittable {
            scrollView.swipeUp()
        }
    }
}
