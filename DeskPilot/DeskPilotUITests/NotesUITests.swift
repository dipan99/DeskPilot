//
//  NotesUITests.swift
//  DeskPilotUITests
//

import XCTest

final class NotesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNotesSectionOpens() throws {
        let app = XCTContext.runActivity(named: "Launch DeskPilot") { _ in
            launchDeskPilot(resetState: true)
        }

        XCTContext.runActivity(named: "Open Notes section") { _ in
            openNotesSection(in: app)
        }

        XCTContext.runActivity(named: "Verify Notes screen controls") { _ in
            app.staticTexts["Notes_title"].assertExists()
            app.buttons["newNoteButton"].assertExists()
            attachScreenshot(named: "Notes Section", app: app)
        }
    }

    @MainActor
    func testCanCreateNoteWithTitleAndContent() throws {
        let app = XCTContext.runActivity(named: "Launch DeskPilot") { _ in
            launchDeskPilot(resetState: true)
        }
        let uniqueSuffix = UUID().uuidString.prefix(8)
        let title = "UI Test Note \(uniqueSuffix)"
        let content = "This note was created by a UI test with a title and content."

        XCTContext.runActivity(named: "Open Notes section") { _ in
            openNotesSection(in: app)
        }

        XCTContext.runActivity(named: "Create note with title and content") { _ in
            createNote(in: app, title: title, content: content)
        }

        XCTContext.runActivity(named: "Verify created note appears") { _ in
            noteTitle(title, in: app).assertExists()
            attachScreenshot(named: "Created Note With Title", app: app)
        }
    }

    @MainActor
    func testCanCreateNoteWithoutTitle() throws {
        let app = XCTContext.runActivity(named: "Launch DeskPilot") { _ in
            launchDeskPilot(resetState: true)
        }
        let uniqueSuffix = UUID().uuidString.prefix(8)
        let content = "Derived title note \(uniqueSuffix) first line"

        XCTContext.runActivity(named: "Open Notes section") { _ in
            openNotesSection(in: app)
        }

        XCTContext.runActivity(named: "Create note without title") { _ in
            createNote(in: app, title: nil, content: content)
        }

        XCTContext.runActivity(named: "Verify title is derived from content") { _ in
            noteTitle(content, in: app).assertExists()
            attachScreenshot(named: "Created Note Without Title", app: app)
        }
    }
    
    @MainActor
    func testCanOpenAndEditExistingNote() throws {
        let app = XCTContext.runActivity(named: "Launch DeskPilot") { _ in
            launchDeskPilot(resetState: true)
        }
        let uniqueSuffix = UUID().uuidString.prefix(8)
        let title = "UI Test Note \(uniqueSuffix) To Be Edited"
        let content = "This note was created by a UI test with a title and content. This is before Edit."
        
        let newTitle = title + " Edited"
        let newContent = content + " Edited"
        
        XCTContext.runActivity(named: "Open Notes section") { _ in
            openNotesSection(in: app)
        }
        
        XCTContext.runActivity(named: "Create note which will be edited later") { _ in
            createNote(in: app, title: title, content: content)
        }
        
        XCTContext.runActivity(named: "Verify created note exists") { _ in
            noteTitle(title, in: app).assertExists()
        }
        
        XCTContext.runActivity(named: "Open existing note") { _ in
            openNote(title, in: app)
        }
        
        XCTContext.runActivity(named: "Verify Edit Note Text shows up") { _ in
            app.staticTexts["Edit Note"].assertExists()
        }
        
        XCTContext.runActivity(named: "Verify existing title & content show up") { _ in
            XCTAssertEqual(app.textFields["noteTitleField"].value as? String, title)
            XCTAssertTrue((app.textViews["noteContentEditor"].value as? String)?.contains(content) == true)
        }
        
        XCTContext.runActivity(named: "Edit title & content") { _ in
            editNote(newTitle, newContent, in: app)
        }

        XCTContext.runActivity(named: "Verify note title & content have been edited") { _ in
            openNote(newTitle, in: app)
            app.staticTexts["Edit Note"].assertExists()
            XCTAssertEqual(app.textFields["noteTitleField"].value as? String, newTitle)
            XCTAssertTrue((app.textViews["noteContentEditor"].value as? String)?.contains(newContent) == true)
        }
    }

    @MainActor
    private func openNotesSection(in app: XCUIApplication) {
        app.openSidebarSection(.notes)
        app.staticTexts["Notes_title"].assertExists()
    }

    @MainActor
    private func noteTitle(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS %@", title)
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    @MainActor
    private func createNote(in app: XCUIApplication, title: String?, content: String) {
        app.buttons["newNoteButton"].waitAndClick()
        app.staticTexts["New Note"].assertExists()

        if let title {
            app.textFields["noteTitleField"].waitAndTypeText(title)
        }

        app.textViews["noteContentEditor"].waitAndTypeText(content)
        XCTAssertTrue(
            app.buttons["noteSaveButton"].isEnabled,
            "Expected Save to be enabled after entering note text."
        )
        app.buttons["noteSaveButton"].waitAndClick()
        XCTAssertTrue(
            app.staticTexts["New Note"].waitForNonExistence(timeout: 5),
            "Expected note editor to close after saving."
        )
    }
    
    @MainActor
    private func openNote(_ title: String, in app: XCUIApplication) {
        noteTitle(title, in: app).waitAndClick()
    }
    
    @MainActor
    private func editNote(_ newTitle: String, _ newContent: String, in app: XCUIApplication) {
        let titleField = app.textFields["noteTitleField"]
        titleField.waitAndClick()
        titleField.typeKey("a", modifierFlags: .command)
        titleField.typeText(newTitle)

        let contentEditor = app.textViews["noteContentEditor"]
        contentEditor.waitAndClick()
        contentEditor.typeKey("a", modifierFlags: .command)
        contentEditor.typeText(newContent)
        
        XCTAssertTrue(
            app.buttons["noteSaveButton"].isEnabled,
            "Expected Save to be enabled after entering note text."
        )
        app.buttons["noteSaveButton"].waitAndClick()
        XCTAssertTrue(
            app.staticTexts["Edit Note"].waitForNonExistence(timeout: 5),
            "Expected note editor to close after saving."
        )

    }
}
