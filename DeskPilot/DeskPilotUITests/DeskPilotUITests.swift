//
//  DeskPilotUITests.swift
//  DeskPilotUITests
//
//  Created by Dipan Bag on 7/5/26.
//

import XCTest

final class DeskPilotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesToDashboard() throws {
        let app = launchDeskPilot()

        app.staticTexts["Dashboard_title"].assertExists()
    }
}
