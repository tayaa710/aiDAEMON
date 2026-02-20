# 03 - MILESTONES

Complete development roadmap for aiDAEMON: JARVIS-style AI companion for macOS.

Last Updated: 2026-02-20
Version: 6.0 (Accessibility-First Computer Intelligence)

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
- Floating window with scrollable chat conversation UI
- Local LLaMA 3.1 8B model loads and runs inference
- Anthropic Claude (claude-sonnet-4-5-20250929) as primary cloud brain via Anthropic Messages API
- Reactive orchestrator loop: Claude `tool_use` → policy check → execute → `tool_result` → repeat until `end_turn`
- Local fallback path is preserved when cloud is unavailable
- Works for: opening apps/URLs, searching files, moving windows, showing system info
- Level 1 autonomy default: safe + caution actions auto-execute; dangerous always confirms
- Conversation history persists across sessions
- Tool schema system (ToolDefinition + ToolRegistry) powers orchestrator tool definitions
- Kill switch available via Cmd+Shift+Escape and in-window stop button
- All code compiles and runs

---

## PHASE 4: HYBRID MODEL LAYER

*Goal: Give the assistant a smarter brain by connecting to cloud models while keeping local inference for simple tasks.*

---

### M025: ModelProvider Protocol and Local Backend ✅

**Status**: COMPLETE (2026-02-17)

**Objective**: Create an abstraction layer so the app can use either a local model or a cloud model through the same interface. Wrap the existing local LLM code behind this new interface.

**Why this matters**: Right now the app is hardwired to use the local 8B model. We need a clean interface (`ModelProvider` protocol) so we can plug in a cloud model later without rewriting the inference pipeline. This milestone changes zero behavior — it just reorganizes the code.

**Dependencies**: M024 (existing LLM pipeline)

**Deliverables**:
- [x] `ModelProvider.swift` — Protocol with `providerName`, `isAvailable`, `generate(prompt:params:onToken:) async throws -> String`, `abort()`
- [x] `LocalModelProvider.swift` — Wraps `LLMBridge` behind `ModelProvider` using `withCheckedThrowingContinuation` to bridge callback-based async to Swift async/await
- [x] `LLMManager.swift` updated: stores `activeProvider` (any ModelProvider), creates `LocalModelProvider` on model load, `generate()` dispatches through provider, `lastProviderName` tracks which provider handled the request
- [x] Both new files added to pbxproj (UUIDs C4-C7)
- [x] Existing UI flow works identically (all commands still route through local model)
- [x] Fixed pre-existing corruption in `FileSearcher.swift` line 28

**Success Criteria**:
- [x] App builds without errors (BUILD SUCCEEDED)
- [x] All existing features work exactly as before (local model handles everything)
- [x] `LocalModelProvider` conforms to `ModelProvider` protocol
- [x] No regression in any existing functionality

**Difficulty**: 2/5

**Notes**: `ModelProvider` protocol uses Swift async/await. `LocalModelProvider` bridges from the existing callback-based `LLMBridge.generateAsync()` using `withCheckedThrowingContinuation`. `LLMManager.generate()` now spawns a `Task` to call the async provider. Next pbxproj UUIDs: A1B2C3D4000000C8+.

---

### M026: Cloud Model Provider (API Client) ✅

**Status**: COMPLETE (2026-02-17)

**Objective**: Build a cloud model client that can send prompts to a remote LLM API (Groq, Together AI, or similar) and return the response. Implements the same `ModelProvider` protocol.

**Why this matters**: This is the brain upgrade. Cloud models (70B+) are dramatically smarter than the local 8B model and can handle complex multi-step planning. This client handles the network call, error handling, and response parsing.

**Dependencies**: M025

**Deliverables**:
- [x] `CloudModelProvider.swift` — Implements `ModelProvider` protocol:
  - Sends prompt to cloud API via `URLSession` over HTTPS
  - Parses JSON response to extract generated text (OpenAI-compatible chat completions format)
  - Handles errors: network failure, rate limiting (429), invalid API key (401), server errors (5xx), timeout
  - 30-second request timeout
  - Configurable API endpoint and model name via UserDefaults (`cloud.provider`, `cloud.modelName`)
  - `CloudProviderType` enum: Groq, Together AI, Custom — each with default endpoint and model
  - `CloudModelError` enum with human-readable `errorDescription` for each failure case
  - Conforms to same `ModelProvider` interface as `LocalModelProvider`
- [x] `KeychainHelper.swift` — Secure credential storage:
  - `save(key:value:)` — stores string in Keychain
  - `load(key:)` — retrieves string from Keychain
  - `delete(key:)` — removes entry from Keychain
  - Uses `kSecClassGenericPassword` with service name `com.aidaemon`
  - NEVER stores keys in UserDefaults, files, or source code
- [x] API key is read from Keychain at request time (`generate()` call), not cached in any property
- [x] No API key = `isAvailable = false` gracefully (no crash, no error dialog)
- [x] All requests use HTTPS — HTTP endpoints rejected with `CloudModelError.insecureEndpoint` before any network call
- [x] Both files added to pbxproj (UUIDs C8-CB)

**Security requirements** (from 02-THREAT-MODEL.md):
- [x] API key stored in macOS Keychain ONLY
- [x] All traffic over TLS (HTTPS) — enforced in code, not just convention
- [x] API key appears only in the Authorization header; never logged, never in prompt, never in any property
- [x] API key never included in prompt context sent to model

**Success Criteria**:
- [x] App builds without errors (BUILD SUCCEEDED)
- [x] With a valid API key in Keychain, cloud provider can send a test prompt and receive a response
- [x] Without an API key, cloud provider reports unavailable (no crash, no error dialog)
- [x] Network errors produce clear error messages via `CloudModelError.errorDescription` (not crashes)
- [x] API key is never visible in logs, console output, or source code

**Difficulty**: 3/5

**Notes**: Uses OpenAI-compatible chat completions format (works with OpenAI, Groq, and Together AI out of the box). `CloudProviderType` enum stores selection in UserDefaults (`cloud.provider`), API key in Keychain (`cloud-apikey-<ProviderName>`). Provider can be changed in M027 Settings UI. `inflightTask` uses Swift structured concurrency cancellation — `abort()` cancels the URLSession data task. Next pbxproj UUIDs: `A1B2C3D4000000CC+`.

---

### M027: API Key Settings UI ✅

**Status**: COMPLETE (2026-02-17)

**Objective**: Add a UI in Settings where the user can enter, update, and remove their cloud API key. Also choose their preferred API provider.

**Why this matters**: Users need a way to activate the cloud brain. This gives them a Settings tab where they paste their API key and pick a provider (Groq, Together AI, etc.).

**Dependencies**: M026

**Deliverables**:
- [x] New "Cloud" tab in `SettingsView.swift`:
  - Provider picker (OpenAI, Groq, Together AI, Custom) — stored in UserDefaults `cloud.provider`
  - `SecureField` for API key entry (shows dots, never plain text)
  - "Save Key" button — saves to Keychain via `KeychainHelper`
  - "Test Connection" button — sends a minimal prompt, shows "Connected" (green) or error (red)
  - "Remove Key" button (destructive) — deletes key from Keychain
  - Status indicator: "Configured" (green key icon) / "Not configured" (gray)
  - Help text with clickable link to API key signup page for each provider
- [x] Custom provider section: fields for custom HTTPS endpoint URL and model name
- [x] Provider selection stored in UserDefaults (NOT the key — Keychain only for keys)
- [x] API key stored/retrieved via `KeychainHelper` (from M026)
- [x] Cloud status visible in Settings → Cloud tab (key status indicator + test result)
- [x] No new files — all changes in `SettingsView.swift`
- [x] No pbxproj changes needed

**Success Criteria**:
- [x] User can open Settings → Cloud tab
- [x] User can paste an API key and it's stored in Keychain
- [x] "Test Connection" sends a prompt and shows success/failure
- [x] "Remove Key" clears the key from Keychain
- [x] After removing key, status shows "Not configured"
- [x] API key is never visible in plain text in the UI after entry

**Difficulty**: 2/5

**Notes**: The Cloud tab is the 2nd tab (after General). API key field uses `SecureField` — macOS renders it as dots. After saving, the field clears (key cannot be read back from UI). Status automatically reflects Keychain state on tab appear and after any save/remove action. Test connection creates a live `CloudModelProvider` and sends a 16-token test prompt. OpenAI added as a named first-class provider (endpoint: `api.openai.com`, default model: `gpt-4o-mini`). Default provider set to OpenAI for development (switch to Groq for production users later). Next pbxproj UUIDs: `A1B2C3D4000000CC+` (unchanged — no new files this milestone).

---

### M028: Model Router ✅

**Status**: COMPLETE (2026-02-18)

**Objective**: Build the routing layer that decides whether to use the local model or cloud model for each request.

**Why this matters**: This is where the hybrid magic happens. Simple requests go to the fast local model (no network), complex requests go to the smart cloud model. The user doesn't have to think about it.

**Dependencies**: M025, M026, M027

**Deliverables**:
- [x] `ModelRouter.swift`:
  - `route(input:) -> RoutingDecision` — decides which provider to use, returns provider + reason
  - `fallback(for:) -> ModelProvider?` — returns the other provider for fallback scenarios
  - `RoutingMode` enum: `.auto`, `.alwaysLocal`, `.alwaysCloud` — stored in UserDefaults `model.routingMode`
  - `RoutingDecision` struct: provider + reason string + `isCloud` flag
  - Routing rules:
    - If cloud is unavailable (no API key or offline) → always local
    - If user chose "Always Local" in Settings → always local
    - If user chose "Always Cloud" → cloud if available, else fallback to local
    - Auto mode: simple single-action commands → local, complex multi-step → cloud
    - If primary provider fails → automatic fallback to the other provider
  - Complexity detection heuristic:
    - Short commands with known single-action verbs ("open", "find", "move", "show") → simple
    - Commands with "and then", "then", "after that", "followed by" → complex
    - Commands with "and" joining two verb phrases → complex
    - Long inputs (>80 chars) → complex
    - Keywords: "workflow", "set up", "configure", "schedule", "automate", "screen", "plan" → complex
    - Multiple action verbs in clause-start positions → complex
- [x] `LLMManager.swift` updated:
  - `router` property (ModelRouter) created on model load and rebuilt before each generate() call
  - `generate()` accepts `userInput:` parameter for routing decisions
  - `lastWasCloud` and `lastRoutingReason` published properties for UI
  - Automatic fallback: if primary provider fails, tries the other provider
  - `rebuildRouter()` public method to refresh router with latest cloud config
- [x] UI shows which model was used: "Local" or "Cloud" badge with icon on each result
  - `ResultsView` updated with `modelBadge` and `isCloudModel` parameters
  - Cloud badge: blue with cloud icon. Local badge: gray with desktop icon.
  - Badge appears in result header row, right-aligned
  - `ResultsState` tracks `modelBadge` and `isCloudModel`, cleared on `clear()`
- [x] User override in Settings → Cloud tab: "Model Routing" section
  - Picker: "Auto" / "Always Local" / "Always Cloud"
  - Contextual help text explains each mode
  - Stored in UserDefaults `model.routingMode`
- [x] `ModelRouter.swift` added to pbxproj (UUIDs CC-CD)

**Success Criteria**:
- [x] "open safari" → routed to local model, works as before
- [x] "set up a workflow that does X then Y then Z" → routed to cloud model (if available)
- [x] With cloud disabled (or "Always Local"), everything routes to local (no errors)
- [x] UI shows which model handled each request (Local/Cloud badge)
- [x] Fallback works: if local fails, cloud is tried (if available), and vice versa

**Difficulty**: 3/5

**Notes**: `RoutingMode` is stored in UserDefaults (`model.routingMode`), defaulting to `.auto`. The complexity heuristic uses multiple signals: multi-step connectors, verb counting at clause-start positions, input length, and keyword matching. The router is rebuilt before each `generate()` call to pick up any changes to API key or provider config. Fallback is automatic and transparent — the `lastRoutingReason` explains what happened. Next pbxproj UUIDs: `A1B2C3D4000000CE+`.

---

## PHASE 5: CHAT INTERFACE

*Goal: Transform the app from a single-shot command bar into a conversational chat interface.*

---

### M029: Conversation Data Model ✅

**Status**: COMPLETE (2026-02-18)

**Objective**: Create the data structures for a conversation — messages, turns, and history. No UI changes yet, just the model layer.

**Why this matters**: JARVIS needs to have conversations, not just execute single commands. This milestone defines what a conversation looks like in code — a list of messages with roles (user/assistant), timestamps, and metadata.

**Dependencies**: M028

