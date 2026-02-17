# 03 - MILESTONES

Complete development roadmap for aiDAEMON: JARVIS-style AI companion for macOS.

Last Updated: 2026-02-17
Version: 3.0 (JARVIS Product Roadmap)

---

## LLM Agent Workflow (MANDATORY)

**After completing every milestone, you MUST:**

1. **Update this file** — mark the milestone complete, add commit hash, add implementation notes.
2. **Provide manual setup steps** — tell the owner exactly what they need to do (Xcode settings, permissions, downloads, API keys, terminal commands). Assume they have zero cloud/backend experience.
3. **Provide manual tests** — tell the owner exactly what to test, what to type/click, and what they should see. Specify pass/fail criteria.
4. **STOP and WAIT** — do not start the next milestone until the owner tells you to.

---

## Completed Foundation (M001–M024)

These milestones built the foundation: Xcode project, UI shell, local LLM inference, command parsing, 4 tool executors (app launcher, file search, window manager, system info), validation, confirmation dialogs, and result display. They are complete and documented in git history.

**Summary of what exists**:
- macOS app that launches with Cmd+Shift+Space hotkey
- Floating window with text input
- Local LLaMA 3.1 8B model loads and runs inference
- User types a command → LLM parses it → executor runs it → result shown
- Works for: opening apps/URLs, searching files, moving windows, showing system info
- Confirmation dialogs for risky actions
- All code compiles and runs

---

## PHASE 4: HYBRID MODEL LAYER

*Goal: Give the assistant a smarter brain by connecting to cloud models while keeping local inference for simple tasks.*

---

### M025: ModelProvider Protocol and Local Backend

**Status**: PLANNED

**Objective**: Create an abstraction layer so the app can use either a local model or a cloud model through the same interface. Wrap the existing local LLM code behind this new interface.

**Why this matters**: Right now the app is hardwired to use the local 8B model. We need a clean interface (`ModelProvider` protocol) so we can plug in a cloud model later without rewriting the inference pipeline. This milestone changes zero behavior — it just reorganizes the code.

**Dependencies**: M024 (existing LLM pipeline)

**Deliverables**:
- [ ] `ModelProvider.swift` — Protocol definition:
  ```swift
  protocol ModelProvider {
      var providerName: String { get }
      var isAvailable: Bool { get }
      func generate(prompt: String, params: GenerationParams) async throws -> String
  }
  ```
- [ ] `LocalModelProvider.swift` — Wraps existing `LLMBridge` + `LLMManager` behind the `ModelProvider` protocol. No new logic, just adapter pattern.
- [ ] `LLMManager.swift` updated to use `ModelProvider` instead of directly calling `LLMBridge`. Existing behavior preserved exactly.
- [ ] Existing UI flow works identically (open app, find file, etc. still work through local model).

**Success Criteria**:
- [ ] App builds without errors
- [ ] All existing features work exactly as before (local model handles everything)
- [ ] `LocalModelProvider` conforms to `ModelProvider` protocol
- [ ] No regression in any existing functionality

**Difficulty**: 2/5

---

### M026: Cloud Model Provider (API Client)

**Status**: PLANNED

**Objective**: Build a cloud model client that can send prompts to a remote LLM API (Groq, Together AI, or similar) and return the response. Implements the same `ModelProvider` protocol.

**Why this matters**: This is the brain upgrade. Cloud models (70B+) are dramatically smarter than the local 8B model and can handle complex multi-step planning. This client handles the network call, error handling, and response parsing.

**Dependencies**: M025

**Deliverables**:
- [ ] `CloudModelProvider.swift` — Implements `ModelProvider` protocol:
  - Sends prompt to cloud API via `URLSession` over HTTPS
  - Parses JSON response to extract generated text
  - Handles errors: network failure, rate limiting, invalid API key, timeout
  - 30-second request timeout
  - Supports configurable API endpoint URL and model name
  - Conforms to the same `ModelProvider` interface as local
- [ ] `KeychainHelper.swift` — Secure credential storage:
  - `save(key:value:)` — stores string in Keychain
  - `load(key:)` — retrieves string from Keychain
  - `delete(key:)` — removes entry from Keychain
  - Uses `kSecClassGenericPassword` with service name `com.aidaemon`
  - NEVER stores keys in UserDefaults, files, or source code
- [ ] API key is read from Keychain at request time, not cached in memory
- [ ] No API key = provider reports `isAvailable = false` gracefully
- [ ] All requests use HTTPS. HTTP is rejected.

**Security requirements** (from 02-THREAT-MODEL.md):
- API key stored in macOS Keychain ONLY
- All traffic over TLS (HTTPS)
- No prompt or response data logged to cloud provider
- API key never included in prompt context sent to model

**Success Criteria**:
- [ ] App builds without errors
- [ ] With a valid API key in Keychain, cloud provider can send a test prompt and receive a response
- [ ] Without an API key, cloud provider reports unavailable (no crash, no error dialog)
- [ ] Network errors produce clear error messages (not crashes)
- [ ] API key is never visible in logs, console output, or source code

**Difficulty**: 3/5

---

### M027: API Key Settings UI

**Status**: PLANNED

**Objective**: Add a UI in Settings where the user can enter, update, and remove their cloud API key. Also choose their preferred API provider.

**Why this matters**: Users need a way to activate the cloud brain. This gives them a Settings tab where they paste their API key and pick a provider (Groq, Together AI, etc.).

**Dependencies**: M026

**Deliverables**:
- [ ] New "Cloud" tab in `SettingsView.swift`:
  - Provider picker (dropdown: Groq, Together AI, Custom)
  - API key text field (secure/password style — shows dots, not the actual key)
  - "Test Connection" button — sends a simple test prompt and shows success/failure
  - "Remove Key" button — deletes key from Keychain
  - Status indicator: "Connected" (green) / "Not configured" (gray) / "Error" (red)
  - Help text explaining where to get an API key (with URL for each provider)
- [ ] Provider selection stored in UserDefaults (just the provider name, NOT the key)
- [ ] API key stored/retrieved via `KeychainHelper` (from M026)
- [ ] Cloud indicator somewhere visible (menu bar or settings) showing whether cloud is active

**Success Criteria**:
- [ ] User can open Settings → Cloud tab
- [ ] User can paste an API key and it's stored in Keychain
- [ ] "Test Connection" sends a prompt and shows success/failure
- [ ] "Remove Key" clears the key from Keychain
- [ ] After removing key, cloud provider shows as unavailable
- [ ] API key is never visible in plain text in the UI after entry

