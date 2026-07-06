//
//  RealAIEvaluationUITests.swift
//  DeskPilotUITests
//

import XCTest

final class RealAIEvaluationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRealAssistantCanRetrieveSeededNoteFact() throws {
        try skipUnlessRealAIEvaluationsEnabled()

        let app = XCTContext.runActivity(named: "Launch DeskPilot with real assistant") { _ in
            launchDeskPilot()
        }
        let uniqueSuffix = UUID().uuidString.prefix(8)
        let title = "Real AI Eval Eric Contact \(uniqueSuffix)"
        let expectedFact = "555-1234"
        let content = "Eric's phone number is \(expectedFact). This note was seeded for a real AI evaluation."

        XCTContext.runActivity(named: "Seed note with exact fact") { _ in
            createNote(title: title, content: content, in: app)
            note(containing: title, in: app).assertExists()
        }

        XCTContext.runActivity(named: "Ask real assistant about seeded note") { _ in
            app.openSidebarSection(.assistant)
            app.textFields["assistantInput"].assertExists()
            sendAssistantMessage("Use my notes. What was Eric's phone number?", in: app)
        }

        XCTContext.runActivity(named: "Verify response contains exact fact") { _ in
            assistantResponse(containing: expectedFact, in: app).assertExists(timeout: 120)
            attachScreenshot(named: "Real AI Exact Fact Response", app: app)
        }
    }

    private func skipUnlessRealAIEvaluationsEnabled() throws {
        guard ProcessInfo.processInfo.environment["RUN_REAL_AI_EVALS"] == "1" else {
            throw XCTSkip("Set RUN_REAL_AI_EVALS=1 to run real local-MLX evaluation tests.")
        }
    }

    @MainActor
    private func createNote(title: String, content: String, in app: XCUIApplication) {
        app.openSidebarSection(.notes)
        app.staticTexts["Notes_title"].assertExists()
        app.buttons["newNoteButton"].waitAndClick()
        app.staticTexts["New Note"].assertExists()
        app.textFields["noteTitleField"].waitAndTypeText(title)
        app.textViews["noteContentEditor"].waitAndTypeText(content)
        app.buttons["noteSaveButton"].waitAndClick()
        XCTAssertTrue(
            app.staticTexts["New Note"].waitForNonExistence(timeout: 5),
            "Expected note editor to close after saving."
        )
    }

    @MainActor
    private func sendAssistantMessage(_ message: String, in app: XCUIApplication) {
        app.textFields["assistantInput"].waitAndTypeText(message)
        XCTAssertTrue(
            app.buttons["assistantSendButton"].isEnabled,
            "Expected Send to be enabled after entering an assistant message."
        )
        app.buttons["assistantSendButton"].waitAndClick()
    }

    @MainActor
    private func note(containing text: String, in app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)
        return app.descendants(matching: .any).matching(predicate).firstMatch
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
}
