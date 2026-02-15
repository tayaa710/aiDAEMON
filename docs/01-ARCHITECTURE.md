# 01 - ARCHITECTURE

Complete system architecture and technical specifications for aiDAEMON.

Last Updated: 2026-02-15
Version: 1.0

---

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        USER                                  │
│                          ↓                                   │
│                   Global Hotkey                              │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              UI Layer (SwiftUI)                       │  │
│  │  - Floating input window                             │  │
│  │  - Results display                                    │  │
│  │  - Confirmation dialogs                               │  │
│  │  - Settings interface                                 │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Intent Parser (Local LLM)                     │  │
│  │  - LLaMA 3 8B (4-bit quantized)                      │  │
│  │  - llama.cpp inference engine                        │  │
│  │  - Input: natural language string                    │  │
│  │  - Output: structured command JSON                   │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Command Validator                             │  │
│  │  - Sanitize parameters                                │  │
│  │  - Check safety (destructive? reversible?)           │  │
│  │  - Resolve file paths                                 │  │
│  │  - Determine if confirmation needed                   │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Execution Engine                              │  │
│  │  - App Launcher (open -a)                            │  │
│  │  - File Operations (mdfind, mv, mkdir)               │  │
│  │  - Window Manager (Accessibility API)                │  │
│  │  - System Info (shell commands)                      │  │
│  │  - AppleScript/JXA Bridge                            │  │
│  │  - Process Manager (killall, pkill)                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Action Logger                                 │  │
│  │  - SQLite database                                    │  │
│  │  - Command history                                    │  │
│  │  - Success/failure tracking                           │  │
│  │  - Undo metadata (where applicable)                   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Settings Store                                │  │
│  │  - User preferences                                   │  │
│  │  - Custom aliases                                     │  │
│  │  - Auto-approve rules (future)                        │  │
│  │  - Permission status cache                            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Component Specifications

### 1. UI Layer

**Technology**: SwiftUI (macOS 13.0+)

**Primary Interface**: Floating Window
- Appears on global hotkey (default: Cmd+Shift+Space)
- Always on top (NSWindow level: .floating)
- Centered on current screen
- Auto-hides when focus lost (configurable)
- Size: ~400x80px (collapsed), expands for results

**Components**:
```
FloatingInputWindow
├── CommandTextField (main input)
├── ResultsView (shows command preview or output)
├── ConfirmationDialog (for destructive actions)
└── ProgressIndicator (during LLM inference)
```

**Settings Window**:
```
SettingsView
├── GeneralTab (hotkey, auto-hide, theme)
├── PermissionsTab (status + grant instructions)
├── HistoryTab (view/clear command log)
├── AliasesTab (custom commands, future)
└── AboutTab (version, licenses, credits)
```

**Key Behaviors**:
- Escape key always closes window
- Enter key submits command
- Up/down arrows navigate history (future)
- Tab for autocomplete suggestions (future)

---

### 2. Intent Parser (Local LLM)

**Model**: LLaMA 3 8B Instruct (4-bit quantization)
**Engine**: llama.cpp via Swift bindings
**Inference**: CPU-only (GPU acceleration via Metal future optimization)

**Model Files**:
- Primary: `llama-3-8b-instruct-q4_k_m.gguf` (~4.3GB)
- Location: `~/Library/Application Support/aiDAEMON/models/`
- Fallback: Download on first launch if not bundled

**Prompt Template**:
```
You are a macOS command interpreter. Convert user intent to structured JSON.

Available command types:
- APP_OPEN: Open an application or URL
- FILE_SEARCH: Find files using Spotlight
- WINDOW_MANAGE: Resize, move, or close windows
- SYSTEM_INFO: Show system information
- FILE_OP: File operations (move, rename, delete, create)
- PROCESS_MANAGE: Quit, restart, or kill processes
- QUICK_ACTION: System actions (screenshot, trash, DND)

Output JSON only, no explanation.

Example:
User: "open youtube"
{"type": "APP_OPEN", "target": "https://youtube.com"}

User: "find tax documents from 2024"
{"type": "FILE_SEARCH", "query": "tax", "kind": "pdf", "date": "2024"}

User: "{USER_INPUT}"
```

**Output Format** (JSON):
```json
{
  "type": "COMMAND_TYPE",
  "target": "primary target (app, file, url)",
  "parameters": {
    "key": "value"
  },
  "confidence": 0.95
}
```

**Error Handling**:
- Parse failures → show error, ask user to rephrase
- Low confidence (<0.7) → show "Did you mean?" with interpretation
- Invalid JSON → retry once with simpler prompt
- Timeout (>5 sec) → abort, show timeout message