**Difficulty**: 2/5

---

### M028: Model Router

**Status**: PLANNED

**Objective**: Build the routing layer that decides whether to use the local model or cloud model for each request.

**Why this matters**: This is where the hybrid magic happens. Simple requests go to the fast local model (no network), complex requests go to the smart cloud model. The user doesn't have to think about it.

**Dependencies**: M025, M026, M027

**Deliverables**:
- [ ] `ModelRouter.swift`:
  - `route(input:context:) -> ModelProvider` — decides which provider to use
  - Routing rules:
    - If cloud is unavailable (no API key or offline) → always local
    - If user has explicitly disabled cloud in Settings → always local
    - If input is a simple single-action command (open app, find file, move window, system info) → local
    - If input requires multi-step planning, complex reasoning, or screen analysis → cloud
    - If local model fails or produces unparseable output → fallback to cloud (if available)
  - Complexity detection heuristic:
    - Short commands with known action words ("open", "find", "move", "show") → simple
    - Commands with "and", "then", "after that", multiple verbs → complex
    - Commands referencing screen content or requiring understanding of app state → complex
- [ ] `LLMManager.swift` updated to use `ModelRouter` instead of always using local
- [ ] UI shows which model was used for each response (e.g., small "Local" or "Cloud" badge)
- [ ] User override in Settings: "Always use local" / "Always use cloud" / "Auto (recommended)"

**Success Criteria**:
- [ ] "open safari" → routed to local model, works as before
- [ ] "set up a workflow that does X then Y then Z" → routed to cloud model (if available)
- [ ] With cloud disabled, everything routes to local (no errors)
- [ ] UI shows which model handled each request
- [ ] Fallback works: if local fails, cloud is tried (if available)

**Difficulty**: 3/5

---

## PHASE 5: CHAT INTERFACE

*Goal: Transform the app from a single-shot command bar into a conversational chat interface.*

---

### M029: Conversation Data Model

**Status**: PLANNED

**Objective**: Create the data structures for a conversation — messages, turns, and history. No UI changes yet, just the model layer.

**Why this matters**: JARVIS needs to have conversations, not just execute single commands. This milestone defines what a conversation looks like in code — a list of messages with roles (user/assistant), timestamps, and metadata.

**Dependencies**: M028

**Deliverables**:
- [ ] `Conversation.swift`:
  - `Message` struct: `id`, `role` (user/assistant/system), `content`, `timestamp`, `metadata` (which model was used, tool calls made, etc.)
  - `Conversation` class (ObservableObject): ordered array of `Message`, `addMessage()`, `clearHistory()`
  - `ConversationStore` — manages active conversation, persists session history to disk (JSON file in app support directory)
  - Session auto-saves when window hides, auto-loads when window shows
- [ ] Conversation context is included in prompts sent to the model:
  - Last N messages (configurable, default 10) are prepended as context
  - This gives the model memory of what was just discussed
- [ ] Message metadata tracks: model used (local/cloud), tool calls, success/failure

**Success Criteria**:
- [ ] App builds without errors
- [ ] Messages can be created, stored, and retrieved
- [ ] Conversation persists across window hide/show cycles
- [ ] Conversation context is included in model prompts

**Difficulty**: 2/5

---

### M030: Chat UI

**Status**: PLANNED

**Objective**: Replace the single-shot command bar with a scrollable chat conversation view. User messages on the right, assistant messages on the left (or similar chat layout).

**Why this matters**: This is the visual transformation from "command launcher" to "JARVIS conversation." The user should feel like they're chatting with an assistant, not entering search queries.

**Dependencies**: M029

**Deliverables**:
- [ ] `ChatView.swift` — replaces the current `ResultsView` in the floating window:
  - Scrollable message list (newest at bottom)
  - User messages: right-aligned, blue/accent background
  - Assistant messages: left-aligned, gray/dark background
  - Typing indicator when model is generating
  - Auto-scroll to newest message
  - Each message shows timestamp on hover
  - Cloud/local badge on assistant messages
- [ ] `FloatingWindow.swift` updated:
  - Window expands taller to accommodate chat (min height ~400px when chat has messages)
  - Input field stays at the bottom
  - Chat history visible above input
  - Window starts compact (just input field) when no messages yet
- [ ] `CommandInputView.swift` updated:
  - Enter submits message to conversation (not direct to LLM)
  - Shift+Enter for newline (multi-line input)
  - Up arrow to edit last message (future)
- [ ] Escape still hides window but preserves conversation
- [ ] "New conversation" button or shortcut (Cmd+N) clears chat

**Success Criteria**:
- [ ] Chat shows message history with user/assistant bubbles
- [ ] New messages appear at bottom and auto-scroll
- [ ] Multiple messages can be sent in sequence (conversation flows)
- [ ] Window resizes appropriately for chat content
- [ ] Escape hides window, reopening shows previous conversation
- [ ] All existing features still work (open app, find file, etc.)

**Difficulty**: 3/5

---

### M031: Conversation Context in Prompts

**Status**: PLANNED

**Objective**: Feed conversation history into model prompts so the assistant remembers what was said earlier in the conversation.

**Why this matters**: Without this, every message is treated independently. With this, the user can say "open Safari" then "now move it to the left" and the assistant knows "it" refers to Safari.

**Dependencies**: M029, M030

**Deliverables**:
- [ ] `PromptBuilder.swift` updated:
  - New method `buildConversationalPrompt(messages:currentInput:)` that includes recent message history
  - Format: system prompt + conversation history + current user input
  - History truncated to fit within model context window (local: ~2048 tokens for history, cloud: ~4096 tokens)
  - Token counting to prevent overflow
- [ ] Both local and cloud model providers use conversational prompts
- [ ] Assistant responses are stored in conversation before being displayed

**Success Criteria**:
- [ ] User can say "open Safari" → "now move it to the left half" → assistant understands "it" = Safari
- [ ] Conversation context doesn't exceed model limits (graceful truncation)
- [ ] Each response is coherent with prior conversation

**Difficulty**: 3/5

---

## PHASE 6: AGENT LOOP

*Goal: Build the orchestrator — the think-plan-act cycle that makes the assistant actually intelligent.*

---

### M032: Tool Schema System

**Status**: PLANNED

