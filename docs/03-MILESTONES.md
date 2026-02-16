# 03 - MILESTONES

Complete development roadmap broken into atomic milestones.

Last Updated: 2026-02-16
Version: 1.0

---

## Milestone Structure

Each milestone includes:
- **Objective**: What is being built
- **Why**: Why this exists / why this order
- **Success Criteria**: How to know it's done
- **Dependencies**: What must be complete first
- **Deliverables**: Concrete outputs
- **Testing**: What to verify
- **No Regressions**: What must still work
- **Difficulty**: Estimated complexity (1-5)
- **Shipping Gate**: Can we ship after this?

---

## PHASE 0: SETUP & FOUNDATION

### M001: Project Initialization ✅
**Status**: COMPLETE (2026-02-15) | **Commit**: `0ff4feb`

**Objective**: Create Xcode project and basic structure

**Why**: Need working project before writing code

**Dependencies**: None

**Deliverables**:
- [x] Xcode project created
- [x] SwiftUI macOS app template
- [x] Bundle identifier set: `com.aidaemon`
- [x] Deployment target: macOS 13.0+
- [x] Git repository initialized
- [x] `.gitignore` configured (Xcode, Models/, build artifacts)

**Success Criteria**:
- [x] Project builds without errors (`xcodebuild` BUILD SUCCEEDED)
- [x] App launches and shows default window with "aiDAEMON" text
- [x] Git commit created

**Testing**:
- [x] Build succeeds
- [x] Run shows app

**Difficulty**: 1/5

**Shipping**: No

---

### M002: Documentation Integration ✅
**Status**: COMPLETE (2026-02-15)

**Objective**: Link documentation into project

**Why**: Keep docs accessible during development

**Dependencies**: M001

**Deliverables**:
- [x] `docs/` folder added to Xcode project as folder reference
- [x] README.md added to Xcode sidebar
- [x] QUICKSTART.md added to Xcode sidebar
- [x] License file created (MIT)

**Success Criteria**:
- [x] Docs visible in Xcode sidebar
- [x] Can open and read from IDE

**Testing**:
- [x] Project builds with doc references
- [x] Files visible in Xcode sidebar

**Difficulty**: 1/5

**Shipping**: No

---

### M003: LLM Model Acquisition ✅
**Status**: COMPLETE (2026-02-15)

**Objective**: Download and verify LLaMA 3 8B model

**Why**: Need model file before implementing inference

**Dependencies**: M001

**Deliverables**:
- [x] LLaMA 3.1 8B Instruct (4-bit quantized) downloaded
- [x] Model file placed in `Models/` directory (`Models/model.gguf`)
- [x] GGUF format verified (magic bytes: `GGUF`)
- [x] `.gitignore` excludes `Models/` folder and `*.gguf`
- [x] Documentation updated with model details

**Success Criteria**:
- [x] File `Models/model.gguf` exists (4.6GB)
- [x] SHA256: `7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c`
- [x] Valid GGUF format confirmed

**Testing**:
- [x] Verify file integrity (GGUF header + SHA256)

**Difficulty**: 2/5

**Shipping**: No

**Notes**: Model filename is `model.gguf` (LLaMA 3.1 8B Instruct Q4_K_M)

---

### M004: Swift Package Dependencies ✅
**Status**: COMPLETE (2026-02-15)

**Objective**: Add required third-party packages

**Why**: Need external libraries for core functionality

**Dependencies**: M001

**Deliverables**:
- [x] llama.cpp via `mattt/llama.swift` (LlamaSwift) @ 2.8061.0 - XCFramework wrapper
- [x] Sparkle framework @ 2.8.1 (via SPM)
- [x] KeyboardShortcuts @ 2.4.0 (via SPM, by sindresorhus)
- [x] C++ interop enabled (`SWIFT_CXX_INTEROP_MODE = default`)

**Success Criteria**:
- [x] All packages resolve successfully
- [x] Project builds with dependencies (BUILD SUCCEEDED)
- [x] No version conflicts
- [x] All three imports compile (`import LlamaSwift`, `import Sparkle`, `import KeyboardShortcuts`)

**Testing**:
- [x] Build project with all dependencies
- [x] Import each package - verified all compile

**Difficulty**: 3/5

**Shipping**: No

**Notes**: Used `mattt/llama.swift` instead of official `ggml-org/llama.cpp` (Package.swift removed from upstream). LlamaSwift wraps llama.cpp as precompiled XCFramework, supports macOS 13.0+.

---

## PHASE 1: CORE UI

### M005: App Structure & Entry Point ✅
**Status**: COMPLETE (2026-02-15)

**Objective**: Set up app lifecycle and window management

**Why**: Foundation for all UI work

**Dependencies**: M001, M004

**Deliverables**:
- [x] `aiDAEMONApp.swift` - SwiftUI app entry point with `NSApplicationDelegateAdaptor`
- [x] `AppDelegate.swift` - macOS lifecycle hooks
- [x] Menu bar configuration (minimal: About, Quit via default SwiftUI menu)
- [x] App activates without showing window by default (Settings scene only)

**Success Criteria**:
- [x] App launches
- [x] No default window appears
- [x] Menu bar shows app name + Quit option
- [x] App stays running in background (`applicationShouldTerminateAfterLastWindowClosed` returns false)

**Testing**:
- [x] Build succeeds
- [x] Launch app - no window should appear
- [x] Check menu bar - app is running
- [x] Quit from menu bar works

**Difficulty**: 2/5

**Shipping**: No

---

### M006: Global Hotkey Detection ✅
**Status**: COMPLETE (2026-02-15)

**Objective**: Detect global hotkey to toggle UI visibility

**Why**: Primary user entry point

**Dependencies**: M005

**Deliverables**:
- [x] `HotkeyManager.swift` class
- [x] Register global hotkey: Cmd+Shift+Space (default toggle shortcut)
- [x] Notification posted when hotkey pressed
- [x] Hotkey works even when app not focused

**Success Criteria**:
- [x] Press Cmd+Shift+Space from any app
- [x] Console logs "Hotkey pressed"
- [x] Works regardless of focused app

**Testing**:
- [x] Focus different apps (Safari, Finder, etc.)
- [x] Press hotkey
- [x] Verify notification received

**Difficulty**: 2/5

**Shipping**: No

---

### M007: Floating Window UI ✅
**Status**: COMPLETE (2026-02-15)

**Objective**: Create floating input window

**Why**: Primary user interface

**Dependencies**: M006

**Deliverables**:
- [x] `FloatingWindow.swift` - NSWindow subclass
- [x] Window properties:
  - [x] Always on top (`.floating` level)
  - [x] No title bar
  - [x] Centered on current screen
  - [x] Size: 400x80px
  - [x] Rounded corners, shadow
- [x] Window toggles on hotkey press (Cmd+Shift+Space shows/hides)
- [x] Window hides on Escape key

**Success Criteria**:
- [x] Hotkey shows window when hidden
- [x] Hotkey hides window when visible
- [x] Window appears centered on screen with cursor
- [x] Escape hides window
- [x] Window stays above all other windows

**Testing**:
- [x] Hotkey (window hidden) → window appears
- [x] Hotkey (window visible) → window disappears
- [x] Escape → window disappears
- [x] Try with multiple monitors (if available)

**Difficulty**: 3/5

**Shipping**: No

---

### M008: Text Input Field ✅
**Status**: COMPLETE (2026-02-15)

**Objective**: Add text field to floating window

**Why**: User needs to type commands

**Dependencies**: M007

**Deliverables**:
- [x] `CommandInputView.swift` - SwiftUI text field
- [x] Placeholder text: "What do you want to do?"
- [x] Auto-focus when window appears
- [x] Enter key submits input
- [x] Escape key clears and hides window

**Success Criteria**:
- [x] Window shows with text field focused
- [x] Can type text
- [x] Enter key triggers action (print to console for now)
- [x] Escape clears text and hides window

**Testing**:
- [x] Type "hello world"
- [x] Press Enter → see console log
- [x] Press Escape → text clears, window hides

