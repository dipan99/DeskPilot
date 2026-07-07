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
        let settings = AppSettings.current
        let userNameLine = settings.userName.isEmpty ? "" : "The user's name is \(settings.userName). "
        let locationLine = settings.userLocation.isEmpty ? "" : "The user's location is \(settings.userLocation). "

        return """
            You are DeskPilot, a local macOS productivity assistant. \
            You help users manage their workday including meetings, tasks, notes, files, and weather. \
            \(settings.responseStyle.promptInstruction) Do not use markdown formatting. \
            Today's date is \(today). \
            \(userNameLine)\
            \(locationLine)\
            You can see the full conversation history in the messages above. \
            Use it to answer follow-up questions without needing any tools.
            """
    }
}