**Objective**: Define a formal schema for every tool the assistant can use. This replaces the ad-hoc `CommandType` enum with a structured, extensible tool definition system.

**Why this matters**: For the AI to plan multi-step workflows, it needs to know what tools are available, what parameters they accept, and what they do. This is the "menu" the planner reads from.

**Dependencies**: M031

**Deliverables**:
- [ ] `ToolDefinition.swift`:
  ```swift
  struct ToolDefinition {
      let id: String              // "app_open", "file_search", etc.
      let name: String            // "Open Application"
      let description: String     // "Opens an application or URL"
      let parameters: [ToolParameter]  // typed parameter definitions
      let riskLevel: RiskLevel    // .safe, .caution, .dangerous
      let requiredPermissions: [PermissionType]
  }

  struct ToolParameter {
      let name: String           // "target"
      let type: ParameterType    // .string, .int, .bool, .enum([...])
      let description: String    // "The app name or URL to open"
      let required: Bool
  }
  ```
- [ ] `ToolRegistry.swift` — replaces `CommandRegistry.swift`:
  - `register(tool:executor:)` — register a tool with its definition and executor
  - `allTools() -> [ToolDefinition]` — list all registered tools (used by planner prompt)
  - `executor(for toolId:) -> ToolExecutor?` — get executor for a tool
  - `validate(call:) -> ValidationResult` — validate arguments against schema
- [ ] Existing executors (AppLauncher, FileSearcher, WindowManager, SystemInfo) registered as tools with full schemas
- [ ] `CommandRegistry.swift` kept temporarily for backward compatibility but all new code uses `ToolRegistry`

**Success Criteria**:
- [ ] All 4 existing executors registered as tools with schemas
- [ ] Tool definitions include parameter types, descriptions, and risk levels
- [ ] Schema validation catches invalid arguments (wrong type, missing required field)
- [ ] App builds and existing features work through both old and new registry

**Difficulty**: 3/5

---

### M033: Orchestrator Skeleton

**Status**: PLANNED

**Objective**: Build the core agent loop — the component that takes a user goal, asks the model to plan, and executes the steps.

**Why this matters**: This is the heart of JARVIS. Instead of "user types → model outputs one command → executor runs it," the flow becomes "user types → model plans multiple steps → orchestrator runs them in sequence, checking each result."

**Dependencies**: M032

**Deliverables**:
- [ ] `Orchestrator.swift`:
  - State machine: `idle` → `understanding` → `planning` → `awaiting_approval` → `executing` → `responding`
  - `handleUserInput(text:conversation:)` — entry point
  - `Understanding` phase: sends user input + conversation context + available tools to model
  - `Planning` phase: model returns a structured plan (list of tool calls)
  - `Awaiting approval` phase: shows plan to user in chat, waits for confirmation
  - `Executing` phase: runs each tool call in sequence via ToolRegistry
  - `Responding` phase: summarizes what happened
  - Error handling: if a step fails, the orchestrator tells the user what went wrong
  - Maximum 10 steps per plan (hard limit, prevents runaway)
  - 60-second total timeout for plan execution
- [ ] `PlannerPrompt.swift`:
  - Constructs the planning prompt: "You have these tools: [list]. The user wants: [goal]. Output a JSON plan."
  - Includes tool definitions from ToolRegistry
  - Includes conversation context
  - Output format:
    ```json
    {
      "understanding": "User wants to open Safari and move it to the left",
      "steps": [
        {"tool": "app_open", "args": {"target": "Safari"}},
        {"tool": "window_manage", "args": {"target": "Safari", "position": "left_half"}}
      ]
    }
    ```
- [ ] `PlanParser.swift` — parses model's JSON plan into structured `Plan` object
- [ ] `FloatingWindow` / chat UI updated to show:
  - "I understand you want to..." (understanding)
  - "Here's my plan: 1... 2... 3..." (plan preview)
  - "Approve?" button (at autonomy level 0)
  - Step-by-step progress as execution happens
  - Final summary

**Success Criteria**:
- [ ] User says "open Safari and move it to the left" → orchestrator plans 2 steps → executes both
- [ ] Plan is shown to user before execution (at level 0 autonomy)
- [ ] User can approve or cancel the plan
- [ ] If a step fails, user sees which step and why
- [ ] Single-step commands still work (plan with 1 step)
- [ ] 10-step limit enforced
- [ ] Timeout enforced

**Difficulty**: 5/5

---

### M034: Policy Engine v1

**Status**: PLANNED

**Objective**: Build the runtime policy engine that evaluates every planned action before execution. Replaces the existing `CommandValidator` with a more powerful, tool-aware system.

**Why this matters**: The policy engine is the safety system. It sits between the planner and the executor and decides: is this action safe? Does it need confirmation? Should it be blocked?

**Dependencies**: M033

**Deliverables**:
- [ ] `PolicyEngine.swift`:
  - `evaluate(step:context:autonomyLevel:) -> PolicyDecision`
  - `PolicyDecision` enum: `.allow`, `.requireConfirmation(reason:)`, `.deny(reason:)`
  - Reads risk level from ToolDefinition
  - Applies autonomy level rules (see 00-FOUNDATION.md):
    - Level 0: everything needs confirmation
    - Level 1: safe actions auto-execute
    - Level 2: safe + scoped caution actions auto-execute
    - Level 3: routine autonomy (still blocks dangerous)
  - DANGEROUS actions are NEVER auto-approved regardless of level
  - Unknown tools default to DANGEROUS
  - Path traversal detection for file operations
  - Input sanitization (control chars, null bytes, length limits)
- [ ] Autonomy level stored in UserDefaults, configurable in Settings
- [ ] `SettingsView.swift` updated: new "Safety" section with autonomy level picker and explanation of each level
- [ ] Orchestrator calls PolicyEngine before each step execution
- [ ] Existing `CommandValidator.swift` logic absorbed into PolicyEngine

**Success Criteria**:
- [ ] At level 0: every action shows confirmation dialog
- [ ] At level 1: "open Safari" auto-executes, "delete file" shows confirmation
- [ ] Dangerous actions always show confirmation regardless of level
- [ ] Unknown tool IDs are treated as dangerous
- [ ] Path traversal attempts are blocked
- [ ] Autonomy level is changeable in Settings

**Difficulty**: 3/5

---

### M035: Error Recovery and Retry

**Status**: PLANNED

**Objective**: When a step in a plan fails, the orchestrator should attempt recovery instead of just stopping.

