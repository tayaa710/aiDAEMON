# 00 - FOUNDATION

**This document is the permanent source of truth.**

When in doubt, this file overrides issues, chat messages, code comments, and secondary docs.

Last Updated: 2026-02-17
Version: 3.0 (JARVIS Product Vision)

---

## What Is aiDAEMON?

**aiDAEMON is a JARVIS-style AI companion app for macOS.**

Think Iron Man's JARVIS — you talk to your computer (or type), and it does things for you. Open apps, move windows, set up workflows, search files, control browsers, manage your calendar — anything you'd normally do with a mouse and keyboard, your AI companion does instead.

The app runs natively on macOS. A small local AI handles simple tasks instantly. For complex tasks (multi-step planning, understanding what's on screen), it connects to a private cloud brain that the user pays for via subscription.

**Target customer**: Anyone who wants to control their Mac by just telling it what to do.

**Business model**: Free tier (local AI, simple tasks) + paid tier ($15-20/month, cloud brain for complex tasks).

---

## Product Principles

### 1. Privacy Is Sacred

Users are trusting this app with access to their entire computer. That trust must never be violated.

- **Simple tasks never leave the Mac.** Local model handles them entirely.
- **Complex tasks go to the cloud brain, but data is encrypted in transit and never stored.**
- **No telemetry, no analytics, no tracking** unless the user explicitly opts in.
- **No training on user data.** Ever. By anyone. This is contractual, not just a promise.
- **Users can see exactly what was sent to the cloud** in an audit log.
- **Users can disable cloud entirely** and still have a functional (but less capable) assistant.

### 2. Security Is a System, Not a Feature

Security cannot be a prompt instruction or an afterthought. It is enforced in code.

- Every proposed action passes through a **policy engine** before execution.
- Destructive actions (delete files, kill processes, send emails) **always require user confirmation**.
- No raw shell command execution. All system actions go through **structured, validated tool calls**.
- API keys and credentials stored in **macOS Keychain only**. Never in files, never in UserDefaults.
- All network traffic uses **HTTPS/TLS**. No exceptions.
- Prompt injection defenses at every boundary where untrusted text enters the system.

### 3. User Authority Over Agent Autonomy

The user is always the boss. The AI is a powerful assistant, not an autonomous agent.

- **Level 0 (default)**: AI explains what it wants to do and waits for approval before every action.
- **Level 1**: Safe actions (read-only, non-destructive) auto-execute. Risky actions still need approval.
- **Level 2**: Auto-execute within user-defined scopes (e.g., "you can manage files in ~/Downloads").
- **Level 3**: Routine autonomy for scheduled/recurring tasks. Still has safety limits.
- **No level allows silent destructive actions.** Ever.
- **Kill switch**: User can instantly stop all agent activity at any time.

### 4. Transparency Always

- The AI shows what it understood ("I think you want me to...")
- The AI shows its plan before acting ("Here's what I'll do: 1... 2... 3...")
- The AI shows what happened ("Done. I opened Safari and moved it to the left half.")
- If something failed, the AI explains why and what it tried.
- Complete action history is viewable and searchable.

### 5. Works Offline, Better Online

- **Offline**: Local 8B model handles simple tasks — open apps, find files, move windows, system info.
- **Online**: Cloud brain handles complex tasks — multi-step planning, screen understanding, workflow automation.
- The app gracefully degrades. Losing internet means losing complex features, not all features.

---

## Technical Identity

- **Platform**: macOS 13.0+ (native Swift + SwiftUI)
- **Bundle ID**: com.aidaemon
- **Distribution**: Direct download (not App Store — sandbox restrictions conflict with automation capabilities)
- **Local AI**: LLaMA 3.1 8B (Q4_K_M quantization) via llama.cpp / LlamaSwift
- **Cloud AI**: Pay-per-token API (Groq, Together AI, or AWS Bedrock — provider is swappable)
- **Auto-updates**: Sparkle framework
- **Global hotkey**: KeyboardShortcuts framework

---

## What This Project Is NOT

- **NOT a chatbot.** It doesn't just answer questions — it takes actions on your computer.
- **NOT spyware.** It never watches, records, or transmits without explicit consent.
- **NOT cloud-dependent.** Core features work entirely offline.
- **NOT an autonomous agent.** It proposes actions and waits for approval (by default).
- **NOT open-source (yet).** May open-source in the future, but not a priority for v1.

---

## What Must Never Regress

These are absolute rules. If a milestone or feature would violate any of these, it must be redesigned.

1. User can always see what the assistant is about to do before it does it (at autonomy level 0-1)
2. Destructive actions always require explicit approval
3. Kill switch / emergency stop is always available and instant
4. Local-first baseline works without internet
5. All actions are logged and explainable
6. Policy engine cannot be bypassed by prompt content
7. Credentials are never stored outside macOS Keychain
8. Network traffic is always encrypted (HTTPS/TLS)
9. No user data is ever used for model training

---

## Development Model

This project is built entirely by LLM agents. The owner:
- Does NOT write code
- DOES build in Xcode
- DOES perform manual testing
- DOES make product decisions
- Has LIMITED cloud/backend experience — agents must provide step-by-step setup instructions

See `README.md` for the mandatory LLM agent workflow.

---

## Completed Foundation (M001-M024)

The following capabilities already exist and should be reused, not rebuilt:

| Capability | Files | Status |
|-----------|-------|--------|
| Xcode project + signing | `aiDAEMON.xcodeproj` | Working |
| Global hotkey (Cmd+Shift+Space) | `HotkeyManager.swift` | Working |
| Floating window UI | `FloatingWindow.swift` | Working |
| Text input | `CommandInputView.swift` | Working |
| Results display | `ResultsView.swift` | Working |
| Settings window | `SettingsView.swift` | Working |
| Local LLM loading | `ModelLoader.swift` | Working |
| llama.cpp bridge | `LLMBridge.swift` | Working |
| LLM inference manager | `LLMManager.swift` | Working |
| Prompt builder | `PromptBuilder.swift` | Working |
| JSON command parsing | `CommandParser.swift` | Working |
| Command registry + dispatch | `CommandRegistry.swift` | Working |
| App launcher | `AppLauncher.swift` | Working |
| File search (Spotlight) | `FileSearcher.swift` | Working |
| Window management | `WindowManager.swift` | Working |
| System info | `SystemInfo.swift` | Working |
| Command validation | `CommandValidator.swift` | Working |
| Confirmation dialogs | `ConfirmationDialog.swift` | Working |

This foundation is the "hands" of the assistant. The new milestones add the "brain" (cloud model + agent loop) and "eyes" (screen vision).
