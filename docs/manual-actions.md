# Manual Actions Checklist

This file records manual setup tasks that have been completed. New manual tasks are provided by the LLM agent after each milestone — they are NOT pre-listed here.

Last Updated: 2026-02-19

---

## How This Works

After completing each milestone, the LLM agent will tell you:
1. **Manual setup steps** — things you need to do (Xcode settings, permissions, downloads, etc.)
2. **Manual tests** — things to try to verify the milestone works

You do not need to look at this file for upcoming tasks. This file is a historical record only.

---

## Completed Setup (M001–M024)

- [x] Install Xcode
- [x] Install Xcode Command Line Tools
- [x] Verify Swift toolchain is available
- [x] Download `Models/model.gguf` (LLaMA 3.1 8B Instruct Q4_K_M, 4.6GB)
- [x] Verify model integrity (GGUF header + SHA256: `7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c`)
- [x] Add SPM dependencies (`LlamaSwift`, `Sparkle`, `KeyboardShortcuts`)
- [x] Grant Accessibility permission to aiDAEMON in System Settings → Privacy & Security → Accessibility
- [x] Build and run app in Xcode (Debug configuration)
- [x] Verify hotkey (Cmd+Shift+Space) summons floating window
- [x] Verify basic commands work: open apps, find files, move windows, system info

## Completed Setup (M025–M034)

- [x] Configure cloud provider in Settings → Cloud (Anthropic supported as first-class provider)
- [x] Save API key in macOS Keychain via Settings UI
- [x] Verify cloud test connection succeeds
- [x] Verify model routing options in Settings (Auto / Always Local / Always Cloud)
- [x] Verify autonomy setting in Settings (Level 0 / Level 1)
- [x] Verify conversational chat persistence across hide/show
- [x] Verify orchestrator multi-step loop is active for cloud requests
- [x] Verify inline confirmation flow appears when policy requires it
- [x] Verify emergency stop using Cmd+Shift+Escape
