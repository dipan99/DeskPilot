//
//  ChatServing.swift
//  DeskPilot
//

import Foundation

protocol ChatServing {
    func send(messages: [ChatMessage], tools: [ToolDefinition]?) async throws -> ChatResponseMessage
}

extension ChatServing {
    func send(messages: [ChatMessage]) async throws -> ChatResponseMessage {
        try await send(messages: messages, tools: nil)
    }
}
