//
//  MLXService.swift
//  DeskPilot
//

import Foundation

// MLX Service

struct MLXService {
    func sendMessage(_ userMessage: String) async throws -> String {
        // 1. Build the URL
        guard let url = URL(string: Constants.MLX.baseURL) else {
            throw MLXError.invalidURL
        }

        // 2. Build the request body
        let chatRequest = ChatRequest(
            model: Constants.MLX.modelName,
            messages: [
                ChatMessage(role: "system", content: Prompts.system),
                ChatMessage(role: "user", content: userMessage)
            ]
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

// Error types

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