**Performance Requirements**:
- First inference (model load): <3 seconds
- Subsequent inferences: <1 second (target), <2 seconds (acceptable)
- Model stays loaded in memory while app running
- Unload if system memory pressure detected

---

### 3. Command Validator

**Purpose**: Sanitize and safety-check parsed commands before execution.

**Validation Steps**:

1. **Type Validation**
   - Ensure command type is recognized
   - Verify required parameters present
   - Check parameter types match expected

2. **Path Resolution**
   - Resolve relative paths to absolute
   - Expand ~ to home directory
   - Verify paths exist (for reads) or parent exists (for writes)
   - Prevent path traversal attacks

3. **Safety Classification**
   ```swift
   enum SafetyLevel {
       case safe           // No confirmation needed (open app, show info)
       case cautious       // Soft confirm (move files, close window)
       case destructive    // Hard confirm (delete, force quit)
   }
   ```

4. **Sanitization**
   - Escape shell metacharacters in parameters
   - Validate URLs are well-formed
   - Prevent command injection (no ; && || etc in parameters)

**Output**:
```swift
struct ValidatedCommand {
    let type: CommandType
    let action: ExecutableAction
    let safetyLevel: SafetyLevel
    let preview: String  // Human-readable description
    let reversible: Bool
}
```

---

### 4. Execution Engine

**Command Executors** (one per type):

#### AppLauncher
```swift
func execute() -> Result<String, Error> {
    if target.starts(with: "http") {
        NSWorkspace.shared.open(URL(string: target))
    } else {
        NSWorkspace.shared.launchApplication(target)
    }
}
```

**Commands**: `open -a`, `NSWorkspace.launchApplication()`
**Permissions**: None (basic macOS capability)

---

#### FileSearcher
```swift
func execute() -> Result<[FileResult], Error> {
    let query = buildSpotlightQuery(parameters)
    let results = Process.run("mdfind", args: [query])
    return parseResults(results)
}
```

**Commands**: `mdfind` (Spotlight CLI)
**Permissions**: None (Spotlight-level access)

---

#### WindowManager
```swift
func execute() -> Result<String, Error> {
    let app = NSWorkspace.shared.frontmostApplication
    let windows = AXUIElementCreateApplication(app.processID)
    // Resize using Accessibility API
}
```

**Commands**: Accessibility API (AXUIElement)
**Permissions**: Accessibility

---

#### SystemInfo
```swift
func execute() -> Result<String, Error> {
    switch infoType {
    case .ip: return Process.run("curl", "-s", "ifconfig.me")
    case .disk: return Process.run("df", "-h")
    case .cpu: return parseActivityMonitor()
    }
}
```

**Commands**: `curl`, `df`, `top`, `sysctl`
**Permissions**: None

---

#### FileOperator
```swift
func execute() -> Result<String, Error> {
    switch operation {
    case .move: return FileManager.default.moveItem(src, dst)
    case .rename: return FileManager.default.moveItem(src, newName)
    case .delete: return FileManager.default.trashItem(src)
    case .create: return FileManager.default.createDirectory(path)
    }
}
```

**Commands**: FileManager API
**Permissions**: None (user-level file access)

---

#### ProcessManager
```swift
func execute() -> Result<String, Error> {
    let pid = findProcess(target)
    return Process.run("kill", ["-TERM", "\(pid)"])
}
```

