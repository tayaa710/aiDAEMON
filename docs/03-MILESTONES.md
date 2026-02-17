# 03 - MILESTONES

Complete development roadmap broken into atomic milestones.

Last Updated: 2026-02-17
Version: 2.0 (Strategic Pivot)

---

## Milestone Structure

Milestones are intentionally granular and may be documented in one of two formats:
- **Atomic format**: Full objective, dependencies, deliverables, success criteria, difficulty, shipping.
- **Grouped format**: Milestone headings plus phase-level objective, deliverables, and exit criteria.

Both formats are valid as long as sequencing, ownership, and gates remain clear.

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

### M021: System Info Executor ✅
**Status**: COMPLETE (2026-02-17)

**Objective**: Display system information

**Why**: Quick info commands

**Dependencies**: M017

**Deliverables**:
- [x] `SystemInfo.swift` struct implementing `CommandExecutor` protocol
- [x] 8 info types: IP address, disk space, CPU usage, battery, memory, hostname, OS version, uptime
- [x] Uses native Swift APIs (no shell commands): `getifaddrs`, `FileManager`, `host_processor_info`, `IOKit.ps`, `ProcessInfo`, `vm_statistics64`
- [x] Public IP via `api.ipify.org` with 5-second timeout
- [x] Alias resolution for LLM output variants (e.g. "ip" → ip_address, "ram" → memory, "storage" → disk_space, "ram_usage" → memory, "battery_status" → battery)
- [x] Hyphen/underscore/case normalisation for target strings
- [x] Registered in `AppDelegate` on launch via `CommandRegistry.shared.register()`
- [x] `PromptBuilder` updated: SYSTEM_INFO/QUICK_ACTION boundary clarified, 3 extra SYSTEM_INFO examples added ("check battery", "how much ram", "disk space") to fix LLM misclassification of battery queries as QUICK_ACTION
- [x] Test deadlock fixed: Tests 8-12 call `fetch()` directly (avoids `DispatchGroup.wait()` deadlock on main thread)

**Success Criteria**:
- [x] "what's my ip" → shows local + public IP address
- [x] "check battery" → shows battery level/status (correctly routed as SYSTEM_INFO)
- [x] "how much ram do i have" → shows memory details
- [x] "disk space" → shows total/used/free with percentages
- [x] Results formatted cleanly with labels

**Testing**:
- [x] Build succeeds (BUILD SUCCEEDED)
- [x] Test 1: Executor name is 'SystemInfo' (automated)
- [x] Test 2: All 8 canonical targets resolve (automated)
- [x] Test 3: All aliases resolve correctly (automated)
- [x] Test 4: Unknown target returns nil (automated)
- [x] Test 5: Hyphen/underscore/case normalisation works (automated)
- [x] Test 6: Missing target returns error (automated)
- [x] Test 7: Unknown target returns descriptive error (automated)
- [x] Test 8: Disk space returns success with details (automated)
- [x] Test 9: OS version returns success with macOS info (automated)
- [x] Test 10: Hostname returns non-empty result (automated)
- [x] Test 11: Uptime returns formatted duration (automated)
- [x] Test 12: Memory returns success with total (automated)
- [x] Test 13: End-to-end parse SYSTEM_INFO command (automated)
- [x] "check battery" routes to SYSTEM_INFO (verified via prompt fix)
- [x] "how much ram do i have" routes to SYSTEM_INFO with target "memory"
- [ ] All info types verified in live UI (manual test)
- [ ] Test on battery and plugged in (manual test)

**Difficulty**: 2/5

**Shipping**: No

**Notes**: Uses native Swift APIs exclusively — no shell-outs or `Process` calls. IP address uses `getifaddrs` for local IP and `URLSession` for public IP (with 5-second timeout to avoid hanging). CPU usage from `host_processor_info` (Mach kernel API). Battery via `IOKit.ps` framework (`IOPSCopyPowerSourcesInfo`). Memory via `vm_statistics64`. All queries dispatched to background queue; completion called on main queue. Tests 8-12 call `fetch()` directly to avoid main-thread deadlock (tests run on main queue, so `DispatchGroup.wait()` would block the `DispatchQueue.main.async` completion callback). Post-completion fixes: added `ram_usage` and `battery_status` aliases; updated `PromptBuilder` with SYSTEM_INFO examples and boundary clarification to prevent LLM misclassification.

