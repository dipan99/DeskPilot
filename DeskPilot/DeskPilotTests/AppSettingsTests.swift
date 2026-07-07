//
//  AppSettingsTests.swift
//  DeskPilotTests
//

import XCTest
@testable import DeskPilot

final class AppSettingsTests: XCTestCase {
    private var originalValues: [String: Any?] = [:]

    override func setUpWithError() throws {
        originalValues = AppSettings.Keys.all.map { key in
            (key, UserDefaults.standard.object(forKey: key))
        }.reduce(into: [:]) { values, pair in
            values[pair.0] = pair.1
        }
        AppSettings.reset()
    }

    override func tearDownWithError() throws {
        AppSettings.reset()
        for (key, value) in originalValues {
            if let value {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
        originalValues = [:]
    }

    func testCurrentUsesDefaultsWhenNoSettingsAreSaved() {
        let settings = AppSettings.current

        XCTAssertEqual(settings.userName, AppSettings.Defaults.userName)
        XCTAssertEqual(settings.userLocation, AppSettings.Defaults.userLocation)
        XCTAssertEqual(settings.modelEndpoint, AppSettings.Defaults.modelEndpoint)
        XCTAssertEqual(settings.modelName, AppSettings.Defaults.modelName)
        XCTAssertEqual(settings.maxTokens, AppSettings.Defaults.maxTokens)
        XCTAssertEqual(settings.conversationMemory, AppSettings.Defaults.conversationMemory)
        XCTAssertEqual(settings.responseStyle, .concise)
    }

    func testCurrentTrimsAndLoadsSavedSettings() {
        UserDefaults.standard.set("  Dipan  ", forKey: AppSettings.Keys.userName)
        UserDefaults.standard.set("  Minneapolis  ", forKey: AppSettings.Keys.userLocation)
        UserDefaults.standard.set("  http://localhost:9000  ", forKey: AppSettings.Keys.modelEndpoint)
        UserDefaults.standard.set("  custom-model  ", forKey: AppSettings.Keys.modelName)
        UserDefaults.standard.set(2048, forKey: AppSettings.Keys.maxTokens)
        UserDefaults.standard.set(12, forKey: AppSettings.Keys.conversationMemory)
        UserDefaults.standard.set(AppSettings.ResponseStyle.detailed.rawValue, forKey: AppSettings.Keys.responseStyle)

        let settings = AppSettings.current

        XCTAssertEqual(settings.userName, "Dipan")
        XCTAssertEqual(settings.userLocation, "Minneapolis")
        XCTAssertEqual(settings.modelEndpoint, "http://localhost:9000")
        XCTAssertEqual(settings.modelName, "custom-model")
        XCTAssertEqual(settings.maxTokens, 2048)
        XCTAssertEqual(settings.conversationMemory, 12)
        XCTAssertEqual(settings.responseStyle, .detailed)
    }

    func testCurrentClampsNumericSettingsAndFallsBackForInvalidStrings() {
        UserDefaults.standard.set("   ", forKey: AppSettings.Keys.modelEndpoint)
        UserDefaults.standard.set("   ", forKey: AppSettings.Keys.modelName)
        UserDefaults.standard.set(99, forKey: AppSettings.Keys.maxTokens)
        UserDefaults.standard.set(99, forKey: AppSettings.Keys.conversationMemory)
        UserDefaults.standard.set("verbose", forKey: AppSettings.Keys.responseStyle)

        let settings = AppSettings.current

        XCTAssertEqual(settings.modelEndpoint, AppSettings.Defaults.modelEndpoint)
        XCTAssertEqual(settings.modelName, AppSettings.Defaults.modelName)
        XCTAssertEqual(settings.maxTokens, 256)
        XCTAssertEqual(settings.conversationMemory, 30)
        XCTAssertEqual(settings.responseStyle, .concise)
    }

    func testResetRemovesSavedSettings() {
        UserDefaults.standard.set("Dipan", forKey: AppSettings.Keys.userName)
        UserDefaults.standard.set(2048, forKey: AppSettings.Keys.maxTokens)

        AppSettings.reset()

        let settings = AppSettings.current
        XCTAssertEqual(settings.userName, AppSettings.Defaults.userName)
        XCTAssertEqual(settings.userLocation, AppSettings.Defaults.userLocation)
        XCTAssertEqual(settings.modelEndpoint, AppSettings.Defaults.modelEndpoint)
        XCTAssertEqual(settings.modelName, AppSettings.Defaults.modelName)
        XCTAssertEqual(settings.maxTokens, AppSettings.Defaults.maxTokens)
        XCTAssertEqual(settings.conversationMemory, AppSettings.Defaults.conversationMemory)
        XCTAssertEqual(settings.responseStyle, .concise)
    }
}

private extension AppSettings.Keys {
    static var all: [String] {
        [
            userName,
            userLocation,
            modelEndpoint,
            modelName,
            maxTokens,
            conversationMemory,
            responseStyle
        ]
    }
}
