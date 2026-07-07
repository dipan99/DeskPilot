//
//  AppShellView.swift
//  DeskPilot
//
//  Created by Dipan Bag on 7/5/26.
//

import SwiftUI

enum DeskPilotSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard = "Dashboard"
    case assistant = "Assistant"
    case files = "Files"
    case calendar = "Calendar"
    case tasks = "Tasks"
    case notes = "Notes"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2"
        case .assistant: return "sparkles"
        case .files: return "folder"
        case .calendar: return "calendar"
        case .tasks: return "checklist"
        case .notes: return "note.text"
        case .settings: return "gear"
        }
    }
}

struct AppShellView: View {
    @State private var selectedSection: DeskPilotSection? = .dashboard
    @State private var assistantUserMessage = ""
    @State private var assistantMessages: [ChatBubbleMessage] = []
    @State private var assistantIsLoading = false

    var body: some View {
        NavigationSplitView {
            List(DeskPilotSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
                    .accessibilityIdentifier("sidebar_\(section.rawValue)")
            }
            .navigationTitle("DeskPilot")
            .accessibilityIdentifier("mainSidebar")
        } detail: {
            switch selectedSection {
            case .dashboard:
                DashboardView { section in
                    selectedSection = section
                }
            case .assistant:
                AssistantView(
                    userMessage: $assistantUserMessage,
                    messages: $assistantMessages,
                    isLoading: $assistantIsLoading
                )
            case .files:
                FilesView()
            case .calendar:
                CalendarView()
            case .tasks:
                TasksView()
            case .notes:
                NotesView()
            case .settings:
                SettingsView()
            case .none:
                PlaceholderScreen(title: "DeskPilot", subtitle: "Choose a section.")
            }
        }
    }
}

struct PlaceholderScreen: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.largeTitle)
                .bold()
                .accessibilityIdentifier("\(title)_title")

            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
