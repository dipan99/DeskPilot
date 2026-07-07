# DeskPilot

DeskPilot is a local-first macOS productivity assistant built with SwiftUI. It combines a sidebar productivity app with an on-device/local-model chat assistant that can use app tools for notes, calendar events, reminders, and recent files.

The current app is intentionally Apple-platform native where possible. Calendar and Tasks use EventKit. Files use macOS metadata/Spotlight-style recent-file data. Notes are stored locally. The Assistant talks to a local MLX-compatible model service and can call deterministic tools.

## What It Can Do

- Show a Dashboard with recent notes, upcoming calendar events, reminders, recent files, and an AI-generated activity summary.
- Chat with a local assistant that can answer questions and call tools.
- Create, open, edit, and persist local notes.
- Query saved notes through the Assistant using the Notes tool.
- Show upcoming Calendar events using EventKit.
- Show incomplete Reminders in the Tasks section using EventKit.
- Show recently used files and reveal them in Finder.
- Configure profile and assistant/model settings, including name, location, response style, model endpoint, model selection, max tokens, and conversation memory.
- Run unit and UI tests through Xcode or the `scripts/runtests` helper.

## Project Docs

- For development architecture, see [DEV_ARCHITECTURE.md](DEV_ARCHITECTURE.md).
- For testing strategy and commands, see [TEST_ARCHITECTURE.md](TEST_ARCHITECTURE.md).
- For current implementation status, see [PROGRESS.md](PROGRESS.md).
- For backend/local model setup, see [backend_setup.md](backend_setup.md).

These links assume the Markdown files live in the same directory as this README.

## Test Runner

The repo includes a lightweight test wrapper:

```bash
bash scripts/runtests
bash scripts/runtests -unit
bash scripts/runtests -ui
bash scripts/runtests -file AppSettingsTests
bash scripts/runtests -file SettingsUITests -result
```

If executable permissions are enabled locally, the same commands can be run as:

```bash
./scripts/runtests -unit
```

## Notes

Weather integration was removed because Apple WeatherKit requires Apple Developer Program capability/provisioning access. DeskPilot currently avoids third-party weather APIs.
