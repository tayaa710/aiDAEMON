# 03 - MILESTONES

Complete development roadmap broken into atomic milestones.

Last Updated: 2026-02-15
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

### M001: Project Initialization
**Objective**: Create Xcode project and basic structure

**Why**: Need working project before writing code

**Dependencies**: None

**Deliverables**:
- Xcode project created
- SwiftUI macOS app template
- Bundle identifier set: `com.aidaemon`
- Deployment target: macOS 13.0+
- Git repository initialized
- `.gitignore` configured (Xcode, Models/, build artifacts)

**Success Criteria**:
- Project builds without errors
- Empty app launches and shows default window
- Git commit created

**Testing**:
- Build (Cmd+B) succeeds
- Run (Cmd+R) shows empty app

**Difficulty**: 1/5

**Shipping**: No

---

### M002: Documentation Integration
**Objective**: Link documentation into project

**Why**: Keep docs accessible during development

**Dependencies**: M001

**Deliverables**:
- `docs/` folder added to Xcode project as reference
- README.md at project root
- License file (MIT or similar)

**Success Criteria**:
- Docs visible in Xcode sidebar
- Can open and read from IDE

**Testing**:
- Open any doc file from Xcode

**Difficulty**: 1/5

**Shipping**: No

---

### M003: LLM Model Acquisition
**Objective**: Download and verify LLaMA 3 8B model

**Why**: Need model file before implementing inference

**Dependencies**: M001

**Deliverables**:
- LLaMA 3 8B Instruct (4-bit quantized) downloaded
- Model file placed in `Models/` directory
- Checksum verified
- `.gitignore` excludes `Models/` folder
- Documentation updated with model source

**Success Criteria**:
- File `Models/llama-3-8b-instruct-q4_k_m.gguf` exists
- File size ~4.3GB
- SHA256 checksum matches official release

**Testing**:
- Verify file integrity
- Test load with llama.cpp CLI (if available)

**Difficulty**: 2/5

**Shipping**: No

**Notes**: See `manual-actions.md` for download instructions

---

### M004: Swift Package Dependencies
**Objective**: Add required third-party packages

**Why**: Need external libraries for core functionality

**Dependencies**: M001

**Deliverables**:
- `llama.cpp` Swift bindings added (via SPM or manual)
- Sparkle framework added (via SPM)
- Sauce or KeyboardShortcuts added (via SPM)

**Success Criteria**:
- All packages resolve successfully
- Project builds with dependencies
- No version conflicts

**Testing**:
- Build project
- Import each package in test file

**Difficulty**: 3/5 (llama.cpp integration can be tricky)

**Shipping**: No

**Notes**: May need custom Swift bridge for llama.cpp - see M015

---

## PHASE 1: CORE UI

### M005: App Structure & Entry Point
**Objective**: Set up app lifecycle and window management

**Why**: Foundation for all UI work

**Dependencies**: M001, M004

**Deliverables**:
- `aiDAEMONApp.swift` - SwiftUI app entry point
- `AppDelegate.swift` - macOS lifecycle hooks
- Menu bar configuration (minimal: About, Quit)
- App activates without showing window by default

**Success Criteria**:
- App launches
- No default window appears
- Menu bar shows app name + Quit option
- App stays running in background

**Testing**:
- Launch app - no window should appear
- Check menu bar - app is running
- Quit from menu bar works

**Difficulty**: 2/5

**Shipping**: No

---

### M006: Global Hotkey Detection
**Objective**: Detect global hotkey to activate UI

**Why**: Primary user entry point

**Dependencies**: M005

**Deliverables**:
- `HotkeyManager.swift` class
- Register global hotkey: Cmd+Shift+Space (default)
- Notification posted when hotkey pressed
- Hotkey works even when app not focused

**Success Criteria**:
- Press Cmd+Shift+Space from any app
- Console logs "Hotkey pressed"
- Works regardless of focused app

**Testing**:
- Focus different apps (Safari, Finder, etc.)
- Press hotkey
- Verify notification received

**Difficulty**: 2/5

**Shipping**: No

---

### M007: Floating Window UI
**Objective**: Create floating input window

**Why**: Primary user interface

**Dependencies**: M006

**Deliverables**:
- `FloatingWindow.swift` - NSWindow subclass
- Window properties:
  - Always on top (`.floating` level)
  - No title bar
  - Centered on current screen
  - Size: 400x80px
  - Rounded corners, shadow
