# 00 - FOUNDATION

**This document is the permanent source of truth.**

When in doubt, this file overrides issues, chat messages, code comments, and secondary docs.

Last Updated: 2026-02-18
Version: 3.1 (Capability-First Pivot)

---

## What Is aiDAEMON?

**aiDAEMON is a JARVIS-style AI companion app for macOS.**

Think Iron Man's JARVIS — you talk to your computer (or type), and it does things for you. Open apps, move windows, set up workflows, search files, control browsers, manage your calendar — anything you'd normally do with a mouse and keyboard, your AI companion does instead.

The app runs natively on macOS. A small local AI handles simple tasks instantly. For complex tasks (multi-step planning, understanding what's on screen), it connects to a private cloud brain that the user pays for via subscription.

**Target customer**: Anyone who wants to control their Mac by just telling it what to do.

**Business model**: Free tier (local AI, simple tasks) + paid tier ($15-20/month, cloud brain for complex tasks).

---

## Product Principles

### 1. Capability First

The primary goal is to be the most capable AI companion on macOS. Users want an assistant that actually *does* things — autonomously, intelligently, without friction.

- **Cloud is the default brain.** Local model handles simple tasks instantly; cloud handles everything complex. Users get the best result by default.
- **MCP (Model Context Protocol)** is the tool integration standard. It gives access to 2,800+ community-built tools and lets the assistant connect to virtually any service.
- **The assistant acts; users review.** By default (Level 1 autonomy), safe actions execute automatically. The assistant does the work and reports back. Only dangerous or ambiguous actions pause for confirmation.
- **Minimal friction.** No plan previews for simple requests. No excessive confirmation dialogs. JARVIS doesn't ask permission to turn on the lights.
- **Maximum intelligence.** Claude (Anthropic) is the preferred cloud brain for complex reasoning, planning, and vision. OpenAI GPT-4o as fallback.

### 2. Responsible Defaults, Not Privacy-First

Users trust this app with their computer. We take that seriously — but we don't let privacy concerns prevent building capable software.

- **Simple tasks process locally** when the local model is sufficient.
- **Cloud tasks are encrypted in transit.** Data is not stored by the provider.
- **Users can audit what was sent** to the cloud via the action log.
- **Screen vision is opt-in** (required for the model to see the screen).
- **API keys live in macOS Keychain only.** Never in files, never in UserDefaults.

### 3. Security Is a System, Not a Feature

Security cannot be a prompt instruction or an afterthought. It is enforced in code.

- Every proposed action passes through a **policy engine** before execution.
- Destructive actions (delete files, kill processes, send emails) **always require user confirmation**.
- No raw shell command execution. All system actions go through **structured, validated tool calls**.
- API keys and credentials stored in **macOS Keychain only**. Never in files, never in UserDefaults.
- All network traffic uses **HTTPS/TLS**. No exceptions.
- Prompt injection defenses at every boundary where untrusted text enters the system.

### 4. User Authority Over Agent Autonomy

The user is always the boss. The AI acts on the user's behalf and can be stopped at any time.

- **Level 1 (default)**: Safe actions (read-only, non-destructive, reversible) auto-execute without asking. Risky actions still need approval. This is the standard experience.
- **Level 0**: AI explains what it wants to do and waits for approval before every action. Opt-in for users who want full control.
- **Level 2**: Auto-execute within user-defined scopes (e.g., "you can manage files in ~/Downloads").
- **Level 3**: Routine autonomy for scheduled/recurring tasks. Still has safety limits.
- **No level allows silent destructive actions.** Ever.
- **Kill switch**: User can instantly stop all agent activity at any time.

### 5. Transparency Always

- The AI shows what it understood ("I think you want me to...")
- For multi-step plans at Level 0: the AI shows its plan before acting.
- For simple tasks at Level 1: the AI acts immediately and reports what it did.
- The AI shows what happened ("Done. Opened Safari and moved it to the left half.")
- If something failed, the AI explains why and what it tried.
- Complete action history is viewable and searchable.

### 6. Works Offline, Better Online

- **Offline**: Local 8B model handles simple tasks — open apps, find files, move windows, system info.
- **Online**: Cloud brain handles complex tasks — multi-step planning, screen understanding, workflow automation.
- The app gracefully degrades. Losing internet means losing complex features, not all features.

---

## Technical Identity

- **Platform**: macOS 13.0+ (native Swift + SwiftUI)
- **Bundle ID**: com.aidaemon
- **Distribution**: Direct download (not App Store — sandbox restrictions conflict with automation capabilities)
- **Local AI**: LLaMA 3.1 8B (Q4_K_M quantization) via llama.cpp / LlamaSwift
- **Cloud AI**: Anthropic Claude (preferred) + OpenAI GPT-4o + Groq — provider is swappable
- **Tool Protocol**: MCP (Model Context Protocol) — industry standard, 2,800+ community tools
- **Browser Control**: CDP (Chrome DevTools Protocol) — far more powerful than AppleScript
- **Auto-updates**: Sparkle framework
- **Global hotkey**: KeyboardShortcuts framework

---

## What This Project Is NOT

- **NOT a chatbot.** It doesn't just answer questions — it takes actions on your computer.
- **NOT passive.** It acts. At Level 1 (default), safe tasks execute immediately without asking.
- **NOT cloud-dependent.** Core features work entirely offline with the local model.
- **NOT locked to one AI provider.** Claude, OpenAI, Groq, and local are all supported and swappable.
- **NOT open-source (yet).** May open-source in the future, but not a priority for v1.

---

## What Must Never Regress

These are absolute rules. If a milestone or feature would violate any of these, it must be redesigned.

1. At autonomy Level 0, user sees every action before it executes
2. Destructive actions always require explicit approval (no exceptions, at any level)
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

## Completed Foundation (M001-M032)

The following capabilities already exist and should be reused, not rebuilt:

| Capability | Files | Status |
|-----------|-------|--------|
| Xcode project + signing | `aiDAEMON.xcodeproj` | Working |
| Global hotkey (Cmd+Shift+Space) | `HotkeyManager.swift` | Working |
| Floating window UI | `FloatingWindow.swift` | Working |
| Text input | `CommandInputView.swift` | Working |
| Results display + model badge | `ResultsView.swift` | Working |
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
| ModelProvider protocol | `ModelProvider.swift` | Working |
| Local model backend | `LocalModelProvider.swift` | Working |
| Cloud model backend | `CloudModelProvider.swift` | Working |
| Keychain credential storage | `KeychainHelper.swift` | Working |
| Model routing (local/cloud) | `ModelRouter.swift` | Working |
| Conversation data model | `Conversation.swift` | Working |
| Chat conversation UI | `ChatView.swift` | Working |
| Tool schema system | `ToolDefinition.swift`, `ToolRegistry.swift` | Working |

This foundation is the "hands" of the assistant. The new milestones add the "brain" (cloud model + agent loop) and "eyes" (screen vision).