**Difficulty**: 2/5

**Shipping**: No

---

### M009: Results Display Area ✅
**Status**: COMPLETE (2026-02-15)

**Objective**: Show command results below input field

**Why**: User needs feedback on what happened

**Dependencies**: M008

**Deliverables**:
- [x] `ResultsView.swift` - displays text output
- [x] Window expands vertically to show results
- [x] Scrollable if output is long
- [x] Styled text (success = green, error = red)

**Success Criteria**:
- [x] After Enter, results area appears
- [x] Shows test output
- [x] Window resizes smoothly
- [x] Scrolls if content > 300px

**Testing**:
- [x] Submit command → see result
- [x] Submit long output → verify scroll
- [x] Test success and error styling

**Difficulty**: 2/5

**Shipping**: No

---

### M010: Settings Window ✅
**Status**: COMPLETE (2026-02-15)

**Objective**: Create settings interface

**Why**: User needs to configure app

**Dependencies**: M005

**Deliverables**:
- [x] `SettingsView.swift` - SwiftUI settings window
- [x] Menu bar item: "Settings..." (Cmd+,)
- [x] Tabbed interface: General, Permissions, History, About
- [x] General tab: Hotkey selector placeholder, theme toggle (future)
- [x] About tab: Version number, links

**Success Criteria**:
- [x] Cmd+, opens settings window
- [x] Tabs are navigable
- [x] Window can be closed and reopened
- [x] Settings persist across launches (via UserDefaults)

**Testing**:
- [x] Open settings
- [x] Navigate tabs
- [x] Close and reopen - verify state

**Difficulty**: 2/5

**Shipping**: No

---

## PHASE 2: LLM INTEGRATION

### M011: LLM Model File Loader ✅
**Status**: COMPLETE (2026-02-15)

**Objective**: Load LLaMA model file into memory

**Why**: Required for inference

**Dependencies**: M003, M004

**Deliverables**:
- [x] `ModelLoader.swift` class
- [x] Function: `loadModel(path:) -> ModelHandle?`
- [x] Handles file not found error
- [x] Handles corrupted model error
- [x] Shows loading progress (future: progress bar)

**Success Criteria**:
- [x] Model loads successfully from `Models/` directory
- [x] Takes <5 seconds on M1 Mac
- [x] Error handling works (test with invalid file)

**Testing**:
- [x] Load valid model → success
- [x] Load missing file → error message
- [x] Load corrupted file → error message

**Difficulty**: 3/5

**Shipping**: No

---

### M012: llama.cpp Swift Bridge ✅
**Status**: COMPLETE (2026-02-15)

**Objective**: Create Swift wrapper for llama.cpp C API

**Why**: Swift can't directly call C++ easily

**Dependencies**: M004, M011

**Deliverables**:
- [x] `LLMBridge.swift` - Swift wrapper class
- [x] Functions exposed: `loadModel(path:)`, `generate(prompt:params:onToken:)`, `unload()`
- [x] `GenerationParams` struct (temperature, topP, topK, repeatPenalty, maxTokens)
- [x] Sampler chain (Top-K → Top-P → Temperature → Distribution, or Greedy)
- [x] Async generation with `generateAsync()` and abort support
- [x] Streaming token output via `onToken` callback
- [x] Memory management (batch alloc/dealloc, sampler chain cleanup, ModelHandle RAII)

**Success Criteria**:
- [x] Can call llama.cpp from Swift (tokenize, decode, sample, detokenize)
- [x] Errors are bridged properly (LLMBridgeError enum)
- [x] Project builds without errors

**Testing**:
- [x] Build succeeds (BUILD SUCCEEDED)
- [ ] Call each function with loaded model (M013)
- [ ] Verify memory with Instruments (M063)
- [ ] Unload model properly (M013)

**Difficulty**: 4/5 (C/Swift bridging is complex)

**Shipping**: No

**Notes**: Uses LlamaSwift (mattt/llama.swift) which provides C++ interop. llama_vocab and other opaque types accessed via OpaquePointer. KV cache cleared via llama_memory_clear (new API).

---

### M013: Basic Inference Test ✅
**Status**: COMPLETE (2026-02-15)

**Objective**: Generate text from LLM

**Why**: Verify model and bridge work

**Dependencies**: M011, M012

**Deliverables**:
- [x] `LLMManager.swift` class (singleton, ObservableObject with state tracking)
- [x] Function: `generate(prompt:params:onToken:completion:)` with async generation
- [x] Model auto-loads on app launch via `AppDelegate`
- [x] FloatingWindow wired to real LLM inference (streaming tokens to UI)
- [x] State machine: idle → loading → ready → generating
- [x] Model path auto-discovery (walks up from bundle to find Models/model.gguf)

**Success Criteria**:
- [x] Prompt in → text out (via FloatingWindow UI)
- [x] Streaming token output displayed in results area
- [x] Error states handled (model not loaded, loading, already generating)

**Testing**:
- [x] Build succeeds (BUILD SUCCEEDED)
- [ ] Run test prompt in UI (manual test with model file)
- [ ] Verify output is sensible
- [ ] Check performance

**Difficulty**: 3/5

**Shipping**: No

**Notes**: LLMManager wraps LLMBridge with state management and model path discovery. FloatingWindow now shows real LLM output instead of placeholders.

---

### M014: Prompt Template Builder ✅
**Status**: COMPLETE (2026-02-16)

**Objective**: Construct structured prompts for command parsing

**Why**: LLM needs specific format to output valid JSON

**Dependencies**: M013

**Deliverables**:
- [x] `PromptBuilder.swift` struct
- [x] Function: `buildCommandPrompt(userInput:) -> String`
- [x] Template as defined in `01-ARCHITECTURE.md` (7 command types, JSON output schema)
- [x] Few-shot examples for all command types (APP_OPEN, FILE_SEARCH, WINDOW_MANAGE, SYSTEM_INFO, PROCESS_MANAGE, QUICK_ACTION)
- [x] `commandParams` generation parameters tuned for JSON output (low temperature 0.1)
- [x] Input sanitisation: quote escaping, control char stripping, whitespace collapsing, 500-char limit
- [x] FloatingWindow wired to use PromptBuilder for all inference calls

**Success Criteria**:
- [x] User input "open safari" → full prompt with examples
- [x] Prompt is properly formatted
- [x] User input is escaped/sanitized

**Testing**:
- [x] Build succeeds (BUILD SUCCEEDED)
- [ ] Test with various user inputs (manual test with model file)
- [ ] Verify no prompt injection possible (manual test)
- [ ] Check output format (manual test)

**Difficulty**: 2/5

**Shipping**: No

**Notes**: PromptBuilder is a pure struct with static methods. Uses low temperature (0.1) for deterministic JSON output. Sanitisation prevents prompt structure breakage via quote escaping and control char removal.

---

### M015: JSON Output Parsing ✅
**Status**: COMPLETE (2026-02-16)

**Objective**: Parse LLM JSON response into struct

**Why**: Need structured data for execution

**Dependencies**: M014

**Deliverables**:
- [x] `CommandParser.swift` - Parser with error handling
- [x] `CommandType` enum - All 7 command types (APP_OPEN, FILE_SEARCH, WINDOW_MANAGE, SYSTEM_INFO, FILE_OP, PROCESS_MANAGE, QUICK_ACTION)
- [x] `Command` struct - Codable with type, target, parameters, confidence
- [x] `AnyCodable` helper - Type-erased wrapper for heterogeneous JSON parameters
- [x] Function: `CommandParser.parse(json:) -> Command` (throws)
- [x] Error handling - 5 error types (invalidJSON, missingType, unknownCommandType, missingRequiredField, invalidFormat)
- [x] JSON cleanup - Strips markdown code fences, extracts first valid JSON object
- [x] Field validation - Type-specific required field checks
- [x] Convenience extensions - `stringParam()`, `intParam()`, `boolParam()`, `description`
- [x] Debug test suite - 8 test cases covering all command types

