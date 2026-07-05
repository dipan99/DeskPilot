//
//  CalendarTool.swift
//  DeskPilot
//

import EventKit
import Foundation
import os

private let logger = Logger(subsystem: "com.dipanbag.DeskPilot", category: "CalendarTool")

struct CalendarTool: Tool {
    let name = "get_calendar_events"
    let displayName = "Calendar"
    let description = "Get the user's calendar events and meetings for a given date range"
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "start_date": [
                "type": "string",
                "description": "Start date in yyyy-MM-dd format (e.g. 2026-07-05)"
            ],
            "end_date": [
                "type": "string",
                "description": "End date in yyyy-MM-dd format (e.g. 2026-07-06). If omitted, defaults to one day after start_date."
            ]
        ],
        "required": ["start_date"]
    ]

    private let store = EKEventStore()

    func execute(arguments: String) async -> ToolResult {
        logger.debug("CalendarTool called with arguments: \(arguments)")

        // Request calendar access
        do {
            let granted = try await store.requestFullAccessToEvents()
            guard granted else {
                return ToolResult(toolName: displayName, output: "Calendar access was denied.")
            }
        } catch {
            return ToolResult(toolName: displayName, output: "Failed to access calendar: \(error.localizedDescription)")
        }

        // Parse the date arguments from the model
        let (startDate, endDate) = parseDateArguments(arguments)
        logger.debug("Querying events from \(startDate) to \(endDate)")

        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = store.events(matching: predicate)
        logger.debug("Found \(events.count) event(s)")

        if events.isEmpty {
            return ToolResult(toolName: displayName, output: "No events found for the requested date range.")
        }

        // Format events as JSON for the model
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let eventList = events.map { event in
            [
                "title": event.title ?? "Untitled",
                "start": formatter.string(from: event.startDate),
                "end": formatter.string(from: event.endDate)
            ]
        }

        if let data = try? JSONSerialization.data(withJSONObject: eventList),
           let json = String(data: data, encoding: .utf8) {
            return ToolResult(toolName: displayName, output: json)
        }

        return ToolResult(toolName: displayName, output: "Failed to format calendar events.")
    }

    private func parseDateArguments(_ arguments: String) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var startDate = calendar.startOfDay(for: Date())
        var endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!

        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return (startDate, endDate)
        }

        if let startStr = json["start_date"], let parsed = dateFormatter.date(from: startStr) {
            startDate = calendar.startOfDay(for: parsed)
        }

        if let endStr = json["end_date"], let parsed = dateFormatter.date(from: endStr) {
            endDate = calendar.startOfDay(for: parsed)
        } else {
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        }

        return (startDate, endDate)
    }
}