**Commands**: `killall`, `pkill`, `kill`
**Permissions**: None (can only kill user's own processes)

---

#### QuickActions
```swift
func execute() -> Result<String, Error> {
    switch action {
    case .screenshot:
        return Process.run("screencapture", ["-c"])
    case .emptyTrash:
        return FileManager.default.emptyTrash()
    case .dnd:
        return AppleScript.execute("set do not disturb")
    }
}
```

**Commands**: `screencapture`, AppleScript, system APIs
**Permissions**: Automation (for AppleScript)

---

### 5. Action Logger

**Storage**: SQLite database at `~/Library/Application Support/aiDAEMON/history.db`

**Schema**:
```sql
CREATE TABLE commands (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    user_input TEXT NOT NULL,
    parsed_type TEXT NOT NULL,
    executed_command TEXT,
    success BOOLEAN NOT NULL,
    error_message TEXT,
    duration_ms INTEGER,
    auto_approved BOOLEAN DEFAULT 0
);

CREATE TABLE undo_metadata (
    command_id INTEGER PRIMARY KEY,
    reversible BOOLEAN,
    undo_data TEXT,  -- JSON with info to reverse action
    FOREIGN KEY (command_id) REFERENCES commands(id)
);

CREATE INDEX idx_timestamp ON commands(timestamp);
CREATE INDEX idx_type ON commands(parsed_type);
```

**Features**:
- Automatic logging of all commands
- Track success/failure rates
- Store undo information (future)
- Export as JSON or CSV
- Auto-cleanup old entries (>10,000 entries, delete oldest)

---

### 6. Settings Store

**Storage**: UserDefaults + SQLite hybrid

**UserDefaults** (simple key-value):
- Hotkey binding
- Window auto-hide delay
- Theme preference
- Permission grant timestamps

**SQLite** (structured data):
```sql
CREATE TABLE aliases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    trigger TEXT UNIQUE NOT NULL,
    expansion TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Future: auto-approval rules
CREATE TABLE auto_approve_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    command_pattern TEXT NOT NULL,
    enabled BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## Data Flow

### Command Execution Flow

```
1. User activates hotkey
   ↓
2. UI shows floating window, focuses text field
   ↓
3. User types: "open youtube"
   ↓
4. User presses Enter
   ↓
5. UI shows "Thinking..." spinner
   ↓
6. LLM inference (1-2 seconds)
   Output: {"type": "APP_OPEN", "target": "https://youtube.com"}
   ↓
7. Validator checks command
   - Type: valid
   - Target: valid URL
   - Safety: SAFE (no confirmation needed)
   ↓
8. UI shows preview: "Opening https://youtube.com in default browser"
   [Execute] [Cancel] buttons
   ↓
9. User clicks Execute (or Enter)
   ↓
10. Executor runs: NSWorkspace.shared.open(URL("https://youtube.com"))
    ↓
11. Logger records: success, duration: 45ms
    ↓
12. UI shows: "✓ Opened YouTube"
    ↓
13. Window auto-hides after 1 second
```

---

## Technology Decisions

### Swift Package Dependencies

**Confirmed**:
- `llama.cpp` (via swift-llama or custom bridge)
- `Sparkle` (auto-updates)
- `Sauce` (global hotkey management)

**Under Consideration**:
- `KeyboardShortcuts` (alternative to Sauce)
- `SQLite.swift` (nicer SQLite interface than raw C)

**Explicitly NOT Using**:
- Electron (too large, not native)
- Python (distribution complexity)
- Web technologies (slower, less integrated)

---

### Build Configuration

**Debug Build**:
- Model: Smaller/faster variant for testing (3B or CPU-optimized)
- Logging: Verbose
- Assertions: Enabled
- Optimization: None

**Release Build**:
- Model: Full LLaMA 3 8B 4-bit quantized
- Logging: Errors only
- Assertions: Disabled
- Optimization: -O (speed)
- Code signing: Required
- Notarization: Required

---

### File Structure

```
aiDAEMON/
├── aiDAEMON/                   # Main app target
│   ├── App/
│   │   ├── aiDAEMONApp.swift  # App entry point
│   │   ├── AppDelegate.swift   # System event handling
│   │   └── HotkeyManager.swift # Global hotkey
│   ├── UI/
│   │   ├── FloatingWindow.swift
│   │   ├── CommandInputView.swift
│   │   ├── ResultsView.swift
│   │   ├── ConfirmationDialog.swift
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       ├── GeneralTab.swift
│   │       ├── PermissionsTab.swift
│   │       └── HistoryTab.swift
│   ├── LLM/
│   │   ├── LLMManager.swift        # Model loading, inference
│   │   ├── PromptBuilder.swift     # Construct prompts
│   │   └── ModelDownloader.swift   # First-launch download
│   ├── Commands/
│   │   ├── CommandParser.swift     # JSON parsing
│   │   ├── CommandValidator.swift  # Safety checks
│   │   ├── Executors/
│   │   │   ├── AppLauncher.swift
│   │   │   ├── FileSearcher.swift
│   │   │   ├── WindowManager.swift
│   │   │   ├── SystemInfo.swift
│   │   │   ├── FileOperator.swift
│   │   │   ├── ProcessManager.swift
│   │   │   └── QuickActions.swift
│   │   └── CommandRegistry.swift   # Maps types to executors
│   ├── Storage/
│   │   ├── ActionLogger.swift
│   │   ├── SettingsStore.swift
│   │   └── Database.swift          # SQLite wrapper
│   └── Utilities/
│       ├── PermissionChecker.swift
│       ├── ProcessRunner.swift     # Safe shell execution
│       └── Extensions/
│           ├── String+Sanitize.swift
│           └── URL+Validation.swift
├── aiDAEMONTests/              # Unit tests
├── aiDAEMONUITests/            # UI tests
├── Models/                     # LLM model files (gitignored)
├── docs/                       # This documentation
└── scripts/                    # Build/deploy scripts
    ├── download-model.sh
    ├── notarize.sh
    └── build-release.sh
```

---

## Security Architecture

### Sandboxing

**App is NOT sandboxed** (required for Accessibility access)

**Implications**:
- Cannot distribute via Mac App Store
- User sees security warning on first launch
- Must be notarized to avoid Gatekeeper block

**Mitigation**:
- Code sign with Apple Developer ID
- Notarize via Apple's notary service
- Include clear permission explanations
- Open source to allow audit (if we go that route)

### Permission Handling

**Accessibility**:
```swift
func checkAccessibility() -> Bool {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
    return AXIsProcessTrustedWithOptions(options)
}
```

**Automation** (per-app):
- Requested on first use of app-specific command
- User sees system dialog: "aiDAEMON wants to control Chrome"
- We cannot programmatically grant this

**Permission UI**:
- Show current status in Settings
- Provide "Open System Settings" button
- Explain what each permission unlocks
- Allow app to function with partial permissions (degrade gracefully)

---

## Performance Benchmarks

### Target Performance (M1 MacBook Air, 8GB RAM)

| Operation | Target | Acceptable | Unacceptable |
|-----------|--------|------------|--------------|
| Hotkey response | <30ms | <100ms | >200ms |
| Window appear | <50ms | <100ms | >200ms |
| First LLM inference (cold) | <2s | <3s | >5s |
| LLM inference (warm) | <800ms | <1.5s | >3s |
| App launch | <100ms | <300ms | >500ms |
| File search (100 results) | <200ms | <500ms | >1s |
| Window resize | <50ms | <100ms | >200ms |
| History query (1000 entries) | <50ms | <150ms | >300ms |

### Memory Targets

- Idle (model loaded): <600MB
- During inference: <1GB peak
- Model file on disk: ~4.3GB

---

## Error Handling Strategy

### Error Categories

**1. User Errors** (clear message, suggest fix)
- "Couldn't find app 'Chrme'" → "Did you mean Chrome?"
- "No files found matching 'tax 2025'" → Show empty result

**2. Permission Errors** (guide to fix)
- "Accessibility access required" → Show Settings button
- "Automation permission needed for Chrome" → Explain + retry

**3. System Errors** (technical but honest)
- "Process not found" → "Couldn't find running app"
- "File operation failed: Permission denied" → Show actual error

**4. Critical Errors** (fail gracefully)
- LLM model corrupted → Offer re-download
- Database corrupted → Reset DB, preserve if possible
- App crash → Crash reporter, restore state on relaunch

### Logging Strategy

**User-Facing Log** (in Settings):
- Last 100 commands
- Success/failure with reason
- Exportable as text

**Developer Log** (Console.app):
- Verbose technical details
- Performance metrics
- Error stack traces

**Crash Reports**:
- Use standard macOS crash reporting
- Optional: upload to developer (opt-in only)

---

## Future Architecture Considerations

### Phase 2+ Features (Not MVP)

**Voice Input**:
- Whisper model for speech-to-text
- Push-to-talk hotkey
- Microphone permission required

**Screen Understanding (Vision)**:
- Claude API or GPT-4V for screen interpretation
- Screen Recording permission required
- Opt-in only, explicit privacy warning

**Cloud Sync**:
- iCloud sync for settings/aliases
- End-to-end encrypted
- Opt-in only

**Plugins/Extensions**:
- User-written Swift plugins
- Sandboxed extension API
- Community plugin repository

---

## Deployment Architecture

### Distribution Package

**Option A: DMG with app bundle**
```
aiDAEMON-1.0.0.dmg
└── aiDAEMON.app/
    └── Contents/
        ├── MacOS/aiDAEMON (binary)
        ├── Resources/ (assets, icons)
        └── Info.plist
```
Model downloaded on first launch.

**Option B: PKG installer**
```
aiDAEMON-1.0.0.pkg
Installs:
  - /Applications/aiDAEMON.app
  - ~/Library/Application Support/aiDAEMON/models/llama-3-8b.gguf
```
Model bundled, larger download.

**Recommendation**: Start with Option A (smaller, faster iteration), move to Option B when stable.

### Update Mechanism

**Sparkle Framework**:
- Checks for updates on launch (daily)
- Downloads delta updates when possible
- User can disable auto-check
- Release notes shown before update

**Update Server**:
- Simple static file hosting (S3, GitHub Releases)
- Appcast XML feed
- Signed updates (EdDSA signature)

---

## Next Steps

See `03-MILESTONES.md` for development roadmap.
See `02-THREAT-MODEL.md` for security details.
