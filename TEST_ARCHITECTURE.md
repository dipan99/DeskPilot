# DeskPilot Test Architecture

## Overview

DeskPilot uses a layered test strategy. The goal is to keep most tests deterministic, fast, and useful during normal development, while still allowing optional real local-LLM evaluation when explicitly requested.

The test suite is split into:

- Unit tests for local logic and tools
- Coordinator tests with a mocked model
- UI tests with mocked assistant behavior
- Optional real-AI evaluation tests

This separation matters because the local LLM is slower, more variable, and depends on an external process. Normal tests should not fail because MLX is not running or because a model phrased a valid answer differently.

## Test Targets

### `DeskPilotTests`

Unit test target. These tests run inside the app test host and should be deterministic.

Current files:

- `DeskPilotTests.swift`
  - Default generated placeholder tests.
- `NotesToolTests.swift`
  - Tests `NotesTool` directly with seeded notes in a temporary JSON file.
  - Does not launch the UI.
  - Does not call MLX.
- `AssistantCoordinatorTests.swift`
  - Tests the assistant tool-calling loop with a scripted fake chat service.
  - Verifies that the coordinator sends tool definitions, executes tools, sends tool results back, and returns final text.
  - Does not call MLX.

Use this target for:

- tool behavior
- parsing and ranking logic
- persistence helpers
- coordinator flow
- error handling

### `DeskPilotUITests`

UI automation target. These tests launch the app and interact through accessibility APIs.

Current files:

- `DeskPilotUITests.swift`
  - Small smoke test for app launch.
- `NavigationUITests.swift`
  - Verifies Dashboard opens by default.
  - Verifies sidebar navigation opens every major section.
- `NotesUITests.swift`
  - Verifies Notes UI workflows:
    - open Notes section
    - create note with title/content
    - create note without title
    - open and edit an existing note
- `AssistantUITests.swift`
  - Uses mocked assistant behavior via `USE_MOCK_ASSISTANT`.
  - Verifies Assistant UI response rendering and chat persistence across tab switches.
- `RealAIEvaluationUITests.swift`
  - Optional real local-LLM evaluation.
  - Skipped by default unless `RUN_REAL_AI_EVALS=1` is set.

Use this target for:

- user workflows
- sidebar navigation
- form entry
- persistence visible in the UI
- mocked assistant UI behavior
- optional real assistant evaluation

## Test Support Helpers

Shared helpers live in:

```text
DeskPilotUITests/TestSupport/
```

### `XCTestCase+AppLaunch.swift`

Provides:

```swift
launchDeskPilot(resetState:additionalArguments:additionalEnvironment:)
attachScreenshot(named:app:lifetime:)
```

Why:

- keeps app launch setup consistent
- always passes `UI_TESTING`
- lets tests opt into app launch arguments like `USE_MOCK_ASSISTANT`
- centralizes screenshot attachment behavior

`resetState: true` adds `RESET_APP_STATE`, which lets the app clear UI-test data before launch. Use this for UI tests that create persisted data, especially Notes workflows.

### `XCUIApplication+Sidebar.swift`

Provides:

```swift
openSidebarSection(_:)
```

Why:

- SwiftUI sidebar rows are exposed as cells/static text, not buttons
- tests should not repeat brittle sidebar queries
- `SidebarSection` keeps section names centralized

### `XCUIElement+Waiting.swift`

Provides:

```swift
waitAndClick()
waitAndTypeText(_:)
assertExists()
```

Why:

- UI tests need explicit waits
- failure messages become more useful
- tests read as workflows instead of low-level polling

## Assistant Test Strategy

Assistant behavior is tested at multiple levels.

### 1. Tool Tests

`NotesToolTests` calls `NotesTool.execute(arguments:)` directly.

This proves the tool can retrieve facts from saved notes without involving the model.

Example:

```text
Given a note containing "Eric's phone number is 555-1234"
When NotesTool searches "Eric phone number"
Then output contains "555-1234"
```

Why:

- deterministic
- fast
- exact assertions
- no dependency on MLX

### 2. Coordinator Tests

`AssistantCoordinatorTests` injects a scripted `ChatServing` implementation.

The fake model returns:

1. a tool call, such as `search_notes`
2. a final assistant response

This proves the coordinator correctly:

- sends tool definitions
- executes the requested tool
- appends the tool result
- asks the model for the final response
- returns response text and tool trace

Why:

- tests the model-tool loop
- no real LLM dependency
- easy to assert exact call structure

### 3. Mocked Assistant UI Tests

`AssistantUITests` launches the app with:

