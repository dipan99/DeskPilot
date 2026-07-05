# DeskPilot Developer Architecture

## Overview

DeskPilot is a local-first macOS productivity assistant built with Swift and SwiftUI. It uses a local LLM (via MLX) with OpenAI-compatible tool calling to answer questions about the user's calendar, files, tasks, notes, and weather.

## Project Structure

```
DeskPilot/
├── App/
│   └── DeskPilotApp.swift              # App entry point
│
├── Core/
│   ├── Constants.swift                 # Config values (server URL, model name, max tokens)
│   ├── Prompts.swift                   # System prompt (computed, includes today's date)
│   │
│   ├── Models/
│   │   └── ChatModels.swift            # Codable types for the OpenAI chat API
│   │
│   ├── Services/
│   │   ├── MLXService.swift            # HTTP client for the local MLX server
│   │   └── AssistantCoordinator.swift  # Orchestrates tool calling loop
│   │
│   └── Tools/
│       ├── Tool.swift                  # Tool protocol + ToolResult
│       └── ToolRegistry.swift          # Holds all tools, converts to API format, lookup by name
│
├── Features/
│   ├── AppShellView.swift              # Main shell: NavigationSplitView + sidebar
│   ├── Assistant/
│   │   └── AssistantView.swift         # Chat UI with bubbles, input bar, tool trace
│   └── Calendar/
│       └── CalendarTool.swift          # EventKit-based calendar tool
│
├── Assets.xcassets
└── DeskPilot.entitlements              # Sandbox permissions (network, calendar)
```

## App Entry Flow

```
DeskPilotApp
  → AppShellView
    → NavigationSplitView
      → Sidebar (DeskPilotSection enum)
      → Detail view (switches on selected section)
        → AssistantView (for .assistant)
        → PlaceholderScreen (for others)
```

`DeskPilotSection` is a `String` enum conforming to `CaseIterable`, `Identifiable`, `Hashable`. Each case maps to a sidebar row with an SF Symbol icon.

## Tool Calling Flow

DeskPilot uses **model-driven tool calling** — the LLM decides which tool to use, not keyword matching.

```
Step 1: User types a message
         │
Step 2: AssistantView calls AssistantCoordinator.handleMessage()
         │
Step 3: Coordinator sends message + tool definitions to MLX server
         │
Step 4: Model returns either:
         ├── A direct reply (no tool needed) → display it
         │
         └── A tool_call (e.g. get_calendar_events with arguments)
              │
Step 5: Coordinator looks up the tool in ToolRegistry
         │
Step 6: Tool.execute(arguments:) runs and returns a ToolResult
         │
Step 7: Coordinator appends the tool result to the conversation
         and sends back to MLX for a natural language response
         │
Step 8: Final response displayed in chat with tool trace
```

This is a standard OpenAI function calling loop. The coordinator handles it in a single async function with no external framework (no LangChain equivalent needed).

## Key Components

### MLXService (Core/Services/MLXService.swift)

HTTP client that talks to the local MLX-LM server at `localhost:8080`.

- `send(messages:tools:)` — Sends a full conversation with optional tool definitions. Returns `ChatResponseMessage` so the caller can check for tool calls.
- `sendMessage(_:)` — Convenience method for simple single-message calls (no tools).
- Uses `URLSession` with `async/await`.

### AssistantCoordinator (Core/Services/AssistantCoordinator.swift)

Orchestrates the tool calling loop. Stateless struct — the view owns the state, the coordinator produces values.

- Takes a `ToolRegistry` and `MLXService` at init.
- `handleMessage(_:) async -> AssistantResponse` — Runs the full flow: send to model → execute tool if needed → send result back → return final response.
- Returns `AssistantResponse` with `text` and optional `toolTrace`.
- Handles errors: if MLX is down, returns an offline message.

### Tool Protocol (Core/Tools/Tool.swift)

```swift
protocol Tool {
    var name: String { get }          // API identifier (e.g. "get_calendar_events")
    var displayName: String { get }   // Human-readable (e.g. "Calendar")
    var description: String { get }   // Sent to model so it knows when to use this tool
    var parameters: [String: Any] { get }  // JSON schema for the tool's arguments
    func execute(arguments: String) async -> ToolResult
}
```

