//
//  ToolRegistry.swift
//  DeskPilot
//

import Foundation

struct ToolRegistry {
    private let tools: [Tool]

    init(tools: [Tool]) {
        self.tools = tools
    }

    /// Convert all registered tools to API-compatible definitions
    func toolDefinitions() -> [ToolDefinition] {
        tools.map { tool in
            ToolDefinition(
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters
            )
        }
    }

    /// Look up a tool by name (used when the model returns a tool call)
    func tool(named name: String) -> Tool? {
        tools.first { $0.name == name }
    }
}
