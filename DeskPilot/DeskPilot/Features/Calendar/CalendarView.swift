//
//  CalendarView.swift
//  DeskPilot
//

import EventKit
import SwiftUI

struct CalendarView: View {
    @State private var state: CalendarViewState = .loading

    private let loader = CalendarEventLoader()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            content
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await loadEvents()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Calendar")
                    .font(.largeTitle)
                    .bold()
                    .accessibilityIdentifier("Calendar_title")

                Text("Upcoming meetings and events from your calendars.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await loadEvents()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(state.isLoading)
            .accessibilityIdentifier("calendarRefreshButton")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView("Loading calendar events...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("calendarLoading")
        case .accessDenied:
            CalendarStateView(
                systemImage: "calendar.badge.exclamationmark",
                title: "Calendar Access Needed",
                message: "DeskPilot needs calendar access to show upcoming meetings and events. Grant access in System Settings, then refresh this view."
            )
            .accessibilityIdentifier("calendarAccessDenied")
        case .empty:
            CalendarStateView(
                systemImage: "calendar",
                title: "No Upcoming Events",
                message: "No meetings or events were found for the next 14 days."
            )
            .accessibilityIdentifier("calendarEmptyState")
        case .failed(let message):
            CalendarStateView(
                systemImage: "exclamationmark.triangle",
                title: "Could Not Load Calendar",
                message: message
            )
            .accessibilityIdentifier("calendarErrorState")
        case .loaded(let events):
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(events) { event in
                        CalendarEventRow(event: event)
                    }
                }
                .padding(.bottom, 24)
            }
            .accessibilityIdentifier("calendarEventsList")
        }
    }

    @MainActor
    private func loadEvents() async {
        state = .loading

        do {
            let events = try await loader.loadUpcomingEvents(days: 14)
            state = events.isEmpty ? .empty : .loaded(events)
        } catch CalendarEventLoaderError.accessDenied {
            state = .accessDenied
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

private enum CalendarViewState {
    case loading
    case accessDenied
    case empty
    case failed(String)
    case loaded([CalendarEventSummary])

    var isLoading: Bool {
        if case .loading = self {
            return true
        }

        return false
    }
}

private struct CalendarEventRow: View {
    let event: CalendarEventSummary

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 4) {
                Text(event.startDate, format: .dateTime.month(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(event.startDate, format: .dateTime.day())
                    .font(.title3)
                    .bold()
            }
            .frame(width: 48)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(event.timeDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Label(event.calendarTitle, systemImage: "calendar")

                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
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
        .accessibilityIdentifier("calendarEventRow")
    }
}

private struct CalendarStateView: View {
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

private struct CalendarEventSummary: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let location: String?

    var timeDescription: String {
        if isAllDay {
            return "All day"
        }

        return "\(startDate.formatted(date: .omitted, time: .shortened)) - \(endDate.formatted(date: .omitted, time: .shortened))"
    }
}

private enum CalendarEventLoaderError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access was denied."
        }
    }
}

@MainActor
private final class CalendarEventLoader {
    private let store = EKEventStore()

    func loadUpcomingEvents(days: Int) async throws -> [CalendarEventSummary] {
        try await requestAccessIfNeeded()

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? startDate
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)

        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                CalendarEventSummary(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title?.isEmpty == false ? event.title : "Untitled Event",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    calendarTitle: event.calendar.title,
                    location: event.location
                )
            }
    }

    private func requestAccessIfNeeded() async throws {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return
        case .notDetermined:
            let granted = try await store.requestFullAccessToEvents()
            guard granted else {
                throw CalendarEventLoaderError.accessDenied
            }
        case .denied, .restricted, .writeOnly:
            throw CalendarEventLoaderError.accessDenied
        @unknown default:
            throw CalendarEventLoaderError.accessDenied
        }
    }
}

#Preview {
    CalendarView()
}
