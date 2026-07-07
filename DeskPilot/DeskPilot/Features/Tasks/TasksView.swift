//
//  TasksView.swift
//  DeskPilot
//

import EventKit
import SwiftUI

struct TasksView: View {
    @State private var state: TasksViewState = .loading

    private let loader = ReminderLoader()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            content
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await loadReminders()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tasks")
                    .font(.largeTitle)
                    .bold()
                    .accessibilityIdentifier("Tasks_title")

                Text("Incomplete reminders from your Reminders lists.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await loadReminders()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(state.isLoading)
            .accessibilityIdentifier("tasksRefreshButton")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView("Loading reminders...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("tasksLoading")
        case .accessDenied:
            TasksStateView(
                systemImage: "checklist.unchecked",
                title: "Reminders Access Needed",
                message: "DeskPilot needs reminders access to show your tasks. Grant access in System Settings, then refresh this view."
            )
            .accessibilityIdentifier("tasksAccessDenied")
        case .empty:
            TasksStateView(
                systemImage: "checkmark.circle",
                title: "No Incomplete Reminders",
                message: "No incomplete reminders were found."
            )
            .accessibilityIdentifier("tasksEmptyState")
        case .failed(let message):
            TasksStateView(
                systemImage: "exclamationmark.triangle",
                title: "Could Not Load Reminders",
                message: message
            )
            .accessibilityIdentifier("tasksErrorState")
        case .loaded(let reminders):
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(reminders) { reminder in
                        ReminderRow(reminder: reminder)
                    }
                }
                .padding(.bottom, 24)
            }
            .accessibilityIdentifier("tasksRemindersList")
        }
    }

    @MainActor
    private func loadReminders() async {
        state = .loading

        do {
            let reminders = try await loader.loadIncompleteReminders()
            state = reminders.isEmpty ? .empty : .loaded(reminders)
        } catch ReminderLoaderError.accessDenied {
            state = .accessDenied
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

private enum TasksViewState {
    case loading
    case accessDenied
    case empty
    case failed(String)
    case loaded([ReminderSummary])

    var isLoading: Bool {
        if case .loading = self {
            return true
        }

        return false
    }
}

private struct ReminderRow: View {
    let reminder: ReminderSummary

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: reminder.prioritySymbolName)
                .font(.title3)
                .foregroundStyle(reminder.priorityColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(reminder.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(reminder.listTitle, systemImage: "list.bullet")

                    if let dueDescription = reminder.dueDescription {
                        Label(dueDescription, systemImage: "calendar")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if let notes = reminder.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.14))
        }
        .accessibilityIdentifier("taskReminderRow")
    }
}

private struct TasksStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ReminderSummary: Identifiable, Hashable {
    let id: String
    let title: String
    let listTitle: String
    let dueDate: Date?
    let notes: String?
    let priority: Int

    var dueDescription: String? {
        dueDate?.formatted(date: .abbreviated, time: .shortened)
    }

    var prioritySymbolName: String {
        switch priority {
        case 1...4:
            return "exclamationmark.circle.fill"
        case 5...9:
            return "circle"
        default:
            return "circle"
        }
    }

    var priorityColor: Color {
        switch priority {
        case 1...4:
            return .red
        default:
            return .secondary
        }
    }
}

private enum ReminderLoaderError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Reminders access was denied."
        }
    }
}

@MainActor
private final class ReminderLoader {
    private let store = EKEventStore()

    func loadIncompleteReminders() async throws -> [ReminderSummary] {
        try await requestAccessIfNeeded()

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        let reminders = await fetchReminders(matching: predicate)

        return reminders
            .sorted { lhs, rhs in
                switch (date(from: lhs.dueDateComponents), date(from: rhs.dueDateComponents)) {
                case let (left?, right?):
                    return left < right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
            }
            .map { reminder in
                ReminderSummary(
                    id: reminder.calendarItemIdentifier,
                    title: reminder.title?.isEmpty == false ? reminder.title : "Untitled Reminder",
                    listTitle: reminder.calendar?.title ?? "Unknown List",
                    dueDate: date(from: reminder.dueDateComponents),
                    notes: reminder.notes,
                    priority: reminder.priority
                )
            }
    }

    private func requestAccessIfNeeded() async throws {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:
            return
        case .notDetermined:
            let granted = try await store.requestFullAccessToReminders()
            guard granted else {
                throw ReminderLoaderError.accessDenied
            }
        case .denied, .restricted, .writeOnly:
            throw ReminderLoaderError.accessDenied
        @unknown default:
            throw ReminderLoaderError.accessDenied
        }
    }

    private func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
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

#Preview {
    TasksView()
}
