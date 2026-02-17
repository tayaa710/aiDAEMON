# 01 - ARCHITECTURE

System architecture for aiDAEMON: a hybrid local/cloud AI companion for macOS.

Last Updated: 2026-02-17
Version: 3.0 (Hybrid JARVIS Architecture)

---

## How It Works (Simple Version)

```
You say: "Set up an n8n workflow that watches my email"

                    ┌─────────────────────────┐
                    │     Your Mac (the app)   │
                    │                          │
  You ──────────── │  1. Hear/read your input  │
  (voice or text)  │  2. Is this simple?       │
                    │     YES → local AI does it│
                    │     NO  → send to cloud   │──── encrypted ───→ Cloud Brain
                    │  3. Get plan back         │←── plan comes back (nothing stored)
                    │  4. Show you the plan     │
                    │  5. You approve           │
                    │  6. Execute steps         │  ← controls your Mac
                    │  7. Show you results      │
                    └─────────────────────────┘
```

**Key point**: The cloud brain only does the *thinking*. All the *doing* happens locally on your Mac. The cloud never touches your files, apps, or screen directly.

---

## System Layers

```
┌─────────────────────────────────────────────────────────┐
│                        USER                              │
│              Text / Voice / (Future: gesture)            │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                  INTERACTION LAYER                        │
│  Chat UI • Input capture • Response display              │
│  Plan preview • Approval dialogs • Action history        │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   MODEL ROUTER                           │
│  Decides: local model or cloud model?                    │
│  Simple task → local 8B  |  Complex task → cloud API     │
└─────────────────────────────────────────────────────────┘
              │                           │
              ▼                           ▼
┌──────────────────────┐    ┌──────────────────────────┐
│   LOCAL MODEL        │    │     CLOUD MODEL          │
│   LLaMA 3.1 8B      │    │     (Groq/Together/AWS)  │
│   via llama.cpp      │    │     via HTTPS API        │
│   On-device, instant │    │     Encrypted, ephemeral │
└──────────────────────┘    └──────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                  ORCHESTRATOR (Agent Loop)                │
│  Understand → Plan → Policy Check → Execute → Verify    │
└─────────────────────────────────────────────────────────┘
         │                │                │
         ▼                ▼                ▼
┌───────────────┐  ┌────────────┐  ┌──────────────┐
│ POLICY ENGINE │  │   MEMORY   │  │  AUDIT LOG   │
│ Risk scoring  │  │ Working    │  │ Every action │
│ Approval gate │  │ Session    │  │ is recorded  │
│ Safety rules  │  │ Long-term  │  │ and viewable │
└───────────────┘  └────────────┘  └──────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                     TOOL RUNTIME                         │
│  Schema-validated tool calls with structured arguments   │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                    TOOL EXECUTORS                         │
│  Apps • Files • Windows • Browser • Clipboard • Screen  │
│  Terminal • Calendar • Email • System • Mouse/Keyboard   │
└─────────────────────────────────────────────────────────┘
```

---

## Layer Details

### 1. Interaction Layer

What the user sees and touches.

**Current assets (reused from M001-M024)**:
- `FloatingWindow.swift` — the hovering command palette (will evolve into chat window)
- `CommandInputView.swift` — text input field
- `ResultsView.swift` — displays results
- `ConfirmationDialog.swift` — approval prompts for risky actions

**Future additions**:
- Chat conversation view (scrollable message history)
- Plan preview cards (shows steps before execution)
- Voice input indicator
- Action history browser

### 2. Model Router

Decides whether to use the local model or the cloud model for each request.

**Routing logic**:
- Single-action commands (open app, find file, move window) → **local model**
- Multi-step tasks, complex planning, screen understanding → **cloud model**
- User has no API key / is offline → **always local model**
- User explicitly chooses → **respect user choice**

**Implementation**: `ModelRouter.swift` with a `ModelProvider` protocol that both local and cloud backends conform to.

```swift
protocol ModelProvider {
    func generate(prompt: String, params: GenerationParams) async throws -> String
    var isAvailable: Bool { get }
    var providerName: String { get }
}
```