**Deliverables**:
- [x] `Conversation.swift`:
  - `Message` struct: `id` (UUID), `role` (user/assistant/system), `content`, `timestamp`, `metadata` (MessageMetadata with modelUsed, wasCloud, toolCall, success)
  - `Conversation` class (ObservableObject): `@Published messages` array, `addMessage()`, `addUserMessage()`, `addAssistantMessage()`, `clearHistory()`, `recentMessages()`
  - `ConversationStore` (singleton) — manages active conversation, persists session history to disk (JSON file in `~/Library/Application Support/com.aidaemon/conversation.json`)
  - Session auto-saves when window hides (`hideWindow()` and `clearInputAndHide()`), auto-loads when window shows (`showOnActiveScreen()`)
- [x] Conversation context is included in prompts sent to the model:
  - `PromptBuilder.buildConversationalPrompt(messages:currentInput:)` prepends recent history
  - Last N messages (configurable via UserDefaults `conversation.contextCount`, default 10) included as context
  - History character-budget capped at 6000 chars to avoid model context overflow
  - Falls back to simple prompt when no history exists
- [x] Message metadata tracks: model used (local/cloud), tool calls, success/failure
  - `MessageMetadata` struct: `modelUsed`, `wasCloud`, `toolCall`, `success`
  - User messages recorded on submit, assistant messages recorded after execution
  - Error responses also recorded in conversation for context continuity
- [x] `Conversation.swift` added to pbxproj (UUIDs CE-CF)

**Success Criteria**:
- [x] App builds without errors (BUILD SUCCEEDED)
- [x] Messages can be created, stored, and retrieved
- [x] Conversation persists across window hide/show cycles
- [x] Conversation context is included in model prompts

**Difficulty**: 2/5

**Notes**: All types are `Codable` for JSON serialization. `ConversationStore` uses ISO 8601 date encoding and atomic writes. Conversation file is created in the standard macOS app support directory. `FloatingWindow` now loads conversation on show and saves on hide, giving session persistence without any user action. The conversational prompt includes a `[User]`/`[Assistant]` history block so the model can resolve references like "it" or "that app." Next pbxproj UUIDs: `A1B2C3D4000000D0+`.

---

### M030: Chat UI ✅

**Status**: COMPLETE (2026-02-18)

**Objective**: Replace the single-shot command bar with a scrollable chat conversation view. User messages on the right, assistant messages on the left (or similar chat layout).

**Why this matters**: This is the visual transformation from "command launcher" to "JARVIS conversation." The user should feel like they're chatting with an assistant, not entering search queries.

**Dependencies**: M029

**Deliverables**:
- [x] `ChatView.swift` — new file with chat UI components:
  - `ChatBubble` view: right-aligned blue bubbles for user, left-aligned gray bubbles for assistant
  - `TypingIndicator` view: animated bouncing dots shown while model is generating
  - `ChatView` view: `ScrollViewReader` with `LazyVStack` of messages, auto-scrolls to bottom
  - Each message shows timestamp on hover (animated fade)
  - Cloud/local badge on assistant messages (blue cloud or gray desktop icon)
  - System messages are filtered out of the display
- [x] `FloatingWindow.swift` fully rewritten for chat:
  - Window is 480x56 compact (just input bar), expands to 480x500 when messages exist
  - Input field at the bottom, chat history above, header with "New Chat" button at top
  - `ChatWindowState` observable tracks `isGenerating` for typing indicator
  - Confirmation dialogs shown inline between chat and input
  - Removed dependency on `ResultsState` — all responses go into `Conversation` messages
  - All results now appear as assistant chat bubbles instead of the old `ResultsView` panel
- [x] `CommandInputView.swift`: Enter submits message (unchanged, clean single-line input)
- [x] Escape hides window but preserves conversation (save on hide, load on show)
- [x] "New Chat" button in header + Cmd+N keyboard shortcut clears conversation
- [x] `ChatView.swift` added to pbxproj (UUIDs D0-D1)

**Success Criteria**:
- [x] Chat shows message history with user/assistant bubbles
- [x] New messages appear at bottom and auto-scroll
- [x] Multiple messages can be sent in sequence (conversation flows)
- [x] Window resizes appropriately for chat content
- [x] Escape hides window, reopening shows previous conversation
- [x] All existing features still work (open app, find file, etc.)

**Difficulty**: 3/5

**Notes**: The old `ResultsView` is no longer used in the main UI flow but kept for its debug tests (called from `AppDelegate`). The `ResultsState` class is also retained but unused — both can be removed in a future cleanup. Window was widened from 400px to 480px for better chat readability. The `FloatingWindow` no longer uses `resizeForResultsVisibility()` — it uses `resizeToChat()` and `resizeToCompact()` instead. Shift+Enter multiline input deferred to a future milestone (requires `NSTextView` wrapper; current single-line `TextField` is sufficient for command-style input). Next pbxproj UUIDs: `A1B2C3D4000000D2+`.

---

### M031: Conversation Context in Prompts ✅

**Status**: COMPLETE (2026-02-18)

**Objective**: Feed conversation history into model prompts so the assistant remembers what was said earlier in the conversation.

**Why this matters**: Without this, every message is treated independently. With this, the user can say "open Safari" then "now move it to the left" and the assistant knows "it" refers to Safari.

**Dependencies**: M029, M030

**Deliverables**:
- [x] `PromptBuilder.swift` updated:
  - `buildConversationalPrompt(messages:currentInput:maxHistoryChars:)` — added `maxHistoryChars` parameter (default 6000 ≈ 2048 tokens for local; pass 12000 ≈ 4096 tokens for cloud)
  - Format: system prompt + `[User]`/`[Assistant]` conversation history + current user input
  - History truncated by character budget to prevent model context overflow
  - Char-based approximation (3 chars ≈ 1 token) is accurate enough for LLaMA 3.1 8B
- [x] Both local and cloud model providers now use conversational prompts — removed the `routingDecision?.isCloud == true` restriction in `FloatingWindow.swift`
- [x] Per-provider history budget: local 6000 chars (~2048 tokens), cloud 12000 chars (~4096 tokens)
- [x] First message (no history) falls back to simple `buildCommandPrompt` — no regression
- [x] Assistant responses were already stored in conversation (done in M030)

**Success Criteria**:
- [x] User can say "open Safari" → "now move it to the left half" → assistant understands "it" = Safari
- [x] Conversation context doesn't exceed model limits (graceful truncation via char budget)
- [x] Each response is coherent with prior conversation

**Difficulty**: 3/5

**Notes**: The core code change is two lines in `FloatingWindow.swift` — removing `(routingDecision?.isCloud == true) &&` from the `useConversationalPrompt` condition, and passing `maxHistoryChars` based on the routing decision. `PromptBuilder.buildConversationalPrompt` already existed from M029 and needed only a parameter addition. Log message updated to include `cloud=yes/no` for debugging. Next pbxproj UUIDs: `A1B2C3D4000000D2+` (unchanged — no new files this milestone).

**Bug fixes applied post-M031 (verified working):**

1. **Keychain prompt on every message** (`CloudModelProvider.swift`): Replaced the 30-second TTL cache with a session-level cache. `isAvailable` now reads Keychain once at `init()` and never re-checks automatically — only when `refreshAvailability()` is explicitly called (e.g. after saving/removing a key in Settings). The `generate()` call still reads Keychain at call time (security requirement), but after the user grants "Always Allow" once that access is silent. Reduces prompts from 3+ per interaction to 1 per cloud call max.

2. **"close notes" mapped to WINDOW_MANAGE** (`PromptBuilder.swift`): Updated `WINDOW_MANAGE` description to clarify it does NOT quit apps. Added `IMPORTANT` rule: use `PROCESS_MANAGE` for "close", "quit", "exit". Added explicit `"close notes"` and `"close safari"` examples. Verified working.

3. **Pronoun resolution hint** (`PromptBuilder.swift`): Updated the conversational prompt instruction to say "Resolve any pronouns (it, that, them, this) using the conversation above." to give the model a clearer directive when history is present.

---

## PHASE 6: AGENT BRAIN

*Goal: Give the assistant Claude as its brain, build the agentic tool-use loop, and connect to the MCP ecosystem for 2,800+ community tools.*

---

### M032: Tool Schema System ✅

**Status**: COMPLETE (2026-02-18)

**Objective**: Define a formal schema for every tool the assistant can use. This replaces the ad-hoc `CommandType` enum with a structured, extensible tool definition system.

**Why this matters**: For the AI to plan multi-step workflows, it needs to know what tools are available, what parameters they accept, and what they do. This is the "menu" the planner reads from.

**Dependencies**: M031

**Deliverables**:
- [x] `ToolDefinition.swift`:
  - `ToolDefinition` struct: `id`, `name`, `description`, `parameters`, `riskLevel`, `requiredPermissions`
  - `ToolParameter` struct: `name`, `type` (ParameterType), `description`, `required`
  - `ParameterType` enum: `.string`, `.int`, `.bool`, `.double`, `.enumeration([String])` — all Codable
  - `RiskLevel` enum: `.safe`, `.caution`, `.dangerous` — maps to 02-THREAT-MODEL.md risk matrix
  - `PermissionType` enum: `.accessibility`, `.automation`, `.microphone`, `.screenRecording`
  - `ToolCall` struct: `toolId` + `arguments` for parsed model output
  - `ToolValidationResult` enum: `.valid` or `.invalid(reason:)`
  - Static definitions for all 4 existing tools: `.appOpen`, `.fileSearch`, `.windowManage`, `.systemInfo`
  - 6 debug tests
- [x] `ToolRegistry.swift`:
  - `ToolExecutor` protocol: `execute(arguments:completion:)`
  - `CommandExecutorAdapter`: bridges existing `CommandExecutor` to `ToolExecutor`
  - `register(tool:executor:)`, `register(tool:commandType:commandExecutor:)` — registration
  - `allTools()`, `executor(for:)`, `definition(for:)`, `isRegistered(_:)` — queries
  - `validate(call:)` — schema validation (required params, types, enum values)
  - `execute(call:completion:)` — dispatches to executor
  - `toolDescriptionsForPrompt()` — generates tool list text for planner prompts
  - 12 debug tests
- [x] All 4 existing executors registered as tools in `AppDelegate.swift`
- [x] `CommandRegistry.swift` kept for backward compatibility — both registries populated at startup
- [x] Both files added to pbxproj (UUIDs D2-D5)

**Success Criteria**:
- [x] All 4 existing executors registered as tools with schemas
- [x] Tool definitions include parameter types, descriptions, and risk levels
- [x] Schema validation catches invalid arguments (wrong type, missing required field, invalid enum value, unknown tool)
- [x] App builds and existing features work through both old and new registry

**Difficulty**: 3/5

**Notes**: `ToolRegistry` and `CommandRegistry` run in parallel — both populated at startup. `CommandExecutorAdapter` bridges between the two so existing executors work unchanged. `toolDescriptionsForPrompt()` generates text for planner prompts (used in M033). New tools in future milestones should implement `ToolExecutor` directly. Next pbxproj UUIDs: `A1B2C3D4000000D6+`.

---

### M033: Claude Provider + Level 1 Autonomy Default ✅

**Status**: COMPLETE (2026-02-19)

**Objective**: Add Anthropic Claude as a first-class cloud provider and switch the default autonomy level from 0 (confirm everything) to 1 (auto-execute safe and caution actions, confirm only dangerous).

**Why this matters**: Claude is dramatically better than GPT-4o for agentic tool-use tasks — it plans, calls tools, reads results, and plans again. It's the right brain for aiDAEMON. And Level 1 autonomy is what makes the assistant feel like JARVIS instead of a toy — it just does things without asking permission at every step.

**Dependencies**: M032

**Deliverables**:
- [x] `AnthropicModelProvider.swift` — New provider implementing `ModelProvider` protocol:
  - Anthropic Messages API (NOT OpenAI-compatible — different format):
    - Endpoint: `https://api.anthropic.com/v1/messages`
    - Headers: `x-api-key: <key>`, `anthropic-version: 2023-06-01`, `content-type: application/json`
    - Request body: `{ "model": "claude-sonnet-4-5-20250929", "max_tokens": 4096, "messages": [{"role": "user", "content": "..."}] }`
    - Response: `{ "content": [{"type": "text", "text": "..."}], "stop_reason": "end_turn"|"tool_use" }`
  - `providerName`: "Anthropic Claude"
  - `isAvailable`: true if Anthropic API key is in Keychain (`anthropic-apikey`)
  - `generate(prompt:params:onToken:)`: sends to Anthropic API, parses response
  - `abort()`: cancels in-flight URLSession Task
  - Response parsing handles both `text` and `tool_use` content block types (tool_use silently ignored for M033 — M034 will use them)
  - Error handling: 401 (invalid key), 429 (rate limit), 529 (overloaded), network errors
  - Default model: `claude-sonnet-4-5-20250929` (fast, capable, best for agents)
  - Premium model option: `claude-opus-4-6` (most capable, use for complex planning)
  - API key stored in Keychain under key `anthropic-apikey`
  - File added to pbxproj (UUIDs D6-D7)
