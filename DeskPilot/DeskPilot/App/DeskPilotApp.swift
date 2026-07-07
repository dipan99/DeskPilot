//
//  DeskPilotApp.swift
//  DeskPilot
//
//  Created by Dipan Bag.
//

import SwiftUI

@main
struct DeskPilotApp: App {
    init() {
        if CommandLine.arguments.contains("UI_TESTING"),
           CommandLine.arguments.contains("RESET_APP_STATE") {
            AppSettings.reset()
            try? NotesStore.resetTestStore()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppShellView()
        }
    }
}