```text
USE_MOCK_ASSISTANT
```

That makes `AssistantView` use `MockAssistantChatService` instead of `MLXService`.

Why:

- verifies real UI behavior
- avoids MLX dependency in normal UI tests
- keeps response content predictable
- still exercises the Assistant UI, `AssistantCoordinator`, and tool trace display

### 4. Real AI Evaluation

`RealAIEvaluationUITests` launches the app normally and talks to the real local MLX server.

It is skipped unless this environment variable is set:

```text
RUN_REAL_AI_EVALS=1
```

Current eval:

```text
Seed note: Eric's phone number is 555-1234
Ask: Use my notes. What was Eric's phone number?
Assert: response contains 555-1234
```

Why it is opt-in:

- requires MLX server to be running
- slower than normal tests
- model behavior can vary
- should not block regular local or CI runs by default

For factual retrieval, prefer exact fact checks such as phone numbers, dates, emails, or names. Do not use AI-as-judge for normal automated pass/fail tests.

## Test Data And State Isolation

Normal UI tests launch with `UI_TESTING`. In that mode, Notes storage uses a UI-test-specific notes file instead of the regular app notes file.

Tests that create persisted UI data should launch with:

```swift
launchDeskPilot(resetState: true)
```

This adds `RESET_APP_STATE`, and the app deletes the UI-test notes store before the test starts. This keeps tests independent from previous runs and avoids polluting real user data.

Unit tests should avoid app-global persistence entirely. Prefer temporary files or injected stores, as `NotesToolTests` does with a temporary notes JSON file.

Real AI evaluations are optional and skipped by default. They should seed their own facts with unique titles and assert exact factual values rather than relying on existing user data.

## Mocking Architecture

`ChatServing` is the protocol used by the coordinator:

```swift
protocol ChatServing {
    func send(messages: [ChatMessage], tools: [ToolDefinition]?) async throws -> ChatResponseMessage
}
```

Implementations:

- `MLXService`
  - production local model client
- `MockAssistantChatService`
  - UI-test mock service
- scripted fake service inside `AssistantCoordinatorTests`
  - unit-test fake model

Why:

- keeps `AssistantCoordinator` independent from one concrete model client
- allows deterministic unit/UI tests
- keeps production behavior unchanged

## Accessibility Notes

SwiftUI on macOS sometimes exposes visible text as `value` instead of `label`. Tests that inspect chat or note cards may need to check both:

```swift
label CONTAINS text OR value CONTAINS text
```

Chat bubbles explicitly set:

```swift
.accessibilityLabel(message.content)
.accessibilityIdentifier("assistantResponse")
```

This makes UI test queries more stable.

## Running Tests In Xcode

### Run All Normal Tests

Use:

```text
Command-U
```

The real AI evaluation test will appear in the suite but skip unless `RUN_REAL_AI_EVALS=1` is set.

### Run One Test Class

Open the Test Navigator:

```text
Command-6
```

Click the diamond next to a class, for example:

- `NotesToolTests`
- `AssistantCoordinatorTests`
- `NavigationUITests`
- `NotesUITests`
- `AssistantUITests`

### Run One Test Method

Click the diamond next to the individual method in the editor or Test Navigator.

Examples:

- `testSearchNotesFindsRelevantPhoneNumber`
- `testCoordinatorExecutesToolCallAndReturnsFinalResponse`
- `testAssistantUsesMockedNotesToolResponse`

### Run Real AI Evaluation In Xcode

1. Start the local MLX server.
2. In Xcode, choose the `DeskPilot` scheme.
3. Open:

   ```text
   Product > Scheme > Edit Scheme...
   ```

4. Select `Test`.
5. Open the `Arguments` tab.
6. Under `Environment Variables`, add:

   ```text
   RUN_REAL_AI_EVALS = 1
   ```

7. Run:

   ```text
   RealAIEvaluationUITests/testRealAssistantCanRetrieveSeededNoteFact
   ```

Leave `RUN_REAL_AI_EVALS` disabled for normal test runs.

## Running Tests From Command Line

All commands below assume you are in the repository root that contains `DeskPilot.xcodeproj`.

If your local checkout path contains spaces, keep quoted paths in any commands that include explicit paths.

### Build

```sh
xcodebuild build \
  -project "DeskPilot.xcodeproj" \
  -scheme "DeskPilot" \
  -destination "platform=macOS"
```

### Run All Tests

```sh
xcodebuild test \
  -project "DeskPilot.xcodeproj" \
  -scheme "DeskPilot" \
  -destination "platform=macOS"
```

