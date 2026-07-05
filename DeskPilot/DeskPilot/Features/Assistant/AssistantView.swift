//
//  AssistantView.swift
//  DeskPilot
//
//  Created by Dipan Bag.
//

import SwiftUI

struct AssistantView: View {
    @State private var userMessage: String = ""
    @State private var messages: [ChatBubbleMessage] = []
    @State private var isLoading: Bool = false

    private let coordinator = AssistantCoordinator(
        registry: ToolRegistry(tools: [
            CalendarTool(),
            FilesTool()
        ]),
        mlxService: MLXService()
    )

    var body: some View {
        VStack(spacing: 0) {
            // Chat messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input bar
            HStack {
                TextField("Ask DeskPilot...", text: $userMessage)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("assistantInput")
                    .onSubmit {
                        Task { await sendMessage() }
                    }

                Button("Send") {
                    Task { await sendMessage() }
                }
                .disabled(isLoading || userMessage.isEmpty)
                .accessibilityIdentifier("assistantSendButton")
            }
            .padding()
        }
    }

    private func sendMessage() async {
        let message = userMessage
        userMessage = ""

        // Capture history before adding current exchange
        let history = messages

        messages.append(ChatBubbleMessage(role: .user, content: message))

        isLoading = true

        let thinkingMessage = ChatBubbleMessage(role: .assistant, content: "Thinking...")
        messages.append(thinkingMessage)

        let response = await coordinator.handleMessage(message, conversationHistory: history)

        // Replace the "Thinking..." placeholder with the real response
        if let index = messages.firstIndex(where: { $0.id == thinkingMessage.id }) {
            messages[index] = ChatBubbleMessage(
                id: thinkingMessage.id,
                role: .assistant,
                content: response.text,
                toolTrace: response.toolTrace
            )
        }

        isLoading = false
    }
}

// MARK: - Chat Bubble Message

struct ChatBubbleMessage: Identifiable {
    let id: UUID
    let role: Role
    let content: String
    let toolTrace: String?

    enum Role {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, content: String, toolTrace: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.toolTrace = toolTrace
    }
}

// MARK: - Chat Bubble View

struct ChatBubble: View {
    let message: ChatBubbleMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(10)
                    .background(message.role == .user ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier(
                        message.role == .user ? "userBubble" : "assistantResponse"
                    )

                if let trace = message.toolTrace {
                    Text("Tool: \(trace)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("assistantToolTrace")
                }
            }

            if message.role == .assistant { Spacer() }
        }
    }
}