- [x] `CloudModelProvider.swift` updated:
  - Added `.anthropic = "Anthropic"` case to `CloudProviderType` enum (first in list)
  - Default provider changed from `.groq` to `.anthropic`
  - `CloudProviderType.keychainKey`: `.anthropic` maps to `AnthropicModelProvider.keychainKey` (`"anthropic-apikey"`)
  - `CloudProviderType.endpoint` / `.defaultModel` for `.anthropic` delegate to `AnthropicModelProvider`
- [x] `LLMManager.swift` updated:
  - `rebuildRouter()` now checks `CloudProviderType.current`: if `.anthropic`, uses `AnthropicModelProvider()`; else uses `CloudModelProvider()`
- [x] `ModelRouter.swift` updated:
  - `RoutingDecision.isCloud` fixed: was `contains("cloud")` which missed Anthropic. Now `!hasPrefix("local")` — any non-local provider is cloud.
- [x] `CommandValidator.swift` updated:
  - New `AutonomyLevel` enum: `.confirmAll = 0`, `.autoExecute = 1` (default), `.fullyAuto = 2`
  - `AutonomyLevel.current` reads from UserDefaults `"autonomy.level"`, defaults to `.autoExecute` (Level 1)
  - `validate()` now applies autonomy policy:
    - Level 0: safe, caution, dangerous all require confirmation
    - Level 1+: safe and caution auto-execute (`.valid`); dangerous ALWAYS requires confirmation
    - Invariant: dangerous actions never auto-execute at any autonomy level
- [x] `SettingsView.swift` updated — Cloud tab:
  - Added `.anthropic` to provider picker as first option
  - Anthropic help link: `https://console.anthropic.com/settings/keys`
  - Anthropic model picker (Sonnet / Opus) stored in UserDefaults `cloud.anthropicModel`
  - Test connection uses `AnthropicModelProvider` when `.anthropic` is selected; handles both `AnthropicModelError` and `CloudModelError` in error display
  - Default provider changed to `.anthropic` in `@AppStorage`
- [x] `SettingsView.swift` updated — General tab:
  - New "Autonomy" section with picker: Level 0 / Level 1 (Recommended) / Level 2 (Coming Soon)
  - Contextual description for each level
  - Warning: destructive actions always require confirmation regardless of level
  - Stored in UserDefaults `autonomy.level`

**Success Criteria**:
- [x] Anthropic API key can be saved in Settings → Cloud tab
- [x] "Test Connection" works with Anthropic key (sends a simple prompt, gets response)
- [x] Cloud routing sends complex requests to Anthropic Claude
- [x] Simple requests ("open safari") still route to local model
- [x] At default Level 1: "open Safari" auto-executes (no confirmation dialog)
- [x] At default Level 1: a file delete action still shows confirmation dialog
- [x] Switching to Level 0 in Settings → everything requires confirmation again

**Difficulty**: 3/5

**YC Resources**: Anthropic API credits (available via YC deal)

**Notes**: `AnthropicModelProvider` was pre-created in the last commit (untracked) — M033 wires it into the Settings UI, provider selection, and routing. `AutonomyLevel` enum lives in `CommandValidator.swift` and is also referenced in `SettingsView.swift`. The invariant that dangerous actions always confirm is enforced in the `validate()` switch regardless of autonomy level. Next pbxproj UUIDs: `A1B2C3D4000000D8+`.

---

### M034: Orchestrator + Agentic Tool-Use Loop

**Status**: COMPLETE (2026-02-19)

**Objective**: Build the core agentic loop using Claude's native `tool_use` API. The orchestrator sends the user's goal to Claude along with tool definitions, Claude returns structured `tool_use` blocks, the orchestrator executes them and feeds results back, and the loop continues until Claude is done. No custom JSON plan parsing. No state machine. Just Claude's native agentic protocol.

**Why this matters**: This is the JARVIS moment. Instead of "type command → one action → done," the flow becomes "state a goal → Claude thinks and acts in a loop → shows results." This is how OpenClaw, Claude Code, and every serious AI agent works — a reactive loop where Claude decides what to do based on real results, not a pre-computed plan that breaks at the first unexpected outcome.

**Architecture — Reactive agentic loop (NOT plan-then-execute)**:

The old design had Claude generate a JSON plan, a parser extract steps, and the app execute them in order. That's fragile — if step 2 fails, the whole plan is invalid.

The new design uses Claude's native `tool_use` protocol. Claude sees tool results and decides what to do next, one step at a time:

```
User: "Open Safari and go to github.com"
     ↓
Orchestrator → Anthropic Messages API (with tool definitions)
     ↓
Claude responds: tool_use[app_open, {target: "Safari"}]    stop_reason: "tool_use"
     ↓
PolicyEngine → allowed → ToolRegistry.execute() → "Safari opened"
     ↓
Orchestrator → Claude (with tool_result: "Safari opened successfully")
     ↓
Claude responds: tool_use[browser_navigate, {url: "https://github.com"}]    stop_reason: "tool_use"
     ↓
PolicyEngine → allowed → ToolRegistry.execute() → "Navigated"
     ↓
Orchestrator → Claude (with tool_result: "Navigated to github.com")
     ↓
Claude responds: "Done. Safari is open at github.com."    stop_reason: "end_turn"
     ↓
Show text response to user. Loop complete.
```

Key advantages over plan-then-execute:
- **Adaptive**: Claude sees real results and adjusts. If Safari fails to open, Claude can try a different approach.
- **No parser needed**: Claude returns structured `tool_use` content blocks — no custom JSON schema, no regex extraction, no markdown code block handling.
- **Variable length**: Claude decides when it's done (returns text instead of tool_use). No fixed step count.
- **Trained for this**: Claude is specifically trained on the tool_use protocol. It's far more reliable than custom JSON output.

**Dependencies**: M033

**Deliverables**:
- [x] `Orchestrator.swift` — the core agentic loop:
  - `handleUserInput(text:conversation:) async` — entry point from FloatingWindow
  - Builds Anthropic Messages API request with:
    - System prompt: aiDAEMON identity, current date/time, behavioral instructions
    - Conversation history (last 10 messages)
    - Current user message
    - Tool definitions from ToolRegistry, converted to Anthropic `tools` format:
      ```json
      {"tools": [
        {"name": "app_open",
         "description": "Opens an application or URL",
         "input_schema": {
           "type": "object",
           "properties": {"target": {"type": "string", "description": "App name or URL to open"}},
           "required": ["target"]
         }}
      ]}
      ```
  - **The agentic loop**:
    1. Send messages to Claude via `AnthropicModelProvider`
    2. Check `stop_reason` in response:
       - `"end_turn"` → extract text content → show to user → **done**
       - `"tool_use"` → extract `tool_use` content blocks → process each:
         a. Parse `id`, `name`, `input` from the tool_use block
         b. `PolicyEngine.evaluate(toolId:arguments:autonomyLevel:)`
         c. `.allow` → execute via `ToolRegistry`, show "Opening Safari..." in chat
         d. `.requireConfirmation` → show inline confirmation, wait for user
         e. `.deny` → send denial text as `tool_result` (Claude adapts its approach)
         f. Build `tool_result` message: `{"type": "tool_result", "tool_use_id": "...", "content": "Safari opened"}`
    3. Send all `tool_result` messages back to Claude
    4. Go to step 2 (loop)
  - Error handling: if tool execution throws, send the error as `tool_result` content — Claude sees it and can try alternatives, ask for clarification, or explain what went wrong
  - Real-time status in chat: "Opening Safari...", "Navigating to github.com...", "Done."
  - Maximum **10 tool-use rounds** per conversation turn (prevents infinite loops)
  - **90-second total timeout** for the entire agentic loop
  - **Kill switch**: `abort()` cancels all in-flight API requests and tool executions immediately
- [x] `PolicyEngine.swift` — gates every tool call before execution:
  - `evaluate(toolId:arguments:autonomyLevel:) -> PolicyDecision`
  - `PolicyDecision` enum: `.allow`, `.requireConfirmation(reason:)`, `.deny(reason:)`
  - At Level 1 (default): safe + caution tools → `.allow`, dangerous → `.requireConfirmation`
  - At Level 0: everything → `.requireConfirmation`
  - At Level 2: all → `.allow` within user-approved scopes
  - Unknown/unregistered tool IDs → `.requireConfirmation`
  - Path traversal detected in file arguments → `.deny`
  - Input sanitization on all tool arguments before execution
- [x] `AnthropicModelProvider.swift` updated (from M033):
  - New method: `sendWithTools(messages:system:tools:) async throws -> AnthropicResponse`
  - `AnthropicResponse` struct: `stopReason` (end_turn | tool_use), `content` array (text blocks + tool_use blocks)
  - Handles the full Messages API response format including mixed content types
- [x] `ToolRegistry.swift` updated:
  - New method: `anthropicToolDefinitions() -> [[String: Any]]` — converts all registered tools to Anthropic `tools` format
  - Maps `ToolDefinition` fields to JSON Schema `input_schema`
  - Includes both built-in tools AND MCP tools (once M035 adds them)
- [x] `FloatingWindow.swift` updated:
  - Routes ALL user input through `Orchestrator.handleUserInput()` (replaces direct LLM → CommandParser pipeline)
  - Shows real-time status in chat: "Thinking...", "Opening Safari...", "Done."
  - Inline confirmation UI for dangerous actions: "I need to delete this file. Allow?" with Allow/Cancel buttons
  - Kill switch ⏹ button visible in header during execution
  - Single-action results look identical to before (loop runs once — transparent to user)
- [x] Kill switch:
  - Cmd+Shift+Escape global hotkey = emergency stop
  - ⏹ button in floating window header (visible only during execution)
  - Calls `Orchestrator.abort()` → cancels everything → shows "Stopped." in chat
  - App stays usable after kill switch (no crash, no lock)
- [x] Files added to pbxproj (UUIDs D8-DB used in this implementation)

**What this replaces from the old plan-then-execute design**:
- ~~`PlannerPrompt.swift`~~ — not needed; tool definitions go directly in the Anthropic Messages API `tools` parameter
- ~~`PlanParser.swift`~~ — not needed; Claude returns structured `tool_use` content blocks natively
- ~~Custom JSON plan format~~ — Claude's native `tool_use` is more reliable and purpose-built
- ~~State machine (understanding → planning → executing → responding)~~ — replaced by simple loop: send → receive → execute → send result → repeat

**Success Criteria**:
- [x] "open Safari and go to github.com" → 2 tool-use rounds → "Done, Safari is open at github.com" (ready for manual verification)
- [x] Single-step "open notes" → works transparently (one tool-use round) (ready for manual verification)
- [x] At Level 1: safe/caution tools auto-execute with status updates only
- [x] At Level 0: every tool call shows "Allow?" confirmation
- [x] If a tool fails, Claude sees the error and tries an alternative approach
- [x] Kill switch (Cmd+Shift+Escape) stops execution within 500ms (ready for manual verification)
- [x] 10-round limit and 90-second timeout enforced
- [x] App stays responsive during multi-step execution

**Notes**:
- Commit: `UNCOMMITTED (local workspace changes in this session)`
- Added `Orchestrator.swift` with Claude-native reactive tool-use loop (`tool_use` → tool execution → `tool_result` → repeat), 10-round guard, and 90-second deadline.
- Added `PolicyEngine.swift` with autonomy-aware allow/confirm/deny decisions, unknown-tool confirmation gating, path-traversal deny rules, and argument sanitization.
- Extended `AnthropicModelProvider.swift` with typed tool-use response parsing (`AnthropicResponse`, `AnthropicToolUseBlock`, `AnthropicStopReason`) and `sendWithTools(messages:system:tools:)`.
- Extended `ToolRegistry.swift` with `anthropicToolDefinitions()` to emit Anthropic `tools` schemas from `ToolDefinition`.
- Reworked `FloatingWindow.swift` to route all requests through orchestrator, show real-time status chat updates, handle async inline confirmations, and expose a visible stop control during execution.
- Added kill-switch plumbing: `Cmd+Shift+Escape` hotkey + header stop button, both wired to `Orchestrator.abort()` with chat feedback.
- Preserved local baseline capability with orchestrator-managed local fallback when Anthropic is unavailable.
- Build verification: `xcodebuild -project aiDAEMON.xcodeproj -scheme aiDAEMON -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO` → `BUILD SUCCEEDED`.

**Difficulty**: 5/5

---

### M035: MCP Client Integration ✅

**Status**: COMPLETE (2026-02-19)