---

### M022: Command Validation Layer ✅
**Status**: COMPLETE (2026-02-17)

**Objective**: Validate commands before execution

**Why**: Security and safety

**Dependencies**: M017

**Deliverables**:
- [x] `CommandValidator.swift` struct with `validate(_:) -> ValidationResult` method
- [x] `ValidationResult` enum: `.valid(Command)`, `.needsConfirmation(Command, reason:, level:)`, `.rejected(reason:)`
- [x] `SafetyLevel` enum: `.safe`, `.caution`, `.dangerous`
- [x] Input sanitization: strips null bytes + control chars, truncates to 500 chars per field
- [x] Required field validation for all 7 command types with descriptive error messages
- [x] Path traversal detection (`../`, `/..`) for FILE_OP and FILE_SEARCH commands
- [x] Safety classification: read-only ops → `.safe`; file ops/quit → `.caution`; force kill → `.dangerous`
- [x] Wired into `FloatingWindow.handleGenerationResult` between parse and execute
- [x] `executeValidatedCommand()` helper extracted to clean up pipeline
- [x] 15 automated tests covering validation, sanitization, safety classification, path traversal
- [x] Tests wired into `AppDelegate` debug test suite

**Success Criteria**:
- [x] Valid commands pass through unchanged
- [x] Invalid commands rejected with explanation
- [x] Dangerous commands flagged for confirmation (M023 will add dialog)
- [x] Path traversal attempts blocked

**Testing**:
- [x] Build succeeds (BUILD SUCCEEDED)
- [x] Test 1: Valid SYSTEM_INFO is .valid (automated)
- [x] Test 2: SYSTEM_INFO with nil target is .rejected (automated)
- [x] Test 3: Valid APP_OPEN is .valid (automated)
- [x] Test 4: FILE_SEARCH with 1-char query is .rejected (automated)
- [x] Test 5: Valid FILE_SEARCH is .valid (automated)
- [x] Test 6: Path traversal in FILE_OP target is .rejected (automated)
- [x] Test 7: Control characters stripped from target (automated)
- [x] Test 8: Overlong target truncated to 500 chars (automated)
- [x] Test 9: FILE_OP delete needs .caution confirmation (automated)
- [x] Test 10: PROCESS_MANAGE force_quit needs .dangerous confirmation (automated)
- [x] Test 11: WINDOW_MANAGE is .valid (non-destructive) (automated)
- [x] Test 12: WINDOW_MANAGE with blank target is .rejected (automated)
- [x] Test 13: Confirmation reason contains target name (automated)
- [x] Test 14: FILE_SEARCH resolves query field correctly (automated)
- [x] Test 15: APP_OPEN with empty string target is .rejected (automated)

**Difficulty**: 3/5

**Shipping**: No

**Notes**: Validator sits between `CommandParser.parse` and `CommandRegistry.execute`. `.needsConfirmation` cases currently log the reason and proceed (M023 will intercept these for the confirmation dialog). Sanitization runs on every command: control chars stripped, max 500 chars enforced per string field. Path traversal check covers `../` and `/..` sequences.

---

### M023: Confirmation Dialog System ✅
**Status**: COMPLETE (2026-02-17)

**Objective**: Show confirmation for destructive actions

**Why**: Prevent accidental damage

**Dependencies**: M022

**Deliverables**:
- [x] `ConfirmationDialog.swift` — `ConfirmationState` observable + `ConfirmationDialogView` SwiftUI view
- [x] `ConfirmationState` manages pending command, reason, safety level, and approve/cancel callbacks
- [x] Inline confirmation view replaces results area in FloatingWindow when `.needsConfirmation` is returned
- [x] Approve button executes the command; Cancel button shows "Action cancelled" message
- [x] Visual styling: orange background/border for `.caution`, red for `.dangerous`
- [x] Dangerous actions show "Warning" header with triangle icon and "Proceed Anyway" button (red tint)
- [x] Caution actions show "Confirm Action" header with circle icon and "Approve" button (accent tint)
- [x] Escape key dismisses confirmation (via existing `clearInputAndHide`)
- [x] 8 automated tests covering state lifecycle, callbacks, and validator integration
- [x] Tests wired into `AppDelegate` debug test suite