**Why this matters**: Real-world usage will have failures — app doesn't open, file not found, window can't be moved. A good assistant adapts rather than giving up.

**Dependencies**: M033, M034

**Deliverables**:
- [ ] `Orchestrator.swift` updated with recovery logic:
  - If a step fails, ask the model: "Step N failed because [error]. What should I try instead?"
  - Model can suggest an alternative step
  - Maximum 2 retry attempts per step
  - If all retries fail, report failure clearly and continue to next step (if steps are independent) or stop (if steps are dependent)
- [ ] Step dependency tracking:
  - Steps can be marked as dependent on previous steps
  - If step 1 fails and step 2 depends on it, skip step 2
  - If step 1 fails and step 2 is independent, still try step 2
- [ ] User sees: "Step 2 failed: [reason]. I tried an alternative but it also failed. Continuing with step 3..."
- [ ] Total plan timeout still enforced (60 seconds)

**Success Criteria**:
- [ ] If "open Chrome" fails (not installed), assistant tries "open Google Chrome" or suggests alternative
- [ ] After max retries, clear error message shown
- [ ] Independent steps still execute even if earlier steps fail
- [ ] Dependent steps are skipped with explanation

**Difficulty**: 3/5

---

## PHASE 7: COMPUTER CONTROL

*Goal: Give the assistant eyes (screen vision) and hands (mouse/keyboard control) so it can interact with any app.*

---

### M036: Screenshot Capture

**Status**: PLANNED

**Objective**: Take screenshots of the user's screen programmatically, to be used for vision analysis.

**Why this matters**: For the assistant to "see" what's on screen and click the right buttons, it needs screenshots. This is the foundation for screen vision.

**Dependencies**: M034

**Deliverables**:
- [ ] `ScreenCapture.swift`:
  - `captureFullScreen() -> NSImage?` — captures the entire primary display
  - `captureWindow(of app: String) -> NSImage?` — captures a specific app's window
  - `captureRegion(rect: CGRect) -> NSImage?` — captures a specific screen region
  - Uses `CGWindowListCreateImage` API (requires Screen Recording permission)
  - Returns image as NSImage, can be converted to JPEG/PNG data for cloud upload
  - Compresses to JPEG at 80% quality to reduce upload size
  - Maximum resolution cap (1920x1080) to limit data sent to cloud
- [ ] Permission check: if Screen Recording not granted, returns nil with clear error
- [ ] Permission request helper: opens System Settings → Privacy → Screen Recording
- [ ] Screenshot tool registered in ToolRegistry:
  - id: `screen_capture`
  - risk level: `caution`
  - required permission: `.screenRecording`

**Security requirements**:
- Screenshot data is ephemeral — processed and discarded, never written to disk
- If sent to cloud for analysis, user must have opted into screen vision
- Audit log records that a screenshot was taken (but does not store the image)

**Success Criteria**:
- [ ] With Screen Recording permission: screenshot returns valid image
- [ ] Without permission: graceful error with instruction to grant permission
- [ ] Screenshot quality is sufficient for reading text on screen
- [ ] Image size is reasonable for cloud upload (< 500KB typical)

**Difficulty**: 3/5

---

### M037: Vision Analysis (Cloud)

**Status**: PLANNED

**Objective**: Send screenshots to a vision-capable cloud model to understand what's on screen — identify UI elements, read text, locate buttons.

**Why this matters**: This is how JARVIS "sees." It takes a screenshot, sends it to a vision model (like Claude or GPT-4V), and gets back a description of what's on screen: "I see a browser with Gmail open. The compose button is at the top left."

**Dependencies**: M036, M026

**Deliverables**:
- [ ] `VisionAnalyzer.swift`:
  - `analyze(image:prompt:) async throws -> String` — sends image + question to vision API
  - Uses the cloud model provider's vision endpoint
  - Prompt templates:
    - "Describe what's on this screen"
    - "Find the button labeled [X] and give me its approximate coordinates"
    - "What application is in the foreground?"
    - "Read the text in the main content area"
  - Response parsing: extract coordinates, element descriptions, text content
  - 10-second timeout for vision requests
- [ ] `CloudModelProvider.swift` updated to support vision (image + text) requests
  - Multipart request: image data + text prompt
  - Provider-specific formatting (different APIs have different image formats)
- [ ] Screen vision opt-in toggle in Settings:
  - Default: OFF
  - When enabled: clear warning about what will be sent to cloud
  - "Screenshots are sent to [provider] for analysis. They are not stored."
  - Visual indicator in UI when screen vision is active

**Security requirements**:
- Screen vision is OFF by default
- Requires explicit opt-in per session (or persistent opt-in with clear toggle)
- Screenshots sent over HTTPS, not stored by provider
- Audit log records that vision analysis was performed

**Success Criteria**:
- [ ] With vision enabled: screenshot → cloud → description of screen content returned
- [ ] Can identify buttons, text fields, and labels in common apps
- [ ] Coordinate estimates are close enough for mouse clicking (within ~50px)
- [ ] Without vision enabled: feature is completely inactive (no screenshots taken)
- [ ] Works with at least one cloud vision provider (Groq, OpenAI, or Anthropic)

**Difficulty**: 4/5

---

### M038: Mouse Control

**Status**: PLANNED

**Objective**: Programmatically move the mouse cursor and click at specific screen coordinates.

**Why this matters**: Combined with screen vision, this lets the assistant click buttons, select menus, and interact with any app — even apps that don't have AppleScript support.

**Dependencies**: M036

**Deliverables**:
- [ ] `MouseController.swift`:
  - `moveTo(x:y:)` — move cursor to screen coordinates
  - `click(x:y:)` — move cursor and left-click
  - `doubleClick(x:y:)` — move cursor and double-click
  - `rightClick(x:y:)` — move cursor and right-click
  - Uses `CGEvent` API for mouse events
  - Coordinate validation: reject negative or off-screen coordinates
  - Small delay between move and click (50ms) for reliability
- [ ] Mouse click tool registered in ToolRegistry:
  - id: `mouse_click`
  - risk level: `caution`
  - parameters: x (int), y (int), clickType (enum: single/double/right)
  - required permission: `.accessibility`
- [ ] Visual feedback: brief highlight flash at click location (optional, can be disabled)

**Security requirements**:
- Click coordinates validated against screen bounds
- Audit log records every click action with coordinates
- Cannot click outside visible screen area