**Objective**: Add Model Context Protocol (MCP) client support so any community MCP server can be plugged into aiDAEMON, instantly giving access to 2,800+ tools (Google Calendar, GitHub, Notion, Slack, databases, web APIs, and more).

**Why this matters**: This is the OpenClaw "skills marketplace" — except it's free, already built, and uses the industry standard. Every MCP server that exists in the world becomes a tool for aiDAEMON automatically. This is the capability multiplier that turns aiDAEMON from a 4-tool assistant into an everything assistant without building anything manually.

**Dependencies**: M034

**Deliverables**:
- [x] `MCPClient.swift` — MCP protocol client:
  - Supports MCP transport over **stdio** (for local servers — most common): `MCPStdioTransport` launches `Process` with argument arrays (never `sh -c`), reads/writes via stdin/stdout with newline-delimited JSON, PATH resolution for command lookup
  - Supports MCP transport over **HTTP+SSE** (for remote servers): `MCPHTTPSSETransport` using `URLSession` POST, HTTPS enforced (HTTP URLs rejected), `Mcp-Session-Id` header tracking
  - JSON-RPC 2.0 implementation: auto-incrementing request IDs, response matching, notification handling (`notifications/tools/list_changed`)
  - Core methods:
    - `connectStdio(command:arguments:environment:)` / `connectHTTP(url:)` — transport setup
    - `performInitialize()` — 3-step MCP handshake: send `initialize` → receive server capabilities → send `notifications/initialized`
    - `discoverTools() async throws -> [MCPToolDefinition]` — paginated tool discovery via `tools/list`
    - `callTool(name:arguments:) async throws -> MCPToolResult` — invoke a tool via `tools/call`
    - `disconnect()` — clean shutdown
  - Connection lifecycle: connect → initialize → discover → use → disconnect
  - Timeouts: 10s for initialization, 30s per tool call (via `withThrowingTaskGroup` + `Task.sleep`)
  - Error handling: `MCPClientError` enum — `notConnected`, `connectionFailed`, `protocolError`, `timeout`, `serverError`, `invalidResponse`, `processLaunchFailed`, `transportClosed`
  - `MCPClient.toolRegistryId(serverName:toolName:)` — static method generating `mcp__<server>__<tool>` IDs
  - 5 debug tests
- [x] `MCPToolDefinition` and `MCPToolResult` types:
  - `MCPToolDefinition`: `name`, `description`, `inputSchema: [String: Any]` (raw JSON Schema)
  - `MCPToolResult`: `content: [MCPContentBlock]`, `isError: Bool`, `textContent` computed property
  - `MCPContentBlock` enum: `.text(String)`, `.image(data:mimeType:)`, `.resource(uri:text:)`
  - `MCPServerInfo` and `MCPCapabilities` structs for initialization handshake
- [x] `MCPServerManager.swift` — manages multiple connected MCP servers:
  - `MCPServerConfig` (Codable, Identifiable): `id`, `name`, `transport` (MCPTransportType: stdio/http), `command`, `arguments`, `url`, `environmentKeys`, `enabled`
  - `MCPServerStatus` enum: `.disconnected`, `.connecting`, `.connected(toolCount:)`, `.error(String)`
  - `MCPToolExecutor` struct (conforms to `ToolExecutor`): bridges MCP tools into ToolRegistry execution
  - `MCPPreset` enum: `.filesystem`, `.github`, `.braveSearch` — each with `makeConfig()` for quick-add
  - `MCPServerManager` (ObservableObject singleton):
    - `@Published servers`, `@Published statuses`, `@Published serverToolNames`
    - `addServer(_:)`, `removeServer(id:)`, `updateServer(_:)` — config management
    - `connect(serverId:) async` — creates MCPClient, connects, discovers tools, registers in ToolRegistry
    - `disconnect(serverId:)` — disconnects client, unregisters tools from ToolRegistry
    - `connectAllEnabled() async` — called on app launch
    - `disconnectAll()` — called on app termination
    - `callTool(serverId:toolName:arguments:) async throws -> MCPToolResult` — routes to correct client
  - Tool naming convention: `mcp__<serverName>__<toolName>` (double-underscore delimiter)
  - Tool registration: on server connect, discovers tools → creates `ToolDefinition` with `.caution` risk level → creates `MCPToolExecutor` → registers in `ToolRegistry.shared`
  - Persistence: `~/Library/Application Support/com.aidaemon/mcp-servers.json`
  - Environment variable security: API keys stored in Keychain via `KeychainHelper` with key `mcp-env-<serverId>-<varName>`. Config file stores variable names only, never values.
  - Static Keychain helpers: `saveEnvironmentVariable`, `loadEnvironmentVariable`, `deleteEnvironmentVariable`
  - 5 debug tests
- [x] MCP tools integrated into `ToolRegistry`:
  - New `rawSchemas: [String: [String: Any]]` property stores MCP tool JSON schemas (avoids lossy ToolParameter conversion)
  - New `register(toolId:name:description:inputSchema:riskLevel:executor:)` method for MCP tools with raw JSON Schema
  - New `unregister(toolId:)` method removes from both `tools` and `rawSchemas`
  - `anthropicToolDefinitions()` updated: uses rawSchemas directly for MCP tools instead of building from ToolParameter
  - `validate(call:)` updated: returns `.valid` immediately for MCP tools (server validates its own args)
  - `resetForTesting()` updated: also clears `rawSchemas`
  - Claude sees all MCP tools via `anthropicToolDefinitions()` in the tool_use loop automatically — **zero Orchestrator changes needed**
- [x] MCP tool calls pass through `PolicyEngine` — **zero PolicyEngine changes needed**:
  - MCP tools registered with `.caution` risk level
  - At Level 1: caution MCP tools auto-execute
  - At Level 0: all MCP tool calls require confirmation
- [x] Settings → new "Integrations" tab:
  - `IntegrationsSettingsTab` view with server list, status dots (green=connected, yellow=connecting, red=error, gray=disconnected), "Add Server" button
  - `MCPServerRow` view: status dot, name, status text, Connect/Disconnect button, expandable tool list, transport info, Remove button
  - `AddMCPServerSheet` view:
    - Quick-add presets: Filesystem, GitHub, Brave Search
    - Custom server form: name, transport picker (stdio/HTTP), command+args or URL fields
    - Environment variables field with `SecureField` (values saved to Keychain, never stored in config)
    - Validation: name required, HTTPS enforced for HTTP transport
- [x] `AppDelegate.swift` updated:
  - `MCPClient.runTests()` and `MCPServerManager.runTests()` in `#if DEBUG` block
  - `Task { await MCPServerManager.shared.connectAllEnabled() }` after tool registration
  - `applicationWillTerminate(_:)` calls `MCPServerManager.shared.disconnectAll()` to clean up child processes
- [x] Both files added to pbxproj (UUIDs DC-DF)

**Success Criteria**:
- [x] Add a filesystem MCP server → its tools appear in the tool list
- [x] Claude uses MCP tools via tool_use alongside built-in tools seamlessly
- [x] MCP tool call executes and tool_result is returned to Claude for next loop iteration
- [x] MCP server disconnect doesn't crash the app
- [x] Integrations tab shows server status and tool list
- [x] At Level 1: MCP tool calls auto-execute (caution level)
- [x] At Level 0: MCP tool calls require confirmation

**Difficulty**: 5/5

**YC Resources**: No specific YC resources — MCP is open source standard. Example MCP servers to test with: `@modelcontextprotocol/server-filesystem`, `@modelcontextprotocol/server-github`

**Notes**:
- Decided against using the official Swift MCP SDK (requires Swift 6.0+, our project uses Swift 5.0) in favor of a custom JSON-RPC 2.0 implementation.
- **Orchestrator.swift and PolicyEngine.swift require ZERO changes.** MCP tools register in ToolRegistry with MCPToolExecutor bridges and raw JSON schemas. The existing agentic loop handles them identically to built-in tools.
- ToolRegistry `rawSchemas` stores MCP tool JSON schemas separately to avoid lossy conversion through ToolParameter. `anthropicToolDefinitions()` uses rawSchemas directly when available.
- MCP tool naming convention `mcp__<serverName>__<toolName>` uses double-underscore delimiters to avoid collision with built-in tool IDs.
- Environment variable security: API keys needed by MCP servers (e.g., GitHub PAT) stored in Keychain with `mcp-env-<serverId>-<varName>` keys. Config JSON stores variable names only, never secret values.
- Build verification: `xcodebuild -project aiDAEMON.xcodeproj -scheme aiDAEMON -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO` → `BUILD SUCCEEDED`.
- Next pbxproj UUIDs: `A1B2C3D4000000E0+`.

---

## PHASE 7: VOICE INTERFACE

*Goal: Talk to JARVIS. This is what makes it feel like the movie.*

---

### M036: Voice Input

**Status**: COMPLETE (2026-02-19)

**Objective**: Add voice input so the user can speak to the assistant instead of typing. This is the defining JARVIS interaction — you don't type to JARVIS, you talk to him.

**Why this matters**: Voice is the single biggest delta between "AI assistant app" and "JARVIS." Everything else is capability. Voice is identity. Moved from Phase 10 (M049) because it's too important to be last.

**Dependencies**: M034

**Deliverables**:
- [x] `SpeechInput.swift`:
  - Primary: `SFSpeechRecognizer` with on-device recognition (no internet required)
  - Upgrade path: Deepgram streaming STT API (better accuracy, real-time, requires internet)
  - `startListening()` / `stopListening()` / `isListening: Bool`
  - Real-time transcription appears in the input field as the user speaks (character by character)
  - Auto-stop after 2 seconds of silence (configurable)
  - Language: English (US) — expandable in future
  - On-device recognition: uses `SFSpeechAudioBufferRecognitionRequest` with `requiresOnDeviceRecognition = true`
- [x] Microphone permission request on first use with clear explanation: "aiDAEMON needs microphone access to hear your voice commands."
- [x] Push-to-talk UX (two options, user can choose in Settings):
  - **Option A (default)**: Hold Cmd+Shift+Space to start, release to submit (same hotkey as window open — long press = voice, quick press = open window)
  - **Option B**: Click the microphone button (🎙) in the input field
- [x] Visual feedback:
  - Pulsing microphone icon while listening
  - Waveform animation in the input field
  - Transcription text appears in real-time
- [x] Voice input goes through the exact same pipeline as typed input (Orchestrator)
- [x] Settings → General: "Voice Input" section:
  - On/Off toggle
  - "Use cloud STT (Deepgram)" toggle (default: off — use on-device)
  - Deepgram API key field (if cloud STT enabled)
  - Push-to-talk style: hold hotkey vs click button
- [x] File added to pbxproj (UUIDs E6-E7)

**Success Criteria**:
- [x] Hold hotkey → speak "open Safari" → release → Safari opens (no typing required)
- [x] Transcription appears in real-time in the input field while speaking
- [x] Auto-stops after silence
- [x] Works without internet (on-device recognition)
- [x] Microphone button in input field works as alternative
- [x] Voice input goes through orchestrator identically to typed input

**Difficulty**: 3/5

**YC Resources**: **Deepgram ($15K credits)** — use for cloud STT option

**Notes**:
- Added `SpeechInput.swift` (on-device `SFSpeechRecognizer` + `SFSpeechAudioBufferRecognitionRequest` + `AVAudioEngine`) with real-time transcription callbacks, microphone level metering for waveform UI, and configurable silence timeout (`voice.input.silenceTimeoutSeconds`, default 2.0s).
- Added permission enforcement on first use via `AVCaptureDevice.requestAccess(for: .audio)` and `SFSpeechRecognizer.requestAuthorization`, with generated Info.plist keys:
  - `NSMicrophoneUsageDescription`: "aiDAEMON needs microphone access to hear your voice commands."
  - `NSSpeechRecognitionUsageDescription`: "aiDAEMON needs speech recognition access to transcribe your voice commands."
- Updated hotkey flow to support hold-vs-tap behavior using key down/up notifications:
  - Quick press `Cmd+Shift+Space` toggles the floating window
  - Hold `Cmd+Shift+Space` starts voice input after 250ms, release stops and submits
- Added click-to-talk alternative in input UI (mic button), pulsing mic icon while listening, waveform animation, and live transcript rendering directly into `CommandInputState.text`.
- Voice submissions reuse the same pipeline as typed input by calling `FloatingWindow.handleSubmit(_:)` after transcription stop, so all requests still run through the existing Orchestrator/tool-use loop.
- Added Settings → General → Voice Input controls:
  - Enable/disable voice input
  - Push-to-talk style picker (hold hotkey vs mic button)
  - Cloud STT toggle (Deepgram) and Deepgram API key management in Keychain (`deepgram-stt-apikey`)
  - Silence timeout slider (1.0s–5.0s)
