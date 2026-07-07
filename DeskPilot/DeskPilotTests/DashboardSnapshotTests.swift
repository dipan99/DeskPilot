//
//  DashboardSnapshotTests.swift
//  DeskPilotTests
//

import XCTest
@testable import DeskPilot

final class DashboardSnapshotTests: XCTestCase {
    func testSummaryInputFormatsAllSections() {
        let snapshot = DashboardSnapshot(
            notes: [item("Note A"), item("Note B")],
            events: [item("Standup")],
            tasks: [item("Pay card")],
            files: [item("Proposal.pdf")],
            calendarMessage: "No events.",
            tasksMessage: "No tasks."
        )

        XCTAssertEqual(snapshot.summaryInput, """
        Notes: Note A; Note B
        Calendar: Standup
        Tasks: Pay card
        Files: Proposal.pdf
        """)
    }

    func testDeterministicSummaryReturnsEmptyStateMessage() {
        XCTAssertEqual(DashboardSnapshot.empty.deterministicSummary, "No recent activity found yet.")
    }

    func testDeterministicSummaryIncludesAvailableRecentItemsInOrder() {
        let snapshot = DashboardSnapshot(
            notes: [item("Eric contact")],
            events: [item("Rath Yatra")],
            tasks: [item("Credit Card Due")],
            files: [item("DeskPilot.app")],
            calendarMessage: "No events.",
            tasksMessage: "No tasks."
        )

        XCTAssertEqual(
            snapshot.deterministicSummary,
            "Upcoming: Rath Yatra. Next task: Credit Card Due. Recent note: Eric contact. Recent file: DeskPilot.app."
        )
    }

    func testDeterministicSummarySkipsMissingSections() {
        let snapshot = DashboardSnapshot(
            notes: [],
            events: [item("Design review")],
            tasks: [],
            files: [item("AppShellView.swift")],
            calendarMessage: "No events.",
            tasksMessage: "No tasks."
        )

        XCTAssertEqual(
            snapshot.deterministicSummary,
            "Upcoming: Design review. Recent file: AppShellView.swift."
        )
    }

    private func item(_ title: String) -> DashboardItem {
        DashboardItem(id: title, title: title, subtitle: "Subtitle", date: nil)
    }
}
