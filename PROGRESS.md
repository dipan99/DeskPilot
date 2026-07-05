# DeskPilot Progress

## What's Built

### Core Infrastructure
- **App shell** — `NavigationSplitView` with sidebar (`DeskPilotSection` enum) and detail views
- **MLX backend integration** — Local LLM server (Qwen3-4B-4bit via mlx-lm) with OpenAI-compatible API at `localhost:8080`
- **MLXService** — `URLSession` async/await HTTP client with debug logging
- **Chat UI** — Scrollable chat with user/assistant bubbles, "Thinking..." indicator, Enter-to-send
- **System prompt** — Computed property that includes today's date for resolving relative dates
- **Constants** — Centralized config (server URL, model name, max tokens, memory count)

### Tool Calling System
- **Tool protocol** — Self-describing tools with name, description, JSON schema parameters, and async execute
- **ToolRegistry** — Holds all tools, converts to OpenAI-compatible definitions, lookup by name
- **AssistantCoordinator** — Orchestrates the full tool calling loop (send → tool call → execute → send result → final response)
- **Model-driven routing** — The LLM decides which tool to call, no keyword matching

### Tools Implemented
| Tool | File | What it does |
|------|------|-------------|
| **CalendarTool** | `Features/Calendar/CalendarTool.swift` | Reads calendar events via EventKit. Accepts `start_date` and optional `end_date` parameters. |
| **FilesTool** | `Features/Files/FilesTool.swift` | Searches files via Spotlight (`NSMetadataQuery`). Uses `@MainActor` isolated `SpotlightSearch` class with async notification stream. |
| **RemindersTool** | `Features/Tasks/RemindersTool.swift` | Reads reminders via EventKit. Filters by `status` (incomplete/complete/all) and optional due date range. Read-only. |

### Conversation Memory
- Last 9 messages (configurable via `Constants.MLX.conversationMemory`) included in each request
- History captured before appending current message to avoid including the "Thinking..." placeholder
- System prompt tells the model to use conversation history for follow-up questions

### Logging
- `os.Logger` with subsystem `com.dipanbag.DeskPilot`
- Categories: `MLXService`, `AssistantCoordinator`, `CalendarTool`, `RemindersTool`, `FilesTool`
- Logs outgoing request JSON, raw responses, tool calls, tool results, errors

### Sandbox & Permissions
- Outgoing Connections (Client) — for localhost HTTP
- Calendar entitlement — covers both Calendar and Reminders via EventKit
- Privacy usage descriptions needed for Calendar and Reminders

## Key Decisions & Lessons

- **max_tokens = 2048** — The model uses reasoning tokens internally. Default 512 caused `finish_reason: "length"` with no output.
- **Model-driven tool calling over keyword routing** — Proper OpenAI function calling pattern. The model sees tool definitions and decides when to use them.
- **Computed system prompt** — Includes today's date so the model can resolve "tomorrow", "next week", etc.
- **No concurrency escape hatches** — Used `@MainActor` isolated classes with async notification streams instead of `nonisolated(unsafe)` or `@preconcurrency import`.
- **Calendar entitlement covers Reminders** — Both use EventKit; no separate Reminders checkbox in App Sandbox.

## Not Yet Built
- Weather tool
- Notes tool
- Dashboard view (currently placeholder)
- Settings view
- Write operations (creating events, completing reminders)
- Streaming responses
- UI tests updated for tool calling architecture
