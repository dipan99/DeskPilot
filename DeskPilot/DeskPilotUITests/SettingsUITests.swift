//
//  SettingsUITests.swift
//  DeskPilotUITests
//

import XCTest

final class SettingsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "RESET_APP_STATE"]
        app.launch()
        app.terminate()
    }

    @MainActor
    func testSettingsSectionOpens() throws {
        let app = XCTContext.runActivity(named: "Launch DeskPilot") { _ in
            launchDeskPilot(resetState: true)
        }

        XCTContext.runActivity(named: "Open Settings section") { _ in
            app.openSidebarSection(.settings)
            app.staticTexts["Settings_title"].assertExists()
            app.textFields["settingsUserNameField"].assertExists()
            app.textFields["settingsUserLocationField"].assertExists()
        }
    }

    @MainActor
    func testCanUpdatePersonalSettingsAndReturnToThem() throws {
        let app = XCTContext.runActivity(named: "Launch DeskPilot") { _ in
            launchDeskPilot(resetState: true)
        }
        let uniqueSuffix = UUID().uuidString.prefix(6)
        let name = "UI User \(uniqueSuffix)"
        let location = "Minneapolis \(uniqueSuffix)"

        XCTContext.runActivity(named: "Open Settings section") { _ in
            app.openSidebarSection(.settings)
            app.staticTexts["Settings_title"].assertExists()
        }

        XCTContext.runActivity(named: "Update profile settings") { _ in
            let nameField = app.textFields["settingsUserNameField"]
            let locationField = app.textFields["settingsUserLocationField"]

            replaceText(in: nameField, with: name)
            replaceText(in: locationField, with: location)
        }

        XCTContext.runActivity(named: "Navigate away and return to Settings") { _ in
            app.openSidebarSection(.dashboard)
            app.staticTexts["Dashboard_title"].assertExists()

            app.openSidebarSection(.settings)
            app.staticTexts["Settings_title"].assertExists()
        }

        XCTContext.runActivity(named: "Verify profile settings persisted in UI") { _ in
            XCTAssertEqual(app.textFields["settingsUserNameField"].value as? String, name)
            XCTAssertEqual(app.textFields["settingsUserLocationField"].value as? String, location)
            attachScreenshot(named: "Settings Updated", app: app)
        }
    }

    @MainActor
    private func replaceText(in field: XCUIElement, with text: String) {
        field.waitAndClick()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(text)
    }
}
