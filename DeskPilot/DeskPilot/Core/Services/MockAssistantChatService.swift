//
//  MockAssistantChatService.swift
//  DeskPilot
//

import Foundation

final class MockAssistantChatService: ChatServing {
    private var requestCount = 0

    func send(messages: [ChatMessage], tools: [ToolDefinition]?) async throws -> ChatResponseMessage {
        requestCount += 1

        if tools != nil {
            return ChatResponseMessage(
                content: nil,
                toolCalls: [
                    ToolCall(
                        id: "mock_notes_call_1",
                        type: "function",
                        function: ToolCallFunction(
                            name: "search_notes",
                            arguments: #"{"query":"Eric phone number"}"#
                        )
                    )
                ]
            )
        }

        return ChatResponseMessage(
            content: "Eric's phone number is 555-1234.",
            toolCalls: nil
        )
    }
}
