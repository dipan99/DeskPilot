//
//  NotesToolTests.swift
//  DeskPilotTests
//

import XCTest
@testable import DeskPilot

@MainActor
final class NotesToolTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeskPilotTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    func testSearchNotesFindsRelevantPhoneNumber() async throws {
        let tool = try await makeTool(notes: [
            DeskNote(title: "Eric contact", content: "Eric's phone number is 555-1234."),
            DeskNote(title: "Lunch ideas", content: "Try the ramen place near the office.")
        ])

        let result = await tool.execute(arguments: #"{"query":"Eric phone number"}"#)

        XCTAssertEqual(result.toolName, "Notes")
        XCTAssertTrue(result.output.contains("Eric contact"))
        XCTAssertTrue(result.output.contains("555-1234"))
        XCTAssertFalse(result.output.contains("Lunch ideas"))

        let matches = try decodeMatches(from: result.output)
        XCTAssertEqual(matches.first?["title"] as? String, "Eric contact")
        XCTAssertNotNil(matches.first?["snippet"])
        XCTAssertNotNil(matches.first?["lexical_score"])
        XCTAssertNotNil(matches.first?["semantic_score"])
        XCTAssertNotNil(matches.first?["relevance_score"])
        XCTAssertEqual(matches.first?["matched_terms"] as? [String], ["eric", "number", "phone"])
    }

    func testSearchNotesReturnsNoMatchesMessage() async throws {
        let tool = try await makeTool(notes: [
            DeskNote(title: "Eric contact", content: "Eric's phone number is 555-1234.")
        ])

        let result = await tool.execute(arguments: #"{"query":"quarterly budget"}"#)

        XCTAssertEqual(result.toolName, "Notes")
        XCTAssertTrue(result.output.contains("No saved notes matched 'quarterly budget'."))
    }

    func testSearchNotesRespectsMaxResults() async throws {
        let tool = try await makeTool(notes: [
            DeskNote(title: "Project Alpha", content: "Alpha planning notes."),
            DeskNote(title: "Project Beta", content: "Beta planning notes."),
            DeskNote(title: "Project Gamma", content: "Gamma planning notes.")
        ])

        let result = await tool.execute(arguments: #"{"query":"project planning","max_results":2}"#)
        let matches = try decodeMatches(from: result.output)

        XCTAssertEqual(matches.count, 2)
    }

    func testSearchNotesUsesVectorSimilarityForRelatedWordForms() async throws {
        let tool = try await makeTool(notes: [
            DeskNote(title: "Running plan", content: "Morning runs should include hill intervals."),
            DeskNote(title: "Recipe", content: "Add basil and tomatoes to the sauce.")
        ])

        let result = await tool.execute(arguments: #"{"query":"run interval"}"#)
        let matches = try decodeMatches(from: result.output)

        XCTAssertEqual(matches.first?["title"] as? String, "Running plan")
        XCTAssertTrue((matches.first?["semantic_score"] as? Double ?? 0) > 0)
        XCTAssertFalse(result.output.contains("Recipe"))
    }

    func testSearchNotesHandlesEmptyNotesStore() async throws {
        let tool = try await makeTool(notes: [])

        let result = await tool.execute(arguments: #"{"query":"Eric"}"#)

        XCTAssertEqual(result.toolName, "Notes")
        XCTAssertEqual(result.output, "No notes have been saved yet.")
    }

    private func makeTool(notes: [DeskNote]) async throws -> NotesTool {
        let notesURL = temporaryDirectory.appendingPathComponent("notes.json")
        let store = NotesStore(notesURL: notesURL)
        try await store.saveNotes(notes)
        return NotesTool(store: store)
    }

    private func decodeMatches(from output: String) throws -> [[String: Any]] {
        let data = try XCTUnwrap(output.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }
}
