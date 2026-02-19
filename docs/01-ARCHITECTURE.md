# 01 - ARCHITECTURE

System architecture for aiDAEMON: a native macOS AI companion with reactive Claude tool-use and local fallback.

Last Updated: 2026-02-19
Version: 4.0 (Reactive Orchestrator Architecture)

---

## How It Works (Simple Version)

```text
You: "Open Safari and go to github.com"

1) Input captured in floating chat window
2) Orchestrator sends conversation + tools to Claude
3) Claude returns structured tool_use blocks
4) PolicyEngine evaluates each tool call
5) Allowed calls execute via ToolRegistry
6) Tool results are sent back to Claude
7) Loop repeats until Claude returns final text
8) User sees status + final response in chat
```

If Claude is unavailable (no API key / no network), aiDAEMON uses a local fallback path so core baseline actions still work.

---

## System Layers

```text
USER (text now, voice planned)
  ↓
INTERACTION LAYER
  Floating window, chat bubbles, inline confirmations, stop controls
  ↓
ORCHESTRATOR (reactive loop)
  send → receive tool_use → policy check → execute → tool_result → repeat
  ↓
POLICY ENGINE
  allow / require confirmation / deny
  ↓
TOOL RUNTIME (ToolRegistry)
  schema validation + dispatch
  ↓
TOOL EXECUTORS
  app_open, file_search, window_manage, system_info
```

Model providers sit behind the orchestrator:
- Primary: Anthropic Claude (`AnthropicModelProvider`)
- Fallback: Local LLaMA path (legacy parser flow) via `LLMManager`

---

## Layer Details

### 1. Interaction Layer

Current files:
- `FloatingWindow.swift` - chat window controller + UI shell
- `ChatView.swift` - conversation rendering + typing indicator
- `CommandInputView.swift` - input field and submit behavior
- `ConfirmationDialog.swift` - inline approval UI for guarded actions

Current UX behavior:
- Real-time status messages ("Thinking...", "Opening ...")
- Inline confirmation for policy-gated actions
- Kill switch support:
  - `Cmd+Shift+Escape`
  - red stop button in header during execution

### 2. Orchestrator

Current file:
- `Orchestrator.swift`

Current behavior:
- Uses Anthropic Messages API with native `tools` parameter
- Sends conversation history (last ~10 messages), system prompt, and tool definitions
- Handles mixed response blocks (`text`, `tool_use`)
- Executes reactive loop until `end_turn`
- Guardrails:
  - 10 tool-use rounds max
  - 90-second total timeout per user turn
  - explicit abort path for kill switch

### 3. Policy Engine

Current file:
- `PolicyEngine.swift`

Current behavior:
- Evaluates each tool call before execution
- Returns `allow`, `requireConfirmation`, or `deny`
- Applies autonomy levels from Settings
- Sanitizes arguments before execution
- Denies path traversal patterns in file/path-like arguments

### 4. Tool Runtime

Current files:
- `ToolDefinition.swift`
- `ToolRegistry.swift`

Current behavior:
- Registers tool schemas + executors
- Validates tool arguments against schema
- Executes validated calls via registered executors
- Exposes Anthropic-compatible tool JSON schema (`anthropicToolDefinitions()`)

### 5. Model Layer

Current files:
- `AnthropicModelProvider.swift`
- `CloudModelProvider.swift`
- `LocalModelProvider.swift`
- `LLMManager.swift`
- `ModelRouter.swift`

Current behavior:
- Anthropic provider is primary cloud path
- OpenAI-compatible cloud provider remains available/configurable
- Local model remains available as fallback when cloud is unavailable
- Model router still exists for local/cloud routing in legacy/local fallback flow

### 6. Conversation Layer

Current file:
- `Conversation.swift`

Current behavior:
- Message persistence to:
  - `~/Library/Application Support/com.aidaemon/conversation.json`
- Metadata on assistant messages (provider, cloud/local, tool/success)
- Used by orchestrator as input history context

---

## Current Built-in Tools

- `app_open` - app/URL launching
- `file_search` - Spotlight search
- `window_manage` - window positioning
- `system_info` - system status queries

Additional tools are planned in later milestones (M035+).

---

## Data Flow A: Cloud-Orchestrated Turn (Primary)

```text
User input
  → FloatingWindow submits to Orchestrator
  → Orchestrator sends Anthropic request with tools
  → Claude returns tool_use
  → PolicyEngine evaluates tool
  → ToolRegistry executes tool
  → Orchestrator sends tool_result back to Claude
  → Claude returns end_turn text
  → Chat displays final response
```

## Data Flow B: Local Fallback Turn

```text
User input
  → Orchestrator detects cloud unavailable
  → Local generation path (legacy parser + validator + command registry)
  → Tool executes locally
  → Chat displays result
```

---

## Permissions Required

| Permission | Why | Current Use |
|-----------|-----|-------------|
| Accessibility | Window control and future full computer control | `window_manage` and future mouse/keyboard tools |
| Automation | App-to-app control (future) | Planned milestones |
| Microphone | Voice input | Planned milestones |
| Screen Recording | Vision/screenshot tools | Planned milestones |

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Hotkey to visible UI | < 150ms |
| Single safe action | < 2s typical |
| Multi-step orchestrator responsiveness | UI remains responsive throughout |
| Kill switch reaction | < 500ms target |
| App memory usage (idle) | < 200MB |

---

## Technology Stack

| Component | Technology |
|-----------|------------|
| App framework | SwiftUI + AppKit |
| Local model | llama.cpp via LlamaSwift |
| Primary cloud model | Anthropic Messages API |
| Optional cloud providers | OpenAI-compatible APIs |
| Global hotkeys | KeyboardShortcuts |
| Credential storage | macOS Keychain |
| Updates | Sparkle |