The real AI evaluation test will skip unless `RUN_REAL_AI_EVALS=1` is present.

### Run All Unit Tests

```sh
xcodebuild test \
  -project "DeskPilot.xcodeproj" \
  -scheme "DeskPilot" \
  -destination "platform=macOS" \
  -only-testing:DeskPilotTests
```

### Run All UI Tests

```sh
xcodebuild test \
  -project "DeskPilot.xcodeproj" \
  -scheme "DeskPilot" \
  -destination "platform=macOS" \
  -only-testing:DeskPilotUITests
```

### Run One Test Class

Unit test class:

```sh
xcodebuild test \
  -project "DeskPilot.xcodeproj" \
  -scheme "DeskPilot" \
  -destination "platform=macOS" \
  -only-testing:DeskPilotTests/NotesToolTests
```

UI test class:

```sh
xcodebuild test \
  -project "DeskPilot.xcodeproj" \
  -scheme "DeskPilot" \
  -destination "platform=macOS" \
  -only-testing:DeskPilotUITests/AssistantUITests
```

### Run One Test Method

```sh
xcodebuild test \
  -project "DeskPilot.xcodeproj" \
  -scheme "DeskPilot" \
  -destination "platform=macOS" \
  -only-testing:DeskPilotTests/NotesToolTests/testSearchNotesFindsRelevantPhoneNumber
```

```sh
xcodebuild test \
  -project "DeskPilot.xcodeproj" \
  -scheme "DeskPilot" \
  -destination "platform=macOS" \
  -only-testing:DeskPilotUITests/AssistantUITests/testAssistantUsesMockedNotesToolResponse
```

### Run Real AI Evaluation From CLI

Start the local MLX server first.

Then run:

```sh
RUN_REAL_AI_EVALS=1 xcodebuild test \
  -project "DeskPilot.xcodeproj" \
  -scheme "DeskPilot" \
  -destination "platform=macOS" \
  -only-testing:DeskPilotUITests/RealAIEvaluationUITests/testRealAssistantCanRetrieveSeededNoteFact
```

Without `RUN_REAL_AI_EVALS=1`, this test skips.

### Run Mocked Assistant UI Tests From CLI

No MLX server required:

```sh
xcodebuild test \
  -project "DeskPilot.xcodeproj" \
  -scheme "DeskPilot" \
  -destination "platform=macOS" \
  -only-testing:DeskPilotUITests/AssistantUITests
```

The tests pass `USE_MOCK_ASSISTANT` through `launchDeskPilot(additionalArguments:)`.

## What Should Not Be Tested With Real AI By Default

Avoid default pass/fail tests that depend on:

- exact wording from the real model
- similarity scores
- AI judging another AI response
- local MLX availability
- model latency

Those belong in opt-in evaluation tests, not normal deterministic tests.

## Extending The Test Suite

When adding a new feature, add tests at the lowest useful layer first.

### New Local Feature

For a feature that does not involve the assistant, such as a new screen or editor:

1. Add unit tests for pure formatting, parsing, persistence, or data-model logic in `DeskPilotTests`.
2. Add UI tests for the main user workflow in `DeskPilotUITests`.
3. Add accessibility identifiers to controls that tests need to locate.
4. Use `XCTContext.runActivity` for major UI steps.
5. Attach screenshots only for useful states or failure diagnosis.
6. Use `launchDeskPilot(resetState: true)` if the workflow creates persisted UI data.

### New Tool

For a new assistant tool:

1. Add deterministic tool tests in `DeskPilotTests`.
2. Seed the tool with controlled data using temporary files, injected stores, or fake dependencies.
3. Assert exact tool output for important facts and error cases.
4. Add coordinator tests if the tool introduces a new tool-calling behavior.
5. Add mocked assistant UI tests only if the user-visible Assistant behavior changes.

### New Assistant Flow

For a new assistant behavior:

1. Keep the core flow covered by `AssistantCoordinatorTests` using a fake `ChatServing` implementation.
2. Use `MockAssistantChatService` for UI-level assistant tests.
3. Avoid requiring MLX for normal tests.
4. Add a real AI evaluation only for important factual retrieval behavior that cannot be meaningfully covered with mocks.

### New Real AI Evaluation

For an opt-in real model eval:

1. Put it in `RealAIEvaluationUITests`.
2. Keep it skipped unless `RUN_REAL_AI_EVALS=1`.
3. Seed exact, unique test facts during the test.
4. Assert exact values such as phone numbers, dates, emails, names, or IDs.
5. Do not assert exact prose from the model.
6. Do not use real AI evals as required CI coverage.
