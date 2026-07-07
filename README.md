# DeskPilot

DeskPilot is a macOS SwiftUI desktop assistant app. It combines a local assistant chat experience with small productivity sections such as Dashboard, Notes, Files, Calendar, and Tasks.

The app is designed around local-first workflows. Assistant interactions are coordinated through a tool-calling layer so the assistant can answer questions using app data, such as saved notes, without hardwiring feature logic into the chat UI.

## What DeskPilot Can Do

- Show a dashboard as the default app entry point.
- Navigate between app sections through the sidebar.
- Create, view, edit, and persist notes.
- Derive a note title from the first content line when no title is provided.
- Search notes through a `NotesTool`.
- Ask the Assistant questions that can use tools, such as retrieving details from saved notes.
- Preserve Assistant chat state while switching between sections.
- Run deterministic unit and UI tests using mocked assistant behavior.
- Run optional real local-AI evaluation tests when MLX is available.

## Project Layout

```text
DeskPilot/
  DeskPilot/               App source
  DeskPilotTests/          Unit tests
  DeskPilotUITests/        UI automation tests
  DeskPilot.xcodeproj      Xcode project
```

Important app areas:

- `DeskPilot/App/`
  - App entry point.
- `DeskPilot/Features/`
  - User-facing app sections such as Assistant, Notes, Calendar, Files, and Tasks.
- `DeskPilot/Core/Services/`
  - Assistant coordination, model service abstractions, MLX client, and mocks.
- `DeskPilot/Core/Tools/`
  - Tool protocol and registry.
- `DeskPilotTests/`
  - Deterministic unit tests for tools and coordinator behavior.
- `DeskPilotUITests/`
  - End-to-end UI tests and UI test helpers.

## Documentation

Detailed project docs live one level above this Xcode project directory:

- Backend setup: [`../backend_setup.md`](backend_setup.md)
- Development architecture: [`../DEV_ARCHITECTURE.md`](DEV_ARCHITECTURE.md)
- Test architecture: [`../TEST_ARCHITECTURE.md`](TEST_ARCHITECTURE.md)
- Current progress notes: [`../PROGRESS.md`](PROGRESS.md)

Use this README as the short entry point. Use the linked docs when you need implementation details, setup instructions, testing strategy, or project status.

## Running The App

Open `DeskPilot.xcodeproj` in Xcode, select the `DeskPilot` scheme, then run the app.

The Assistant expects the local MLX-compatible backend to be available for real model responses. For backend setup, see [`../backend_setup.md`](../backend_setup.md).

## Running Tests

Use `Command-U` in Xcode to run the normal test suite.

The normal suite uses deterministic tests and mocked assistant behavior where needed. Real local-AI evaluation tests are opt-in and skipped unless explicitly enabled.

For the full testing strategy and command-line examples, see [`../TEST_ARCHITECTURE.md`](../TEST_ARCHITECTURE.md).

