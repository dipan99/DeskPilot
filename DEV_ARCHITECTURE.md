# DeskPilot Development Architecture

DeskPilot is a SwiftUI macOS app organized around feature modules and a small shared core. The main architecture goal is to keep UI, local state, model access, and tool execution separated enough that each area can be tested independently.

## App Structure

```text
DeskPilot/
  App/
    DeskPilotApp.swift
  Core/
    AppSettings.swift
    Constants.swift
    Prompts.swift
    Models/
      ChatModels.swift
    Services/
      AssistantCoordinator.swift
      ChatServing.swift
      MLXService.swift
      MockAssistantChatService.swift
    Tools/
      Tool.swift
      ToolRegistry.swift
  Features/
    Assistant/
    Calendar/
    Dashboard/
    Files/
    Notes/
    Settings/
    Tasks/
    AppShellView.swift
```

## App Shell

`AppShellView` owns app-wide navigation and state that should survive sidebar switching.

It currently keeps:

- selected sidebar section
- Assistant chat input, messages, and loading state
- Dashboard snapshot, summary, loading state, and loaded state

This matters because SwiftUI recreates detail views when switching sections. State that must survive tab/sidebar changes belongs above the recreated view.

## Settings

`AppSettings` is the source of truth for user-configurable app settings. It reads from `UserDefaults.standard` and sanitizes values through `AppSettings.current`.

Settings currently include:

- user name
- user location
- model endpoint
- selected model name
- max tokens
- conversation memory
- response style

`SettingsView` uses `@AppStorage` so changes persist immediately. Tests that mutate settings must reset or isolate app state to avoid leaking test data into the normal app.

## Assistant Flow

The Assistant UI uses `AssistantCoordinator` to handle chat messages.

High-level flow:

1. User sends a message from `AssistantView`.
2. `AssistantCoordinator` sends conversation context, system prompt, and tool definitions to a `ChatServing` implementation.
3. The chat service is either:
   - `MLXService` for real local model calls
   - `MockAssistantChatService` for deterministic UI tests
4. If the model returns tool calls, the coordinator resolves tools through `ToolRegistry`.
5. Tool results are sent back to the model for a final user-facing response.

`ChatServing` keeps the coordinator testable because tests can inject scripted model responses instead of calling the real model.

## Tools

Tools conform to `Tool`.

Each tool provides:

- stable `name` used by model tool calls
- human-readable `displayName`
- model-facing `description`
- JSON schema-like `parameters`
- async `execute(arguments:)`

Current tools:

- `CalendarTool`
- `FilesTool`
- `RemindersTool`
- `NotesTool`

`ToolRegistry` converts registered tools into model-facing definitions and resolves tool calls by name.

## Notes

Notes are local app data. The UI supports creating, opening, editing, and saving notes. Notes persist locally through `NotesStore`.

`NotesTool` lets the Assistant query notes. Retrieval is deterministic and hybrid:

- lexical/token scoring handles exact or near-exact word overlap
- lightweight semantic-style scoring handles related word forms
- ranked results include scores, matched terms, and snippets

This keeps retrieval explainable and testable while giving the model relevant note context.

## Dashboard

`DashboardView` displays:

- AI summary
- recent notes
- upcoming calendar events
- incomplete reminders
- recent files

`DashboardLoader` gathers a `DashboardSnapshot`. `DashboardSummarizer` asks the local model for a short summary, but falls back to `DashboardSnapshot.deterministicSummary` if the model fails or returns empty text.

Dashboard summary loading is intentionally not triggered on every sidebar switch. `AppShellView` owns dashboard state, and `DashboardView` only loads when:

- the dashboard has not loaded yet
- the user clicks Refresh

## Calendar And Tasks

Calendar and Tasks use EventKit.

- `CalendarView` shows upcoming events.
- `TasksView` shows incomplete reminders.
- `CalendarTool` and `RemindersTool` expose those capabilities to the Assistant.

Because EventKit depends on system permissions and user data, UI tests should verify stable UI states rather than exact event/reminder names.

## Files

`FilesView` shows recently used files and folders and can reveal them in Finder. Recent file discovery depends on macOS metadata availability, so UI tests should allow either loaded results or an empty/error state.

## Weather

Weather was removed. Apple WeatherKit requires developer account capability/provisioning access, and the project currently avoids third-party weather APIs.

## Test Mode

The app recognizes launch arguments used by UI tests:

- `UI_TESTING`
- `RESET_APP_STATE`
- `USE_MOCK_ASSISTANT`

When launched with `UI_TESTING RESET_APP_STATE`, the app resets test-sensitive state such as notes and settings.

`USE_MOCK_ASSISTANT` makes `AssistantView` use `MockAssistantChatService` instead of `MLXService`, enabling deterministic Assistant UI tests.