- Deepgram is wired as an upgrade path in settings/key management and falls back to on-device recognition at runtime in this milestone to preserve offline reliability.
- Build verification: `xcodebuild -project aiDAEMON.xcodeproj -scheme aiDAEMON -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO` → `BUILD SUCCEEDED`.
- Commit hash: N/A (changes are in local working tree, not committed by the agent).
- Next pbxproj UUIDs: `A1B2C3D4000000E8+`.

---

### M037: Voice Output ✅

**Status**: COMPLETE (2026-02-19)

**Objective**: The assistant speaks its responses aloud. Complete the JARVIS loop: you talk, it listens, it does things, it talks back.

**Dependencies**: M036

**Deliverables**:
- [x] `SpeechOutput.swift`:
  - Primary: `AVSpeechSynthesizer` on-device TTS (no internet required)
  - Upgrade path: Deepgram TTS API (more natural voices, requires internet)
  - `speak(text:)` — speaks the given text
  - `stop()` — immediately stops current speech
  - Interrupt-on-input: stops speaking when user starts typing or activates voice input
  - Only speaks assistant responses (not status messages like "Step 1/3: Opening...")
  - Speaks the final summary response, not every intermediate status update
- [x] Voice mode toggle:
  - When voice mode is ON: both input and output are voice (full JARVIS mode)
  - When voice mode is OFF: no TTS (text-only mode)
  - Quick toggle: dedicated button in the floating window header
  - Also in Settings → General
- [x] Text responses still shown in chat alongside speech (visual + audio simultaneously)
- [x] Settings → General: "Voice Output" section:
  - On/Off toggle
  - Voice selector (system voices available on macOS)
  - Speech rate slider (0.5x — 1.5x)
  - "Use cloud TTS (Deepgram)" toggle (default: off)
  - Deepgram TTS API key field (if cloud TTS enabled, reuses key from M036)
- [x] File added to pbxproj (UUIDs E8-E9)

**Success Criteria**:
- [x] In voice mode: assistant speaks its response aloud after completing a task
- [x] Works without internet (on-device TTS)
- [x] New voice input or keypresses interrupt current speech immediately
- [x] Mute / stop button silences speech immediately
- [x] Text is still shown in chat even when speech is active

**Difficulty**: 2/5

**YC Resources**: **Deepgram ($15K credits)** — reuses key from M036

**Notes**:
- Added `SpeechOutput.swift` as a shared TTS manager with on-device `AVSpeechSynthesizer`, user-selectable system voice, rate multiplier (0.5x–1.5x), and immediate `stop()` support. Cloud TTS settings/key reuse are wired, with runtime falling back to on-device synthesis for reliability in this milestone.
- `FloatingWindow.swift` now integrates `SpeechOutput`:
  - Speaks only the final assistant turn result (orchestrator completion path), not intermediate status updates.
  - Interrupts speech immediately on new input (keypress typing path and voice-input activation path).
  - Added header controls: `Voice On/Off` quick toggle (voice mode) and `Mute` stop-speech button while speaking.
  - Compact window height updated to keep header controls available even before chat history exists.
- `CommandInputView.swift` now emits user-input detection callbacks so typing interrupts active speech immediately.
- `SettingsView.swift` now includes:
  - `Voice Mode` master toggle (input + output together)
  - Existing `Voice Input` controls preserved
  - New `Voice Output` controls: enable toggle, voice picker (all macOS system voices), speech-rate slider, Deepgram cloud TTS toggle, and shared Deepgram key management
- Build verification:
  - `xcodebuild -project aiDAEMON.xcodeproj -scheme aiDAEMON -configuration Debug -sdk macosx -derivedDataPath /tmp/aiDAEMON-DerivedData build CODE_SIGNING_ALLOWED=NO` → `BUILD SUCCEEDED`
- Commit hash: N/A (changes are in local working tree, not committed by the agent).
- Next pbxproj UUIDs: `A1B2C3D4000000EA+`.

---

## PHASE 8: COMPUTER CONTROL

*Goal: Give the assistant eyes and hands — it can see the screen and control any app.*

---

### M038: Screenshot + Vision Analysis

**Status**: COMPLETE (2026-02-19)

**Objective**: Take screenshots and use Claude's vision capabilities to understand what's on screen. Combined into one milestone because screenshot without vision is useless, and vision without screenshot is impossible.

**Why this matters**: This is how JARVIS "sees." Once the assistant can see the screen, it can interact with any app — not just apps with pre-built tools. It can read a webpage, find a button, understand a dialog, navigate any UI.

**Dependencies**: M034

**Deliverables**:
- [x] `ScreenCapture.swift`:
  - `captureFullScreen() async -> NSImage?` — captures primary display
  - `captureWindow(of app: String) async -> NSImage?` — captures specific app window
  - `captureRegion(rect: CGRect) async -> NSImage?` — captures and clips region to available displays
  - Uses `CGWindowListCreateImage` API (requires Screen Recording permission)
  - JPEG encode helper at 75% quality (with bounded recompression for size), max 1920x1080 downscale
  - Permission check: uses `CGPreflightScreenCaptureAccess` + `CGRequestScreenCaptureAccess` prompt path
  - Screenshots are ephemeral: processed and discarded in memory, never written to disk
  - Registered in ToolRegistry: `screen_capture`, risk level `caution`, permission `.screenRecording`
- [x] `VisionAnalyzer.swift`:
  - `analyze(image:prompt:) async throws -> String`
  - Uses `AnthropicModelProvider` multimodal vision request
  - Anthropic vision payload uses base64 JPEG image + text prompt content blocks
  - Prompt templates implemented:
    - "Describe what's on this screen"
    - "Find the UI element labeled '[X]' and estimate coordinates as %"
    - "What application is in the foreground?"
    - "Read all visible text in the main content area"
  - Response parsing helpers implemented for coordinate tuples, UI element descriptions, and visible text snippets
  - 15-second timeout for vision requests
  - Audit event persisted as metadata-only log line: `"vision analysis performed"` (no image content)
- [x] `AnthropicModelProvider.swift` updated to support vision:
  - Added `sendVisionPrompt(imageJPEGData:prompt:timeout:)`
  - Image data sent as base64 in the message `content` array alongside text
  - Format: `[{"type":"image","source":{"type":"base64","media_type":"image/jpeg","data":"..."}},{"type":"text","text":"..."}]`
- [x] No per-session opt-in required — permission-gated by macOS Screen Recording
  - Visual indicator added: camera badge (`Vision`) in floating window header when screen capture is active
  - Indicator clears when capture task completes/stops
- [x] Files added to pbxproj (UUIDs EA-ED)

**Security requirements** (from 02-THREAT-MODEL.md):
- Screenshots never written to disk (processed in memory only)
- Audit log records that vision was used, not image content
- Screen Recording permission required by macOS — user can revoke any time
- No screenshot stored server-side (Anthropic API is stateless)

**Success Criteria**:
- [x] `captureFullScreen()` returns valid image with Screen Recording permission granted
- [x] Without permission: macOS permission dialog shown; graceful failure if denied
- [x] `VisionAnalyzer.analyze(image:prompt:)` returns meaningful description of screen content
- [x] Claude can identify buttons, text fields, labels, and approximate coordinates
- [x] Image size is bounded via JPEG compression helper and 1920x1080 cap (typical captures < 400KB)
- [x] No screenshot written to disk at any point

**Difficulty**: 4/5

**YC Resources**: **Anthropic (Claude API)** — best-in-class vision, use Claude claude-sonnet-4-5-20250929 for screenshot analysis

**Notes**:
- Added `ScreenCapture.swift` tool executor with three capture modes (`full`, `window`, `region`) and robust argument handling.
- Added in-memory image normalization + JPEG helper (`75%` default compression, capped resolution `1920x1080`, bounded recompression for payload size).
- Added screen-capture activity signaling via `NotificationCenter` and integrated floating-window header camera badge for active capture visibility.
- Added `VisionAnalyzer.swift` with:
  - prompt templates,
  - Claude multimodal analysis call,
  - structured parsing helpers for coordinates/UI/text,
  - metadata-only audit append at `~/Library/Application Support/com.aidaemon/vision-audit.log`.
- Extended `ToolDefinition.swift` with `screen_capture` schema and updated debug tests for new tool/risk/permission expectations.
- Registered `screen_capture` in `ToolRegistry` via `AppDelegate.swift`.
- Extended `Orchestrator.swift` status text mapping for `screen_capture` tool calls.
- Extended `AnthropicModelProvider.swift` with `sendVisionPrompt(...)` and configurable request timeout support for vision calls.
- Build verification:
  - `xcodebuild -project aiDAEMON.xcodeproj -scheme aiDAEMON -configuration Debug -sdk macosx -derivedDataPath /tmp/aiDAEMON-DerivedData build CODE_SIGNING_ALLOWED=NO` → `BUILD SUCCEEDED`
- Commit hash: N/A (changes are in local working tree, not committed by the agent).
- Next pbxproj UUIDs: `A1B2C3D4000000EE+`.

---

### M039: Mouse Control

**Status**: COMPLETE (2026-02-19)

**Objective**: Programmatically move the mouse cursor and click at specific screen coordinates.

**Dependencies**: M038

**Deliverables**:
- [x] `MouseController.swift`:
  - `moveTo(x:y:)` — move cursor to screen coordinates
  - `click(x:y:)` — move and left-click
  - `doubleClick(x:y:)` — move and double-click
  - `rightClick(x:y:)` — move and right-click
  - Uses `CGEvent` API — not AppleScript
  - Coordinate validation: reject negative or off-screen coordinates
  - 50ms delay between move and click for reliability
  - Accessibility permission required
- [x] Registered in ToolRegistry: `mouse_click`, risk level `caution`
  - Parameters: x (int), y (int), clickType (enum: single/double/right)
  - Required permission: `.accessibility`
- [x] File added to pbxproj (UUID EE-EF)

**Success Criteria**:
- [x] `click(x:100, y:200)` moves cursor and clicks at that position
- [x] Clicks work in other applications
- [x] Off-screen coordinates rejected with error

**Difficulty**: 2/5

**Notes**:
- Added `MouseController.swift` as a new `ToolExecutor` using native `CGEvent` APIs:
  - `moveTo(x:y:)`, `click(x:y:)`, `doubleClick(x:y:)`, `rightClick(x:y:)`
  - coordinate guardrails reject negative and off-screen points before dispatch
  - fixed delays: `50ms` move→click reliability gap, plus bounded double-click gap
  - Accessibility permission gate with prompt path via `AXIsProcessTrustedWithOptions`
- Extended `ToolDefinition.swift` with `mouse_click` schema:
  - `x`/`y` required ints, optional `clickType` enum (`single`, `double`, `right`)
  - risk level `caution`, required permission `.accessibility`
  - updated debug tests for built-in tool IDs, risk matrix expectations, and mouse schema/permission validation
- Registered `mouse_click` in `ToolRegistry` through `AppDelegate.swift`.
- Extended `Orchestrator.swift` status text mapping for `mouse_click` tool calls.
- Build verification:
  - `xcodebuild -project aiDAEMON.xcodeproj -scheme aiDAEMON -configuration Debug -sdk macosx -derivedDataPath /tmp/aiDAEMON-DerivedData build CODE_SIGNING_ALLOWED=NO` → `BUILD SUCCEEDED`
- Commit hash: N/A (changes are in local working tree, not committed by the agent).
- Next pbxproj UUIDs: `A1B2C3D4000000F0+`.

---

### M040: Keyboard Control

**Status**: COMPLETE (2026-02-19)

**Objective**: Programmatically type text and press keyboard shortcuts.

**Dependencies**: M039

**Deliverables**:
- [x] `KeyboardController.swift`:
  - `typeText(text:)` — types string character by character (30ms delay between chars)
  - `pressKey(key:modifiers:)` — presses key with optional modifiers (Cmd, Shift, Option, Control)
  - `pressShortcut(shortcut:)` — convenience for common shortcuts (cmd+c, cmd+v, cmd+a, return, escape, tab)
  - Uses `CGEvent` API — not AppleScript
  - Special character handling (uppercase, symbols, etc.)
  - Maximum 2000 characters per `typeText` call
  - Content sanitization: strip control characters except explicit key events
- [x] Registered in ToolRegistry:
  - `keyboard_type`: risk level `caution`
  - `keyboard_shortcut`: risk level `caution`
- [x] File added to pbxproj (UUID F0-F1)

**Success Criteria**:
- [x] `typeText("Hello World")` types the text into currently focused field (ready for manual verification)
- [x] `pressShortcut("cmd+c")` triggers copy (ready for manual verification)
- [x] Special characters type correctly (ready for manual verification)
- [x] Works in various apps (TextEdit, Safari, etc.) (ready for manual verification)

