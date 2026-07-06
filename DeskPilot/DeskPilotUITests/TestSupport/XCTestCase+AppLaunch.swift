//
//  XCTestCase+AppLaunch.swift
//  DeskPilotUITests
//

import XCTest

extension XCTestCase {
    @MainActor
    func launchDeskPilot(
        resetState: Bool = false,
        additionalArguments: [String] = [],
        additionalEnvironment: [String: String] = [:]
    ) -> XCUIApplication {
        let app = XCUIApplication()

        var launchArguments = ["UI_TESTING"]
        if resetState {
            launchArguments.append("RESET_APP_STATE")
        }
        launchArguments.append(contentsOf: additionalArguments)

        app.launchArguments = launchArguments
        app.launchEnvironment = additionalEnvironment
        app.launch()

        return app
    }
}
