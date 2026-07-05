//
//  AssistantView.swift
//  DeskPilot
//
//  Created by Dipan Bag on 7/5/26.
//

import SwiftUI

struct AssistantView: View {
    @State private var userMessage: String = ""
    @State private var assistantResponse: String = "Ask DeskPilot about meetings, files, notes, tasks, or weather."
    @State private var toolTrace: String = "No tool used yet."
    @State private var isLoading: Bool = false

    private let mlxService = MLXService()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Assistant")
                .font(.largeTitle)
                .bold()

            Text("Ask DeskPilot to help with your workday.")
                .foregroundStyle(.secondary)

            HStack {
                TextField("Ask DeskPilot...", text: $userMessage)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("assistantInput")

                Button("Send") {
                    Task { await sendMessage() }
                }
                .disabled(isLoading)
                .accessibilityIdentifier("assistantSendButton")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Response")
                    .font(.headline)

                Text(assistantResponse)
                    .accessibilityIdentifier("assistantResponse")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Tool Trace")
                    .font(.headline)

                Text(toolTrace)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("assistantToolTrace")
            }

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sendMessage() async {
        let message = userMessage
        userMessage = ""
        isLoading = true
        assistantResponse = "Thinking..."
        toolTrace = "Tool used: MLX Local Model"

        do {
            assistantResponse = try await mlxService.sendMessage(message)
        } catch {
            // Fall back to keyword routing when server is unavailable
            assistantResponse = mockResponse(for: message)
            toolTrace = "Tool used: Mock Fallback (server unavailable)"
        }

        isLoading = false
    }

    private func mockResponse(for input: String) -> String {
        let message = input.lowercased()

        if message.contains("meeting") || message.contains("calendar") {
            return "You have 2 meetings today: Apple prep at 4 PM and Project Sync at 6 PM."
        } else if message.contains("file") || message.contains("resume") {
            return "I found matching files: Resume.pdf and Apple_Interview_Notes.md."
        } else if message.contains("task") {
            return "You have 3 pending tasks today."
        } else if message.contains("note") {
            return "Your latest note is: XCUITest prep notes."
        } else if message.contains("weather") {
            return "Today's mock weather is 72°F and clear."
        } else {
            return "I can help with meetings, files, notes, tasks, and weather."
        }
    }
}