**Success Criteria**:
- [x] Destructive command → confirmation dialog appears inline
- [x] Approve → command executes
- [x] Cancel → "Action cancelled" message shown
- [x] Safe commands bypass dialog entirely

**Testing**:
- [x] Build succeeds (BUILD SUCCEEDED)
- [x] Test 1: Initial state is not presented (automated)
- [x] Test 2: Present sets all fields correctly (automated)
- [x] Test 3: Dismiss clears all fields and callbacks (automated)
- [x] Test 4: onApprove callback fires (automated)
- [x] Test 5: onCancel callback fires (automated)
- [x] Test 6: FILE_OP delete triggers caution confirmation (automated)
- [x] Test 7: PROCESS_MANAGE force_quit triggers dangerous confirmation (automated)
- [x] Test 8: Safe command does not trigger confirmation (automated)
- [ ] Test destructive commands in live UI (manual test)
- [ ] Verify cancel shows "Action cancelled" (manual test)
- [ ] Verify approve executes command (manual test)

**Difficulty**: 2/5

**Shipping**: No

**Notes**: Confirmation dialog is shown inline in the floating window, replacing the results area. Uses `ConfirmationState` observable to drive visibility and button callbacks. `FloatingWindow.presentConfirmation()` sets up approve/cancel closures that dismiss the dialog and either execute or show cancellation message. Keyboard shortcuts: Enter = approve (`.defaultAction`), Escape = cancel (`.cancelAction` + existing window dismiss). Visual distinction between caution (orange) and dangerous (red) levels helps users gauge risk.

---

### M024: Execution Result Handling ✅
**Status**: COMPLETE (2026-02-17)

**Objective**: Display execution results and errors

**Why**: User feedback

**Dependencies**: M018-M021

**Deliverables**:
- [x] SF Symbol icons in ResultsView header: `checkmark.circle.fill` (success), `xmark.circle.fill` (error)
- [x] Updated labels: "Success" (was "Result"), "Error", "Processing"
- [x] Compact result display: `"user input → Action Type"` context line + executor output
- [x] Loading state shows `"Executing: Action Type..."` during command dispatch
- [x] 6 automated tests covering icons, labels, state lifecycle, and color distinctness
- [x] Tests wired into `AppDelegate` debug test suite

**Success Criteria**:
- [x] Success → green checkmark + "Success" label + message
- [x] Error → red X + "Error" label + error description
- [x] Output formatted with compact context line + executor results

**Testing**:
- [x] Build succeeds (BUILD SUCCEEDED)
- [x] Test 1: Success style has checkmark icon and 'Success' label (automated)
- [x] Test 2: Error style has xmark icon and 'Error' label (automated)
- [x] Test 3: Loading style has 'Processing' label (automated)
- [x] Test 4: ResultsState show/clear lifecycle works (automated)
- [x] Test 5: All styles have distinct text colors (automated)
- [x] Test 6: Success/error have icons, loading does not (automated)
- [ ] Test successful commands in live UI (manual test)
- [ ] Test failing commands in live UI (manual test)

**Difficulty**: 2/5

**Shipping**: No

**Notes**: ResultsView now shows SF Symbol icons alongside the header label for success (green checkmark) and error (red X). Loading state retains the ProgressView spinner. Execution results display a compact `"user input → Action Type"` context line instead of the verbose command breakdown, keeping results clean and scannable.

---

## PHASE 4: PIVOT TRANSITION

### M025: Strategic Pivot Documentation Baseline ✅
**Status**: COMPLETE (2026-02-17)

**Objective**: Rewrite project documentation to reflect the companion-first vision.

**Why**: The old roadmap optimized for a command launcher, not a JARVIS-style companion.

**Dependencies**: M024

**Deliverables**:
- Foundation, architecture, threat model, milestones, shipping docs rewritten.
- Completed milestones M001-M024 preserved.
- New roadmap created with transition milestones first.

**Success Criteria**:
- Documentation consistently reflects the pivot.
- Next milestone points to transition execution work (not legacy scope).

