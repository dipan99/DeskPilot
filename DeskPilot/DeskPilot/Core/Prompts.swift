//
//  Prompts.swift
//  DeskPilot
//

import Foundation

enum Prompts {
    static var system: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd, EEEE"
        let today = formatter.string(from: Date())

        return """
            You are DeskPilot, a local macOS productivity assistant. \
            You help users manage their workday including meetings, tasks, notes, files, and weather. \
            Keep responses concise and helpful. Do not use markdown formatting. \
            Today's date is \(today).
            """
    }
}
