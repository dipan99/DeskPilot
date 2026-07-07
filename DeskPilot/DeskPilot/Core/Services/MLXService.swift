//
//  MLXService.swift
//  DeskPilot
//

import Foundation
import os

private let logger = Logger(subsystem: "com.dipanbag.DeskPilot", category: "MLXService")

// MARK: - MLX Service

struct MLXService: ChatServing {

    /// Send a conversation (array of messages) to the model, optionally with tool definitions.
    /// Returns the raw ChatResponseMessage so the caller can check for tool_calls.
    func send(messages: [ChatMessage], tools: [ToolDefinition]? = nil) async throws -> ChatResponseMessage {
        let settings = AppSettings.current

        guard let url = URL(string: settings.modelEndpoint) else {
            throw MLXError.invalidURL
        }

        let chatRequest = ChatRequest(
            model: settings.modelName,
            messages: messages,
            tools: tools,
            maxTokens: settings.maxTokens
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(chatRequest)

        // Log the outgoing request body
        if let requestBody = request.httpBody, let requestStr = String(data: requestBody, encoding: .utf8) {
            logger.debug("Request JSON: \(requestStr)")
        }

        let (data, _) = try await URLSession.shared.data(for: request)

        // Log the raw response from the server
        if let rawResponse = String(data: data, encoding: .utf8) {
            logger.debug("Raw response: \(rawResponse)")
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)

        guard let responseMessage = chatResponse.choices.first?.message else {
            throw MLXError.noResponse
        }

        return responseMessage
    }

    /// Simple convenience method for sending a single user message (no tools).
    func sendMessage(_ userMessage: String) async throws -> String {
        let messages = [
            ChatMessage(role: "system", content: Prompts.system),
            ChatMessage(role: "user", content: userMessage)
        ]

        let response = try await send(messages: messages)
        guard let content = response.content else {
            throw MLXError.noResponse
        }
        return content
    }
}

// MARK: - Errors

enum MLXError: Error, LocalizedError {
    case invalidURL
    case noResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL."
        case .noResponse: return "No response from the model."
        }
    }
}
