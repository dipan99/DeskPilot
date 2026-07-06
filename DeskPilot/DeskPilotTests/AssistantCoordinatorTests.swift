//
//  AssistantCoordinatorTests.swift
//  DeskPilotTests
//

import XCTest
@testable import DeskPilot

@MainActor
final class AssistantCoordinatorTests: XCTestCase {
    func testCoordinatorExecutesToolCallAndReturnsFinalResponse() async {
        let tool = SpyNotesTool(output: #"[{"title":"Eric contact","content":"Eric's phone number is 555-1234."}]"#)
        let chatService = ScriptedChatService(responses: [
            ChatResponseMessage(
                content: nil,
                toolCalls: [
                    ToolCall(
                        id: "call_notes_1",
                        type: "function",
                        function: ToolCallFunction(
                            name: "search_notes",
                            arguments: #"{"query":"Eric phone number"}"#
                        )
                    )
                ]
            ),
            ChatResponseMessage(content: "Eric's phone number is 555-1234.", toolCalls: nil)
        ])
        let coordinator = AssistantCoordinator(
            registry: ToolRegistry(tools: [tool]),
            chatService: chatService
        )

        let response = await coordinator.handleMessage(
            "What was Eric's phone number?",
            conversationHistory: []
        )

        XCTAssertEqual(response.text, "Eric's phone number is 555-1234.")
        XCTAssertEqual(response.toolTrace, "Notes")
        XCTAssertEqual(tool.receivedArguments, #"{"query":"Eric phone number"}"#)
        XCTAssertEqual(chatService.requests.count, 2)
        XCTAssertEqual(chatService.requests[0].tools?.first?.function.name, "search_notes")
        XCTAssertTrue(chatService.requests[1].messages.contains { message in
            message.role == "tool" &&
            message.toolCallId == "call_notes_1" &&
            (message.content?.contains("555-1234") == true)
        })
    }

    func testCoordinatorReturnsDirectResponseWithoutToolCall() async {
        let chatService = ScriptedChatService(responses: [
            ChatResponseMessage(content: "I can help with that.", toolCalls: nil)
        ])
        let coordinator = AssistantCoordinator(
            registry: ToolRegistry(tools: [SpyNotesTool(output: "[]")]),
            chatService: chatService
        )

        let response = await coordinator.handleMessage("Hello", conversationHistory: [])

        XCTAssertEqual(response.text, "I can help with that.")
        XCTAssertNil(response.toolTrace)
        XCTAssertEqual(chatService.requests.count, 1)
        XCTAssertEqual(chatService.requests[0].messages.last?.role, "user")
        XCTAssertEqual(chatService.requests[0].messages.last?.content, "Hello")
    }

    func testCoordinatorReturnsUnknownToolMessage() async {
        let chatService = ScriptedChatService(responses: [
            ChatResponseMessage(
                content: nil,
                toolCalls: [
                    ToolCall(
                        id: "call_unknown_1",
                        type: "function",
                        function: ToolCallFunction(
                            name: "unknown_tool",
                            arguments: "{}"
                        )
                    )
                ]
            )
        ])
        let coordinator = AssistantCoordinator(
            registry: ToolRegistry(tools: [SpyNotesTool(output: "[]")]),
            chatService: chatService
        )

        let response = await coordinator.handleMessage("Use a missing tool", conversationHistory: [])

        XCTAssertEqual(response.text, "Unknown tool: unknown_tool")
        XCTAssertNil(response.toolTrace)
        XCTAssertEqual(chatService.requests.count, 1)
    }
}

@MainActor
private final class ScriptedChatService: ChatServing {
    struct Request {
        let messages: [ChatMessage]
        let tools: [ToolDefinition]?
    }

    private var responses: [ChatResponseMessage]
    private(set) var requests: [Request] = []

    init(responses: [ChatResponseMessage]) {
        self.responses = responses
    }

    func send(messages: [ChatMessage], tools: [ToolDefinition]?) async throws -> ChatResponseMessage {
        requests.append(Request(messages: messages, tools: tools))
        guard !responses.isEmpty else {
            throw ScriptedChatServiceError.noResponse
        }

        return responses.removeFirst()
    }
}

private enum ScriptedChatServiceError: Error {
    case noResponse
}

@MainActor
private final class SpyNotesTool: Tool {
    let name = "search_notes"
    let displayName = "Notes"
    let description = "Search notes"
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "query": ["type": "string"]
        ],
        "required": ["query"]
    ]

    private let output: String
    private(set) var receivedArguments: String?

    init(output: String) {
        self.output = output
    }

    func execute(arguments: String) async -> ToolResult {
        receivedArguments = arguments
        return ToolResult(toolName: displayName, output: output)
    }
}