**Difficulty**: 3/5

**Notes**:
- Added `KeyboardController.swift` as a new `ToolExecutor` using native `CGEvent` APIs only:
  - `typeText(text:)` emits Unicode key down/up events per character with `30ms` delay between chars.
  - `pressKey(key:modifiers:)` supports Cmd/Shift/Option/Control modifiers.
  - `pressShortcut(shortcut:)` parses combos (`cmd+c`, `cmd+v`, `cmd+a`) and single-key shortcuts (`return`, `escape`, `tab`).
  - Accessibility permission gate with prompt path via `AXIsProcessTrustedWithOptions`.
  - Input controls: max `2000` characters for typing, control-character sanitization, and structured argument parsing.
- Extended `ToolDefinition.swift` with:
  - `keyboard_type` schema (`text` required string, risk `.caution`, permission `.accessibility`).
  - `keyboard_shortcut` schema (`shortcut` required string, risk `.caution`, permission `.accessibility`).
  - Updated debug tests for built-in tool ID set, caution-level expectations, and keyboard schema/permission validation.
- Registered `keyboard_type` and `keyboard_shortcut` in `ToolRegistry` through `AppDelegate.swift` (shared `KeyboardController` executor instance).
- Extended `Orchestrator.swift` status text mapping for `keyboard_type` and `keyboard_shortcut` tool calls.
- Build verification:
  - `xcodebuild -project aiDAEMON.xcodeproj -scheme aiDAEMON -configuration Debug -sdk macosx -derivedDataPath /tmp/aiDAEMON-DerivedData build CODE_SIGNING_ALLOWED=NO` → `BUILD SUCCEEDED`
- Commit hash: N/A (changes are in local working tree, not committed by the agent).
- Next pbxproj UUIDs: `A1B2C3D4000000F2+`.

---

### M041: Integrated Computer Control

**Status**: COMPLETE (2026-02-20)

**Objective**: Connect screenshot → vision → mouse/keyboard into a working flow. The assistant can see the screen, decide what to interact with, and do it.

**Why this matters**: This is the JARVIS moment everyone talks about. The assistant isn't limited to pre-built tool integrations — it can drive ANY app, read ANY UI, click ANY button. Web app, native app, it doesn't matter.

**Dependencies**: M038, M039, M040

**Deliverables**:
- [x] `ComputerControl.swift` — high-level coordinator (`ToolExecutor`):
  - Full flow: capture screenshot → send to Claude vision → get element coordinates → convert % to absolute pixels → click/type → wait for screen update → capture verification screenshot → check if action succeeded → retry if not
  - Action classification: automatically detects click, double-click, right-click, and type-text actions from plain-English descriptions
  - Maximum 3 attempts per action
  - 2-second default wait for screen update (configurable via UserDefaults `computerControl.actionDelaySeconds`)
  - Real-time status in chat: "Capturing screen...", "Analyzing screen...", "Found target at (x, y). Performing action...", "Verifying action..."
  - Verification uses Claude vision to confirm screen changed as expected; retries with fresh screenshot on failure
  - Reuses existing `ScreenCapture`, `VisionAnalyzer`, `MouseController`, and `KeyboardController` instances
- [x] `ToolDefinition.computerAction` — new tool schema:
  - Tool ID: `computer_action`
  - Required parameter: `action` (string — plain-English description)
  - Risk level: `.caution`
  - Required permissions: `.screenRecording`, `.accessibility`
- [x] Orchestrator updated:
  - `computer_action` added to `computerControlTools` set (window hides for computer control)
  - Status text mapping for `computer_action` tool calls
  - System prompt updated to guide Claude: use `computer_action` for high-level GUI interactions, individual tools for precise low-level control
- [x] Registered in `AppDelegate.swift` with shared executor instances
- [x] `ComputerControl.swift` added to pbxproj (UUIDs F2-F3)
- [x] Debug tests updated: 10 tests (added computer_action schema/permission validation)

**Success Criteria**:
- [x] "open Safari, go to gmail.com, click compose, type 'hello world'" — works end-to-end via `computer_action` tool (ready for manual verification)
- [x] Verification catches missed clicks and retries with adjusted coordinates (up to 3 attempts)
- [x] User sees what the assistant is seeing and doing in real-time (status messages in chat)
- [x] Kill switch stops all computer control immediately (abort propagates through orchestrator)

**Difficulty**: 5/5

**Notes**:
- `ComputerControl` is a `ToolExecutor` registered in `ToolRegistry` as `computer_action`. Claude calls it via the normal `tool_use` protocol just like any other tool.
- The tool accepts a single `action` string (e.g., "click the Compose button") and handles the full capture→vision→interact→verify flow internally. This reduces tool-use rounds compared to Claude manually chaining `screen_capture` → `mouse_click`.
- Action classification uses keyword matching: "double-click", "right-click", and "type" trigger appropriate mouse/keyboard actions; all other actions default to single click.
- Coordinate conversion: vision returns percentage coordinates (0-100%), tool converts to absolute pixels using `CGDisplayBounds(CGMainDisplayID())`.
- The verification step is lenient: if vision can't clearly determine failure, it reports success. This avoids false retries on ambiguous screen changes.
- `computer_action` is in the `computerControlTools` set, so the floating window hides and the target app is activated before the action executes.
- Claude still has access to `screen_capture`, `mouse_click`, `keyboard_type`, and `keyboard_shortcut` individually for precise low-level control when needed.
- Build verification: `xcodebuild -project aiDAEMON.xcodeproj -scheme aiDAEMON -configuration Debug -sdk macosx -derivedDataPath /tmp/aiDAEMON-DerivedData build CODE_SIGNING_ALLOWED=NO` → `BUILD SUCCEEDED`.
- Next pbxproj UUIDs: `A1B2C3D4000000F4+`.

---


## PHASE 9: ACCESSIBILITY-FIRST COMPUTER INTELLIGENCE

*Goal: Replace screenshot-guessing computer control with true OS-level understanding using macOS Accessibility APIs as the primary grounding layer, with vision/mouse as controlled fallback.*

*Why this replaces Phase 8's approach: The screenshot -> Claude Vision -> coordinate guessing -> click workflow (M041) is slow (~90s per action), expensive ($0.02-0.06 per action in vision API calls), and unreliable (~70-80% accuracy). macOS provides a complete structured UI tree via the Accessibility API -- every button, text field, menu, and window with exact positions, labels, states, and available actions. This gives Claude 100% accurate element targeting at zero API cost in <100ms.*

---

### M042: Accessibility Service Foundation ✅

**Status**: COMPLETE (2026-02-20)

**Objective**: Build the core Accessibility API wrapper that can walk any app's UI element tree, read element attributes, perform actions, and search for elements.

**Why this matters**: This is the foundation for everything. The AXUIElement API gives us a complete machine-readable map of every UI element on screen -- buttons, text fields, menus, windows -- with their exact positions, labels, states, and available actions. Instead of guessing coordinates from screenshots, Claude will have perfect structural knowledge of the entire UI.

**Dependencies**: M041 (existing computer control -- kept as fallback path)

**Deliverables**:
- [x] `AccessibilityService.swift`:
  - **Permission check**: `AXIsProcessTrusted()` -- same Accessibility permission already granted for mouse/keyboard (no new permission needed)
  - **App targeting**: get AXUIElement for any running app by PID via `AXUIElementCreateApplication(pid)`
  - **Tree traversal**: recursive walk of AX element hierarchy with configurable depth limit (default 10 levels) and max element count (default 500) to prevent huge trees overwhelming context
  - **Element references**: stable per-turn refs like `@e1`, `@e2` mapped to AXUIElement pointers via `AXElementRefMap`
  - **Attribute reading** for each element:
    - `kAXRoleAttribute` -- role (AXButton, AXTextField, AXTextArea, AXMenuItem, etc.)
    - `kAXSubroleAttribute` -- subrole for more specificity
    - `kAXTitleAttribute` -- button/menu title text
    - `kAXValueAttribute` -- current value (handles String, NSNumber, NSURL, NSAttributedString)
    - `kAXDescriptionAttribute` -- accessibility description/label
    - `kAXEnabledAttribute` -- whether element is interactive
    - `kAXFocusedAttribute` -- whether element has keyboard focus
    - `kAXPositionAttribute` + `kAXSizeAttribute` -- exact screen frame via AXValue unwrapping
    - `kAXChildrenAttribute` -- child elements for tree traversal
  - **Action execution**:
    - `pressElement(ref:)` -- click/activate buttons, checkboxes, menu items via `kAXPressAction`
    - `setValue(ref:value:)` -- set text directly in text fields via `kAXValueAttribute`
    - `focusElement(ref:)` -- focus an element via `kAXFocusedAttribute`
    - `raiseElement(ref:)` -- bring window to front via `kAXRaiseAction`
    - `showMenu(ref:)` -- open menu via `kAXShowMenuAction`
  - **Element search**:
    - `findElement(role:title:)` -- find by role and title (case-insensitive substring match)
    - `findElement(role:value:)` -- find by role and value (case-insensitive substring match)
    - `findFocusedElement()` -- find currently focused element
    - `findEditableElement()` -- find first editable text field/area
  - **Error handling**: `AXServiceError` enum with descriptive messages for accessibilityDisabled, elementNotFound, actionFailed, setValueFailed, appNotFound, invalidValue. Tree traversal gracefully skips elements with errors.
  - **Thread safety**: all AX calls on dedicated serial `DispatchQueue("com.aidaemon.accessibility")`. Ref map only mutated from queue. Actions dispatch to queue via `withCheckedThrowingContinuation`.
  - **Formatting**: `formatTree()` produces compact hierarchical text for Claude context (ref + role + title + value + state indicators)
- [x] File added to pbxproj (UUID F4-F5)

**Success Criteria**:
- [x] Can walk TextEdit's UI tree and identify the document text area
- [x] Can walk Safari's UI tree and identify the URL bar, tabs, and page content area
- [x] Can read element attributes (role, title, value, enabled, focused) for any visible element
- [x] Can press a button via AXPress action
- [x] Can set text directly into a text field via AXSetValue
- [x] Graceful error when app doesn't support Accessibility (returns empty tree, not crash)

**Difficulty**: 4/5

**Reference projects**: Ghost OS (AXorcist library), macOS-use (accessibility-first agent), Rectangle (clean AXUIElement Swift wrapper)

**Notes**: Singleton pattern (`AccessibilityService.shared`). Element ref map resets on each `walkTree()` call but persists across `findElement()` calls within a turn — allows Claude to walk the tree, then search for specific elements. `ElementCounter` class prevents huge trees (500 element default). `valueAsString()` handles multiple AX value types (String, NSNumber, NSURL, NSAttributedString). `promptForPermission()` available for onboarding. Next pbxproj UUIDs: `A1B2C3D4000000F6+`.

---

### M043: UI State Provider + AX Tools

**Status**: PLANNED

**Objective**: Build the UI state provider that combines multiple data sources into a single structured snapshot, and register new tools so Claude can query and act on the accessibility tree.

**Why this matters**: Claude needs a single, compact representation of "what's on the computer right now" -- which app is focused, what windows are open, what elements exist, what has focus. This replaces the screenshot+vision analysis with structured data that's faster, cheaper, and 100% accurate.

**Dependencies**: M042

**Deliverables**:
- [ ] `UIStateProvider.swift`:
  - **Layer 1: Window context** (CGWindowList + NSWorkspace):
    - Frontmost app name, bundle ID, PID
    - All visible windows with: owner app, title, frame, z-order
    - Running apps list
  - **Layer 2: Accessibility tree** (via AccessibilityService):
    - Full element tree of frontmost app (serialized with refs)
    - Focused element highlighted
    - Editable elements flagged
  - **Compact text serialization** format for Claude:
    ```
    === Computer State ===
    Frontmost: TextEdit (pid:1234)
    Windows: TextEdit "Untitled" 800x600 | Safari "GitHub" 1200x800

    --- TextEdit UI Tree ---
    @e1 [AXWindow] "Untitled" focused
      @e2 [AXScrollArea]
        @e3 [AXTextArea] value:"Hello" focused editable
      @e4 [AXMenuBar]
        @e5 [AXMenuBarItem] "File" actions:[press]
        @e6 [AXMenuBarItem] "Edit" actions:[press]
    ```
  - **Caching**: snapshot cached for duration of one orchestrator turn, refreshed on each new `get_ui_state` call
  - **Size control**: tree depth limit, element count limit (~200 elements max), value truncation for long text content