**Success Criteria**:
- [ ] `click(x:100, y:200)` moves cursor and clicks at that position
- [ ] Clicks work in other applications (Finder, Safari, etc.)
- [ ] Double-click and right-click work correctly
- [ ] Off-screen coordinates are rejected with error

**Difficulty**: 2/5

---

### M039: Keyboard Control

**Status**: PLANNED

**Objective**: Programmatically type text and press keyboard shortcuts.

**Why this matters**: The assistant needs to type text into fields, press Enter, use Cmd+C/Cmd+V, and navigate with keyboard shortcuts. This is the other half of computer control (alongside mouse).

**Dependencies**: M038

**Deliverables**:
- [ ] `KeyboardController.swift`:
  - `typeText(text:)` — types a string character by character with brief delays
  - `pressKey(key:modifiers:)` — presses a key with optional modifiers (Cmd, Shift, Option, Control)
  - `pressShortcut(shortcut:)` — convenience for common shortcuts (Cmd+C, Cmd+V, Cmd+A, etc.)
  - Uses `CGEvent` API for key events
  - Typing speed: ~50ms between characters (fast but reliable)
  - Special character handling: handles shift for uppercase, symbols, etc.
- [ ] Keyboard type tool registered in ToolRegistry:
  - id: `keyboard_type`
  - risk level: `caution`
  - parameters: text (string) OR key (string) + modifiers (array of strings)
- [ ] Keyboard shortcut tool:
  - id: `keyboard_shortcut`
  - risk level: `caution`
  - parameters: shortcut (string, e.g., "cmd+c", "cmd+shift+s")

**Security requirements**:
- Text content is sanitized (no control characters except explicit key presses)
- Audit log records what was typed (content may be redacted if it looks like a password)
- Maximum text length per type action: 1000 characters

