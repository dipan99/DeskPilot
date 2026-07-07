# DeskPilot Progress

This document tracks current implementation status.

## Completed

### App Shell

- Sidebar navigation for Dashboard, Assistant, Files, Calendar, Tasks, Notes, and Settings.
- Assistant chat state persists when switching sections.
- Dashboard state persists when switching sections.

### Assistant

- Local-model chat flow through `MLXService`.
- `ChatServing` abstraction for real and mocked assistant services.
- `AssistantCoordinator` supports direct responses and tool-call responses.
- Mocked Assistant service supports deterministic UI tests.

### Tools

- Tool protocol and registry.
- Calendar tool.
- Files tool.
- Reminders tool.
- Notes tool with hybrid retrieval.
- Weather tool removed.

### Notes

- Notes section implemented.
- Create notes with title and content.
- Auto-title notes from content when title is omitted.
- Open and edit existing notes.
- Notes persist locally.
- Notes tool can retrieve relevant saved notes for Assistant queries.

### Calendar

- Calendar section shows upcoming events through EventKit.
- Calendar tool exposes event data to the Assistant.

### Tasks

- Tasks section shows incomplete reminders through EventKit.
- Reminders tool exposes reminder data to the Assistant.

### Files

- Files section lists recent files/folders from macOS metadata.
- File rows can reveal items in Finder.
- Files tool exposes recent file information to the Assistant.

### Settings

- Settings section added.
- User name and location settings.
- Assistant response style.
- Conversation memory.
- Model endpoint.
- Model selection dropdown with `default_model (Qwen3-4B-4bit)`.
- Max tokens.
- Reset to defaults.

### Dashboard

- Dashboard shows recent notes, upcoming events, reminders, and recent files.
- Dashboard cards navigate to their source sections.
- AI summary at the top of the Dashboard.
- AI summary is generated only on initial Dashboard load and manual Refresh, not every sidebar switch.
- Deterministic summary fallback when the model is unavailable.

### Testing

Unit tests:

- `AppSettingsTests`
- `AssistantCoordinatorTests`
- `DashboardSnapshotTests`
- `NotesToolTests`
- `ToolRegistryTests`

UI tests:

- `NavigationUITests`
- `NotesUITests`
- `AssistantUITests`
- `DashboardUITests`
- `SettingsUITests`
- launch tests
- optional real AI evaluation test

Test support helpers:

- app launch helper
- sidebar navigation helper
- element waiting/clicking helper

Test runner:

- `scripts/runtests`
- supports all tests, unit-only, UI-only, file/class selection, and `.xcresult` report output.

## Deferred

- Weather integration. Apple WeatherKit requires paid developer capability/provisioning access, and third-party weather APIs are currently out of scope.
- More UI tests for Files, Calendar, and Tasks can be added later with flexible assertions around system data and permission states.
- Deeper Dashboard summarizer unit tests would benefit from injecting a `ChatServing` dependency into `DashboardSummarizer`.