Each tool is self-describing. The `ToolRegistry` converts tools to `ToolDefinition` structs for the API automatically. Adding a new tool means:
1. Create a struct conforming to `Tool`
2. Add it to the registry in `AssistantView`

No routing logic needs to change.

### ToolRegistry (Core/Tools/ToolRegistry.swift)

- `toolDefinitions()` — Converts all registered tools to OpenAI-compatible `ToolDefinition` array.
- `tool(named:)` — Looks up a tool by name when the model returns a tool call.

### ChatModels (Core/Models/ChatModels.swift)

Codable types matching the OpenAI chat completions API:

**Request side:**
- `ChatMessage` — role, content, optional tool_call_id and tool_calls
- `ChatRequest` — model, messages, optional tools array, optional max_tokens
- `ToolDefinition` / `ToolFunctionDefinition` — describes a tool for the model

**Response side:**
- `ChatResponse` → `ChatChoice` → `ChatResponseMessage`
- `ChatResponseMessage` has optional `content` (text reply) and optional `toolCalls` (function calls)
- `ToolCall` → `ToolCallFunction` — the model's requested function name + arguments JSON

**Helper:**
- `AnyCodable` — Handles encoding/decoding `[String: Any]` dictionaries for tool parameter schemas.

### Prompts (Core/Prompts.swift)

`Prompts.system` is a **computed property** (not a constant) because it includes today's date, which the model needs to resolve relative date references like "tomorrow" or "next week".

### Constants (Core/Constants.swift)

```swift
Constants.MLX.baseURL    // "http://127.0.0.1:8080/v1/chat/completions"
Constants.MLX.modelName  // "default_model"
Constants.MLX.maxTokens  // 2048
```

`maxTokens` is set to 2048 because the model uses internal reasoning tokens before producing output. The default (512) was too low and caused the model to run out of tokens before it could output tool calls.

## Chat UI (Features/Assistant/AssistantView.swift)

- `@State messages: [ChatBubbleMessage]` — conversation history
- `@State isLoading` — disables send button during requests
- `ScrollViewReader` auto-scrolls to the latest message
- `.onSubmit` on TextField allows pressing Enter to send

**ChatBubbleMessage** has:
- `role` (.user or .assistant)
- `content` (the text)
- `toolTrace` (optional, shown as small caption under assistant bubbles)

**ChatBubble** renders:
- User messages: blue, right-aligned
- Assistant messages: gray, left-aligned
- Tool trace: caption2 text below the bubble with `assistantToolTrace` accessibility ID

**"Thinking..." flow:**
1. User sends message → user bubble added
2. "Thinking..." placeholder bubble added immediately
3. Coordinator runs async
4. Placeholder replaced in-place with the real response (same UUID)

## Logging

Uses Apple's `os.Logger` framework. Filter console output by subsystem `com.dipanbag.DeskPilot`.

| Category | What it logs |
|----------|-------------|
| `MLXService` | Outgoing request JSON, raw server response |
| `AssistantCoordinator` | Tool count sent, model response summary, tool call name + arguments, tool result, final response, errors |
| `CalendarTool` | Raw arguments received, parsed date range, event count |

## Sandbox Entitlements

The app runs in App Sandbox with these permissions:

- **Outgoing Connections (Client)** — Required for HTTP calls to localhost:8080
- **Calendars** — Required for EventKit access to read calendar events

These are configured in Signing & Capabilities in Xcode and stored in `DeskPilot.entitlements`.

## Adding a New Tool

1. Create a new file in the appropriate `Features/` directory (e.g. `Features/Weather/WeatherTool.swift`)
2. Implement the `Tool` protocol with `name`, `displayName`, `description`, `parameters`, and `execute()`
3. Add it to the registry in `AssistantView.swift`:
   ```swift
   private let coordinator = AssistantCoordinator(
       registry: ToolRegistry(tools: [
           CalendarTool(),
           WeatherTool()  // add here
       ]),
       mlxService: MLXService()
   )
   ```
4. The model will automatically see the new tool and use it when relevant. No routing logic changes needed.

## Backend

See `backend_setup.md` for MLX-LM server setup instructions.