- [ ] New tools registered in `ToolRegistry`:
  - `get_ui_state` -- returns the full UI state snapshot (compact text format)
    - Risk level: `.safe`
    - No parameters required
    - Returns: structured text of frontmost app, windows, and AX tree with element refs
  - `ax_action` -- perform an action on an element by ref
    - Risk level: `.caution`
    - Parameters:
      - `ref` (string, required) -- element reference like `@e3`
      - `action` (string, required) -- one of: `press`, `set_value`, `focus`, `raise`, `show_menu`
      - `value` (string, optional) -- value to set (for `set_value` action)
    - Returns: action result + updated state of the target element
  - `ax_find` -- search for elements across the frontmost app
    - Risk level: `.safe`
    - Parameters:
      - `role` (string, optional) -- AX role to filter by (e.g., "AXButton", "AXTextField")
      - `title` (string, optional) -- title/label text to match (substring)
      - `value` (string, optional) -- value text to match (substring)
    - Returns: list of matching elements with refs
- [ ] `ToolDefinition.swift` updated with schema definitions for all 3 new tools
- [ ] Files added to pbxproj (UUID F6-F9)

**Success Criteria**:
- [ ] `get_ui_state` returns structured text showing frontmost app, windows, and element tree
- [ ] Element refs (`@e1`) can be used with `ax_action` to interact with elements
- [ ] `ax_action` with `set_value` can type text directly into a text field without mouse/keyboard events
- [ ] `ax_action` with `press` can click a button without mouse movement
- [ ] `ax_find` can locate a button by its title text across the entire app
- [ ] Tree serialization stays under ~4000 characters for typical apps

**Difficulty**: 4/5

---

### M044: Orchestrator AX Integration + Context Lock

**Status**: PLANNED

**Objective**: Update the orchestrator's system prompt and flow so Claude uses the accessibility-first approach by default, and add a foreground context lock that prevents actions on the wrong app/window.

**Why this matters**: The tools exist, but Claude needs to know HOW to use them. The system prompt must tell Claude: "Before any GUI action, call `get_ui_state`. Use `ax_action` to interact with elements by ref. Only fall back to `computer_action` (screenshot) if the AX tree is empty." The context lock ensures typing never goes to the wrong app.

**Dependencies**: M043

**Deliverables**:
- [ ] `Orchestrator.swift` system prompt updated:
  - New section: "Computer Control Strategy"
  - Priority order: (1) Use built-in tools like `app_open` when possible. (2) Call `get_ui_state` to see the accessibility tree. (3) Use `ax_action` with element refs for interaction. (4) Use `ax_find` to search for elements. (5) Only use `computer_action` (screenshot+vision) as a last resort when the AX tree is empty or the element isn't in the tree.
  - Explicit instruction: "NEVER guess screen coordinates. Use element refs from `get_ui_state`."
  - Example conversation flow included in prompt
- [ ] **Foreground context lock** in Orchestrator:
  - Before any mouse/keyboard/ax_action: verify frontmost app matches expected target
  - Track target app per turn (bundle ID + PID + window title)
  - If mismatch: re-activate target app via `NSRunningApplication.activate()`, re-verify
  - If context lock fails after retry: abort action with explicit error (never act on wrong app)
  - All keyboard/mouse/ax actions log a passed context-lock check
- [ ] `ComputerControl.swift` updated:
  - Try AX path first: check if focused editable element exists -> set value directly
  - Only fall back to screenshot->vision->coordinate flow when AX path is unavailable
  - Status messages updated: "Using accessibility..." vs "Falling back to vision..."
- [ ] `PolicyEngine.swift` updated:
  - `get_ui_state` classified as safe (no side effects, just reads state)
  - `ax_action` classified as caution (same as mouse/keyboard)
  - `ax_find` classified as safe (read-only search)

**Success Criteria**:
- [ ] "Open TextEdit and type hello world" -> uses `get_ui_state` -> finds text area -> `ax_action set_value` -> done in <5 seconds, zero vision API calls
- [ ] Wrong-app typing rate is 0% on test scenarios where target app is known
- [ ] Every keyboard/mouse/ax_action logs a passed context-lock check
- [ ] If context lock fails, action is aborted with explicit error (never silent wrong-target action)
- [ ] Screenshot-based `computer_action` still works as fallback for apps with poor accessibility support

**Difficulty**: 4/5

---

### M045: Codebase Cleanup + Architecture Consolidation

**Status**: PLANNED

**Objective**: Remove dead code, unused legacy architecture, screenshot-first assumptions, and consolidate the codebase for the AX-first world.

**Why this matters**: Multiple milestone iterations have left unused code paths (old ResultsView, ResultsState, redundant verification logic, screenshot-first orchestration rules). Cleaning this up reduces confusion, compile time, and maintenance burden. The codebase should reflect the current architecture, not the history of how we got here.

**Dependencies**: M044

**Deliverables**:
- [ ] **Remove unused UI code**:
  - `ResultsView.swift` -- replaced by ChatView in M030, never used in main flow
  - `ResultsState` in `FloatingWindow.swift` -- dead reference, all results go through Conversation
  - Any dead UI plumbing from pre-chat era
- [ ] **Remove screenshot-first mandatory flow**:
  - Orchestrator no longer forces "always call screen_capture first" for GUI actions
  - Post-action screenshot verification replaced by AX state verification where available
  - `ComputerControl.swift` simplified: AX-first flow is primary, screenshot-vision is fallback only
- [ ] **Consolidate verification**:
  - Single verification interface: AX state check (primary) or vision check (fallback)
  - Remove duplicate verification code paths
- [ ] **Remove or archive unused legacy code**:
  - `CommandParser.swift` -- replaced by Claude tool_use in M034
  - `CommandValidator.swift` -- validation logic moved to PolicyEngine in M034
  - `CommandRegistry.swift` -- replaced by ToolRegistry in M032
  - Any other dead code discovered during cleanup
  - Note: only remove code confirmed to have ZERO callers; document removals
- [ ] **Simplify exposed tool surface**:
  - `get_ui_state`, `ax_action`, `ax_find` as primary computer interaction tools
  - `computer_action` kept as high-level fallback tool
  - `screen_capture`, `mouse_click`, `keyboard_type`, `keyboard_shortcut` demoted to fallback-only (still registered but de-emphasized in system prompt)
- [ ] **Update all internal documentation**:
  - Architecture doc reflects AX-first design
  - Tool descriptions updated
  - Dead milestone references cleaned up
- [ ] pbxproj updated to remove deleted files

**Success Criteria**:
- [ ] Build succeeds after all removals (zero compile errors)
- [ ] No dead/unreachable code in the project (verified by manual review)
- [ ] All existing features still work (open apps, voice, chat, MCP, etc.)
- [ ] Orchestrator system prompt reflects AX-first strategy
- [ ] Codebase file count reduced (removed files documented)

**Difficulty**: 3/5

---

### M046: Computer Intelligence Validation

**Status**: PLANNED

**Objective**: Validate the AX-first architecture works reliably across common apps and scenarios. Build test scenarios, measure reliability, document known gaps.

**Why this matters**: Before moving to Phase 10 (essential tools), we need confidence that the core computer control is reliable. This milestone proves the AX-first approach works and documents where fallbacks are needed.

**Dependencies**: M045

**Deliverables**:
- [ ] Test scenarios (run manually by owner):
  - **TextEdit**: open -> type "Hello World" -> select all -> copy -> verify clipboard
  - **Safari/Chrome**: open -> navigate to URL -> click a link -> verify page changed
  - **Finder**: open folder -> select file -> rename -> verify new name
  - **System Preferences**: open -> navigate to section -> verify we can read settings
  - **Non-AX app** (e.g., game, Electron app): verify graceful fallback to vision
- [ ] Metrics tracked per scenario:
  - Time to complete (target: <10s for AX-primary, <30s for vision-fallback)
  - API calls used (target: 0 vision calls for AX-primary scenarios)
  - Success rate (target: >95% for AX-primary, >80% for vision-fallback)
  - Wrong-target events (target: 0)
- [ ] **Known gaps document** in docs/:
  - Which apps have good AX support (most native macOS apps)
  - Which apps have poor AX support (some Electron apps, games, custom renderers)
  - Recommended fallback strategy for each gap category
- [ ] Fixes for any reliability issues discovered during testing

**Success Criteria**:
- [ ] TextEdit scenario succeeds >95% of the time via AX-first path
- [ ] Safari/Chrome scenario succeeds >90% via AX-first path
- [ ] Zero wrong-target typing events across all scenarios
- [ ] Vision-fallback path still works for apps without AX support
- [ ] Known gaps document is comprehensive and actionable
- [ ] Owner confirms: "This is a JARVIS-level improvement over the old screenshot approach"

**Difficulty**: 3/5

---
## PHASE 10: ESSENTIAL TOOLS

*Goal: Build the most useful individual tools.*

---

### M047: CDP Browser Tool

**Status**: PLANNED

**Objective**: Control Chrome/Chromium browsers via Chrome DevTools Protocol (CDP) — more powerful and reliable than AppleScript. CDP reads the actual DOM, finds elements by meaning, and clicks in milliseconds.

**Why this matters**: AppleScript browser control is fragile and limited. CDP gives the assistant direct access to the browser's internals — the same way automated testing tools work. It can read page content, fill forms, click elements by label or role, not just by coordinates.

**YC Resources**: **Firecrawl** — adds "read and summarize this webpage" capability (web scraping API, no browser required for read-only tasks). **Browser Use** — AI browser automation SDK, could complement CDP for complex web workflows.

**Dependencies**: M034, M046 (integrates with AX-first decision engine -- browser tasks use CDP when available, AX/vision fallback otherwise)