**Success Criteria**:
- [ ] `typeText("Hello World")` types the text into the currently focused field
- [ ] `pressShortcut("cmd+c")` triggers copy
- [ ] Works in various apps (TextEdit, Safari address bar, etc.)
- [ ] Special characters (!, @, #, etc.) type correctly

**Difficulty**: 3/5

---

### M040: Integrated Computer Control Flow

**Status**: PLANNED

**Objective**: Connect screenshot → vision → mouse/keyboard into a working flow where the assistant can see the screen, decide what to click, and click it.

**Why this matters**: This is the milestone where the assistant can actually "drive" the computer — look at the screen, understand it, and take action. This is the JARVIS moment.

**Dependencies**: M037, M038, M039

**Deliverables**:
- [ ] `ComputerControl.swift` — high-level coordinator:
  - `performAction(description:) async throws` — "click the compose button in Gmail"
  - Flow: capture screenshot → send to vision model → get element location → move mouse → click
  - Verification: after clicking, capture new screenshot → verify screen changed as expected
  - Retry: if click missed (screen didn't change), try again with adjusted coordinates
  - Maximum 3 attempts per action
- [ ] Orchestrator updated to support computer control steps in plans:
  - New step type: `{"tool": "computer_action", "args": {"action": "click the New Workflow button"}}`
  - Orchestrator calls ComputerControl for these steps
- [ ] Wait-for-change capability: after an action, wait up to 5 seconds for the screen to update before proceeding to next step
- [ ] User sees: real-time updates of what the assistant is seeing and doing
  - "I see the Gmail inbox. Looking for the Compose button..."
  - "Found it at (150, 300). Clicking..."
  - "Compose window opened. Typing the recipient..."

**Security requirements**:
- Every computer control action logged in audit
- User can interrupt at any time (kill switch pauses execution)
- Screen vision must be opted-in
- Dangerous-looking actions (typing passwords, clicking "Delete") require confirmation

**Success Criteria**:
- [ ] Assistant can open Safari, navigate to a URL, and click a specific link
- [ ] Assistant can open TextEdit and type a paragraph of text
- [ ] Verification catches missed clicks and retries
- [ ] User can see what the assistant is doing in real-time
- [ ] Kill switch stops execution immediately

**Difficulty**: 5/5

---

## PHASE 8: ESSENTIAL TOOLS

*Goal: Build out the most useful tools beyond the existing 4.*

---

### M041: Clipboard Tool

**Status**: PLANNED

**Objective**: Read from and write to the macOS clipboard.

**Dependencies**: M034

**Deliverables**:
- [ ] `ClipboardTool.swift`:
  - `read() -> String?` — reads current clipboard text content
  - `write(text:)` — writes text to clipboard
  - Uses `NSPasteboard.general`
  - Handles: plain text, rich text (strips to plain), URLs
- [ ] Registered in ToolRegistry:
  - `clipboard_read`: risk level `safe`
  - `clipboard_write`: risk level `caution`

**Success Criteria**:
- [ ] Copy text in another app → assistant can read it
- [ ] Assistant writes to clipboard → user can paste it

**Difficulty**: 1/5

---

### M042: File Operations Tool

**Status**: PLANNED

**Objective**: Copy, move, rename, and delete files and folders.

**Dependencies**: M034

**Deliverables**:
- [ ] `FileOperations.swift`:
  - `copy(from:to:)` — copies file or folder
  - `move(from:to:)` — moves file or folder
  - `rename(path:newName:)` — renames file or folder
  - `delete(path:)` — moves to Trash (NOT permanent delete)
  - `createFolder(path:)` — creates new directory
  - Uses `FileManager` API exclusively (no shell commands)
  - Path validation: no traversal, no system directories, must be within user's home
  - Scope restriction: by default, only operates within ~/Desktop, ~/Documents, ~/Downloads. Configurable.
- [ ] Registered in ToolRegistry:
  - `file_copy`, `file_move`, `file_rename`: risk level `caution`
  - `file_delete`: risk level `dangerous` (even though it's Trash, not permanent)
  - `folder_create`: risk level `caution`

**Security requirements**:
- Path traversal blocked (../../ etc.)
- System directories blocked (/System, /Library, /usr, etc.)
- Delete moves to Trash, NEVER uses permanent delete
- All operations logged in audit

**Success Criteria**:
- [ ] "copy my resume from Downloads to Documents" works
- [ ] "delete the old report on my Desktop" moves it to Trash
- [ ] Attempting to access /System returns error
- [ ] Path traversal attempts are blocked

**Difficulty**: 3/5

---

### M043: Browser Navigation Tool

**Status**: PLANNED

**Objective**: Open URLs in the user's preferred browser and control basic browser navigation via AppleScript.

**Dependencies**: M034

**Deliverables**:
- [ ] `BrowserTool.swift`:
  - `openURL(url:browser:)` — opens URL in specified or default browser
  - `getCurrentURL(browser:) -> String?` — reads current tab URL (via AppleScript)
  - `getCurrentTitle(browser:) -> String?` — reads current tab title
  - `newTab(url:browser:)` — opens URL in new tab
  - Supports Safari and Chrome via AppleScript
  - Falls back to `NSWorkspace.shared.open(url)` for other browsers
- [ ] Registered in ToolRegistry:
  - `browser_open`: risk level `safe`
  - `browser_read_url`: risk level `safe`
  - `browser_new_tab`: risk level `caution`

**Success Criteria**:
- [ ] "open youtube.com" opens it in default browser
- [ ] "what page am I on?" reads current Safari/Chrome tab URL and title
- [ ] Works with both Safari and Chrome

**Difficulty**: 3/5

---

### M044: Notification Tool

**Status**: PLANNED

**Objective**: Show macOS system notifications on behalf of the assistant.

**Dependencies**: M034

**Deliverables**:
- [ ] `NotificationTool.swift`:
  - `notify(title:body:)` — shows macOS notification via `UNUserNotificationCenter`
  - Notification actions: dismiss (default), open aiDAEMON
  - Request notification permission on first use
- [ ] Registered in ToolRegistry:
  - `notification_send`: risk level `caution`

**Success Criteria**:
- [ ] "remind me in 5 minutes" → notification appears after 5 minutes
- [ ] Notification shows aiDAEMON icon and custom message

**Difficulty**: 2/5

---

### M045: Safe Terminal Tool

**Status**: PLANNED

**Objective**: Execute terminal commands in a sandboxed environment with strict allowlisting.

**Why this matters**: Some tasks genuinely need terminal commands (git status, npm install, brew update). But unrestricted terminal access is extremely dangerous. This tool provides a safe middle ground.

**Dependencies**: M034

**Deliverables**:
- [ ] `TerminalTool.swift`:
  - `execute(command:workingDirectory:) -> (stdout:String, stderr:String, exitCode:Int)`
  - **ALLOWLISTED commands only**. Anything not on the list is rejected:
    - `git` (status, log, diff, add, commit, push, pull, branch, checkout)
    - `ls`, `pwd`, `which`, `whoami`
    - `brew` (list, info, install, update)
    - `npm` / `yarn` / `pnpm` (install, run, build, test, list)
    - `python3` / `node` (script execution with file path, not inline code)
    - `cat`, `head`, `tail`, `wc` (read-only file inspection)
    - `curl` (GET requests only, no POST/PUT/DELETE)
    - `ping`, `dig`, `nslookup` (network diagnostics)
  - **BLOCKED patterns** (hard-coded, cannot be overridden):
    - `rm -rf`, `rm -r`, `sudo`, `chmod`, `chown`, `dd`, `mkfs`
    - Pipe to `sh`, `bash`, `zsh`, `eval`
    - Redirect to system files
    - Any command containing `$()` or backtick substitution
  - Uses `Process` with argument arrays (no shell interpolation)
  - Working directory restricted to user's home and subdirectories
  - 30-second timeout per command
  - Output truncated to 10,000 characters
- [ ] Registered in ToolRegistry:
  - `terminal_run`: risk level `dangerous` (always requires confirmation)

**Security requirements**:
- NEVER uses `Process("/bin/sh", ["-c", ...])` — always direct command execution
- Arguments passed as array, never string interpolation
- Allowlist is hardcoded, not configurable by model
- Every execution logged with full command and output

**Success Criteria**:
- [ ] `git status` executes and returns output
- [ ] `rm -rf /` is rejected immediately
- [ ] `sudo anything` is rejected
- [ ] Unknown commands are rejected
- [ ] 30-second timeout works (test with `sleep 60`)
- [ ] Output truncation works for very long output

**Difficulty**: 4/5

---

## PHASE 9: MEMORY AND CONTEXT

*Goal: Make the assistant context-aware and able to remember user preferences.*

---

### M046: Working and Session Memory

**Status**: PLANNED

**Objective**: Implement the first two memory tiers — working memory (current task) and session memory (current conversation).

**Dependencies**: M035

**Deliverables**:
- [ ] `MemoryManager.swift`:
  - Working memory: key-value store for current task context (cleared when task completes)
    - e.g., "current_app" = "Safari", "last_search_results" = [...]
  - Session memory: conversation history + context gathered during session
    - Persisted to disk between window hide/show
    - Cleared on "new conversation" or app quit
  - `store(key:value:tier:)`, `recall(key:tier:)`, `clear(tier:)`
- [ ] Context providers (integrated into orchestrator):
  - Frontmost app detector: `NSWorkspace.shared.frontmostApplication`
  - Clipboard reader: current clipboard text (with permission)
  - These context values are included in planner prompts automatically

**Success Criteria**:
- [ ] Assistant remembers what was discussed earlier in the session
- [ ] Context about frontmost app is available to the planner
- [ ] Working memory clears between tasks
- [ ] Session memory persists across window toggles

**Difficulty**: 3/5

---

### M047: Long-Term Memory

**Status**: PLANNED

**Objective**: Add persistent memory that survives across sessions. User preferences, facts, and habits.

**Dependencies**: M046

**Deliverables**:
- [ ] Long-term memory store:
  - Stored as encrypted JSON file in app support directory
  - Entries: `{ key, value, category, created, lastUsed }`
  - Categories: preference, fact, habit, instruction
  - Examples: "I prefer Chrome over Safari", "My project folder is ~/code/myapp", "I use n8n for automation"
- [ ] Memory write requires user confirmation:
  - Assistant: "I'd like to remember that you prefer Chrome. OK?"
  - User approves → stored
  - User denies → not stored
- [ ] Blocked categories (NEVER stored):
  - Passwords, API keys, tokens, private keys
  - Social security numbers, credit card numbers
  - Medical information
  - Pattern matching to detect and block these
- [ ] Memory included in planner prompts:
  - "User preferences: [list of long-term memories]"
  - Relevant memories selected based on current query

**Success Criteria**:
- [ ] User says "I always use Chrome" → assistant asks to remember → user approves → remembered across sessions
- [ ] Next session: "open my browser" → opens Chrome (because it remembered)
- [ ] User tries to store a password → blocked with explanation
- [ ] Memory persists after app quit and restart

**Difficulty**: 3/5

---

### M048: Memory Management UI

**Status**: PLANNED

**Objective**: Let users view, edit, and delete their stored memories.

**Dependencies**: M047

**Deliverables**:
- [ ] New "Memory" tab in Settings:
  - List of all long-term memories with category, value, and dates
  - Delete individual memories (swipe or button)
  - Edit memory values
  - "Delete All Memories" button with confirmation
  - Search/filter memories
  - Memory count and storage size shown
- [ ] In-chat memory commands:
  - "what do you remember about me?" → lists relevant memories
  - "forget that I like Chrome" → deletes specific memory

**Success Criteria**:
- [ ] All memories visible in Settings
- [ ] Individual memories can be deleted
- [ ] "Delete All" wipes everything with confirmation
- [ ] Memory count updates in real-time

**Difficulty**: 2/5

---

## PHASE 10: VOICE INTERFACE

*Goal: Talk to JARVIS instead of typing.*

---

### M049: Speech-to-Text Input

**Status**: PLANNED

**Objective**: Add voice input using Apple's on-device Speech framework.

**Why this matters**: Typing is fine, but talking to your computer like JARVIS is the dream. Apple's Speech framework runs on-device (no cloud, perfect privacy) and is free.

**Dependencies**: M034

**Deliverables**:
- [ ] `SpeechInput.swift`:
  - Uses `SFSpeechRecognizer` with on-device recognition
  - `startListening()` / `stopListening()`
  - Real-time transcription shown in input field as user speaks
  - Auto-stop after 3 seconds of silence
  - Language: English (US) — expandable later
- [ ] Microphone permission request with clear explanation
- [ ] Push-to-talk UX:
  - Hold a hotkey (e.g., Cmd+Shift+Space long press) to speak
  - Release to submit
  - Or: click a microphone button in the input field
- [ ] Voice input treated identically to text input (goes through same pipeline)
- [ ] Visual indicator: pulsing microphone icon while listening

**Success Criteria**:
- [ ] Hold hotkey → speak "open Safari" → release → Safari opens
- [ ] Transcription appears in real-time in the input field
- [ ] Auto-stops after silence
- [ ] Works without internet (on-device recognition)

**Difficulty**: 3/5

---

### M050: Text-to-Speech Output

**Status**: PLANNED

**Objective**: The assistant speaks its responses aloud.

**Dependencies**: M049

**Deliverables**:
- [ ] `SpeechOutput.swift`:
  - Uses `AVSpeechSynthesizer` for on-device TTS
  - Speaks assistant responses when voice mode is active
  - Voice selection in Settings (system voices)
  - Speech rate configurable
  - Can be interrupted by new user input
- [ ] Voice mode toggle: when on, both input and output are voice
- [ ] Text responses still shown in chat alongside speech
- [ ] Mute button to temporarily silence TTS

**Success Criteria**:
- [ ] Assistant speaks its response aloud
- [ ] Works without internet (on-device TTS)
- [ ] User can interrupt by speaking or pressing a key
- [ ] Mute button stops speech immediately

**Difficulty**: 2/5

---

## PHASE 11: SAFETY AND POLISH

*Goal: Harden security, build trust, and polish the experience.*

---

### M051: Audit Log System

**Status**: PLANNED

**Objective**: Build a comprehensive, user-viewable log of every action the assistant takes.

**Dependencies**: M034

**Deliverables**:
- [ ] `AuditLog.swift`:
  - Every action recorded: timestamp, tool, arguments, result, model used, cloud/local
  - Stored as JSON files in app support directory (one file per day)
  - Retention: 30 days by default (configurable)
  - Sensitive fields automatically redacted in log (passwords, API keys detected by pattern)
- [ ] Audit viewer in Settings:
  - Timeline view of actions
  - Filter by date, tool, success/failure
  - Expand to see full details
  - "What was sent to cloud?" filter
  - Export to JSON
  - "Delete All Logs" button

**Success Criteria**:
- [ ] Every tool execution creates an audit entry
- [ ] Cloud requests show what was sent (prompt text, whether screenshot included)
- [ ] User can view, filter, and export logs
- [ ] Sensitive data is redacted in logs

**Difficulty**: 3/5

---

### M052: Kill Switch and Emergency Stop

**Status**: PLANNED

**Objective**: Instant, reliable way to stop all assistant activity.

**Dependencies**: M033

**Deliverables**:
- [ ] Global kill switch hotkey (e.g., Cmd+Shift+Escape):
  - Immediately stops all orchestrator execution
  - Cancels any in-progress tool calls
  - Stops mouse/keyboard automation
  - Shows "Stopped" message
  - Does NOT quit the app — just stops the current activity
- [ ] Kill switch button in the floating window UI (always visible during execution)
- [ ] Kill switch in menu bar dropdown
- [ ] After kill switch: assistant enters idle state, asks user what to do

**Success Criteria**:
- [ ] During multi-step execution, kill switch stops everything within 500ms
- [ ] Mouse/keyboard control stops immediately
- [ ] No half-completed actions after kill switch (or they're safely rolled back)
- [ ] Assistant remains usable after kill switch (doesn't crash or lock up)

**Difficulty**: 3/5

---

### M053: Permission Management UI

**Status**: PLANNED

**Objective**: Clear, user-friendly interface showing what permissions the app has and why.

**Dependencies**: M034

**Deliverables**:
- [ ] "Permissions" tab in Settings:
  - List of all macOS permissions (Accessibility, Automation, Microphone, Screen Recording)
  - Status for each: Granted / Not Granted / Not Requested
  - "Why needed" explanation for each
  - "Open System Settings" button for each permission
  - Visual warning for missing critical permissions (Accessibility)
- [ ] Autonomy level controls (moved here from Safety section):
  - Clear explanation of each level with examples
  - Current level highlighted
  - Scope management for Level 2 (which folders/apps are auto-approved)
- [ ] Cloud settings summary:
  - Is cloud enabled?
  - Is screen vision enabled?
  - What provider is connected?
  - Quick toggle to disable cloud entirely

**Success Criteria**:
- [ ] All permission states accurately shown
- [ ] "Open System Settings" links work for each permission
- [ ] Autonomy level is clearly explained and changeable
- [ ] Cloud status is visible at a glance

**Difficulty**: 2/5

---

### M054: Security Hardening Pass

**Status**: PLANNED

**Objective**: Comprehensive security review and hardening of all code written so far.

**Dependencies**: M040, M045 (all tools built)

**Deliverables**:
- [ ] Code audit for:
  - Command injection vulnerabilities
  - Path traversal vulnerabilities
  - Unvalidated inputs
  - Hardcoded secrets
  - Insecure network calls
  - Memory leaks of sensitive data
- [ ] Prompt injection testing:
  - Test clipboard injection scenarios
  - Test file name injection scenarios
  - Test model output injection scenarios
  - Document findings and fixes
- [ ] Terminal tool audit:
  - Verify allowlist cannot be bypassed
  - Test edge cases (unicode, long strings, special characters)
- [ ] Screen vision audit:
  - Verify screenshots are not persisted to disk
  - Verify opt-in flow cannot be bypassed

**Success Criteria**:
- [ ] No known command injection vulnerabilities
- [ ] No known path traversal vulnerabilities
- [ ] No hardcoded secrets in codebase
- [ ] All network calls use HTTPS
- [ ] All credentials in Keychain only
- [ ] Prompt injection test suite passes

**Difficulty**: 4/5

---

## PHASE 12: PRODUCT LAUNCH

*Goal: Package and ship the product.*

---

### M055: User Onboarding Flow

**Status**: PLANNED

**Objective**: First-launch experience that guides users through setup.

**Dependencies**: M053

**Deliverables**:
- [ ] Welcome screen on first launch:
  - "Welcome to aiDAEMON — your AI companion for Mac"
  - Brief explanation (3-4 slides) of what it can do
  - Permission requests with clear explanations (Accessibility, etc.)
  - Optional: set up cloud brain (enter API key) or skip for local-only
  - Optional: enable voice input
  - Hotkey tutorial: "Press Cmd+Shift+Space to summon me anytime"
- [ ] Setup state tracking: remembers where user left off, doesn't re-show completed steps

**Success Criteria**:
- [ ] New user goes from install to working assistant in < 3 minutes
- [ ] All permissions explained clearly before requesting
- [ ] Users who skip cloud setup get a working local-only assistant

**Difficulty**: 3/5

---

### M056: Auto-Update System

**Status**: PLANNED

**Objective**: Ship updates to users automatically using Sparkle.

**Dependencies**: M055

**Deliverables**:
- [ ] Sparkle integration configured:
  - Appcast XML hosted (location TBD — GitHub releases or S3)
  - Automatic update check on launch (configurable frequency)
  - User prompt for available updates
  - Background download and install on quit
- [ ] Code signing and notarization:
  - Developer ID certificate configured
  - Build signed for distribution
  - Notarized with Apple for Gatekeeper
- [ ] Update settings in Settings:
  - "Check for updates automatically" toggle
  - "Check now" button
  - Current version displayed

**Success Criteria**:
- [ ] App checks for updates on launch
- [ ] When update available, user is prompted
- [ ] Update installs cleanly
- [ ] Notarized build passes Gatekeeper

**Difficulty**: 3/5

---

### M057: Performance Optimization

**Status**: PLANNED

**Objective**: Profile and optimize the app for daily use.

**Dependencies**: M056

**Deliverables**:
- [ ] Profile with Instruments:
  - Memory usage (target: < 200MB idle, < 5GB with model loaded)
  - CPU usage when idle (target: < 1%)
  - Launch time (target: < 3 seconds)
  - Model load time (target: < 5 seconds)
- [ ] Optimize identified bottlenecks
- [ ] Lazy model loading (don't load model until first use)
- [ ] Memory cleanup when window is hidden (release non-essential resources)

**Success Criteria**:
- [ ] App meets performance targets
- [ ] No memory leaks over extended use (1 hour)
- [ ] App feels responsive — no noticeable lag in UI

**Difficulty**: 3/5

---

### M058: Beta Build and Distribution

**Status**: PLANNED

**Objective**: Create a distributable beta build and share with initial testers.

**Dependencies**: M057

**Deliverables**:
- [ ] Signed, notarized .dmg installer
- [ ] Installation instructions document
- [ ] Beta feedback mechanism (link to form or GitHub issues)
- [ ] Known issues document
- [ ] Distribute to 5-10 beta testers

**Success Criteria**:
- [ ] Beta testers can install and run the app
- [ ] Core workflows work (open apps, find files, manage windows, chat, voice)
- [ ] Cloud brain works for beta testers with API keys
- [ ] Feedback received and triaged

**Difficulty**: 3/5

---

### M059: Public Launch

**Status**: PLANNED

**Objective**: Ship v1.0 to the public.

**Dependencies**: M058 + all beta feedback addressed

**Deliverables**:
- [ ] Landing page / website
- [ ] Download link (direct .dmg)
- [ ] Documentation / FAQ
- [ ] Pricing page (free tier vs paid tier)
- [ ] Payment integration for paid tier (Stripe or similar)
- [ ] Support channel (email or Discord)

**Success Criteria**:
- [ ] Users can discover, download, install, and use the app
- [ ] Free tier works without payment
- [ ] Paid tier activates with payment
- [ ] No critical bugs in first week

**Difficulty**: 4/5

---

## Milestone Summary

**Completed**: M001–M024 (foundation)

**Remaining**: M025–M059 (35 milestones)

| Phase | Milestones | What It Delivers |
|-------|-----------|-----------------|
| Phase 4: Hybrid Model | M025–M028 | Local + cloud AI, API key management, smart routing |
| Phase 5: Chat Interface | M029–M031 | Conversational UI, message history, context |
| Phase 6: Agent Loop | M032–M035 | Tool schemas, orchestrator, policy engine, error recovery |
| Phase 7: Computer Control | M036–M040 | Screenshots, vision, mouse, keyboard, integrated control |
| Phase 8: Essential Tools | M041–M045 | Clipboard, files, browser, notifications, terminal |
| Phase 9: Memory | M046–M048 | Working/session/long-term memory, memory UI |
| Phase 10: Voice | M049–M050 | Speech input and output |
| Phase 11: Safety & Polish | M051–M054 | Audit log, kill switch, permissions UI, security hardening |
| Phase 12: Product Launch | M055–M059 | Onboarding, updates, optimization, beta, public launch |

**Critical Path**:
M025 → M026 → M028 → M032 → M033 → M034 → M040 → M054 → M058 → M059

---

## Next Action

Start with **M025: ModelProvider Protocol and Local Backend**.