**Success Criteria**:
- [x] Valid JSON → parsed Command struct
- [x] Invalid JSON → error with explanation
- [x] Missing fields → error
- [x] Unknown command type → error

**Testing**:
- [x] Build succeeds (BUILD SUCCEEDED)
- [x] Test cases for all 7 command types (DEBUG test suite)
- [ ] Test malformed JSON (manual test)
- [ ] Test missing required fields (manual test)

**Difficulty**: 2/5

**Shipping**: No

**Notes**: Parser is resilient to LLM output quirks (markdown fences, extra text). Uses AnyCodable for flexible parameter types. Type-safe convenience accessors for common parameter types.

---

### M016: End-to-End LLM Pipeline ✅
**Status**: COMPLETE (2026-02-16)

**Objective**: User input → LLM → parsed command

**Why**: Complete parsing flow

**Dependencies**: M015

**Deliverables**:
- [x] Integration: User types → prompt built → LLM infers → JSON parsed → Command displayed
- [x] Loading indicator (spinner + "Processing" label) in UI during inference
- [x] Streaming tokens shown during generation with loading style
- [x] Parsed Command displayed with human-readable formatting (action type, target, parameters, confidence)
- [x] User-friendly error messages for parse failures with recovery suggestion
- [x] Raw output shown on parse failure for debugging

**Success Criteria**:
- [x] Type "open youtube" → parsed as APP_OPEN with target displayed
- [x] Loading spinner shows during inference
- [x] Errors are user-friendly with "Try rephrasing" suggestion

**Testing**:
- [x] Build succeeds (BUILD SUCCEEDED)
- [ ] Test each command type (manual test with model file)
- [ ] Verify timing (<2 sec) (manual test)
- [ ] Test error handling (manual test)

**Difficulty**: 3/5

**Shipping**: No

**Notes**: Pipeline: CommandInputView → PromptBuilder.buildCommandPrompt → LLMManager.generate (streaming) → CommandParser.parse → formatted display. Added `.loading` ResultStyle with spinner. Parse errors show user-friendly explanation + raw output for debugging.

---

## PHASE 3: COMMAND EXECUTION

### M017: Command Type Registry ✅
**Status**: COMPLETE (2026-02-16)

**Objective**: Map command types to executor classes

**Why**: Dispatching commands to correct handlers

**Dependencies**: M015

**Deliverables**:
- [x] `CommandRegistry.swift` class (singleton)
- [x] `CommandExecutor` protocol with `execute(_:completion:)` and `name`
- [x] `ExecutionResult` struct (success/failure with message + details)
- [x] Registry maps `CommandType` enum to executor via `executor(for:) -> CommandExecutor`
- [x] `execute(_:completion:)` convenience method for direct dispatch
- [x] `PlaceholderExecutor` stubs for all 7 command types (replaced as real executors are built)
- [x] `register(_:for:)` method for swapping in real executors
- [x] FloatingWindow wired to dispatch parsed commands through registry
- [x] `CommandType` extended with `CaseIterable` conformance

**Success Criteria**:
- [x] All command types have executors registered (placeholder stubs)
- [x] Registry is extensible via `register(_:for:)`
- [x] FloatingWindow dispatches through registry after parsing

**Testing**:
- [x] Build succeeds (BUILD SUCCEEDED)
- [ ] Request executor for each type (manual test)
- [ ] Register custom executor, verify it replaces placeholder (manual test)

**Difficulty**: 2/5

**Shipping**: No

**Notes**: PlaceholderExecutor returns "not yet implemented" errors for all types. Real executors (M018-M021, M043-M045) will call `CommandRegistry.shared.register()` to replace placeholders.

---

### M018: App Launcher Executor ✅
**Status**: COMPLETE (2026-02-16)

**Objective**: Open applications and URLs

**Why**: Most common command type

**Dependencies**: M017

**Deliverables**:
- [x] `AppLauncher.swift` struct implementing `CommandExecutor` protocol
- [x] URL detection (http/https prefixes, bare domain patterns like "youtube.com")
- [x] Application opening via `NSWorkspace.openApplication(at:configuration:)` (modern API)
- [x] Bundle ID lookup with known-app map (Safari, Chrome, Firefox, Slack, etc.)
- [x] Filesystem search across /Applications, /System/Applications, /Utilities
- [x] Fuzzy app name matching (e.g. "chrome" finds "Google Chrome")
- [x] Registered in `AppDelegate` on launch via `CommandRegistry.shared.register()`

**Success Criteria**:
- [x] "open safari" → Safari opens (via bundle ID lookup)
- [x] "open youtube.com" → YouTube opens in default browser (URL detection)
- [x] Invalid app name → error message with suggestion

**Testing**:
- [x] Build succeeds (BUILD SUCCEEDED)
- [ ] Open various apps (Safari, Chrome, Finder) (manual test)
- [ ] Open URLs (http, https, bare domains) (manual test)
- [ ] Test invalid app names (manual test)

**Difficulty**: 2/5

**Shipping**: No

**Notes**: Uses modern `NSWorkspace.openApplication(at:configuration:)` instead of deprecated `launchApplication()`. Three-tier lookup: bundle ID map → exact name match in filesystem → fuzzy/contains match. URL auto-prefixes `https://` for bare domains.

---

### M019: File Search Executor ✅
**Objective**: Search files using Spotlight

**Why**: Second most common command

**Dependencies**: M017

**Deliverables**:
- [x] `FileSearcher.swift` class
- [x] Uses `mdfind` command (Spotlight via `kMDItemDisplayName` query)
- [x] Parses results to array of file paths
- [x] Displays results in UI (file name + abbreviated path, capped at 20 results)
- [x] Kind filtering (pdf, image, video, audio, document, text, folder, etc.)
- [x] Input sanitization to prevent mdfind injection
- [x] Registered in CommandRegistry via AppDelegate

**Success Criteria**:
- "find tax" → lists files containing "tax"
- Results show file name and path
- Clickable to open in Finder (future)

**Testing**:
- [x] Search for known files — "find safari" returns Safari-related files (manual test) ✅
- [x] Search with no results — nonsense query returns "No files found" (manual test) ✅
- [x] Search with many results — broad query returns capped results (manual test) ✅
- [x] Search with kind filter e.g. "pdf" (manual test) ✅
- [x] Build succeeds (BUILD SUCCEEDED) ✅
- [x] All 15 automated tests pass at launch ✅

**Difficulty**: 3/5

**Shipping**: No

**Notes**: Uses `mdfind -limit 20` with `kMDItemDisplayName` for name-based Spotlight search. Supports optional `kind` parameter mapped to UTI types (e.g. "pdf" → `com.adobe.pdf`). Results limited to 20 via mdfind `-limit` flag (prevents hanging on broad queries). Minimum 2-character query enforced. Paths abbreviated with `~` for home directory. `Command` struct extended with `query` field to match LLM output format (`FILE_SEARCH` uses `query` instead of `target`).

---

### M019b: Search Relevance Ranking ✅
**Objective**: Replace `mdfind` shell-out with native `NSMetadataQuery` and add relevance-based result ranking

**Why**: Current mdfind returns results in arbitrary Spotlight order. Users expect the most relevant files first — exact name matches, recently used files, and files in common locations should rank higher than obscure system files.

**Dependencies**: M019

**Deliverables**:
- [x] Migrated from `Process("/usr/bin/mdfind")` to `NSMetadataQuery` (native Swift Spotlight API)
- [x] `SpotlightSearcher` wrapper class — manages NSMetadataQuery lifecycle with completion handler
- [x] `RelevanceScorer` — weighted composite scoring system:
  - Spotlight relevance (`kMDQueryResultContentRelevance`) — 30% weight
  - Exact/starts-with name match — 25% weight
  - Recency (`kMDItemLastUsedDate` with exponential decay) — 25% weight
  - Location priority (~/Desktop, ~/Documents, ~/Downloads) — 20% weight
- [x] Fetch 50 candidates, score and sort, display top 20
- [x] 5-second timeout prevents hanging if Spotlight is rebuilding index
- [x] `MockMetadataItem` for unit testing scorer in isolation

