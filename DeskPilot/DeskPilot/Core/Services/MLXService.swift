//
//  MLXService.swift
//  DeskPilot
//

import Foundation

// MARK: - Request types (what we send to the server)

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
}

// MARK: - Response types (what the server sends back)

struct ChatResponse: Codable {
    let choices: [ChatChoice]
}

struct ChatChoice: Codable {
    let message: ChatResponseMessage
}

struct ChatResponseMessage: Codable {
    let content: String
}

// MARK: - MLX Service

struct MLXService {
    private let baseURL = "http://127.0.0.1:8080/v1/chat/completions"

    func sendMessage(_ userMessage: String) async throws -> String {
        // 1. Build the URL
        guard let url = URL(string: baseURL) else {
            throw MLXError.invalidURL
        }

        // 2. Build the request body
        let chatRequest = ChatRequest(
            model: "default_model",
            messages: [ChatMessage(role: "user", content: userMessage)]
        )

        // 3. Create the HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(chatRequest)

        // 4. Send the request and get the response
        let (data, _) = try await URLSession.shared.data(for: request)

        // 5. Decode the JSON response
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)

        // 6. Return the assistant's reply
        guard let reply = chatResponse.choices.first?.message.content else {
            throw MLXError.noResponse
        }

        return reply
    }
}

// MARK: - Error types

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
