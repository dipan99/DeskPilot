//
//  DashboardView.swift
//  DeskPilot
//

import AppKit
import EventKit
import SwiftUI

struct DashboardView: View {
    let openSection: (DeskPilotSection) -> Void

    @Binding var snapshot: DashboardSnapshot
    @Binding var summary: String
    @Binding var isLoading: Bool
    @Binding var hasLoaded: Bool

    private let loader = DashboardLoader()
    private let summarizer = DashboardSummarizer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                summaryCard

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                    dashboardSection(
                        title: "Notes",
                        systemImage: "note.text",
                        emptyText: "No recent notes.",
                        items: snapshot.notes,
                        section: .notes
                    )

                    dashboardSection(
                        title: "Calendar",
                        systemImage: "calendar",
                        emptyText: snapshot.calendarMessage,
                        items: snapshot.events,
                        section: .calendar
                    )

                    dashboardSection(
                        title: "Tasks",
                        systemImage: "checklist",
                        emptyText: snapshot.tasksMessage,
                        items: snapshot.tasks,
                        section: .tasks
                    )

                    dashboardSection(
                        title: "Files",
                        systemImage: "folder",
                        emptyText: "No recent files found.",
                        items: snapshot.files,
                        section: .files
                    )
                }
            }
            .padding(32)
        }
        .accessibilityIdentifier("dashboardScrollView")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await loadDashboardIfNeeded()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dashboard")
                    .font(.largeTitle)
                    .bold()
                    .accessibilityIdentifier("Dashboard_title")

                Text("A quick view of recent notes, upcoming events, tasks, and files.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await loadDashboard()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(isLoading)
            .accessibilityIdentifier("dashboardRefreshButton")
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)

                Text("AI Summary")
                    .font(.headline)
            }

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Text(summary)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.blue.opacity(0.18))
        }
        .accessibilityIdentifier("dashboardAISummary")
    }

    private func dashboardSection(
        title: String,
        systemImage: String,
        emptyText: String,
        items: [DashboardItem],
        section: DeskPilotSection
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.headline)

                Spacer()

                Button("Open") {
                    openSection(section)
                }
                .font(.caption)
                .accessibilityIdentifier("dashboardOpen\(title)Button")
            }

            if items.isEmpty {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        Button {
                            openSection(section)
                        } label: {
                            DashboardItemRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 220, alignment: .topLeading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.14))
        }
    }

    @MainActor
    private func loadDashboardIfNeeded() async {
        guard !hasLoaded else {
            return
        }

        await loadDashboard()
    }

    @MainActor
    private func loadDashboard() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        summary = "Loading your recent activity..."

        let loadedSnapshot = await loader.loadSnapshot()
        snapshot = loadedSnapshot
        summary = await summarizer.summarize(snapshot: loadedSnapshot)
        hasLoaded = true
        isLoading = false
    }
}

private struct DashboardItemRow: View {
    let item: DashboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DashboardSnapshot {
    let notes: [DashboardItem]
    let events: [DashboardItem]
    let tasks: [DashboardItem]
    let files: [DashboardItem]
    let calendarMessage: String
    let tasksMessage: String

    static let empty = DashboardSnapshot(
        notes: [],
        events: [],
        tasks: [],
        files: [],
        calendarMessage: "Calendar access is needed to show upcoming events.",
        tasksMessage: "Reminders access is needed to show tasks."
    )

    var summaryInput: String {
        [
            "Notes: \(notes.map(\.title).joined(separator: "; "))",
            "Calendar: \(events.map(\.title).joined(separator: "; "))",
            "Tasks: \(tasks.map(\.title).joined(separator: "; "))",
            "Files: \(files.map(\.title).joined(separator: "; "))"
        ].joined(separator: "\n")
    }

    var deterministicSummary: String {
        var parts: [String] = []

        if let firstEvent = events.first {
            parts.append("Upcoming: \(firstEvent.title).")
        }

        if let firstTask = tasks.first {
            parts.append("Next task: \(firstTask.title).")
        }

        if let firstNote = notes.first {
            parts.append("Recent note: \(firstNote.title).")
        }

        if let firstFile = files.first {
            parts.append("Recent file: \(firstFile.title).")
        }

        return parts.isEmpty ? "No recent activity found yet." : parts.joined(separator: " ")
    }
}

struct DashboardItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let date: Date?
}

@MainActor
private final class DashboardLoader {
    private let notesStore = NotesStore()
    private let eventStore = EKEventStore()

    func loadSnapshot() async -> DashboardSnapshot {
        async let notes = loadNotes()
        async let events = loadEventsIfAuthorized()
        async let tasks = loadTasksIfAuthorized()
        async let files = loadRecentFiles()

        let loadedNotes = await notes
        let loadedEvents = await events
        let loadedTasks = await tasks
        let loadedFiles = await files

        return DashboardSnapshot(
            notes: loadedNotes,
            events: loadedEvents.items,
            tasks: loadedTasks.items,
            files: loadedFiles,
            calendarMessage: loadedEvents.message,
            tasksMessage: loadedTasks.message
        )
    }

