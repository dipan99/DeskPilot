//
//  DeskPilotUITests.swift
//  DeskPilotUITests
//
//  Created by Dipan Bag on 7/5/26.
//

import XCTest

final class DeskPilotUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    @MainActor
    func testAppLaunchesToDashboard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Dashboard_title"].waitForExistence(timeout: 5))
    }
    
    @MainActor
    func testAssistantRespondsToMeetingQuestion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()

        app.buttons["sidebar_Assistant"].click()

        let input = app.textFields["assistantInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))

        input.click()
        input.typeText("What meetings do I have today?")

        app.buttons["assistantSendButton"].click()

        let response = app.staticTexts["assistantResponse"]
        XCTAssertTrue(response.waitForExistence(timeout: 5))
        XCTAssertTrue(response.label.contains("2 meetings today"))

        let toolTrace = app.staticTexts["assistantToolTrace"]
        XCTAssertTrue(toolTrace.label.contains("MockCalendarService"))
    }

//    @MainActor
//    func testExample() throws {
//        // UI tests must launch the application that they test.
//        let app = XCUIApplication()
//        app.launch()
//
//        // Use XCTAssert and related functions to verify your tests produce the correct results.
//        // XCUIAutomation Documentation
//        // https://developer.apple.com/documentation/xcuiautomation
//    }
//
//    @MainActor
//    func testLaunchPerformance() throws {
//        // This measures how long it takes to launch your application.
//        measure(metrics: [XCTApplicationLaunchMetric()]) {
//            XCUIApplication().launch()
//        }
//    }
}