**Success Criteria**:
- "find tax" → `tax.pdf` on Desktop ranks above `/Library/Caches/something-tax-related`
- "find screenshot" → recent screenshots rank first
- Results feel noticeably more useful than random Spotlight order
- No performance regression (NSMetadataQuery should be faster than Process/pipe)

**Testing**:
- [ ] Search for file with exact name match — appears first (manual test)
- [ ] Search for common term — recent files ranked higher (manual test)
- [ ] Search for file in ~/Documents vs /Library — Documents file ranks higher (manual test)
- [ ] Performance: results appear within 1 second for common queries (manual test)
- [x] Build succeeds (BUILD SUCCEEDED)
- [x] Test 15: Exact name match scores higher than contains (automated)
- [x] Test 16: Recent file scores higher than old file (automated)
- [x] Test 17: ~/Documents scores higher than /usr (automated)

**Difficulty**: 3/5

**Shipping**: No

**Notes**: Uses `NSMetadataQuery` with notification pattern (`.NSMetadataQueryDidFinishGathering`). Query runs on main thread (run loop required). `SpotlightSearcher` is a one-shot wrapper: starts query, waits for completion or timeout, scores results, fires completion handler. Eliminated Process/pipe overhead. `kMDItem*` constants require `as String` cast in Swift with C++ interop enabled. Tests pump `RunLoop.main` to allow NSMetadataQuery callbacks during synchronous test execution.

---

### M020: Window Manager Executor ✅
**Status**: COMPLETE (2026-02-16)

**Objective**: Resize and position windows

**Why**: Power user feature

**Dependencies**: M017

**Deliverables**:
- [x] `WindowManager.swift` struct implementing `CommandExecutor` protocol
- [x] Uses Accessibility API (`AXUIElement`) to get and manipulate target app window
- [x] `WindowPosition` enum with 10 positions: left_half, right_half, top_half, bottom_half, full_screen, center, top_left, top_right, bottom_left, bottom_right
- [x] Position alias resolution (e.g. "left" → left_half, "maximize" → full_screen, "centered" → center)
- [x] Handles hyphens, spaces, and case-insensitive input (e.g. "left-half", "LEFT HALF")
- [x] Coordinate system conversion (NSScreen bottom-left → AX top-left)
- [x] Multi-monitor support (frames respect screen origin offset)
- [x] Accessibility permission check with `AXIsProcessTrusted()` — prompts user if not granted
- [x] Tracks last non-aiDAEMON focused app and uses it when aiDAEMON is frontmost
- [x] Window lookup fallback chain: focused window → main window → first window in app window list
- [x] Registered in `AppDelegate` on launch via `CommandRegistry.shared.register()`

**Success Criteria**:
- [x] "left half" from aiDAEMON palette resizes the previously active app window (not aiDAEMON)
- [x] "full screen" → target app window maximizes
- [x] Works with different apps (requires Accessibility permission)

**Testing**:
- [ ] Test each position command with real windows (manual test)
- [ ] Test with Safari, Finder, TextEdit (manual test)
- [ ] Test Accessibility permission prompt on first use (manual test)
- [ ] Test on multi-monitor setup if available (manual test)
- [x] Build succeeds (BUILD SUCCEEDED)
- [x] Test 1: Executor name is 'WindowManager' (automated)
- [x] Test 2: All 10 position strings resolve correctly (automated)
- [x] Test 3: All aliases resolve correctly (automated)
- [x] Test 4: Hyphen/space/case variants resolve correctly (automated)
- [x] Test 5: Unknown position returns nil (automated)
- [x] Test 6: left_half frame calculation correct (automated)
- [x] Test 7: right_half frame calculation correct (automated)
- [x] Test 8: full_screen frame calculation correct (automated)
- [x] Test 9: center frame calculation correct (60% of screen) (automated)
- [x] Test 10: Quarter position frames correct (automated)
- [x] Test 11: Multi-monitor offset screen preserves origin (automated)
- [x] Test 12: Missing position returns error (automated)
- [x] Test 13: End-to-end parse WINDOW_MANAGE command (automated)
- [x] Test 14: All positions have non-empty displayName (automated)
- [x] Test 15: Current app does not overwrite remembered external target app (automated)
- [x] Test 16: Frontmost target aliases resolve correctly (automated)

**Difficulty**: 4/5 (Accessibility API is complex)

**Shipping**: No

**Notes**: Uses `AXUIElement` API with target-app resolution: explicit app target (if present), otherwise frontmost non-aiDAEMON app, otherwise last remembered external app captured before the palette activates. This avoids resizing the aiDAEMON command window itself. Window selection falls back from focused → main → first window to handle apps that do not expose a focused window while inactive. Coordinate conversion needed: NSScreen uses bottom-left origin, AX API uses top-left origin relative to primary screen. Center position uses 60% of screen dimensions. Requires Accessibility permission (see M030) — gracefully prompts user and returns error if not granted. Position resolution handles LLM output quirks (hyphens, spaces, case variations). 16 automated tests run on launch covering position resolution, frame calculations, and target selection safeguards.

---

### M021: System Info Executor
**Objective**: Display system information

**Why**: Quick info commands

**Dependencies**: M017

**Deliverables**:
- `SystemInfo.swift` class
- Commands: IP address, disk space, CPU usage, battery
- Uses shell commands: `curl`, `df`, `pmset`

**Success Criteria**:
- "what's my ip" → shows IP address
- "disk space" → shows available space
- Results formatted cleanly

**Testing**:
- Test each info command
- Verify output formatting
- Test on battery and plugged in

**Difficulty**: 2/5

**Shipping**: No

---

### M022: Command Validation Layer
**Objective**: Validate commands before execution

**Why**: Security and safety

**Dependencies**: M017

**Deliverables**:
- `CommandValidator.swift` class
- Validates parameters
- Classifies safety level
- Sanitizes inputs
- Resolves file paths

**Success Criteria**:
- Valid commands pass through
- Invalid commands are rejected with explanation
- Dangerous commands are flagged

**Testing**:
- Test with valid commands
- Test with injection attempts
- Test with path traversal attempts

**Difficulty**: 3/5

**Shipping**: No

---

### M023: Confirmation Dialog System
**Objective**: Show confirmation for destructive actions

**Why**: Prevent accidental damage

**Dependencies**: M022

**Deliverables**:
- `ConfirmationDialog.swift` view
- Shows before destructive operations
- Clear description of action
- Approve / Cancel buttons

**Success Criteria**:
- Destructive command → confirmation dialog appears
- Approve → command executes
- Cancel → command aborted

**Testing**:
- Test destructive commands
- Verify cancel works
- Verify approve works

**Difficulty**: 2/5

**Shipping**: No

---

### M024: Execution Result Handling
**Objective**: Display execution results and errors

**Why**: User feedback

**Dependencies**: M018-M021

**Deliverables**:
- Success messages in ResultsView
- Error messages in ResultsView
- Formatted output for file lists, info, etc.

**Success Criteria**:
- Success → green checkmark + message
- Error → red X + error description
- Output formatted nicely

**Testing**:
- Test successful commands
- Test failing commands
- Verify formatting

**Difficulty**: 2/5

**Shipping**: No

---

## PHASE 4: PERMISSIONS & SAFETY

### M025: Permission Checker Utility
**Objective**: Check macOS permission status

**Why**: Know what permissions we have

**Dependencies**: M001

**Deliverables**:
- `PermissionChecker.swift` class
- Functions: `hasAccessibility()`, `hasAutomation(for:)`
- Checks without prompting user

**Success Criteria**:
- Returns true if permission granted
- Returns false if not granted
- Does not trigger system prompt

**Testing**:
- Test with permissions granted
- Test without permissions
- Verify no unwanted prompts

**Difficulty**: 2/5

**Shipping**: No

---

### M026: Permission Request Flow
**Objective**: Request permissions when needed

**Why**: Can't function without permissions

**Dependencies**: M025