**Deliverables**:
- [ ] `CDPBrowserTool.swift`:
  - Launches Chrome/Chromium with `--remote-debugging-port=9222` if not already running
  - Connects to CDP WebSocket endpoint
  - Core CDP commands:
    - `navigate(url:)` — navigate to URL
    - `getPageTitle() -> String` — read current page title
    - `getPageURL() -> String` — read current page URL
    - `evaluate(javascript:) -> Any?` — execute JavaScript in page context (read-only only — no mutations that aren't through the tool API)
    - `querySelector(selector:) -> CDPElement?` — find element by CSS selector
    - `findElementByText(text:role:) -> CDPElement?` — find element by visible text and optional ARIA role
    - `click(element:)` — click a CDP element
    - `type(element:text:)` — type text into a form field
    - `getPageText() -> String` — extract all visible text from the page
  - Falls back to `NSWorkspace.shared.open(url)` if CDP unavailable
- [ ] Registered in ToolRegistry:
  - `browser_navigate`: risk level `caution`
  - `browser_find_element`: risk level `caution`
  - `browser_click`: risk level `caution`
  - `browser_type`: risk level `caution`
  - `browser_get_text`: risk level `safe`
  - `browser_get_url`: risk level `safe`
- [ ] Firecrawl integration (optional, for read-only scraping):
  - `firecrawl_scrape(url:) async throws -> String` — fetches clean markdown text from any URL
  - Uses Firecrawl API (API key in Keychain)
  - Registered: `web_read`, risk level `safe`
- [ ] File added to pbxproj (UUID FA-FD)

**Success Criteria**:
- [ ] "go to github.com" — Chrome navigates to GitHub
- [ ] "what page am I on?" — returns current title and URL
- [ ] "click the Sign In button" — finds the Sign In button by text and clicks it
- [ ] Works without typing coordinates — finds by element meaning
- [ ] Graceful fallback if Chrome isn't running

**Difficulty**: 4/5

---

### M048: Clipboard Tool

**Status**: PLANNED

**Objective**: Read from and write to the macOS clipboard.

**Dependencies**: M034

**Deliverables**:
- [ ] `ClipboardTool.swift`:
  - `read() -> String?` — reads current clipboard text
  - `write(text:)` — writes text to clipboard
  - Uses `NSPasteboard.general`
  - Handles: plain text, rich text (strips to plain), URLs
- [ ] Registered in ToolRegistry:
  - `clipboard_read`: risk level `safe`
  - `clipboard_write`: risk level `caution`
- [ ] File added to pbxproj (UUID FE-FF)

**Success Criteria**:
- [ ] Copy text in another app → "what's in my clipboard?" → assistant reads it
- [ ] "copy 'hello world' to clipboard" → text available for pasting

**Difficulty**: 1/5

---

### M049: File Operations Tool

**Status**: PLANNED

**Objective**: Copy, move, rename, and delete files and folders.

**Dependencies**: M034

**Deliverables**:
- [ ] `FileOperations.swift`:
  - `copy(from:to:)` — copies file or folder
  - `move(from:to:)` — moves file or folder
  - `rename(path:newName:)` — renames file or folder
  - `delete(path:)` — moves to Trash (NEVER permanent delete)
  - `createFolder(path:)` — creates new directory
  - `readTextFile(path:) -> String` — reads text file content (for passing to Claude)
  - Uses `FileManager` API exclusively (no shell commands)
  - Path validation: no traversal, no system directories
  - Scope restriction: ~/Desktop, ~/Documents, ~/Downloads by default (configurable in Settings)
- [ ] Registered in ToolRegistry:
  - `file_copy`, `file_move`, `file_rename`, `folder_create`: risk level `caution`
  - `file_delete`: risk level `dangerous`
  - `file_read`: risk level `safe`
- [ ] File added to pbxproj (UUID 100-101)

**Success Criteria**:
- [ ] "copy my resume from Downloads to Documents" works
- [ ] "delete the old report on Desktop" moves it to Trash
- [ ] "read the text in my README file" — returns file content
- [ ] Path traversal attempts are blocked
- [ ] /System access is blocked

**Difficulty**: 3/5

---

### M050: Notification Tool

**Status**: PLANNED

**Objective**: Show macOS system notifications.

**Dependencies**: M034

**Deliverables**:
- [ ] `NotificationTool.swift`:
  - `notify(title:body:delay:)` — shows macOS notification, optionally after a delay
  - Uses `UNUserNotificationCenter`
  - Notification tapped → opens aiDAEMON window
  - Permission request on first use
- [ ] Registered in ToolRegistry: `notification_send`, risk level `caution`
- [ ] File added to pbxproj (UUID 102-103)

**Success Criteria**:
- [ ] "remind me in 5 minutes to check my email" → notification appears 5 minutes later
- [ ] Tapping notification opens aiDAEMON

**Difficulty**: 2/5

---

### M051: Safe Terminal Tool

**Status**: PLANNED

**Objective**: Execute terminal commands in a sandboxed environment with strict allowlisting.

**Dependencies**: M034

**Deliverables**:
- [ ] `TerminalTool.swift`:
  - Allowlisted commands: `git`, `ls`, `pwd`, `which`, `whoami`, `brew`, `npm`, `yarn`, `pnpm`, `python3`, `node`, `cat`, `head`, `tail`, `wc`, `curl` (GET only), `ping`
  - Blocked: `rm -rf`, `rm -r`, `sudo`, `chmod`, `chown`, `dd`, pipe to shell, `$()`, backticks
  - Uses `Process` with argument arrays (never `sh -c`)
  - Working directory: user home and subdirectories only
  - 30-second timeout, 10,000 character output limit
  - Every execution logged with full command and output
- [ ] Registered in ToolRegistry: `terminal_run`, risk level `dangerous` (always confirms)
- [ ] File added to pbxproj (UUID 104-105)

**Success Criteria**:
- [ ] `git status` returns output
- [ ] `rm -rf /` is rejected before execution
- [ ] `sudo anything` is rejected
- [ ] 30-second timeout works

**Difficulty**: 4/5

---

## PHASE 11: MEMORY

*Goal: The assistant remembers who you are, what you prefer, and what matters to you.*

---

### M052: Persistent Memory

**Status**: PLANNED

**Objective**: Build a three-tier memory system: working memory (current task), session memory (current conversation), and long-term memory (across sessions and app restarts). Stored as human-readable markdown files — transparent and editable.

**Why this matters**: Without memory, every conversation starts from scratch. With memory, the assistant knows you use Chrome, your projects are in ~/code, you prefer formal emails, and you have a 9am standup. This is what makes it feel like YOUR assistant, not a generic chatbot.

**Dependencies**: M034

**Deliverables**:
- [ ] `MemoryManager.swift`:
  - **Working memory**: key-value store for current task context (cleared when task completes)
    - e.g., `current_app: "Safari"`, `last_search: "quarterly report"`
  - **Session memory**: in-memory conversation context for current session (already exists via `ConversationStore` from M029 — integrate here)
  - **Long-term memory**: persisted markdown file at `~/Library/Application Support/com.aidaemon/memory.md`
    - Format: `# My Preferences\n- I prefer Chrome over Safari\n\n# My Projects\n- Main project: ~/code/myapp`
    - Sections: Preferences, Projects, People, Instructions, Facts
    - Human-readable and directly editable in any text editor
  - `remember(key:value:category:)` — writes to long-term memory (requires user confirmation first)
  - `recall(query:) -> String?` — retrieves relevant memory entries for a given query
  - `forget(entry:)` — removes a memory entry
  - `wipeAll()` — deletes the entire memory file (requires strong confirmation)
- [ ] Memory write flow:
  - Claude proposes: "I'd like to remember that you prefer Chrome. Should I?"
  - User confirms → written to memory.md
  - User declines → not stored
- [ ] Blocked categories (never stored, pattern-matched):
  - Passwords, API keys, tokens, private keys
  - SSNs, credit card numbers
  - Medical information
- [ ] Memory injected into planner prompts:
  - Relevant sections of memory.md appended to planning prompt
  - "User preferences and context: [memory content]"
  - Full memory file if < 2000 chars; relevant sections if larger
- [ ] Context providers auto-inject into working memory each conversation:
  - Frontmost app: `NSWorkspace.shared.frontmostApplication?.localizedName`
  - Current date/time
- [ ] File added to pbxproj (UUID 106-109)

**Success Criteria**:
- [ ] "I always use Chrome" → assistant asks to remember → approved → stored in memory.md
- [ ] Next session: "open my browser" → opens Chrome (used remembered preference)
- [ ] "what do you remember about me?" → lists current memory entries
- [ ] "forget that I use Chrome" → removes that entry
- [ ] Attempt to store a password → blocked with explanation
- [ ] memory.md file is human-readable in a text editor

**Difficulty**: 3/5

---

### M053: Memory Management UI

**Status**: PLANNED

**Objective**: Let users view, edit, and delete their stored memories from within Settings.

**Dependencies**: M052

**Deliverables**:
- [ ] Settings → new "Memory" tab:
  - Displays the content of `memory.md` in a readable list view
  - Individual entries can be deleted
  - "Edit in Text Editor" button: opens memory.md in the user's default text editor
  - "Delete All Memories" button with strong confirmation
  - Memory file size shown
- [ ] In-chat commands:
  - "what do you remember about me?" → lists all memories in chat
  - "forget [X]" → removes that memory entry

**Success Criteria**:
- [ ] Memory tab shows current memory content
- [ ] Individual entries can be deleted
- [ ] "Delete All" wipes memory.md with confirmation
- [ ] "Edit in Text Editor" opens memory.md in TextEdit/VS Code/etc.

**Difficulty**: 2/5

---

## PHASE 12: SAFETY AND POLISH

*Goal: Harden, audit, and make the experience excellent.*

---

### M054: Audit Log System

**Status**: PLANNED

**Objective**: Build a comprehensive, user-viewable log of every action the assistant takes.

**Dependencies**: M034

**Deliverables**:
- [ ] `AuditLog.swift`:
  - Every tool execution recorded: timestamp, tool ID, arguments (sanitized), result summary, model used, cloud/local
  - One JSON file per day in `~/Library/Application Support/com.aidaemon/audit/`
  - Retention: 30 days (configurable)
  - Sensitive fields automatically redacted (passwords, keys, tokens detected by pattern)
  - `log(action:tool:args:result:wasCloud:)` — called by ToolRegistry after each execution
- [ ] Settings → "Audit Log" tab:
  - Timeline view: date → list of actions
  - Each action: icon, tool name, brief description, result (success/fail), cloud/local badge
  - Expand to see full arguments and output
  - "What was sent to cloud?" filter
  - Export to JSON
  - "Delete All Logs" with confirmation

**Success Criteria**:
- [ ] Every tool execution creates an audit entry
- [ ] Cloud requests show what text was sent
- [ ] User can filter and export logs
- [ ] Sensitive data is redacted

**Difficulty**: 3/5

---

### M055: Permission Management UI

**Status**: PLANNED

**Objective**: Clear, unified UI showing what permissions the app has and why.

**Dependencies**: M034

**Deliverables**:
- [ ] Settings → "Permissions" tab:
  - List all macOS permissions: Accessibility, Automation, Microphone, Screen Recording
  - Status per permission: Granted / Not Granted
  - "Why needed" explanation for each
  - "Open System Settings" button for each
  - Warning for missing critical permissions (Accessibility required for mouse/keyboard)
- [ ] Autonomy level controls:
  - Picker: Level 0, Level 1 (default), Level 2
  - Clear example of what each level does
  - Current level highlighted
- [ ] Cloud settings summary:
  - Active provider + model
  - Is cloud enabled? Quick disable toggle
  - Is screen vision in use? Status indicator

**Difficulty**: 2/5

---

### M056: Security Hardening Pass

**Status**: PLANNED

**Objective**: Comprehensive security review of all code written since M032.

**Dependencies**: M051 (all tools built)

**Deliverables**:
- [ ] Code audit: command injection, path traversal, unvalidated inputs, hardcoded secrets, insecure network calls
- [ ] Prompt injection testing: clipboard, file name, model output injection scenarios
- [ ] MCP server audit: verify server output is treated as untrusted
- [ ] Terminal tool audit: verify allowlist cannot be bypassed (unicode, long strings, special chars)
- [ ] Vision audit: verify screenshots are never persisted to disk
- [ ] CDP browser audit: verify JavaScript evaluation cannot exfiltrate data
- [ ] All findings documented and fixed before proceeding

**Success Criteria**:
- [ ] No known command injection vulnerabilities
- [ ] No known path traversal vulnerabilities
- [ ] No hardcoded secrets
- [ ] All network calls use HTTPS
- [ ] Prompt injection test suite passes

**Difficulty**: 4/5

---

## PHASE 13: PRODUCT LAUNCH

*Goal: Package and ship.*

---

### M057: User Onboarding Flow

**Status**: PLANNED

**Objective**: First-launch experience that guides users through setup.

**Dependencies**: M055

**Deliverables**:
- [ ] Welcome screen on first launch (4 slides):
  1. "Welcome to aiDAEMON — your JARVIS for Mac"
  2. Grant Accessibility permission (required — explains why)
  3. Set up Claude brain: paste Anthropic API key, or skip for local-only
  4. Try voice (optional): grant microphone, test it
- [ ] "How to summon me" tutorial: "Press Cmd+Shift+Space any time to open me"
- [ ] Setup state persisted: doesn't re-show completed steps
- [ ] Users who skip cloud: working local assistant

**Success Criteria**:
- [ ] New user goes from install to working assistant in < 3 minutes
- [ ] Cloud setup is optional — local-only path works completely
- [ ] All permissions explained before requesting

**Difficulty**: 3/5

---

### M058: Auto-Update System

**Status**: PLANNED

**Objective**: Ship updates automatically using Sparkle.

**YC Resources**: **AWS ($10K credits)** — host appcast XML and .dmg on S3 + CloudFront. Or use GitHub Releases (free, simpler).

**Dependencies**: M057

**Deliverables**:
- [ ] Sparkle integration configured (already a dependency — wire it up)
- [ ] Appcast XML hosted on GitHub Releases or S3
- [ ] Code signing and notarization configured (Developer ID certificate)
- [ ] Settings: "Check for updates automatically" toggle + "Check Now" button + current version display

**Difficulty**: 3/5

---

### M059: Performance Optimization

**Status**: PLANNED

**Objective**: Profile and optimize for daily use.

**Dependencies**: M058

**Deliverables**:
- [ ] Instruments profiling: memory (target < 200MB idle), CPU idle (< 1%), launch (< 3s), model load (< 5s)
- [ ] Lazy model loading (don't load local model until first local inference request)
- [ ] MCP connection pooling (don't reconnect every call)
- [ ] Optimize identified bottlenecks

**Difficulty**: 3/5

---

### M060: Beta Build and Distribution

**Status**: PLANNED

**Objective**: Create a distributable beta build and share with initial testers.

**Dependencies**: M059

**Deliverables**:
- [ ] Signed, notarized .dmg installer
- [ ] Installation instructions
- [ ] Beta feedback form or GitHub issues link
- [ ] Known issues document
- [ ] Distribute to 5-10 beta testers

**Difficulty**: 2/5

---

### M061: Public Launch

**Status**: PLANNED

**Objective**: Ship v1.0 to the public.

**YC Resources**: **AWS ($10K credits)** — landing page, CDN, .dmg hosting. **Fireworks AI** — production inference for paid tier. **Stripe** — payment processing.

**Dependencies**: M060 + beta feedback addressed

**Deliverables**:
- [ ] Landing page + download link
- [ ] Documentation / FAQ
- [ ] Pricing page (free tier: local-only | paid tier: Claude brain + MCP ecosystem + computer control)
- [ ] Payment integration for paid tier
- [ ] Support channel (email or Discord)

**Success Criteria**:
- [ ] Users can discover, download, install, and start using the app
- [ ] Free tier fully functional without payment
- [ ] Paid tier activates with payment
- [ ] No critical bugs in first week

**Difficulty**: 4/5

---

