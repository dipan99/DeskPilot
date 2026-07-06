//
//  AssistantUITests.swift
//  DeskPilotUITests
//

import XCTest

final class AssistantUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAssistantUsesMockedNotesToolResponse() throws {
        let app = XCTContext.runActivity(named: "Launch DeskPilot with mocked assistant") { _ in
            launchDeskPilot(additionalArguments: ["USE_MOCK_ASSISTANT"])
        }

        XCTContext.runActivity(named: "Open Assistant section") { _ in
            openAssistantSection(in: app)
        }

        XCTContext.runActivity(named: "Ask assistant about saved note detail") { _ in
            sendAssistantMessage("What was Eric's phone number?", in: app)
        }

        XCTContext.runActivity(named: "Verify mocked assistant response") { _ in
            assistantResponse(containing: "555-1234", in: app).assertExists(timeout: 10)
            app.staticTexts["assistantToolTrace"].assertExists()
            let toolTraceText = app.staticTexts["assistantToolTrace"]
            let toolTraceValue = toolTraceText.value as? String ?? ""
            XCTAssertTrue(toolTraceText.label.contains("Notes") || toolTraceValue.contains("Notes"))
            attachScreenshot(named: "Mocked Assistant Notes Response", app: app)
        }
    }

    @MainActor
    func testAssistantChatPersistsWhenSwitchingSections() throws {
        let app = XCTContext.runActivity(named: "Launch DeskPilot with mocked assistant") { _ in
            launchDeskPilot(additionalArguments: ["USE_MOCK_ASSISTANT"])
        }
        let message = "What was Eric's phone number?"

        XCTContext.runActivity(named: "Send assistant message") { _ in
            openAssistantSection(in: app)
            sendAssistantMessage(message, in: app)
            assistantResponse(containing: "555-1234", in: app).assertExists(timeout: 10)
        }

        XCTContext.runActivity(named: "Switch away from Assistant") { _ in
            app.openSidebarSection(.notes)
            app.staticTexts["Notes_title"].assertExists()
        }

        XCTContext.runActivity(named: "Return to Assistant and verify chat remains") { _ in
            app.openSidebarSection(.assistant)
            assistantBubble(containing: "phone number", in: app).assertExists()
            assistantResponse(containing: "555-1234", in: app).assertExists()
            attachScreenshot(named: "Assistant Chat Persisted", app: app)
        }
    }

    @MainActor
    private func openAssistantSection(in app: XCUIApplication) {
        app.openSidebarSection(.assistant)
        app.textFields["assistantInput"].assertExists()
    }

    @MainActor
    private func sendAssistantMessage(_ message: String, in app: XCUIApplication) {
        app.textFields["assistantInput"].waitAndTypeText(message)
        XCTAssertTrue(
            app.buttons["assistantSendButton"].isEnabled,
            "Expected Send to be enabled after entering an assistant message."
        )
        app.buttons["assistantSendButton"].waitAndClick()
        assistantBubble(containing: "phone number", in: app).assertExists()
    }

    @MainActor
    private func assistantResponse(containing text: String, in app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)",
            "assistantResponse",
            text,
            text
        )
        return app.staticTexts.matching(predicate).firstMatch
    }

    @MainActor
    private func assistantBubble(containing text: String, in app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)",
            "userBubble",
            text,
            text
        )
        return app.staticTexts.matching(predicate).firstMatch
    }
}