    private func loadNotes() async -> [DashboardItem] {
        do {
            return try await notesStore.loadNotes()
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(3)
                .map { note in
                    DashboardItem(
                        id: note.id.uuidString,
                        title: note.title,
                        subtitle: note.updatedAt.formatted(date: .abbreviated, time: .shortened),
                        date: note.updatedAt
                    )
                }
        } catch {
            return []
        }
    }

    private func loadEventsIfAuthorized() async -> (items: [DashboardItem], message: String) {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            return ([], "Open Calendar to grant access and show upcoming events.")
        }

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 14, to: startDate) ?? startDate
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(3)

        return (events.map { event in
            DashboardItem(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title?.isEmpty == false ? event.title : "Untitled Event",
                subtitle: event.isAllDay ? "All day" : event.startDate.formatted(date: .abbreviated, time: .shortened),
                date: event.startDate
            )
        }, "No upcoming events in the next 14 days.")
    }

    private func loadTasksIfAuthorized() async -> (items: [DashboardItem], message: String) {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            return ([], "Open Tasks to grant access and show reminders.")
        }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )
        let reminders = await fetchReminders(matching: predicate)
            .sorted { lhs, rhs in
                switch (date(from: lhs.dueDateComponents), date(from: rhs.dueDateComponents)) {
                case let (left?, right?): return left < right
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
            }
            .prefix(3)

        return (reminders.map { reminder in
            let dueDate = date(from: reminder.dueDateComponents)
            return DashboardItem(
                id: reminder.calendarItemIdentifier,
                title: reminder.title?.isEmpty == false ? reminder.title : "Untitled Reminder",
                subtitle: dueDate?.formatted(date: .abbreviated, time: .shortened) ?? reminder.calendar?.title ?? "No due date",
                date: dueDate
            )
        }, "No incomplete reminders found.")
    }

    private func loadRecentFiles() async -> [DashboardItem] {
        let loader = DashboardRecentFileLoader()
        return await loader.loadRecentFiles(limit: 3)
    }

    private func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    private func date(from components: DateComponents?) -> Date? {
        guard let components else {
            return nil
        }

        return Calendar.current.date(from: components)
    }
}

@MainActor
private final class DashboardRecentFileLoader {
    func loadRecentFiles(limit: Int) async -> [DashboardItem] {
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(
            format: "%K > %@",
            kMDItemLastUsedDate as String,
            Date.distantPast as NSDate
        )
        query.searchScopes = [NSMetadataQueryUserHomeScope, NSMetadataQueryLocalComputerScope]
        query.start()

        do {
            try await waitForQueryToFinish(query)
        } catch {
            query.stop()
            return []
        }

        query.stop()

        var seenPaths = Set<String>()
        var items: [DashboardItem] = []

        for index in 0..<query.resultCount {
            guard let metadataItem = query.result(at: index) as? NSMetadataItem,
                  let path = metadataItem.value(forAttribute: kMDItemPath as String) as? String,
                  let lastUsedDate = metadataItem.value(forAttribute: kMDItemLastUsedDate as String) as? Date else {
                continue
            }

            guard seenPaths.insert(path).inserted else {
                continue
            }

            let url = URL(fileURLWithPath: path)
            items.append(DashboardItem(
                id: path,
                title: metadataItem.value(forAttribute: kMDItemFSName as String) as? String ?? url.lastPathComponent,
                subtitle: lastUsedDate.formatted(date: .abbreviated, time: .shortened),
                date: lastUsedDate
            ))
        }

        return items
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    private func waitForQueryToFinish(_ query: NSMetadataQuery) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                for await notification in NotificationCenter.default.notifications(named: .NSMetadataQueryDidFinishGathering) {
                    if (notification.object as AnyObject) === query {
                        return
                    }
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                throw CancellationError()
            }

            try await group.next()
            group.cancelAll()
        }
    }
}

private struct DashboardSummarizer {
    func summarize(snapshot: DashboardSnapshot) async -> String {
        guard snapshot.summaryInput.trimmingCharacters(in: .whitespacesAndNewlines).count > 32 else {
            return snapshot.deterministicSummary
        }

        let prompt = """
        Summarize the user's very recent DeskPilot activity in one short paragraph. Speak directly to the user using second person words like "you" and "your". Do not refer to the user by name. Do not mention the user's location. Mention only concrete items from the context. Do not invent anything. Do not infer the user's identity from note titles, file names, task names, or event names. If there is little information, keep it brief.

        \(snapshot.summaryInput)
        """

        do {
            let response = try await MLXService().send(messages: [
                ChatMessage(role: "system", content: "You write concise dashboard summaries. Do not use markdown."),
                ChatMessage(role: "user", content: prompt)
            ])

            let text = (response.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? snapshot.deterministicSummary : text
        } catch {
            return snapshot.deterministicSummary
        }
    }
}

#Preview {
    DashboardView(
        openSection: { _ in },
        snapshot: .constant(.empty),
        summary: .constant("No recent activity found yet."),
        isLoading: .constant(false),
        hasLoaded: .constant(true)
    )
}
