# 01 - ARCHITECTURE

System architecture for aiDAEMON: a native macOS AI companion with reactive Claude tool-use, accessibility-first computer control, and local fallback.

Last Updated: 2026-02-20
Version: 5.0 (Accessibility-First Computer Intelligence)

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
USER (text + voice)
  ↓
INTERACTION LAYER
  Floating window, chat bubbles, voice I/O, inline confirmations, stop controls
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
  Built-in: app_open, file_search, window_manage, system_info
  Computer: get_ui_state, ax_action, ax_find (AX-first, M042 foundation done, M043 tool registration)
  Vision:   screen_capture, computer_action (fallback for non-AX apps)
  Input:    mouse_click, keyboard_type, keyboard_shortcut
  MCP:      2,800+ community tools via MCP protocol
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
- `SpeechInput.swift` - voice input (on-device SFSpeechRecognizer)
- `SpeechOutput.swift` - voice output (on-device AVSpeechSynthesizer)

Current UX behavior:
- Real-time status messages ("Thinking...", "Opening ...")
- Inline confirmation for policy-gated actions
- Voice I/O: hold Cmd+Shift+Space to speak, assistant speaks responses
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

### 7. Computer Control Layer

Current files:
- `ScreenCapture.swift` - screenshot capture (CGWindowListCreateImage)
- `VisionAnalyzer.swift` - Claude vision analysis of screenshots
- `MouseController.swift` - CGEvent mouse control
- `KeyboardController.swift` - CGEvent keyboard control
- `ComputerControl.swift` - high-level coordinator (screenshot -> vision -> click/type -> verify)
- `AccessibilityService.swift` - AXUIElement API wrapper (tree walking, attribute reading, action execution, element search)

Planned files (M043):
- `UIStateProvider.swift` - combines NSWorkspace + CGWindowList + AX tree into structured snapshot

Current behavior:
- Screenshot-based path: capture -> Claude Vision -> coordinate guessing -> click (fallback)
- AX-first path (M042 foundation complete): `AccessibilityService` walks the AX tree, reads attributes (role, title, value, enabled, focused, frame), maps elements to per-turn refs (@e1, @e2, ...), executes actions (press, setValue, focus, raise, showMenu), and searches by role/title/value. Tool registration + orchestrator integration pending in M043.

### 8. MCP Integration Layer

Current files:
- `MCPClient.swift` - JSON-RPC 2.0 MCP client (stdio + HTTP+SSE transport)
- `MCPServerManager.swift` - manages multiple MCP server connections + tool registration

Current behavior:
- MCP tools auto-register in ToolRegistry on server connect
- Claude sees MCP tools alongside built-in tools in tool_use loop
- Tools persist across sessions (config in ~/Library/Application Support/com.aidaemon/mcp-servers.json)
- API keys for MCP servers stored in Keychain

---

## Current Built-in Tools

**Core tools:**
- `app_open` - app/URL launching
- `file_search` - Spotlight search
- `window_manage` - window positioning
- `system_info` - system status queries

**Computer control tools (current -- screenshot-based, being replaced by AX-first in M042-M046):**
- `screen_capture` - screenshot + Claude vision analysis
- `computer_action` - high-level GUI interaction (screenshot -> vision -> click/type -> verify)
- `mouse_click` - mouse movement and clicking via CGEvent
- `keyboard_type` - text typing via CGEvent
- `keyboard_shortcut` - keyboard shortcuts via CGEvent

**Computer control tools (accessibility-first -- M042 foundation complete, tool registration in M043):**
- `get_ui_state` - returns structured accessibility tree of frontmost app (zero API cost)
- `ax_action` - interact with UI elements by ref (press, set_value, focus -- 100% accurate)
- `ax_find` - search for elements by role/title/value across the app

**MCP tools (M035):**
- Any tool from connected MCP servers (e.g., filesystem, GitHub, Brave Search)
- Tool naming: `mcp__<serverName>__<toolName>`

**Computer control strategy (M044):**
1. Use built-in tools (app_open, etc.) when possible
2. Use `get_ui_state` + `ax_action` for GUI interaction (primary -- fast, free, accurate)
3. Fall back to `computer_action` (screenshot+vision) only when AX tree is empty/unusable

---

## Computer Control Architecture (AX-First)

**Screenshot path (M038-M041):** Screenshot -> Claude Vision -> coordinate guess -> CGEvent click. Slow (~90s), expensive ($0.02-0.06/action), unreliable (~70-80% accuracy). Kept as fallback.

**AX-first path (M042 foundation complete, M043-M046 integration):** Accessibility tree -> element refs -> direct AX actions. Fast (<5s), free ($0/action), accurate (~99%). `AccessibilityService.swift` provides the core API. Tool registration and orchestrator wiring are next (M043-M044).

```text
Control path priority (highest to lowest):

1. ACCESSIBILITY (AXUIElement API)         -- ~99% accuracy, $0, <100ms
   Read element tree → target by ref → AXPress / AXSetValue
   Works for: most native macOS apps (TextEdit, Safari, Finder, System Preferences)

2. KEYBOARD SHORTCUTS                      -- ~100% accuracy, $0, <50ms
   Known shortcuts for common operations (Cmd+C, Cmd+V, Cmd+T, etc.)
   Works for: all apps that support standard shortcuts

3. SCREENSHOT + VISION (fallback)          -- ~70-80% accuracy, $0.02-0.06, 3-8s
   Capture → Claude Vision → coordinate → CGEvent click
   Works for: games, Electron apps with poor AX, custom renderers
```

**Foreground context lock:** Before any mouse/keyboard/AX action, verify the target app is frontmost. If not, re-activate and re-verify. If lock fails, abort with explicit error. Never act on the wrong app.

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
| Accessibility | Window control, AX tree reading, mouse/keyboard events | `window_manage`, `get_ui_state`, `ax_action`, `mouse_click`, `keyboard_type` |
| Automation | App-to-app control (future) | Planned milestones |
| Microphone | Voice input | `SpeechInput.swift` (on-device STT) |
| Screen Recording | Vision/screenshot fallback for non-AX apps | `screen_capture`, `computer_action` (fallback only) |

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
| Primary cloud model | Anthropic Messages API (claude-sonnet-4-5-20250929) |
| Optional cloud providers | OpenAI-compatible APIs |
| Computer control (primary) | macOS Accessibility API (AXUIElement) — M042 foundation complete, M043-M046 integration |
| Computer control (fallback) | CGEvent (mouse/keyboard) + Claude Vision (screenshots) |
| Tool ecosystem | MCP (Model Context Protocol) — 2,800+ community tools |
| Voice input | SFSpeechRecognizer (on-device) + Deepgram (cloud upgrade) |
| Voice output | AVSpeechSynthesizer (on-device) + Deepgram TTS (cloud upgrade) |
| Global hotkeys | KeyboardShortcuts |
| Credential storage | macOS Keychain |
| Updates | Sparkle |
