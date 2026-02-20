# 00 - FOUNDATION

**This document is the permanent source of truth.**

When in doubt, this file overrides issues, chat messages, code comments, and secondary docs.

Last Updated: 2026-02-20
Version: 6.0 (Accessibility-First Computer Intelligence)

---

## What Is aiDAEMON?

**aiDAEMON is a JARVIS-style AI companion app for macOS.**

Think Iron Man's JARVIS — you talk to your computer (or type), and it does things. Open apps, draft emails, book meetings, control browsers, manage files, write code, automate workflows — anything you'd normally do manually, your AI companion does instead. Autonomously. Without asking permission for every step.

The app runs natively on macOS. It uses a powerful cloud AI brain (Claude) by default. A local model handles fast, private fallback. Tools are extended via MCP (Model Context Protocol) — giving access to 2,800+ community-built integrations out of the box.

**Target customer**: Anyone who wants to control their Mac by talking to it — and wants it to just work, not ask for approval at every step.

**Business model**: Free tier (local AI, 4 core tools) + paid tier ($15-20/month, cloud brain + MCP ecosystem + computer control).

---

## Product Principles

### 1. Capability First, Privacy By Design

The app is maximally capable. Privacy is preserved through architecture, not through restrictions that cripple the product.

- **Cloud brain is on by default.** Claude is the primary intelligence. Local model is the fast/offline fallback.
- **Data is protected in transit** — TLS 1.3, never stored server-side, never used for training.
- **Screen vision is available** when Screen Recording permission is granted — no per-session opt-in needed.
- **Users can audit** everything via the action log.
- **Users can disable cloud** in Settings if they choose — but it's opt-out, not opt-in.
- No telemetry, no analytics, no data sold. Ever.

### 2. Security Is a System, Not a Feature

Security cannot be a prompt instruction or an afterthought. It is enforced in code. Capability-first does not mean security-last.

- Every proposed action passes through a **policy engine** before execution.
- Destructive actions (delete files, kill processes, send emails) **always require user confirmation**, regardless of autonomy level.
- No raw shell command execution. All system actions go through **structured, validated tool calls**.
- API keys and credentials stored in **macOS Keychain only**. Never in files, never in UserDefaults.
- All network traffic uses **HTTPS/TLS**. No exceptions.
- Prompt injection defenses at every boundary where untrusted text enters the system.

### 3. Autonomy Level 1 by Default

The assistant acts. It doesn't ask for permission before every step.

- **Level 0**: AI explains what it wants to do and waits for approval before every action. (Available in Settings, not the default.)
- **Level 1 (default)**: Safe and caution-level actions auto-execute. Only dangerous actions require confirmation. The user sees a brief "Doing X..." status, then results.
- **Level 2**: Auto-execute within user-defined scopes (e.g., "you can manage files in ~/Downloads").
- **Level 3**: Routine autonomy for scheduled/recurring tasks.
- **No level allows silent destructive actions.** Ever.
- **Kill switch**: Cmd+Shift+Escape stops all agent activity instantly at any time.

### 4. Transparent Action, Not Transparent Planning

Users see what happened. They don't need to approve every step before it happens.

- The AI shows real-time status: "Opening Safari... navigating to Gmail... clicking Compose..."
- The AI reports what it did: "Done. Drafted the email and put it in your drafts folder."
- If something failed, the AI explains why and what it tried instead.
- Complete action history is viewable in the audit log.
- At Level 0, tool calls require confirmation inline before execution.

### 5. MCP-Native Tool Ecosystem

aiDAEMON uses Anthropic's **Model Context Protocol** as its tool interface — the industry standard.

- All built-in tools (app launcher, file search, window manager, etc.) are registered as MCP tools.
- Any community MCP server can be added in Settings — Google Calendar, GitHub, Notion, Slack, databases, and 2,800+ more.
- Claude speaks MCP natively. No translation layer.
- aiDAEMON's tool registry IS an MCP server — third-party agents and tools can call into it.

### 6. Works Offline, Better Online

- **Offline**: Local 8B model handles simple tasks — open apps, find files, move windows, system info.
- **Online**: Claude claude-sonnet-4-5-20250929/Opus 4.6 handles complex tasks — multi-step planning, screen understanding, workflow automation, MCP tool use.
- The app gracefully degrades. Losing internet means losing complex features, not all features.

---

## Technical Identity

