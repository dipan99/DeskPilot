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
                    sendMessage()
                }
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

    private func sendMessage() {
        let message = userMessage.lowercased()

        if message.contains("meeting") || message.contains("calendar") {
            assistantResponse = "You have 2 meetings today: Apple prep at 4 PM and Project Sync at 6 PM."
            toolTrace = "Tool used: Calendar"
        } else if message.contains("file") || message.contains("resume") {
            assistantResponse = "I found matching files: Resume.pdf and Apple_Interview_Notes.md."
            toolTrace = "Tool used: File Search"
        } else if message.contains("task") {
            assistantResponse = "You have 3 pending tasks today."
            toolTrace = "Tool used: Tasks"
        } else if message.contains("note") {
            assistantResponse = "Your latest note is: XCUITest prep notes."
            toolTrace = "Tool used: Notes"
        } else if message.contains("weather") {
            assistantResponse = "Today's mock weather is 72°F and clear."
            toolTrace = "Tool used: Weather"
        } else {
            assistantResponse = "I can help with meetings, files, notes, tasks, and weather."
            toolTrace = "Tool used: Fallback Router"
        }

        userMessage = ""
    }
}