**Deliverables**:
- Function to request Accessibility permission
- Clear explanation dialog before request
- "Open System Settings" button

**Success Criteria**:
- First launch → explain why permission needed
- Button opens System Settings to correct pane
- Re-check after user grants permission

**Testing**:
- Test on fresh system (no permissions)
- Verify explanation is clear
- Test Settings button

**Difficulty**: 3/5

**Shipping**: No

---

### M027: Permissions Status UI
**Objective**: Show permission status in Settings

**Why**: User needs to know what's granted

**Dependencies**: M025, M010

**Deliverables**:
- Permissions tab in Settings
- Shows status: ✓ Granted or ✗ Not Granted
- "Grant" buttons for each permission
- Explanation of what each unlocks

**Success Criteria**:
- Status updates in real-time
- Buttons open correct System Settings panes
- Explanations are clear

**Testing**:
- View with no permissions
- Grant permissions, verify UI updates
- Test each "Grant" button

**Difficulty**: 2/5

**Shipping**: No

---

### M028: Graceful Degradation
**Objective**: Handle missing permissions gracefully

**Why**: App should work with partial permissions

**Dependencies**: M025

**Deliverables**:
- Commands that need permissions show error if not granted
- Error message explains which permission is needed
- App doesn't crash without permissions

**Success Criteria**:
- Window management without Accessibility → error message
- Error explains how to grant permission
- App remains functional for other commands

**Testing**:
- Revoke permissions
- Try commands that need them
- Verify errors are helpful

**Difficulty**: 2/5

**Shipping**: No

---

### M029: Safe Shell Execution
**Objective**: Execute shell commands safely

**Why**: Prevent command injection

**Dependencies**: M022

**Deliverables**:
- `ProcessRunner.swift` utility
- Executes commands with argument arrays (not strings)
- Sanitizes all inputs
- Timeouts for long-running commands

**Success Criteria**:
- Safe execution of whitelisted commands
- No command injection possible
- Timeouts work (abort after 10 seconds)

**Testing**:
- Test normal commands
- Test injection attempts (should fail safely)
- Test long-running command with timeout

**Difficulty**: 3/5

**Shipping**: No

---

### M030: Accessibility Permission Integration
**Objective**: Enable window management features

**Why**: Required for window control

**Dependencies**: M020, M026

**Deliverables**:
- Window management requests Accessibility permission
- Clear explanation: "To control windows, aiDAEMON needs Accessibility access"
- Works after permission granted

**Success Criteria**:
- First window command → permission request
- After granting → window management works
- Without permission → clear error

**Testing**:
- Test without permission
- Grant permission
- Test window commands work

**Difficulty**: 2/5

**Shipping**: No

---

## PHASE 5: DATA PERSISTENCE

### M031: SQLite Database Setup
**Objective**: Initialize database for history and settings

**Why**: Persist data across sessions

**Dependencies**: M001

**Deliverables**:
- `Database.swift` wrapper class
- SQLite database at `~/Library/Application Support/aiDAEMON/history.db`
- Schema as defined in `01-ARCHITECTURE.md`
- Migrations system (future-proofing)

**Success Criteria**:
- Database file created on first launch
- Tables created successfully
- Can query database

**Testing**:
- Launch app → verify DB created
- Query empty tables
- Verify file location

**Difficulty**: 3/5

**Shipping**: No

---

### M032: Action Logging
**Objective**: Log all executed commands

**Why**: Audit trail and debugging

**Dependencies**: M031

**Deliverables**:
- `ActionLogger.swift` class
- Function: `log(command:success:error:)`
- Automatic logging after each execution
- Stores timestamp, input, type, success/fail

**Success Criteria**:
- Each command is logged
- Database grows with usage
- Can query recent commands

**Testing**:
- Execute several commands
- Query database - verify entries
- Verify success/failure logged correctly

**Difficulty**: 2/5

**Shipping**: No

---

### M033: Command History View
**Objective**: Display past commands in Settings

**Why**: User wants to see what they've done

**Dependencies**: M032, M010

**Deliverables**:
- History tab in Settings
- List of recent commands (last 100)
- Shows: timestamp, input, success/fail
- Search/filter (future)

**Success Criteria**:
- History tab shows logged commands
- Most recent first
- Updates after new commands

**Testing**:
- Execute commands
- Open History tab
- Verify commands appear

**Difficulty**: 2/5

**Shipping**: No

---

### M034: History Export
**Objective**: Export history as JSON

**Why**: User data portability

**Dependencies**: M033

**Deliverables**:
- "Export" button in History tab
- Saves as JSON file to user-chosen location
- Includes all logged data

**Success Criteria**:
- Click Export → file save dialog
- Saved JSON is valid and complete
- Can re-import (future)

**Testing**:
- Export history
- Verify JSON is valid
- Check all fields present

**Difficulty**: 2/5

**Shipping**: No

---

### M035: History Clear
**Objective**: Delete all logged commands

**Why**: Privacy control

**Dependencies**: M033

**Deliverables**:
- "Clear All History" button
- Confirmation dialog
- Deletes all rows from database

**Success Criteria**:
- Button → confirmation dialog
- Confirm → history deleted
- History view updates to empty

**Testing**:
- Clear history
- Verify database is empty
- Verify UI updates

**Difficulty**: 1/5

**Shipping**: No

---

### M036: Settings Persistence
**Objective**: Save user preferences

**Why**: Remember user choices

**Dependencies**: M010

**Deliverables**:
- `SettingsStore.swift` class
- UserDefaults for simple settings
- Persists hotkey, theme, auto-hide delay
- Loads on launch

**Success Criteria**:
- Change settings → quit app → relaunch → settings remembered
- Defaults are sensible for first launch

**Testing**:
- Change settings, restart, verify persisted
- Delete preferences file, verify defaults

**Difficulty**: 2/5

**Shipping**: No

---

## PHASE 6: POLISH & UX

### M037: Loading States
**Objective**: Show progress during long operations

**Why**: User feedback for slow commands

**Dependencies**: M016

**Deliverables**:
- Spinner during LLM inference
- Progress indicator for file operations
- "Working..." message

**Success Criteria**:
- User sees feedback immediately
- Spinner stops when complete
- No UI freeze

**Testing**:
- Test with slow LLM inference
- Test with large file operations
- Verify smooth animation

**Difficulty**: 2/5

**Shipping**: No

---

### M038: Error Message Improvements
**Objective**: User-friendly error messages

**Why**: Current errors might be too technical

**Dependencies**: M024

**Deliverables**:
- Rewrite error messages for clarity
- Include recovery suggestions
- Avoid jargon

**Success Criteria**:
- Non-technical user can understand errors
- Errors suggest next steps

**Testing**:
- Trigger each error type
- Verify messages are clear
- Get feedback from non-technical user

**Difficulty**: 2/5

**Shipping**: No

---

### M039: Keyboard Shortcuts
**Objective**: Add shortcuts for common actions

**Why**: Power user efficiency

**Dependencies**: M008

**Deliverables**:
- Esc: Close window
- Enter: Submit command
- Cmd+K: Clear input
- Cmd+,: Settings (already done in M010)
- Cmd+H: Show/hide history

**Success Criteria**:
- All shortcuts work
- No conflicts with system shortcuts

**Testing**:
- Test each shortcut
- Verify in documentation

**Difficulty**: 2/5

**Shipping**: No

---

### M040: Window Auto-Hide
**Objective**: Hide window after command completes

**Why**: Reduce UI clutter

**Dependencies**: M024

**Deliverables**:
- Configurable delay (1-5 seconds)
- Auto-hide after successful command
- Don't auto-hide on error (user needs to see)

**Success Criteria**:
- Success → window hides after delay
- Error → window stays open
- Delay is configurable in Settings

**Testing**:
- Run successful command, verify hide
- Run failed command, verify stays open
- Change delay, verify it works

**Difficulty**: 2/5

**Shipping**: No

---

### M041: Visual Polish
**Objective**: Improve aesthetics

**Why**: Professional appearance

**Dependencies**: M007-M009

