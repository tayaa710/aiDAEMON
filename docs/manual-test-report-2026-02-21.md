# Manual Milestone Test Report (M025-M044)

Date: 2026-02-21
Tester: Codex (manual + UI automation)
Build: `xcodebuild -project aiDAEMON.xcodeproj -scheme aiDAEMON -configuration Debug -sdk macosx -derivedDataPath /tmp/aiDAEMON-DerivedData build CODE_SIGNING_ALLOWED=NO` (`BUILD SUCCEEDED`)

## Scope
- Completed milestones under active roadmap: `M025` through `M044`
- Planned milestones `M045+` were not tested (not implemented)

## Environment Notes
- App launched successfully via `open /tmp/aiDAEMON-DerivedData/Build/Products/Debug/aiDAEMON.app`
- Local run of app binary directly (`.../Contents/MacOS/aiDAEMON`) crashes with SIGABRT (details in Findings)
- Cloud path is configured and operational (assistant returned cloud-badged completions)
- Accessibility and Screen Recording permissions were not available for this test run, which blocked full validation of computer-control milestones

## Milestone Matrix
- `M025` ModelProvider local abstraction: PASS (basic command execution path works)
- `M026` Cloud provider API client: PASS (cloud responses received consistently)
- `M027` API key settings UI: PARTIAL (key appears configured and usable; full settings-tab interaction not fully validated)
- `M028` Model router: FAIL (Always Local override did not force local execution)
- `M029` Conversation data model: PASS (conversation persisted across hide/show)
- `M030` Chat UI: PASS (chat bubbles/statuses/input behavior observed)
- `M031` Conversation context in prompts: PASS (`open Notes` -> `open it again` resolved pronoun correctly)
- `M032` Tool schema system: PASS (tool status messages observed during orchestrator runs)
- `M033` Claude provider + Level 1 autonomy: PARTIAL (Claude provider works; dangerous-action confirmation path not fully exercised)
- `M034` Orchestrator tool-use loop: PASS with UX issue (multi-step runs worked; kill switch worked but shows error text)
- `M035` MCP integration: PARTIAL (no crash/regression observed, but no live MCP server configured for functional tool-call test)
- `M036` Voice input: BLOCKED (microphone/manual speech path not testable in this automation session)
- `M037` Voice output: BLOCKED (audio playback/manual validation not testable in this automation session)
- `M038` Screenshot + vision: BLOCKED by Screen Recording permission
- `M039` Mouse control: BLOCKED by Accessibility permission
- `M040` Keyboard control: BLOCKED by Accessibility permission
- `M041` Integrated computer control: BLOCKED by Screen Recording/Accessibility permissions
- `M042` Accessibility service foundation: BLOCKED by Accessibility permission
- `M043` UI state provider + AX tools: PARTIAL (tool chosen; detailed AX tree unavailable due permissions)
- `M044` Foreground context lock + AX integration: BLOCKED by missing permissions required for target actions

## Verified Scenarios
1. Prompt: `open Calculator`
- Observed chat: `Opening Calculator...` then cloud-badged completion (`Calculator opened`)
- External verification: `Calculator` process running

2. Prompt: `find Xcode`
- Observed chat: `Searching for Xcode...`
- Final response includes `/Applications/Xcode.app`

3. Prompt: `show system info`
- Observed repeated tool-status updates (`Checking system info...`)
- Final structured system summary returned

4. Prompt: `open Notes then open Calculator`
- Observed two tool actions in one turn (`Opening Notes...`, `Opening Calculator...`)
- Final response confirms both apps opened

5. Prompt sequence: `open Notes` then `open it again`
- Pronoun resolution succeeded (`it` resolved to Notes)

6. Conversation persistence
- Hide/show via hotkey preserved prior transcript content exactly

7. Kill switch (Cmd+Shift+Escape during active run)
- Execution stopped and chat showed `Stopped.`
- Additional error text also shown (`Agent loop failed: Request was cancelled.`)

8. Prompt: `what is on my screen`
- AX-first status shown (`Reading screen state...`)
- Response included visible apps but noted Accessibility permission limitation

9. Prompt: `in Calculator, click 7`
- Flow attempted computer control
- Returned Screen Recording permission requirement (action not executed)

10. Prompt: `take a screenshot`
- Returned Screen Recording permission requirement (expected block)

## Findings (Bugs/Errors/Crashes)

1. Model routing override ignored (`M028`) - High
- Repro:
  1. Set routing mode to `Always Local`
  2. Restart app
  3. Submit `open Calculator`
- Expected: Local model badge/execution
- Actual: Cloud badge/execution still used (`Cloud` shown in transcript)
- Impact: User cannot enforce local-only behavior

2. Kill switch reports failure text after stop (`M034`) - Medium
- Repro:
  1. Submit `show system info`
  2. Trigger kill switch during execution (`Cmd+Shift+Escape`)
- Expected: clean `Stopped.` terminal state
- Actual: `Stopped.` followed by `Agent loop failed: Request was cancelled.`
- Impact: confusing UX; stop action appears as an error

3. Direct binary launch crash (SIGABRT) - Medium
- Repro:
  1. Run `/tmp/aiDAEMON-DerivedData/Build/Products/Debug/aiDAEMON.app/Contents/MacOS/aiDAEMON` directly from shell
- Expected: app process starts normally
- Actual: immediate abort (`EXIT:134`)
- Crash report: `~/Library/Logs/DiagnosticReports/aiDAEMON-2026-02-20-234401.ips`
- Top frames include `abort -> ___RegisterApplication_block_invoke -> GetCurrentProcess -> NSApplication init`
- Note: launching via `open .../aiDAEMON.app` works

## Permission-Gated Blockers (Not counted as implementation bugs)
- Accessibility permission missing prevented validation of AX actions, mouse, keyboard, and context lock execution paths
- Screen Recording permission missing prevented screenshot and vision/computer-control completion paths
- Voice input/output requires manual microphone/audio verification not feasible in this automation pass

## Recommended Next Manual Pass
1. Grant Accessibility + Screen Recording to the current Debug app identity.
2. Re-run M038-M044 action scenarios (click/type/window control) end-to-end.
3. Re-test `Always Local` after fixing routing override handling.
4. Clean kill-switch completion messaging to avoid post-stop error phrasing.
