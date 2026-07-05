//
//  AssistantCoordinator.swift
//  DeskPilot
//

import Foundation
import os

private let logger = Logger(subsystem: "com.dipanbag.DeskPilot", category: "AssistantCoordinator")

// MARK: - Response type

struct AssistantResponse {
    let text: String
    let toolTrace: String?
}

// MARK: - Coordinator

struct AssistantCoordinator {
    private let registry: ToolRegistry
    private let mlxService: MLXService

    init(registry: ToolRegistry, mlxService: MLXService) {
        self.registry = registry
        self.mlxService = mlxService
    }

    func handleMessage(_ userMessage: String, conversationHistory: [ChatBubbleMessage]) async -> AssistantResponse {
        // Build the conversation with memory
        var messages: [ChatMessage] = [
            ChatMessage(role: "system", content: Prompts.system)
        ]

        // Include the last N messages from conversation history
        let memoryCount = Constants.MLX.conversationMemory
        let recentHistory = conversationHistory.suffix(memoryCount)
        for pastMessage in recentHistory {
            let role = pastMessage.role == .user ? "user" : "assistant"
            messages.append(ChatMessage(role: role, content: pastMessage.content))
        }

        // Add the current user message
        messages.append(ChatMessage(role: "user", content: userMessage))

        let toolDefinitions = registry.toolDefinitions()
        var toolTrace: String? = nil

        logger.debug("Sending message to MLX with \(toolDefinitions.count) tool(s)")

        do {
            // Send to model with tool definitions
            let response = try await mlxService.send(
                messages: messages,
                tools: toolDefinitions.isEmpty ? nil : toolDefinitions
            )

            logger.debug("Model response — content: \(response.content ?? "nil"), toolCalls: \(response.toolCalls?.count ?? 0)")

            // Check if the model wants to call a tool
            if let toolCalls = response.toolCalls, let firstCall = toolCalls.first {
                logger.debug("Tool call: \(firstCall.function.name), arguments: \(firstCall.function.arguments)")

                // Look up the tool
                guard let tool = registry.tool(named: firstCall.function.name) else {
                    logger.error("Unknown tool requested: \(firstCall.function.name)")
                    return AssistantResponse(
                        text: "Unknown tool: \(firstCall.function.name)",
                        toolTrace: nil
                    )
                }

                // Execute the tool
                let result = await tool.execute(arguments: firstCall.function.arguments)
                toolTrace = result.toolName
                logger.debug("Tool result: \(result.output)")

                // Append the assistant's tool call message and the tool result
                messages.append(ChatMessage(
                    role: "assistant",
                    content: response.content ?? ""
                ))
                messages.append(ChatMessage(
                    toolResult: result.output,
                    toolCallId: firstCall.id
                ))

                // Send back to model so it can write a natural response
                let finalResponse = try await mlxService.send(messages: messages)
                let text = (finalResponse.content ?? result.output).trimmingCharacters(in: .whitespacesAndNewlines)
                logger.debug("Final response: \(text)")

                return AssistantResponse(text: text, toolTrace: toolTrace)
            }

            // No tool call — just a regular reply
            let text = (response.content ?? "I'm not sure how to help with that.").trimmingCharacters(in: .whitespacesAndNewlines)
            logger.debug("No tool call, direct reply")
            return AssistantResponse(text: text, toolTrace: nil)

        } catch {
            logger.error("MLX request failed: \(error.localizedDescription)")
            // MLX server is down — return a fallback message
            return AssistantResponse(
                text: "The assistant is offline. Please check the MLX server.",
                toolTrace: nil
            )
        }
    }
}