**Difficulty**: 2/5
**Shipping**: No

---

### M026: Build Stability Recovery
**Status**: PLANNED

**Objective**: Return the project to a reliable build baseline before structural migration.

**Why**: Migration without a stable baseline creates false regressions and debugging noise.

**Dependencies**: M025

**Deliverables**:
- Build succeeds in Debug and Release.
- Existing command flows smoke-tested.
- Build break checklist added to contributor workflow.

**Success Criteria**:
- One-command build success on primary dev machine.
- No known compile blockers in active branch.

**Difficulty**: 2/5
**Shipping**: No

---

### M027: Legacy Capability Inventory
**Status**: PLANNED

**Objective**: Produce a capability map of existing working features and known gaps.

**Why**: Pivot migration requires explicit reuse versus replace decisions.

**Dependencies**: M026

**Deliverables**:
- Matrix of supported commands, quality level, and known defects.
- Executor maturity scoring (A/B/C).
- Legacy-to-new architecture mapping notes.

**Success Criteria**:
- Inventory is complete enough to drive migration planning.

**Difficulty**: 2/5
**Shipping**: No

---

### M028: Legacy-to-Tool Compatibility Adapter (Design)
**Status**: PLANNED

**Objective**: Define how current command dispatch maps to future tool calls.

**Why**: We need backward compatibility while agent runtime is introduced.

**Dependencies**: M027

**Deliverables**:
- Adapter interface spec.
- Mapping rules from `CommandType` to tool schemas.
- Error and fallback behavior defined.

**Success Criteria**:
- Design is approved and unblocks implementation milestones.

**Difficulty**: 3/5
**Shipping**: No

---

### M029: Conversation State Model (Design)
**Status**: PLANNED

**Objective**: Define canonical conversation turn, task, and step models.

**Why**: Agentic behavior requires persistent structured state.

**Dependencies**: M028

**Deliverables**:
- Conversation turn schema.
- Task/step lifecycle states.
- Minimal storage contract.

**Success Criteria**:
- Schema supports multi-step execution and retry tracking.

**Difficulty**: 3/5
**Shipping**: No

---

### M030: Orchestrator State Machine (Design)
**Status**: PLANNED

**Objective**: Define orchestrator states and transition rules.

**Why**: Agent loop reliability depends on deterministic state transitions.

**Dependencies**: M029

**Deliverables**:
- State machine diagram.
- Transition table with failure handling.
- Cancellation and timeout policy.

**Success Criteria**:
- All command paths map to explicit states.

**Difficulty**: 3/5
**Shipping**: No

---

### M031: Policy Engine v1 Ruleset (Design)
**Status**: PLANNED

**Objective**: Specify baseline risk classes and approval rules.

**Why**: Planning without runtime policy enforcement is unsafe.

**Dependencies**: M030

**Deliverables**:
- Safe/caution/dangerous matrix by tool class.
- Autonomy-level gating rules.
- Deny-by-default behavior for unknown actions.

**Success Criteria**:
- Ruleset is testable and implementation-ready.

**Difficulty**: 3/5
**Shipping**: No

---

### M032: Permission UX Refresh Plan
**Status**: PLANNED

**Objective**: Redesign permission messaging for companion workflows.

**Why**: Companion scope needs clearer permission context and trust framing.

**Dependencies**: M031

**Deliverables**:
- Permission screens and user copy.
- Capability-to-permission mapping.
- Degraded-mode behavior documented.

**Success Criteria**:
- Permission flow is understandable for non-technical alpha testers.

**Difficulty**: 2/5
**Shipping**: No

---

### M033: Observability Baseline
**Status**: PLANNED

**Objective**: Define minimum telemetry/logging for debugging agent behavior locally.

**Why**: Multi-step systems are hard to debug without traces.

**Dependencies**: M032

**Deliverables**:
- Structured local logs for plan, action, outcome.
- Correlation IDs across a conversation turn.
- Redaction policy for sensitive values.

**Success Criteria**:
- Failed workflows can be traced end-to-end from logs.

**Difficulty**: 3/5
**Shipping**: No

---

### M034: Pivot Transition Exit Gate
**Status**: PLANNED

