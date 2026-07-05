//
//  ChatModels.swift
//  DeskPilot
//

import Foundation

// equest types (what we send to the server)

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
}

// Response types (what the server sends back)

struct ChatResponse: Codable {
    let choices: [ChatChoice]
}

struct ChatChoice: Codable {
    let message: ChatResponseMessage
}

struct ChatResponseMessage: Codable {
    let content: String
}
