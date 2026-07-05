//
//  Tool.swift
//  DeskPilot
//

import Foundation

// MARK: - Tool Protocol

protocol Tool {
    /// Stable identifier used in API calls (e.g. "get_calendar_events")
    var name: String { get }

    /// Human-readable name for tool trace display (e.g. "Calendar")
    var displayName: String { get }

    /// Description sent to the model so it knows when to use this tool
    var description: String { get }

    /// JSON schema for the tool's parameters
    var parameters: [String: Any] { get }

    /// Execute the tool and return a result string
    func execute(arguments: String) async -> ToolResult
}

// MARK: - Tool Result

struct ToolResult {
    let toolName: String
    let output: String
}
