//
//  RemindersTool.swift
//  DeskPilot
//

import EventKit
import Foundation
import os

private let logger = Logger(subsystem: "com.dipanbag.DeskPilot", category: "RemindersTool")

struct RemindersTool: Tool {
    let name = "get_reminders"
    let displayName = "Reminders"
    let description = "Get the user's reminders and tasks, optionally filtered by completion status and due date range"
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "status": [
                "type": "string",
                "description": "Filter by completion status: incomplete, complete, or all. Defaults to incomplete.",
                "enum": ["incomplete", "complete", "all"]
            ],
            "due_start_date": [
                "type": "string",
                "description": "Start of due date range in yyyy-MM-dd format (optional)"
            ],
            "due_end_date": [
                "type": "string",
                "description": "End of due date range in yyyy-MM-dd format (optional)"
            ]
        ],
        "required": [] as [String]
    ]

    private let store = EKEventStore()

    func execute(arguments: String) async -> ToolResult {
        logger.debug("RemindersTool called with arguments: \(arguments)")

        // Request reminders access
        do {
            let granted = try await store.requestFullAccessToReminders()
            guard granted else {
                return ToolResult(toolName: displayName, output: "Reminders access was denied.")
            }
        } catch {
            return ToolResult(toolName: displayName, output: "Failed to access reminders: \(error.localizedDescription)")
        }

        let args = parseArguments(arguments)
        let predicate = buildPredicate(status: args.status, startDate: args.startDate, endDate: args.endDate)

        logger.debug("Fetching reminders with status: \(args.status)")

        // fetchReminders(matching:) uses a completion handler — bridge to async
        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        logger.debug("Found \(reminders.count) reminder(s)")

        if reminders.isEmpty {
            return ToolResult(toolName: displayName, output: "No reminders found.")
        }

        // Format reminders as JSON for the model
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let reminderList = reminders.map { reminder in
            var entry: [String: String] = [
                "title": reminder.title ?? "Untitled",
                "completed": reminder.isCompleted ? "yes" : "no",
                "list": reminder.calendar?.title ?? "Unknown"
            ]

            if let dueDate = reminder.dueDateComponents,
               let date = Calendar.current.date(from: dueDate) {
                entry["due"] = dateFormatter.string(from: date)
            }

            if let notes = reminder.notes, !notes.isEmpty {
                entry["notes"] = notes
            }

            if reminder.priority > 0 {
                entry["priority"] = "\(reminder.priority)"
            }

            return entry
        }

        if let data = try? JSONSerialization.data(withJSONObject: reminderList),
           let json = String(data: data, encoding: .utf8) {
            return ToolResult(toolName: displayName, output: json)
        }

        return ToolResult(toolName: displayName, output: "Failed to format reminders.")
    }

    // MARK: - Private helpers

    private struct ParsedArgs {
        let status: String
        let startDate: Date?
        let endDate: Date?
    }

    private func parseArguments(_ arguments: String) -> ParsedArgs {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return ParsedArgs(status: "incomplete", startDate: nil, endDate: nil)
        }

        let status = json["status"] ?? "incomplete"

        let startDate: Date? = json["due_start_date"].flatMap { dateFormatter.date(from: $0) }
        let endDate: Date? = json["due_end_date"].flatMap { dateFormatter.date(from: $0) }

        return ParsedArgs(status: status, startDate: startDate, endDate: endDate)
    }

    private func buildPredicate(status: String, startDate: Date?, endDate: Date?) -> NSPredicate {
        switch status {
        case "complete":
            return store.predicateForCompletedReminders(
                withCompletionDateStarting: startDate,
                ending: endDate,
                calendars: nil
            )
        case "all":
            return store.predicateForReminders(in: nil as [EKCalendar]?)
        default:
            return store.predicateForIncompleteReminders(
                withDueDateStarting: startDate,
                ending: endDate,
                calendars: nil
            )
        }
    }
}