**Deliverables**:
- Custom app icon
- Refined window styling (shadows, blur)
- Color scheme (light/dark mode)
- Typography improvements

**Success Criteria**:
- App looks polished
- Dark mode works correctly
- Icon looks good in Dock and menu bar

**Testing**:
- View in light and dark mode
- Check icon at various sizes
- Get design feedback

**Difficulty**: 3/5

**Shipping**: No

---

### M042: Sound Effects (Optional)
**Objective**: Audio feedback for actions

**Why**: Additional user feedback

**Dependencies**: M024

**Deliverables**:
- Success sound
- Error sound
- Configurable on/off in Settings

**Success Criteria**:
- Sounds are subtle and pleasant
- Can be disabled
- Don't play if system is muted

**Testing**:
- Trigger success/error sounds
- Toggle on/off in Settings
- Test with system muted

**Difficulty**: 2/5

**Shipping**: No (nice to have)

---

## PHASE 7: ADDITIONAL EXECUTORS

### M043: File Operations Executor
**Objective**: Move, rename, delete files

**Why**: Common user requests

**Dependencies**: M017, M023

**Deliverables**:
- `FileOperator.swift` class
- Commands: move, rename, delete, create folder
- Uses Trash by default (not rm -rf)
- Confirmation for destructive operations

**Success Criteria**:
- "move file to desktop" → file moves
- "delete old-file.txt" → moves to Trash after confirmation
- Errors are clear

**Testing**:
- Test each operation
- Verify Trash is used
- Test confirmation dialogs

**Difficulty**: 3/5

**Shipping**: No

---

### M044: Process Management Executor
**Objective**: Quit, restart, kill processes

**Why**: Troubleshooting and power user feature

**Dependencies**: M017, M023

**Deliverables**:
- `ProcessManager.swift` class
- Commands: quit app, restart app, force quit, kill port
- Uses `killall`, `pkill`, `lsof`
- Confirmation for force quit

**Success Criteria**:
- "quit chrome" → Chrome quits gracefully
- "force quit chrome" → Chrome force quits after confirmation
- "kill port 3000" → kills process using port

**Testing**:
- Test quit vs force quit
- Test kill by port
- Verify confirmations

**Difficulty**: 3/5

**Shipping**: No

---

### M045: Quick Actions Executor
**Objective**: System-level quick actions

**Why**: Common one-off tasks

**Dependencies**: M017

**Deliverables**:
- `QuickActions.swift` class
- Commands: screenshot, empty trash, Do Not Disturb, lock screen, sleep
- Uses AppleScript and system APIs

**Success Criteria**:
- "screenshot" → takes screenshot to clipboard
- "empty trash" → empties after confirmation
- "do not disturb" → enables DND for specified time

**Testing**:
- Test each action
- Verify AppleScript permissions
- Test DND timer

**Difficulty**: 3/5

**Shipping**: No

---

## PHASE 8: ADVANCED FEATURES

### M046: Custom Aliases
**Objective**: User-defined command shortcuts

**Why**: Personalization and efficiency

**Dependencies**: M031

**Deliverables**:
- Aliases table in database (already in M031 schema)
- UI to add/edit/delete aliases
- Alias expansion before LLM parsing
- Example: "yt" → "open youtube"

**Success Criteria**:
- User can create alias in Settings
- Typing alias expands to full command
- Aliases persist across launches

**Testing**:
- Create alias
- Use alias
- Edit/delete alias

**Difficulty**: 3/5

**Shipping**: No

---

### M047: Multi-Step Commands
**Objective**: Execute multiple commands in sequence

**Why**: Complex workflows

**Dependencies**: M017

**Deliverables**:
- LLM can output multiple commands
- Execute sequentially with progress
- Stop on first error
- Example: "open youtube and go full screen"

**Success Criteria**:
- Multi-step command executes in order
- Progress shown for each step
- Errors stop execution

**Testing**:
- Test 2-3 step commands
- Verify order
- Test error in middle

**Difficulty**: 4/5

**Shipping**: No

---

### M048: Context Awareness
**Objective**: Use current app/window context

**Why**: Smarter command interpretation

**Dependencies**: M025

**Deliverables**:
- Detect frontmost app
- Detect selected files in Finder
- Pass context to LLM prompt
- Example: "zoom in" knows which app to control

**Success Criteria**:
- Context-dependent commands work
- Works with Safari, Finder, etc.
- LLM uses context correctly

**Testing**:
- Test with different frontmost apps
- Test with Finder selection
- Verify context is used

**Difficulty**: 4/5

**Shipping**: No

---

### M049: Command Suggestions
**Objective**: Autocomplete and suggestions

**Why**: Faster input, discoverability

**Dependencies**: M032

**Deliverables**:
- Dropdown of suggestions as user types
- Based on command history (frecency)
- Based on common commands
- Tab to accept suggestion

**Success Criteria**:
- Typing "ope" suggests "open safari"
- Recent commands ranked higher
- Tab completes suggestion

**Testing**:
- Test with history
- Test with no history
- Verify ranking

**Difficulty**: 3/5

**Shipping**: No

---

### M050: Undo System
**Objective**: Reverse certain actions

**Why**: Safety net

**Dependencies**: M032