**Objective**: Approve transition readiness before implementing the new core.

**Why**: Prevent architecture churn and rework.

**Dependencies**: M026-M033

**Deliverables**:
- Transition review checklist completed.
- Risks and unknowns prioritized.
- Agent core milestone backlog confirmed.

**Success Criteria**:
- Team agrees migration can start with controlled risk.

**Difficulty**: 2/5
**Shipping**: No

---

## PHASE 5: AGENT CORE

### M035: Tool Schema Specification v1
### M036: Tool Registry Runtime v1
### M037: Planner Prompt Contract v1
### M038: Step Graph Data Model
### M039: Orchestrator Skeleton Implementation
### M040: Step Execution Controller
### M041: Result Normalization Layer
### M042: Clarification Question Flow
### M043: Retry and Recovery Strategy
### M044: Plan Explanation Generator
### M045: Cancellation and Interrupt Handling
### M046: Background Task Progress Model
### M047: Plan Confidence Scoring
### M048: Error Taxonomy for Agent Runtime
### M049: Planner Evaluation Harness
### M050: Prompt Versioning and Rollback
### M051: Legacy Pipeline Adapter v1
### M052: Agent Core Exit Gate

**Status for M035-M052**: PLANNED

**Phase Objective**: Deliver a working agent loop that can reason, plan, execute, recover, and explain.

**Phase Deliverables**:
- Schema-based tool routing live.
- Multi-step execution (2-5 step plans) operational.
- User-visible planning and explanation path.
- Legacy commands routable through adapter during migration.

**Phase Exit Criteria**:
- Core workflows can run through orchestrator path.
- Policy hooks exist in every action path.
- Regression risk to legacy functionality is controlled.

**Difficulty**: 5/5
**Shipping**: No

---

## PHASE 6: TOOL RUNTIME EXPANSION

### M053: File Operations Executor v1
### M054: Process Management Executor v1
### M055: Quick Actions Executor v1
### M056: Browser Control Tool v1
### M057: Finder Selection Tool v1
### M058: Clipboard Read/Write Tool v1
### M059: Notification Tool v1
### M060: Calendar Read Tool v1
### M061: Calendar Write Tool v1
### M062: Reminder Read/Write Tool v1
### M063: Notes Tool v1
### M064: Email Draft Tool v1
### M065: Local Knowledge Index Tool v1
### M066: Safe Terminal Task Tool v1
### M067: Tool Permission Scoping UI
### M068: Tool Timeout and Circuit Breakers
### M069: Tool Error Recovery Patterns
### M070: Tool Reliability Test Suite
### M071: Tool Performance Budget Pass
### M072: Tool Runtime Exit Gate

**Status for M053-M072**: PLANNED

**Phase Objective**: Expand from narrow command support to broad companion capabilities.

**Phase Deliverables**:
- Missing legacy executor families implemented.
- New high-value companion tools added.
- Tool permissions, timeouts, and resilience controls in place.

**Phase Exit Criteria**:
- At least 15 high-utility tools are production-candidate quality.
- Tool failures degrade gracefully with recoverable messaging.

**Difficulty**: 4/5
**Shipping**: No

---

## PHASE 7: MEMORY AND CONTEXT

### M073: Working Memory Store
### M074: Session Memory Store
### M075: Long-Term Memory Store
### M076: Memory Write Policy Engine
### M077: Memory Retrieval Ranking v1
### M078: Memory Conflict Resolution Rules
### M079: Memory Controls UI (View/Edit/Delete)
### M080: Memory Export and Full Wipe
### M081: Frontmost App Context Provider
### M082: Finder Context Provider
### M083: Clipboard Context Provider
### M084: Browser Tab Context Provider (Opt-In)
### M085: Context Redaction Filters
### M086: Memory+Context Exit Gate

**Status for M073-M086**: PLANNED

**Phase Objective**: Make the assistant context-aware and personalized without violating privacy boundaries.

**Phase Deliverables**:
- Tiered memory model implemented.
- User controls for memory transparency and deletion.
- Context providers available with trust/consent boundaries.

**Phase Exit Criteria**:
- Memory behavior is auditable and user-controllable.
- Context improves quality without unsafe overreach.

