//
//  ToolRegistryTests.swift
//  DeskPilotTests
//

import XCTest
@testable import DeskPilot

final class ToolRegistryTests: XCTestCase {
    func testToolDefinitionsExposeRegisteredTools() {
        let registry = ToolRegistry(tools: [
            StubTool(name: "alpha", displayName: "Alpha", description: "Alpha tool"),
            StubTool(name: "beta", displayName: "Beta", description: "Beta tool")
        ])

        let definitions = registry.toolDefinitions()

        XCTAssertEqual(definitions.map(\.function.name), ["alpha", "beta"])
        XCTAssertEqual(definitions.map(\.function.description), ["Alpha tool", "Beta tool"])
    }

    func testToolNamedReturnsMatchingTool() {
        let registry = ToolRegistry(tools: [
            StubTool(name: "alpha", displayName: "Alpha", description: "Alpha tool"),
            StubTool(name: "beta", displayName: "Beta", description: "Beta tool")
        ])

        let tool = registry.tool(named: "beta")

        XCTAssertEqual(tool?.name, "beta")
        XCTAssertEqual(tool?.displayName, "Beta")
    }

    func testToolNamedReturnsNilForUnknownTool() {
        let registry = ToolRegistry(tools: [
            StubTool(name: "alpha", displayName: "Alpha", description: "Alpha tool")
        ])

        XCTAssertNil(registry.tool(named: "missing"))
    }
}

private struct StubTool: Tool {
    let name: String
    let displayName: String
    let description: String
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [:],
        "required": [] as [String]
    ]

    func execute(arguments: String) async -> ToolResult {
        ToolResult(toolName: displayName, output: arguments)
    }
}