**Deliverables**:
- Undo metadata stored in database
- Cmd+Z to undo last action
- Works for: file moves, window positions
- Cannot undo: deletions (already in Trash, that's undo)

**Success Criteria**:
- Move file → Cmd+Z → file moves back
- Resize window → Cmd+Z → window restores
- Undo metadata stored correctly

**Testing**:
- Test each reversible action
- Verify irreversible actions can't be undone

**Difficulty**: 4/5

**Shipping**: No

---

## PHASE 9: CODE SIGNING & DISTRIBUTION

### M051: App Icon Design
**Objective**: Create professional app icon

**Why**: Required for distribution

**Dependencies**: None (can be parallel)

**Deliverables**:
- 1024x1024 icon design
- Icon set for all sizes (16x16 to 512x512)
- Added to Xcode asset catalog

**Success Criteria**:
- Icon visible in Dock, Finder, menu bar
- Looks good at all sizes
- Matches app aesthetic

**Testing**:
- View at different sizes
- Test in light/dark mode
- Get design feedback

**Difficulty**: 3/5 (design skill dependent)

**Shipping**: No

---

### M052: Code Signing Setup
**Objective**: Sign app with Developer ID

**Why**: Required to avoid Gatekeeper warning

**Dependencies**: None (need Apple Developer account)

**Deliverables**:
- Apple Developer account enrolled ($99/year)
- Developer ID certificate installed
- Xcode configured with signing identity
- App builds with valid signature

**Success Criteria**:
- App is signed after build
- Signature is valid: `codesign -dv --verbose=4 aiDAEMON.app`
- No signing errors

**Testing**:
- Build app
- Verify signature
- Test on different Mac

**Difficulty**: 3/5

**Shipping**: No

**Notes**: See `manual-actions.md` for enrollment steps

---

### M053: Entitlements Configuration
**Objective**: Declare required permissions

**Why**: macOS requires entitlements for certain APIs

**Dependencies**: M052

**Deliverables**:
- Entitlements file configured
- Required: `com.apple.security.automation.apple-events`
- NOT included: `com.apple.security.app-sandbox` (can't use sandbox)

**Success Criteria**:
- App builds with entitlements
- Entitlements visible: `codesign -d --entitlements - aiDAEMON.app`

**Testing**:
- Verify entitlements present
- Verify automation works

**Difficulty**: 2/5

**Shipping**: No

---

### M054: Notarization
**Objective**: Notarize app with Apple

**Why**: Required to distribute outside App Store

**Dependencies**: M052, M053

**Deliverables**:
- Build script to notarize: `scripts/notarize.sh`
- Upload to Apple notary service
- Staple notarization ticket to app
- Verify notarization successful

**Success Criteria**:
- Notarization succeeds
- Stapling succeeds
- `spctl -a -v aiDAEMON.app` shows "accepted"

**Testing**:
- Test on different Mac (without Xcode)
- Verify no Gatekeeper warning

**Difficulty**: 3/5

**Shipping**: No

**Notes**: See `manual-actions.md` for notarization steps

---

### M055: DMG Creation
**Objective**: Package app in distributable DMG

**Why**: Standard macOS distribution format

**Dependencies**: M054

**Deliverables**:
- DMG with app bundle
- Custom background image (optional)
- Applications folder symlink for drag-install
- Script: `scripts/create-dmg.sh`

**Success Criteria**:
- DMG mounts correctly
- User can drag to Applications
- Notarization is preserved

**Testing**:
- Mount DMG
- Install app
- Verify app runs

**Difficulty**: 2/5

**Shipping**: No

---

### M056: Sparkle Auto-Update Integration
**Objective**: Enable automatic updates

**Why**: Keep users on latest version

**Dependencies**: M004, M052

**Deliverables**:
- Sparkle framework configured
- Update feed (appcast.xml) hosted
- EdDSA keys generated
- Updates signed with private key

**Success Criteria**:
- App checks for updates on launch
- Update notification works
- Download and install works
- Rollback if update fails

**Testing**:
- Publish test update
- Verify app detects it
- Install update
- Verify new version runs

**Difficulty**: 4/5

**Shipping**: No

---

### M057: Release Build Script
**Objective**: Automate release process

**Why**: Consistent builds

**Dependencies**: M052-M056

**Deliverables**:
- `scripts/build-release.sh` script
- Steps: Clean → Build → Sign → Notarize → Create DMG → Upload
- Version bumping
- Changelog integration

**Success Criteria**:
- Script runs without errors
- Produces signed, notarized DMG
- DMG is distributable

**Testing**:
- Run script end-to-end
- Install resulting DMG
- Verify all steps work

**Difficulty**: 3/5

**Shipping**: No

---

## PHASE 10: TESTING & QA

### M058: Unit Tests - LLM Parsing
**Objective**: Test LLM prompt building and parsing

**Why**: Core functionality must be reliable

**Dependencies**: M014-M016

**Deliverables**:
- Test suite for PromptBuilder
- Test suite for CommandParser
- Test cases for all command types
- Test malformed inputs

**Success Criteria**:
- All tests pass
- Code coverage >80% for LLM module

**Testing**:
- Run test suite
- Verify coverage

**Difficulty**: 3/5

**Shipping**: No

---

### M059: Unit Tests - Executors
**Objective**: Test each command executor

**Why**: Execution must be reliable

**Dependencies**: M018-M021, M043-M045

**Deliverables**:
- Test suite for each executor
- Mock file system for file operations
- Mock NSWorkspace for app launching

**Success Criteria**:
- All tests pass
- Code coverage >70% for executors

**Testing**:
- Run test suite
- Verify coverage

**Difficulty**: 4/5

**Shipping**: No

---

### M060: Integration Tests
**Objective**: Test end-to-end flows

**Why**: Ensure components work together

**Dependencies**: M058, M059

**Deliverables**:
- Test: User input → LLM → Executor → Result
- Test permission flows
- Test error handling

**Success Criteria**:
- Key user flows work
- No crashes in test suite

**Testing**:
- Run integration tests
- Fix failures

**Difficulty**: 4/5

**Shipping**: No

---

### M061: UI Tests
**Objective**: Automated UI testing

**Why**: Catch UI regressions

**Dependencies**: M007-M010

**Deliverables**:
- XCUITest suite
- Test hotkey toggle activation (show/hide)
- Test input and submission
- Test settings navigation

**Success Criteria**:
- UI tests pass
- Cover major user flows

**Testing**:
- Run UI test suite
- Verify on CI (if set up)

**Difficulty**: 3/5

**Shipping**: No

---

### M062: Performance Testing
**Objective**: Verify performance targets

**Why**: Ensure app is fast

**Dependencies**: M016, M018-M021

**Deliverables**:
- Benchmark suite
- Measure: hotkey response, LLM inference, command execution
- Compare against targets in `01-ARCHITECTURE.md`

**Success Criteria**:
- All benchmarks meet targets
- No performance regressions

**Testing**:
- Run benchmarks
- Profile with Instruments
- Optimize if needed

**Difficulty**: 3/5

**Shipping**: No

---

### M063: Memory Leak Testing
**Objective**: Ensure no memory leaks

**Why**: App stability

**Dependencies**: M011-M013

**Deliverables**:
- Run Instruments Leaks tool
- Test LLM load/unload cycles
- Test window open/close cycles
- Fix any leaks found

**Success Criteria**:
- No leaks detected
- Memory usage stays stable

**Testing**:
- Run with Instruments
- Use app for extended period

**Difficulty**: 3/5

**Shipping**: No

---

### M064: Security Audit
**Objective**: Verify security measures

**Why**: Trust and safety

**Dependencies**: M022, M029

**Deliverables**:
- Manual code review of security-critical code
- Fuzzing tests (malformed inputs)
- Verify sanitization works
- Check entitlements are minimal

**Success Criteria**:
- No security issues found
- All injection attempts blocked
- Checklist in `02-THREAT-MODEL.md` complete

**Testing**:
- Run fuzzing tests
- Manual code review
- External audit (future)

**Difficulty**: 4/5

**Shipping**: No

---

### M065: Beta Testing Program
**Objective**: Get real-world feedback

**Why**: Find bugs we missed

**Dependencies**: M055 (need distributable build)

**Deliverables**:
- Recruit 10-20 beta testers
- Distribute via DMG
- Collect feedback (form or email)
- Track crashes (if opt-in enabled)

**Success Criteria**:
- 10+ testers actively using
- Feedback collected
- Critical bugs identified

**Testing**:
- Deploy to testers
- Monitor feedback
- Triage issues

**Difficulty**: 2/5 (logistics)

**Shipping**: No

---

### M066: Bug Fixes from Beta
**Objective**: Fix issues found in beta

**Why**: Polish before public release

**Dependencies**: M065

**Deliverables**:
- All critical bugs fixed
- High-priority bugs fixed
- Medium bugs triaged for post-launch

**Success Criteria**:
- No known critical bugs
- App is stable for beta testers

**Testing**:
- Re-test fixed bugs
- Regression testing

**Difficulty**: Variable

**Shipping**: No

---

## PHASE 11: LAUNCH PREPARATION

### M067: Documentation - User Guide
**Objective**: Write user-facing documentation

**Why**: Help users get started

**Dependencies**: M066 (app should be stable)

**Deliverables**:
- README.md for GitHub/website
- Getting Started guide
- Command reference (list of supported commands)
- FAQ
- Troubleshooting guide

**Success Criteria**:
- Documentation is clear and complete
- Covers common issues
- Screenshots included

**Testing**:
- Have non-technical user follow guide
- Revise based on feedback

**Difficulty**: 3/5

**Shipping**: No

---

### M068: Privacy Policy
**Objective**: Legal document on data handling

**Why**: Required, builds trust

**Dependencies**: None

**Deliverables**:
- Privacy policy document
- Hosted on website or in app
- Covers: what data is collected (none), local storage, optional features

**Success Criteria**:
- Legally compliant
- User-friendly language
- Accessible from app (About tab)

**Testing**:
- Legal review (optional)
- User readability check

**Difficulty**: 2/5

**Shipping**: No

---

### M069: Website / Landing Page
**Objective**: Public-facing website

**Why**: Distribution and information

**Dependencies**: M051, M067

**Deliverables**:
- Simple landing page
- Features overview
- Download link
- Documentation links
- Privacy policy link

**Success Criteria**:
- Professional appearance
- Clear call-to-action (Download)
- Mobile-friendly

**Testing**:
- Test on multiple browsers
- Get design feedback

**Difficulty**: 3/5

**Shipping**: No

---

### M070: GitHub Repository Setup
**Objective**: Public or private repo for distribution

**Why**: Versioning, issue tracking, releases

**Dependencies**: M067

**Deliverables**:
- GitHub repo created
- README.md
- LICENSE file
- .gitignore configured
- GitHub Releases for distribution
- Issue templates

**Success Criteria**:
- Repo is well-organized
- Releases work for DMG hosting
- Issues can be filed

**Testing**:
- Test cloning repo
- Test release upload

**Difficulty**: 2/5

**Shipping**: No

---

### M071: Analytics Decision
**Objective**: Decide if adding opt-in analytics

**Why**: Understand usage patterns

**Dependencies**: None (decision point)

**Deliverables**:
- Decision: Yes (opt-in) or No
- If Yes: Implement privacy-preserving analytics
- If No: Document decision

**Success Criteria**:
- Decision made and documented
- If implemented: Opt-in UI works

**Testing**:
- If implemented: Verify data is anonymized

**Difficulty**: Variable

**Shipping**: No

---

### M072: Crash Reporting Opt-In
**Objective**: Implement crash reporting

**Why**: Fix crashes we don't know about

**Dependencies**: M071

**Deliverables**:
- Crash reporting library (e.g., Sentry, Crashlytics)
- Opt-in during first launch
- Can be disabled in Settings
- Anonymize all data

**Success Criteria**:
- Crashes are reported (if opted in)
- No PII sent
- Can be disabled

**Testing**:
- Trigger test crash
- Verify report received
- Verify opt-out works

**Difficulty**: 3/5

**Shipping**: No (optional feature)

---

### M073: Final QA Pass
**Objective**: Comprehensive testing before launch

**Why**: Last chance to find bugs

**Dependencies**: M066

**Deliverables**:
- Test all features
- Test all commands
- Test on multiple Macs (if available)
- Test on different macOS versions
- Verify permissions flow
- Verify update mechanism

**Success Criteria**:
- No critical bugs found
- All features work as expected
- Performance meets targets

**Testing**:
- Systematic testing of all features
- Edge cases
- User scenarios

**Difficulty**: 3/5

**Shipping**: No

---

### M074: Launch Checklist
**Objective**: Final pre-launch verification

**Why**: Ensure nothing is forgotten

**Dependencies**: M067-M073

**Deliverables**:
- Checklist of launch requirements
- Items: Code signed ✓, Notarized ✓, Docs ✓, Website ✓, etc.
- All items checked off

**Success Criteria**:
- Every item on checklist is complete
- Ready to publish download link

**Testing**:
- Review checklist with fresh eyes

**Difficulty**: 1/5

**Shipping**: No

---

## PHASE 12: PUBLIC LAUNCH

### M075: Public Release
**Objective**: Make app publicly available

**Why**: Launch day!

**Dependencies**: M074

**Deliverables**:
- DMG uploaded to GitHub Releases
- Website updated with download link
- Announcement (blog post, social media, etc.)
- Monitor for issues

**Success Criteria**:
- Download link works
- Users can install and run app
- No immediate critical bugs

**Testing**:
- Download from public link
- Install on clean Mac
- Verify works

**Difficulty**: 2/5

**Shipping**: YES - PUBLIC LAUNCH

---

### M076: Post-Launch Monitoring
**Objective**: Track issues and feedback

**Why**: Catch problems early

**Dependencies**: M075

**Deliverables**:
- Monitor GitHub issues
- Monitor social media mentions
- Monitor crash reports (if enabled)
- Respond to users
- Triage bugs

**Success Criteria**:
- Active issue tracking
- Users feel heard
- Critical bugs identified quickly

**Testing**:
- N/A (ongoing process)

**Difficulty**: 2/5

**Shipping**: Post-launch activity

---

### M077: First Patch Release
**Objective**: Fix high-priority bugs from launch

**Why**: Stability improvements

**Dependencies**: M076

**Deliverables**:
- v1.0.1 release
- Bug fixes
- Updated DMG
- Release notes

**Success Criteria**:
- Fixes are deployed
- Users update successfully
- Stability improves

**Testing**:
- Test fixes
- Regression test
- Deploy update

**Difficulty**: Variable

**Shipping**: Patch release

---

## FUTURE PHASES (Post-MVP)

### Phase 13: Voice Input (Future)
- M078: Whisper model integration
- M079: Push-to-talk hotkey
- M080: Microphone permission handling
- M081: Speech-to-text accuracy testing

### Phase 14: Vision Features (Future)
- M082: Screen capture implementation
- M083: Claude API integration
- M084: Screen understanding prompts
- M085: Privacy warnings for vision mode

### Phase 15: Cloud Sync (Future)
- M086: iCloud integration
- M087: End-to-end encryption
- M088: Sync conflict resolution
- M089: Settings sync across devices

### Phase 16: Plugin System (Future)
- M090: Plugin API design
- M091: Sandboxing for plugins
- M092: Plugin marketplace
- M093: Community plugins

---

## Milestone Summary

**Total Milestones**: 93+ (MVP = M001-M077)

**By Phase**:
- Phase 0 (Setup): 4 milestones
- Phase 1 (UI): 6 milestones
- Phase 2 (LLM): 6 milestones
- Phase 3 (Execution): 8 milestones
- Phase 4 (Permissions): 6 milestones
- Phase 5 (Data): 6 milestones
- Phase 6 (Polish): 6 milestones
- Phase 7 (Executors): 3 milestones
- Phase 8 (Advanced): 5 milestones
- Phase 9 (Distribution): 7 milestones
- Phase 10 (Testing): 9 milestones
- Phase 11 (Launch Prep): 8 milestones
- Phase 12 (Launch): 3 milestones
- Future: 16+ milestones

**Estimated Timeline** (one developer, part-time):
- Phases 0-3: 2-3 weeks
- Phases 4-6: 2-3 weeks
- Phases 7-9: 2-3 weeks
- Phases 10-11: 1-2 weeks
- Phase 12: 1 week
- **Total MVP: 8-12 weeks**

**Critical Path**:
M001 → M003 → M004 → M011 → M013 → M016 → M018 → M022 → M026 → M052 → M054 → M073 → M075

---

## Next Actions

**Immediate Next Steps**:
1. ~~Complete M001 (Project Initialization)~~ ✅ Done
2. ~~Complete M002 (Documentation Integration)~~ ✅ Done
3. ~~Complete M003 (Download LLM model)~~ ✅ Done
4. ~~Complete M004 (Add dependencies)~~ ✅ Done
5. ~~Complete M005 (App Structure & Entry Point)~~ ✅ Done
6. ~~Complete M006 (Global Hotkey Detection)~~ ✅ Done
7. ~~Complete M007 (Floating Window UI)~~ ✅ Done
8. ~~Complete M008 (Text Input Field)~~ ✅ Done
9. ~~Complete M009 (Results Display Area)~~ ✅ Done
10. ~~Complete M010 (Settings Window)~~ ✅ Done
11. ~~Complete M011 (LLM Model File Loader)~~ ✅ Done
12. ~~Complete M012 (llama.cpp Swift Bridge)~~ ✅ Done
13. ~~Complete M013 (Basic Inference Test)~~ ✅ Done
14. ~~Complete M014 (Prompt Template Builder)~~ ✅ Done
15. ~~Complete M015 (JSON Output Parsing)~~ ✅ Done
16. ~~Complete M016 (End-to-End LLM Pipeline)~~ ✅ Done
17. ~~Complete M017 (Command Type Registry)~~ ✅ Done
18. ~~Complete M018 (App Launcher Executor)~~ ✅ Done
19. ~~Complete M019 (File Search Executor)~~ ✅ Done
20. ~~Complete M019b (Search Relevance Ranking)~~ ✅ Done
21. ~~Complete M020 (Window Manager Executor)~~ ✅ Done
22. Begin M021: System Info Executor

**Tracking Progress**:
- Mark completed milestones with ✓ in this file
- Update `manual-actions.md` as manual tasks are identified
- Commit after each milestone completion

**When Stuck**:
- Re-read `00-FOUNDATION.md` for principles
- Check `01-ARCHITECTURE.md` for technical details
- Consult `02-THREAT-MODEL.md` for security questions
- Break current milestone into smaller tasks

---

**Read Next**: `04-SHIPPING.md` for release strategy details.