- Window shows on hotkey press
- Window hides on Escape key

**Success Criteria**:
- Hotkey shows window
- Window appears centered on screen with cursor
- Escape hides window
- Window stays above all other windows

**Testing**:
- Hotkey → window appears
- Escape → window disappears
- Try with multiple monitors (if available)

**Difficulty**: 3/5

**Shipping**: No

---

### M008: Text Input Field
**Objective**: Add text field to floating window

**Why**: User needs to type commands

**Dependencies**: M007

**Deliverables**:
- `CommandInputView.swift` - SwiftUI text field
- Placeholder text: "What do you want to do?"
- Auto-focus when window appears
- Enter key submits input
- Escape key clears and hides window

**Success Criteria**:
- Window shows with text field focused
- Can type text
- Enter key triggers action (print to console for now)
- Escape clears text and hides window

**Testing**:
- Type "hello world"
- Press Enter → see console log
- Press Escape → text clears, window hides

**Difficulty**: 2/5

**Shipping**: No

---

### M009: Results Display Area
**Objective**: Show command results below input field

**Why**: User needs feedback on what happened

**Dependencies**: M008

**Deliverables**:
- `ResultsView.swift` - displays text output
- Window expands vertically to show results
- Scrollable if output is long
- Styled text (success = green, error = red)

**Success Criteria**:
- After Enter, results area appears
- Shows test output
- Window resizes smoothly
- Scrolls if content > 300px

**Testing**:
- Submit command → see result
- Submit long output → verify scroll
- Test success and error styling

**Difficulty**: 2/5

**Shipping**: No

---

### M010: Settings Window
**Objective**: Create settings interface

**Why**: User needs to configure app

**Dependencies**: M005

**Deliverables**:
- `SettingsView.swift` - SwiftUI settings window
- Menu bar item: "Settings..." (Cmd+,)
- Tabbed interface: General, Permissions, History, About
- General tab: Hotkey selector placeholder, theme toggle (future)
- About tab: Version number, links

**Success Criteria**:
- Cmd+, opens settings window
- Tabs are navigable
- Window can be closed and reopened
- Settings persist across launches (via UserDefaults)

**Testing**:
- Open settings
- Navigate tabs
- Close and reopen - verify state

**Difficulty**: 2/5

**Shipping**: No

---

## PHASE 2: LLM INTEGRATION

### M011: LLM Model File Loader
**Objective**: Load LLaMA model file into memory

**Why**: Required for inference

**Dependencies**: M003, M004

**Deliverables**:
- `ModelLoader.swift` class
- Function: `loadModel(path:) -> ModelHandle?`
- Handles file not found error
- Handles corrupted model error
- Shows loading progress (future: progress bar)

**Success Criteria**:
- Model loads successfully from `Models/` directory
- Takes <5 seconds on M1 Mac
- Error handling works (test with invalid file)

**Testing**:
- Load valid model → success
- Load missing file → error message
- Load corrupted file → error message

**Difficulty**: 3/5

**Shipping**: No

---

### M012: llama.cpp Swift Bridge
**Objective**: Create Swift wrapper for llama.cpp C API

**Why**: Swift can't directly call C++ easily

**Dependencies**: M004

**Deliverables**:
- `LLMBridge.swift` or Objective-C bridging header
- Functions exposed: `loadModel()`, `generate()`, `unload()`
- Memory management (retain/release)

**Success Criteria**:
- Can call llama.cpp from Swift
- No memory leaks (test with Instruments)
- Errors are bridged properly

**Testing**:
- Call each function
- Verify memory with Instruments
- Unload model properly

**Difficulty**: 4/5 (C/Swift bridging is complex)

**Shipping**: No

**Notes**: May use existing Swift package if available

---

### M013: Basic Inference Test
**Objective**: Generate text from LLM

**Why**: Verify model and bridge work

**Dependencies**: M011, M012

**Deliverables**:
- `LLMManager.swift` class
- Function: `generate(prompt:) -> String`
- Test prompt: "Say hello"
- Output printed to console

**Success Criteria**:
- Prompt in → text out
- Generation completes in <3 seconds
- Output is coherent text

**Testing**:
- Run test prompt
- Verify output is sensible
- Check performance

**Difficulty**: 3/5

**Shipping**: No

---

### M014: Prompt Template Builder
**Objective**: Construct structured prompts for command parsing

**Why**: LLM needs specific format to output valid JSON

