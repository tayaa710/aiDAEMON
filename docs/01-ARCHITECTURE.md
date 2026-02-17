# 01 - ARCHITECTURE

Complete system architecture and technical specifications for aiDAEMON.

Last Updated: 2026-02-17
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
- Visibility toggles on global hotkey (default: Cmd+Shift+Space)
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
- Cmd+Shift+Space toggles window show/hide
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
- Primary: `model.gguf` (~4.6GB, LLaMA 3.1 8B Instruct Q4_K_M)
- Location: `Models/` directory at project root (gitignored; developer must download manually)
- SHA256: `7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c`
- Path discovery: app walks up from bundle directory to find `Models/model.gguf` at launch

**Prompt Template** (see `PromptBuilder.swift` for canonical version):
```
You are a macOS command interpreter. Convert user intent to structured JSON.

Available command types:
- APP_OPEN: Open an application or URL
- FILE_SEARCH: Find files using Spotlight
- WINDOW_MANAGE: Resize, move, or close windows
- SYSTEM_INFO: Check or show system status (ip, disk, cpu, battery, memory, hostname, os version, uptime)
- FILE_OP: File operations (move, rename, delete, create)
- PROCESS_MANAGE: Quit, restart, or kill processes
- QUICK_ACTION: Perform system actions (screenshot, empty trash, DND, lock screen)

Use SYSTEM_INFO for questions about system status. Use QUICK_ACTION only for actions that change something.
SYSTEM_INFO targets: ip_address, disk_space, cpu_usage, battery, memory, hostname, os_version, uptime.

Output JSON only, no explanation.

[Few-shot examples follow — see PromptBuilder.swift]

User: "{USER_INPUT}"
```

**Generation Parameters**: temperature=0.1, topK=40, topP=0.9, maxTokens=256, repeatPenalty=1.1

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
- URL detection: http/https prefix or bare domain pattern (e.g. `youtube.com`)
- Opens URLs via `NSWorkspace.shared.open(url)`
- Opens apps via `NSWorkspace.openApplication(at:configuration:)` (modern API)
- Three-tier lookup: known bundle ID map → exact name in /Applications → fuzzy name match

**Permissions**: None (basic macOS capability)

---

#### FileSearcher
- Uses `NSMetadataQuery` (native Spotlight API, not shell `mdfind`)
- `SpotlightSearcher` wrapper: one-shot query with 5-second timeout
- `RelevanceScorer`: weighted composite score (Spotlight relevance 30%, name match 25%, recency 25%, location priority 20%)
- Fetches 50 candidates, scores and sorts, returns top 20
- Supports `kind` parameter mapped to UTI types (e.g. "pdf" → `com.adobe.pdf`)

**Permissions**: None (user-level Spotlight access)

---

#### WindowManager
- Uses Accessibility API (`AXUIElement`) to get/set window position and size
- 10 positions: left_half, right_half, top_half, bottom_half, full_screen, center, top_left, top_right, bottom_left, bottom_right
- Target app resolution: explicit target → frontmost non-aiDAEMON app → last remembered external app
- Coordinate conversion: NSScreen (bottom-left origin) → AX API (top-left relative to primary screen)
- Multi-monitor: respects screen origin offset

**Permissions**: Accessibility (prompts user on first use)

---

#### SystemInfo
- 8 info types: ip_address, disk_space, cpu_usage, battery, memory, hostname, os_version, uptime
- All native Swift APIs — no shell-outs or `Process` calls:
  - IP: `getifaddrs` (local) + `URLSession` to api.ipify.org (public, 5s timeout)
  - Disk: `FileManager.attributesOfFileSystem`
  - CPU: `host_processor_info` (Mach kernel)
  - Battery: `IOKit.ps` (`IOPSCopyPowerSourcesInfo`)
  - Memory: `vm_statistics64`
  - Hostname/OS/Uptime: `ProcessInfo`
- Alias resolution for LLM variants (e.g. "ram" → memory, "storage" → disk_space, "battery_status" → battery)
- All queries dispatched to background queue; completion called on main queue

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
1. User presses hotkey (Cmd+Shift+Space)
   ↓
2. UI toggles floating window visibility (shows if hidden, hides if visible)
   If shown, text field receives focus
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

**Confirmed and in use**:
- `mattt/llama.swift` @ 2.8061.0 — wraps llama.cpp as precompiled XCFramework via SPM; `import LlamaSwift`; requires `SWIFT_CXX_INTEROP_MODE = default`. Note: official `ggml-org/llama.cpp` removed `Package.swift` — do NOT use it directly.
- `sparkle-project/Sparkle` @ 2.8.1 — auto-updates
- `sindresorhus/KeyboardShortcuts` @ 2.4.0 — global hotkey management

**Explicitly NOT Using**:
- Electron (too large, not native)
- Python (distribution complexity)
- Web technologies (slower, less integrated)
- `ggml-org/llama.cpp` direct SPM — Package.swift removed upstream

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

Note: Actual structure is flat (no subdirectories) within the app target. Planned subdirectory layout deferred.

```
aiDAEMON/
├── aiDAEMON/                    # Main app target (flat layout)
│   ├── aiDAEMONApp.swift        # App entry point (@main)
│   ├── AppDelegate.swift        # System lifecycle + test runner + executor registration
│   ├── HotkeyManager.swift      # Global hotkey (KeyboardShortcuts)
│   ├── FloatingWindow.swift     # NSWindow subclass, always-on-top
│   ├── CommandInputView.swift   # SwiftUI text input
│   ├── ResultsView.swift        # SwiftUI results display (success/error/loading styles)
│   ├── SettingsView.swift       # SwiftUI settings window (tabbed)
│   ├── ContentView.swift        # Placeholder (required by project template)
│   ├── ModelLoader.swift        # GGUF model file loading
│   ├── LLMBridge.swift          # llama.cpp C API Swift wrapper
│   ├── LLMManager.swift         # Singleton: model state, async inference, path discovery
│   ├── PromptBuilder.swift      # Prompt template + input sanitisation
│   ├── CommandParser.swift      # JSON → Command struct (CommandType, AnyCodable)
│   ├── CommandRegistry.swift    # CommandExecutor protocol + dispatch + PlaceholderExecutor
│   ├── AppLauncher.swift        # APP_OPEN executor
│   ├── FileSearcher.swift       # FILE_SEARCH executor (NSMetadataQuery + RelevanceScorer)
│   ├── WindowManager.swift      # WINDOW_MANAGE executor (AXUIElement)
│   ├── SystemInfo.swift         # SYSTEM_INFO executor (native APIs)
│   ├── Assets.xcassets          # App icons and color assets
│   └── aiDAEMON.entitlements   # Entitlements (apple-events automation)
├── aiDAEMON.xcodeproj/          # Hand-crafted Xcode project (tracked in git)
├── Models/                      # LLM model files (gitignored)
│   └── model.gguf               # LLaMA 3.1 8B Instruct Q4_K_M (4.6GB, download manually)
├── docs/                        # This documentation
└── scripts/                     # Build/deploy scripts (planned, not yet created)
    ├── notarize.sh              # Planned for M054
    └── create-dmg.sh            # Planned for M055
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