- **Platform**: macOS 13.0+ (native Swift + SwiftUI)
- **Bundle ID**: com.aidaemon
- **Distribution**: Direct download (not App Store — sandbox restrictions conflict with automation capabilities)
- **Primary Cloud AI**: Anthropic Claude (claude-sonnet-4-5-20250929 default, Opus 4.6 for max capability)
- **Secondary Cloud AI**: OpenAI GPT-4o (fallback, already configured)
- **Local AI**: LLaMA 3.1 8B (Q4_K_M quantization) via llama.cpp / LlamaSwift — for offline/fast tasks
- **Tool Protocol**: MCP (Model Context Protocol) — Anthropic's open standard
- **Voice Input**: Apple SFSpeechRecognizer (on-device) + Deepgram (cloud, better accuracy)
- **Voice Output**: AVSpeechSynthesizer (on-device) + Deepgram TTS (cloud, better voices)
- **Browser Control**: Chrome DevTools Protocol (CDP) — not AppleScript
- **Auto-updates**: Sparkle framework
- **Global hotkey**: KeyboardShortcuts framework

---

## Competitive Landscape

**OpenClaw** (Peter Steinberger, acquired by OpenAI Feb 2026) proved the market — 157K GitHub stars in 60 days for an AI agent that controls your computer via messaging apps. Key lessons absorbed:

- **MCP is the industry standard for tool integration.** aiDAEMON uses it natively (not a custom skill system).
- **Claude is the best brain for agentic tasks.** OpenClaw explicitly recommends Claude for its tool-use loop quality.
- **Autonomy is the product.** The viral demo was autonomous execution, not a chatbot. Level 1 by default.
- **CDP for browser control.** Not AppleScript. aiDAEMON uses Chrome DevTools Protocol.

**aiDAEMON's differentiator**: Native macOS Swift app. OpenClaw is Node.js — aiDAEMON gets faster screenshot analysis, native Accessibility API access, tighter system integration, and lower resource usage. The native advantage compounds with computer control (Phase 8) where milliseconds matter.

---

## What This Project Is NOT

- **NOT a chatbot.** It doesn't just answer questions — it takes actions on your computer.
- **NOT spyware.** It never watches, records, or transmits without architectural protections.
- **NOT cloud-dependent.** Core features work entirely offline via local model.
- **NOT open-source (yet).** May open-source in the future, but not a priority for v1.

---

## What Must Never Regress

These are absolute rules. If a milestone or feature would violate any of these, it must be redesigned.

1. Kill switch (Cmd+Shift+Escape) is always available during execution and stops everything within 500ms
2. Destructive actions (file delete, send email, process kill, terminal exec) always require explicit confirmation
3. All actions are logged in the audit log and explainable to the user
4. Local-only baseline works without internet (open apps, find files, move windows, system info)
5. Policy engine cannot be bypassed by prompt content
6. Credentials are never stored outside macOS Keychain
7. Network traffic is always encrypted (HTTPS/TLS 1.3)
8. No user data is ever used for model training (contractual with providers)
9. No raw shell command execution — structured tool calls only

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

## Completed Foundation (M001-M042)

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
| Command validation + autonomy policy | `CommandValidator.swift` | Working |
| Confirmation dialogs | `ConfirmationDialog.swift` | Working |
| ModelProvider protocol | `ModelProvider.swift` | Working |
| Local model backend | `LocalModelProvider.swift` | Working |
| Cloud model backend (OpenAI-compat) | `CloudModelProvider.swift` | Working |
| Anthropic Claude provider | `AnthropicModelProvider.swift` | Working |
| Keychain credential storage | `KeychainHelper.swift` | Working |
| Model routing (local/cloud) | `ModelRouter.swift` | Working |
| Conversation data model | `Conversation.swift` | Working |
| Chat conversation UI | `ChatView.swift` | Working |
| Tool schema system | `ToolDefinition.swift`, `ToolRegistry.swift` | Working |
| Reactive orchestrator loop | `Orchestrator.swift` | Working |
| Tool policy gate | `PolicyEngine.swift` | Working |
| Kill switch hotkey + UI stop | `HotkeyManager.swift`, `FloatingWindow.swift` | Working |
| MCP client + server manager | `MCPClient.swift`, `MCPServerManager.swift` | Working |
| Voice input (on-device STT) | `SpeechInput.swift` | Working |
| Voice output (on-device TTS) | `SpeechOutput.swift` | Working |
| Screen capture | `ScreenCapture.swift` | Working |
| Claude vision analysis | `VisionAnalyzer.swift` | Working |
| Mouse control (CGEvent) | `MouseController.swift` | Working |
| Keyboard control (CGEvent) | `KeyboardController.swift` | Working |
| Computer control coordinator | `ComputerControl.swift` | Working |
| Accessibility API wrapper | `AccessibilityService.swift` | Working |

Current foundation includes the full "hands + brain + eyes + ears + voice" stack. The accessibility service (M042) provides AX tree walking, element refs, attribute reading, action execution, and element search — the foundation for AX-first computer control. Upcoming milestones wire this into Claude's tool-use loop (M043-M046), add essential tools, memory, and ship.
