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
    case weather = "Weather"

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
        case .weather: return "sun.max"
        }
    }
}

struct AppShellView: View {
    @State private var selectedSection: DeskPilotSection? = .dashboard

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
                PlaceholderScreen(title: "Dashboard", subtitle: "Overview of meetings, tasks, notes, and recent files.")
            case .assistant:
                AssistantView()
            case .files:
                PlaceholderScreen(title: "Files", subtitle: "Search local files and open results.")
            case .calendar:
                PlaceholderScreen(title: "Calendar", subtitle: "View meetings and upcoming events.")
            case .tasks:
                PlaceholderScreen(title: "Tasks", subtitle: "Track reminders and action items.")
            case .notes:
                PlaceholderScreen(title: "Notes", subtitle: "Quick meeting notes and searchable notepad.")
            case .settings:
                PlaceholderScreen(title: "Settings", subtitle: "Configure permissions and assistant behavior.")
            case .weather:
                PlaceholderScreen(title: "Weather", subtitle: "Check the weather and set reminders.")
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