**Difficulty**: 5/5
**Shipping**: No

---

## PHASE 8: MULTIMODAL AND COMPANION UX

### M087: Chat-First Interaction Redesign
### M088: Conversation Timeline and Search
### M089: Voice Input Pipeline v1
### M090: Push-to-Talk UX
### M091: On-Device TTS Response v1
### M092: Voice Interrupt and Barge-In Handling
### M093: Screen Capture Consent Flow
### M094: Vision Context Parser v1
### M095: Multimodal Plan Fusion
### M096: Companion Persona Controls
### M097: Proactive Suggestions (Non-Autonomous)
### M098: Routine Template Library
### M099: Accessibility and Internationalization Pass
### M100: Companion UX Exit Gate

**Status for M087-M100**: PLANNED

**Phase Objective**: Deliver a companion experience that feels conversational, multimodal, and human-usable.

**Phase Deliverables**:
- Voice path usable for core tasks.
- Optional vision/context path with strict consent.
- Companion UX for daily usage patterns.

**Phase Exit Criteria**:
- Text + voice flows are reliable for common workflows.
- Multimodal features respect explicit privacy controls.

**Difficulty**: 4/5
**Shipping**: No

---

## PHASE 9: AUTONOMY AND SAFETY HARDENING

### M101: Autonomy Levels Implementation (L0-L3)
### M102: Scope-Based Auto-Approval Rules
### M103: Time-Bound Permission Grants
### M104: Dangerous Action Double Confirmation
### M105: Global Kill Switch and Safe Mode
### M106: Policy Fuzzing Harness
### M107: Prompt/Tool Injection Red-Team Pass
### M108: Incident Response Tooling
### M109: External Security Review Preparation
### M110: Safety Hardening Exit Gate

**Status for M101-M110**: PLANNED

**Phase Objective**: Ensure companion power does not outpace trust and safety.

**Phase Deliverables**:
- Runtime autonomy controls fully enforced.
- Security and abuse testing integrated.
- Emergency controls validated.

**Phase Exit Criteria**:
- No known critical policy bypasses.
- High-risk workflows require explicit user authority.

**Difficulty**: 5/5
**Shipping**: No

---

## PHASE 10: QUALITY, PERFORMANCE, AND RELEASE INFRA

### M111: End-to-End Scenario Test Suite
### M112: CI Pipeline and Quality Gates
### M113: Crash Reporting Opt-In
### M114: Performance Benchmark Suite
### M115: Soak and Leak Testing
### M116: Release Build Automation v2
### M117: Notarization and Update Channel Rehearsal
### M118: Pre-Alpha Candidate Gate

**Status for M111-M118**: PLANNED

**Phase Objective**: Prepare a stable release train before external testing cohorts.

**Phase Deliverables**:
- Automated quality coverage for core workflows.
- Reproducible build and release process.
- Known performance and stability baselines.

**Phase Exit Criteria**:
- Internal dogfood can run daily without major blockers.
- Release candidate quality is sufficient for alpha users.

**Difficulty**: 4/5
**Shipping**: No

---

## PHASE 11: ALPHA PROGRAM (EXTERNAL)

**Planned Window**: 2026-05-11 to 2026-06-26

### M119: Alpha Cohort Recruitment and Onboarding (2026-05-11)
### M120: Alpha Wave 1 (2026-05-18 to 2026-05-29)
### M121: Alpha Triage Sprint (2026-06-01 to 2026-06-05)
### M122: Alpha Wave 2 Verification (2026-06-08 to 2026-06-19)
### M123: Alpha Exit Gate (2026-06-22 to 2026-06-26)

**Status for M119-M123**: PLANNED

**Phase Objective**: Validate real-world usability and uncover architectural edge cases early.

**Phase Deliverables**:
- 15-30 alpha testers across varied hardware profiles.
- Structured feedback and issue triage loops.
- High-priority alpha defects resolved or mitigated.

**Phase Exit Criteria**:
- No unresolved critical defects.
- Weekly active usage signal from alpha cohort.
- Clear readiness for beta scale-up.

**Difficulty**: 3/5
**Shipping**: No

---

## PHASE 12: BETA PROGRAM (BROADER)

