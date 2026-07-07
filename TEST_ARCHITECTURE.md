# DeskPilot Test Architecture

DeskPilot uses two test targets:

- `DeskPilotTests` for deterministic unit tests.
- `DeskPilotUITests` for end-to-end UI flows through XCUIAutomation.

The goal is to test stable app behavior without making tests depend on local machine data unless the test is explicitly marked as an evaluation.

## Unit Tests

Unit tests live in:

```text
DeskPilotTests/
```

Current files:

- `AppSettingsTests.swift`
- `AssistantCoordinatorTests.swift`
- `DashboardSnapshotTests.swift`
- `DeskPilotTests.swift`
- `NotesToolTests.swift`
- `ToolRegistryTests.swift`

### What Belongs In Unit Tests

Use unit tests for logic that does not require clicking through the app:

- settings defaults, trimming, clamping, and reset behavior
- prompt and model/tool coordination behavior
- tool registry lookup and definitions
- note retrieval ranking and output formatting
- dashboard snapshot formatting and deterministic summary fallback

### Isolation

Unit tests should avoid permanently changing user data.

`AppSettingsTests` snapshots relevant `UserDefaults` values in `setUpWithError`, resets settings for the test, and restores the original values in `tearDownWithError`.

`NotesToolTests` writes to a temporary notes file instead of the normal app notes store.

## UI Tests

UI tests live in:

```text
DeskPilotUITests/
```

Current files:

- `AssistantUITests.swift`
- `DashboardUITests.swift`
- `DeskPilotUITests.swift`
- `DeskPilotUITestsLaunchTests.swift`
- `NavigationUITests.swift`
- `NotesUITests.swift`
- `RealAIEvaluationUITests.swift`
- `SettingsUITests.swift`

Shared helpers live in:

```text
DeskPilotUITests/TestSupport/
```

Helpers:

- `XCTestCase+AppLaunch.swift`
- `XCUIApplication+Sidebar.swift`
- `XCUIElement+Waiting.swift`

### Launch Arguments

UI tests use launch arguments to control app behavior:

- `UI_TESTING`
- `RESET_APP_STATE`
- `USE_MOCK_ASSISTANT`

`UI_TESTING RESET_APP_STATE` resets test-sensitive state before launch. This currently includes local notes test storage and app settings.

`USE_MOCK_ASSISTANT` makes the Assistant use `MockAssistantChatService`, which avoids real model calls in deterministic UI tests.

### UI Test Principles

- Test user-visible flows, not internal implementation details.
- Use accessibility identifiers for stable selection.
- Avoid exact assertions against user/system data from Calendar, Reminders, Files, or Spotlight.
- For AI output, prefer mocked Assistant tests for CI and reserve real model checks for optional evaluation.
- Use `XCTContext.runActivity` for major steps so Xcode test reports are readable.
- Attach screenshots only for useful states or failure-oriented debugging.

## Current UI Coverage

Navigation:

- app launches to Dashboard
- sidebar opens each major section

Notes:

- Notes section opens
- create note with title and content
- create note without title
- open and edit existing note

Assistant:

- mocked Assistant uses Notes tool response
- chat persists when switching sections

Dashboard:

- Dashboard summary and refresh controls exist
- Dashboard card Open buttons navigate to Notes, Calendar, Tasks, and Files

Settings:

- Settings section opens
- user can update name/location and return to the same values
- test cleanup resets Settings after mutation

## Real AI Evaluation

`RealAIEvaluationUITests` is optional evaluation coverage, not core deterministic coverage. It can seed known data and ask the real local model to retrieve a fact.

For factual retrieval, use exact fact checks. Example:

- seed note: `Eric's phone number is 555-1234`
- ask: `What was Eric's phone number?`
- acceptable response must contain `555-1234`

Do not use another LLM to grade these tests in core CI. Prefer exact checks for facts like phone numbers, dates, names, and emails.

## Running Tests In Xcode

Use the Test navigator or click the diamond next to a test class/function.

Common Xcode flows:

- Run all tests with `Cmd+U`.
- Run a test class from the gutter diamond.
- Open the Report navigator to inspect `XCTContext.runActivity` steps and screenshots.

## Running Tests From The Command Line

The project includes a wrapper script:

```bash
bash scripts/runtests
bash scripts/runtests -unit
bash scripts/runtests -ui
bash scripts/runtests -file AppSettingsTests
bash scripts/runtests -file SettingsUITests
bash scripts/runtests -file AppSettingsTests -result
```

If executable permissions are enabled:

```bash
./scripts/runtests -unit
```

### Script Options

```text
no args       run all tests
-unit         run DeskPilotTests
-ui           run DeskPilotUITests
-file NAME    run tests from NAME.swift, resolving unit vs UI target
-result       write an .xcresult report bundle under TestResults/
-help         print usage
```

### Direct xcodebuild

Run all tests:

```bash
xcodebuild test \
  -project DeskPilot.xcodeproj \
  -scheme DeskPilot \
  -testPlan DeskPilot \
  -destination 'platform=macOS'
```

Run only unit tests:

```bash
xcodebuild test \
  -project DeskPilot.xcodeproj \
  -scheme DeskPilot \
  -testPlan DeskPilot \
  -destination 'platform=macOS' \
  -only-testing:DeskPilotTests
```

Run one test file/class:

```bash
xcodebuild test \
  -project DeskPilot.xcodeproj \
  -scheme DeskPilot \
  -testPlan DeskPilot \
  -destination 'platform=macOS' \
  -only-testing:DeskPilotTests/AppSettingsTests
```

Run with an `.xcresult` report:

```bash
xcodebuild test \
  -project DeskPilot.xcodeproj \
  -scheme DeskPilot \
  -testPlan DeskPilot \
  -destination 'platform=macOS' \
  -resultBundlePath TestResults/latest.xcresult
```

## Extending Tests For A New Feature

When adding a new feature:

1. Add unit tests for pure logic, storage, formatting, and tool behavior.
2. Add UI tests only for user-facing flows.
3. Add accessibility identifiers for controls the tests need to target.
4. Use `RESET_APP_STATE` for data that should not leak into the real app.
5. Prefer mocked services for deterministic tests.
6. Avoid asserting exact values from Apple system services unless the test owns that data.
