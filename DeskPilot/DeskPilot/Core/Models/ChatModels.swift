//
//  ChatModels.swift
//  DeskPilot
//

import Foundation

// MARK: - Messages

struct ChatMessage: Codable {
    let role: String
    let content: String?
    let toolCallId: String?
    let toolCalls: [ToolCall]?

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCallId = "tool_call_id"
        case toolCalls = "tool_calls"
    }

    // Convenience initializers for common message types
    init(role: String, content: String) {
        self.role = role
        self.content = content
        self.toolCallId = nil
        self.toolCalls = nil
    }

    init(toolResult: String, toolCallId: String) {
        self.role = "tool"
        self.content = toolResult
        self.toolCallId = toolCallId
        self.toolCalls = nil
    }
}

// MARK: - Request

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let tools: [ToolDefinition]?
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model, messages, tools
        case maxTokens = "max_tokens"
    }
}

// MARK: - Tool Definitions (what we send to the model)

struct ToolDefinition: Codable {
    let type: String
    let function: ToolFunctionDefinition

    init(name: String, description: String, parameters: [String: Any]? = nil) {
        self.type = "function"
        self.function = ToolFunctionDefinition(
            name: name,
            description: description,
            parameters: parameters ?? ["type": "object", "properties": [:]]
        )
    }
}

struct ToolFunctionDefinition: Codable {
    let name: String
    let description: String
    let parameters: [String: Any]

    enum CodingKeys: String, CodingKey {
        case name, description, parameters
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        // Encode parameters dict as JSON data then as a raw JSON value
        let data = try JSONSerialization.data(withJSONObject: parameters)
        let json = try JSONDecoder().decode(AnyCodable.self, from: data)
        try container.encode(json, forKey: .parameters)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        let json = try container.decode(AnyCodable.self, forKey: .parameters)
        let data = try JSONEncoder().encode(json)
        parameters = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    init(name: String, description: String, parameters: [String: Any]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

// MARK: - Tool Calls (what the model returns)

struct ToolCall: Codable {
    let id: String
    let type: String
    let function: ToolCallFunction
}

struct ToolCallFunction: Codable {
    let name: String
    let arguments: String
}

// MARK: - Response

struct ChatResponse: Codable {
    let choices: [ChatChoice]
}

struct ChatChoice: Codable {
    let message: ChatResponseMessage
}

struct ChatResponseMessage: Codable {
    let content: String?
    let toolCalls: [ToolCall]?

    enum CodingKeys: String, CodingKey {
        case content
        case toolCalls = "tool_calls"
    }
}

// MARK: - Helper for encoding [String: Any]

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        }
    }
}