### 3. Local Model Backend

What exists today. Runs inference on-device using llama.cpp.

**Current assets (reused)**:
- `ModelLoader.swift` — loads GGUF model into memory
- `LLMBridge.swift` — Swift wrapper for llama.cpp C API
- `LLMManager.swift` — state management and inference coordination

**Characteristics**:
- Zero network traffic
- ~1-3 second inference for simple commands
- Good for: open app, find file, move window, system info
- Struggles with: multi-step planning, complex reasoning, screen understanding

### 4. Cloud Model Backend

New. Sends prompts to a remote model API over encrypted HTTPS.

**Privacy architecture**:
- Prompts sent over TLS 1.3 (encrypted in transit)
- API provider does NOT train on data (contractual)
- No prompts, responses, or context stored server-side
- API key stored in macOS Keychain (never in code or config files)
- User can view what was sent in the local audit log
- User can disable cloud entirely in Settings

**Provider options (swappable)**:
- Groq (fast, cheap, ~$3-5/month for personal use)
- Together AI (similar pricing)
- AWS Bedrock (more enterprise, user's own AWS account)

**Implementation**: `CloudModelProvider.swift` conforming to `ModelProvider` protocol.

### 5. Orchestrator (Agent Loop)

The brain's decision-making cycle. Takes a user goal and breaks it into executable steps.

**States**:
```
idle → understanding → planning → awaiting_approval → executing → verifying → responding
                                                                       ↓
                                                                    failed → recovering
```

**What each state does**:
1. `understanding` — Parse what the user wants. Pull context (frontmost app, clipboard, etc.)
2. `planning` — Ask the model to decompose the goal into tool calls
3. `awaiting_approval` — Show the plan to the user. Wait for approval (at autonomy levels 0-1)
4. `executing` — Run each tool call in sequence
5. `verifying` — Check if the action succeeded (e.g., did the window actually move?)
6. `responding` — Show the user what happened
7. `failed` / `recovering` — Something went wrong. Try an alternative or ask the user.

### 6. Policy Engine

Sits between the planner and executor. Every proposed action must pass through policy.

**Risk classification**:
- `safe` — read-only, non-destructive (show system info, search files, read clipboard)
- `caution` — modifies state but reversible (move files, close apps, change settings)
- `dangerous` — destructive or irreversible (delete files, send emails, kill processes, terminal commands)

**Rules**:
- `safe` actions can auto-execute at autonomy level 1+
- `caution` actions need confirmation at level 0, auto-execute at level 2+ within approved scopes
- `dangerous` actions ALWAYS need explicit confirmation. No exceptions. No autonomy level bypasses this.
- Unknown/unclassified actions are treated as `dangerous` by default

### 7. Tool Runtime

Validates and dispatches tool calls. Every tool has a schema.

**Tool definition shape**:
```swift
struct ToolDefinition {
    let id: String           // e.g., "app_open"
    let name: String         // e.g., "Open Application"
    let description: String  // Human-readable description
    let inputSchema: [ParameterDef]  // Required and optional parameters
    let riskLevel: RiskLevel // safe, caution, or dangerous
    let requiresPermission: [PermissionType]  // e.g., [.accessibility]
}
```

**Current tools (from M001-M024, reused)**:
- `app_open` — Open apps and URLs (AppLauncher.swift)
- `file_search` — Search files via Spotlight (FileSearcher.swift)
- `window_manage` — Move/resize windows (WindowManager.swift)
- `system_info` — Battery, disk, IP, etc. (SystemInfo.swift)

**New tools (to be built)**:
- `screen_capture` — Take screenshot for vision analysis
- `mouse_click` — Click at screen coordinates
- `keyboard_type` — Type text
- `keyboard_shortcut` — Press key combination
- `browser_navigate` — Open URL in browser
- `clipboard_read` — Read clipboard contents
- `clipboard_write` — Write to clipboard
- `file_operation` — Copy, move, rename, delete files
- `terminal_run` — Execute sandboxed terminal commands
- `notification_send` — Show system notification

### 8. Memory Layer

Helps the assistant remember context and preferences.

**Memory tiers**:
- **Working memory** — current task only. What steps have been done, what's next. Cleared when task ends.
- **Session memory** — current conversation. Previous messages and context. Cleared when window closes.
- **Long-term memory** — user-approved preferences. "I always use Chrome." "My project folder is ~/code." Persists across sessions.

**Privacy rules**:
- Long-term memory writes require user confirmation
- User can view, edit, and delete any memory
- Full wipe available in Settings
- Passwords, tokens, and secrets are NEVER stored in memory (blocked by category filter)
- Memory is stored locally in encrypted format. Never sent to cloud.

### 9. Audit Log

Records every action the assistant takes. This is how users can trust the system.

**Logged per action**:
- Timestamp
- What the user asked
- What the AI understood
- What plan was generated
- Whether approval was given
- What tool was called with what arguments
- Whether it succeeded or failed
- Whether cloud model was used (and what was sent)

**Storage**: Local only. JSON files in app support directory. User can export or delete.

---

## Data Flow: Simple Task (Local)

```
User: "open safari"
  → Input captured by CommandInputView
  → ModelRouter: simple task → local model
  → Local LLM generates: {"tool": "app_open", "target": "Safari"}
  → Policy engine: app_open is "safe" → auto-execute
  → AppLauncher opens Safari
  → Result shown: "Opened Safari"
  → Audit log entry written
  → Total time: ~1-2 seconds, zero network
```

## Data Flow: Complex Task (Cloud)

```
User: "set up an n8n workflow that watches my gmail"
  → Input captured
  → ModelRouter: multi-step task → cloud model
  → Prompt sent to Groq API over HTTPS (encrypted)
  → Cloud model returns plan:
      Step 1: Open browser to n8n dashboard
      Step 2: Click "New Workflow"
      Step 3: Add Gmail trigger node
      Step 4: Configure trigger settings
      ...
  → Plan shown to user for approval
  → User approves
  → Steps executed one by one (with screen vision for verification)
  → Each step logged in audit
  → Total time: 15-60 seconds depending on complexity
  → Cloud saw: the prompt text only. Never the screen, files, or credentials.
```

---

## Permissions Required

| Permission | Why | When Asked |
|-----------|-----|-----------|
| Accessibility | Control other apps (move windows, click buttons, read UI elements) | First launch |
| Automation (Apple Events) | Send commands to apps (AppleScript) | First use of app control |
| Microphone | Voice input | When user enables voice |
| Screen Recording | Screenshot for vision features | When user enables screen vision |

Each permission is requested only when needed, with a clear explanation of why.

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Hotkey to visible UI | < 150ms |
| Simple task (local model) | < 2 seconds |
| Complex task (cloud model) | < 5 seconds for plan, varies for execution |
| Screen capture + vision analysis | < 3 seconds |
| App memory usage (idle) | < 200MB |
| App memory usage (model loaded) | < 5GB |

---

## Technology Stack

| Component | Technology | Why |
|-----------|-----------|-----|
| App framework | SwiftUI + AppKit | Native macOS, best system integration |
| Local LLM | llama.cpp via LlamaSwift (mattt/llama.swift) | Best local inference for Apple Silicon |
| Cloud LLM | HTTPS API (Groq/Together/Bedrock) | Cheap, fast, provider-swappable |
| Global hotkey | KeyboardShortcuts (sindresorhus) | Reliable, well-maintained |
| Auto-updates | Sparkle | Standard for non-App Store Mac apps |
| Credential storage | macOS Keychain | OS-level encryption, best practice |
| Screen control | Accessibility API (AXUIElement) | Native, no third-party dependency |
| Keyboard/mouse | CGEvent API | System-level, reliable |
| Speech-to-text | Apple Speech framework | On-device, private, free |
| Text-to-speech | AVSpeechSynthesizer | On-device, private, free |