**Dependencies**: M013

**Deliverables**:
- `PromptBuilder.swift` class
- Function: `buildCommandPrompt(userInput:) -> String`
- Template as defined in `01-ARCHITECTURE.md`
- Few-shot examples included

**Success Criteria**:
- User input "open safari" → full prompt with examples
- Prompt is properly formatted
- User input is escaped/sanitized

**Testing**:
- Test with various user inputs
- Verify no prompt injection possible
- Check output format

**Difficulty**: 2/5

**Shipping**: No

---

### M015: JSON Output Parsing
**Objective**: Parse LLM JSON response into struct

**Why**: Need structured data for execution

**Dependencies**: M014

**Deliverables**:
- `CommandParser.swift` class
- Swift structs for each command type
- Function: `parseCommand(json:) -> Command?`
- Error handling for malformed JSON

**Success Criteria**:
- Valid JSON → parsed Command struct
- Invalid JSON → error with explanation
- Missing fields → error
- Unknown command type → error

**Testing**:
- Test all command types from architecture doc
- Test malformed JSON
- Test missing required fields

**Difficulty**: 2/5

**Shipping**: No

---

### M016: End-to-End LLM Pipeline
**Objective**: User input → LLM → parsed command

**Why**: Complete parsing flow

**Dependencies**: M015

**Deliverables**:
- Integration: User types → prompt built → LLM infers → JSON parsed
- Loading indicator in UI during inference
- Error messages shown in results area

**Success Criteria**:
- Type "open youtube" → returns `{type: APP_OPEN, target: "youtube.com"}`
- Loading spinner shows during inference
- Errors are user-friendly

**Testing**:
- Test each command type
- Verify timing (<2 sec)
- Test error handling

**Difficulty**: 3/5

**Shipping**: No

---

## PHASE 3: COMMAND EXECUTION

### M017: Command Type Registry
**Objective**: Map command types to executor classes

**Why**: Dispatching commands to correct handlers

**Dependencies**: M015

**Deliverables**:
- `CommandRegistry.swift` class
- Registry maps `CommandType` enum to executor class
- Function: `executor(for:) -> CommandExecutor`

**Success Criteria**:
- All command types have executors registered
- Unknown type → error
- Registry is extensible

**Testing**:
- Request executor for each type
- Verify correct executor returned

**Difficulty**: 2/5

**Shipping**: No

---

### M018: App Launcher Executor
**Objective**: Open applications and URLs

**Why**: Most common command type

**Dependencies**: M017

**Deliverables**:
- `AppLauncher.swift` class
- Implements `CommandExecutor` protocol
- Handles app names and URLs
- Uses `NSWorkspace.shared.launchApplication()`

**Success Criteria**:
- "open safari" → Safari opens
- "open youtube.com" → YouTube opens in default browser
- Invalid app name → error message

**Testing**:
- Open various apps (Safari, Chrome, Finder)
- Open URLs (http, https)
- Test invalid app names

**Difficulty**: 2/5

**Shipping**: No

---

### M019: File Search Executor
**Objective**: Search files using Spotlight

**Why**: Second most common command

**Dependencies**: M017

**Deliverables**:
- `FileSearcher.swift` class
- Uses `mdfind` command
- Parses results to array of file paths
- Displays results in UI

**Success Criteria**:
- "find tax" → lists files containing "tax"
- Results show file name and path
- Clickable to open in Finder (future)

**Testing**:
- Search for known files
- Search with no results
- Search with many results

**Difficulty**: 3/5

**Shipping**: No

---

### M020: Window Manager Executor
**Objective**: Resize and position windows

**Why**: Power user feature

**Dependencies**: M017

**Deliverables**:
- `WindowManager.swift` class
- Uses Accessibility API
- Commands: left half, right half, full screen, center
- Gets frontmost window

**Success Criteria**:
- "left half" → current window resizes to left 50%
- "full screen" → current window maximizes
- Works with different apps

**Testing**:
- Test each position command
- Test with Safari, Finder, TextEdit
- Verify smooth animation

**Difficulty**: 4/5 (Accessibility API is complex)

**Shipping**: No

**Notes**: Requires Accessibility permission - see M030

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
- Test hotkey activation
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
1. Complete M001 (Project Initialization)
2. Complete M003 (Download LLM model) - see `manual-actions.md`
3. Complete M004 (Add dependencies)
4. Begin Phase 1 (UI development)

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