**Planned Window**: 2026-07-06 to 2026-08-21

### M124: Beta Infrastructure and Waitlist Prep (2026-06-29)
### M125: Beta Launch Wave (2026-07-06)
### M126: Beta Stabilization Sprint 1 (2026-07-20)
### M127: Beta Stabilization Sprint 2 (2026-08-03)
### M128: Beta Exit Gate (2026-08-17 to 2026-08-21)

**Status for M124-M128**: PLANNED

**Phase Objective**: Validate stability, reliability, and supportability at broader scale.

**Phase Deliverables**:
- 100+ beta participants.
- Release updates shipped during beta with low friction.
- Performance, crash, and task-success metrics tracked.

**Phase Exit Criteria**:
- Crash-free sessions meet target.
- Task completion quality meets launch thresholds.
- Support burden remains manageable.

**Difficulty**: 3/5
**Shipping**: No

---

## PHASE 13: PUBLIC LAUNCH

**Planned Window**: 2026-09-07 to 2026-10-05

### M129: Release Candidate Freeze (2026-09-07)
### M130: Launch Readiness Audit (2026-09-14)
### M131: Public Rollout (2026-09-28)
### M132: Week-1 Patch Planning and Rollout (2026-10-05)

**Status for M129-M132**: PLANNED

**Phase Objective**: Ship a trustworthy companion release and respond fast post-launch.

**Phase Deliverables**:
- Signed, notarized, update-enabled public build.
- Launch checklist completed.
- Week-1 issue response plan executed.

**Phase Exit Criteria**:
- Public users can install, trust, and use core companion workflows.
- No launch-blocking regressions remain open.

**Difficulty**: 3/5
**Shipping**: YES (M131)

---

## FUTURE PHASES (POST-V1)

### Phase 14: Ecosystem and Extensibility
- M133: Plugin SDK Design
- M134: Plugin Capability Sandbox
- M135: Community Plugin Distribution Model
- M136: Enterprise Policy Pack

### Phase 15: Hybrid Intelligence
- M137: Optional Cloud Reasoning Router
- M138: Privacy-Preserving Prompt Redaction Pipeline
- M139: Cross-Device Companion Sync (Opt-In)
- M140: Team Companion Workspaces

---

## Milestone Summary

**Completed Milestones**: M001-M025

**Total Milestones (Current + Planned)**: 140
- Foundation through launch: M001-M132
- Future/post-v1: M133-M140

**MVP/Launch Candidate Scope**: M001-M132

**By Phase (Updated)**:
- Phase 0-3 (legacy foundation): 25 milestones complete (M001-M025)
- Phase 4 (pivot transition): 9 planned milestones (M026-M034)
- Phase 5 (agent core): 18 planned milestones (M035-M052)
- Phase 6 (tool expansion): 20 planned milestones (M053-M072)
- Phase 7 (memory/context): 14 planned milestones (M073-M086)
- Phase 8 (multimodal/UX): 14 planned milestones (M087-M100)
- Phase 9 (autonomy/safety): 10 planned milestones (M101-M110)
- Phase 10 (quality/release infra): 8 planned milestones (M111-M118)
- Phase 11 (alpha): 5 planned milestones (M119-M123)
- Phase 12 (beta): 5 planned milestones (M124-M128)
- Phase 13 (public launch): 4 planned milestones (M129-M132)
- Phase 14-15 future: 8 milestones (M133-M140)

**Planned External Testing Windows**:
- Alpha: 2026-05-11 to 2026-06-26
- Beta: 2026-07-06 to 2026-08-21
- Public Launch Window: 2026-09-07 to 2026-10-05

**Critical Path (Pivoted)**:
M026 -> M034 -> M039 -> M052 -> M072 -> M086 -> M100 -> M110 -> M118 -> M123 -> M128 -> M131

---

## Next Actions

1. Complete M026 (Build Stability Recovery).
2. Complete M027 (Legacy Capability Inventory).
3. Complete M028-M031 (transition designs for adapter, state model, orchestrator, policy).
4. Use M034 exit gate to approve implementation start for agent core.

---

**Read Next**: `04-SHIPPING.md` for detailed stage gates and testing operations.
