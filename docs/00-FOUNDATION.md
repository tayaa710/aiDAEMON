# 00 - FOUNDATION

**This document is the permanent source of truth.**

When in doubt, this file overrides everything else: issues, messages, code comments, external documentation.

Last Updated: 2026-02-15
Version: 1.0

---

## Core Philosophy

### What This Project Is

**aiDAEMON** is a natural language interface for macOS system control that bridges the gap between "click buttons" automation and "understand my intent" intelligence.

It is NOT:
- A chatbot
- A general-purpose AI assistant
- A screen recording/monitoring tool
- An autonomous agent that acts without permission
- A cloud service

It IS:
- A command executor that understands natural language
- A local-first privacy tool
- A power user accelerator
- A teaching tool (shows commands as it runs them)
- A trust-building system (approval-based execution)

### Non-Negotiable Principles

These principles cannot be compromised:

#### 1. Privacy First
- All AI processing happens locally by default
- No screenshots sent to cloud services
- No telemetry without explicit opt-in
- No command logs uploaded anywhere
- User data never leaves the machine unless explicitly requested

#### 2. User Control
- No action executes without user awareness
- Destructive operations require explicit confirmation
- Emergency stop mechanism always available
- Complete action audit log accessible anytime
- User can disable any feature

#### 3. Transparency
- Show what command will be executed before running it
- Explain why permissions are needed
- Make it easy to understand what happened
- Never hide failures or errors
- Teach users as they use the system

#### 4. Safety by Design
- Start with minimal permissions
- Expand capabilities only when needed
- Reversible operations preferred over destructive ones
- Confirmation dialogs for irreversible actions
- Fail safely (error = stop, not guess)

#### 5. Local First, Cloud Optional
- Core functionality works 100% offline
- Cloud features (if any) are opt-in enhancements
- Local LLM is the default and primary parsing method
- Cloud fallback only when explicitly configured

---

## Architectural Invariants

These decisions are locked for the MVP and should only change with strong justification:

### Parsing Strategy: Option A (Local LLM)

**DECISION: We use local LLM inference for intent parsing.**

**Model**: LLaMA 3 8B (quantized to 4-bit)
**Engine**: llama.cpp for inference
**Size**: ~4GB disk space
**Performance**: 20-50 tokens/sec on M1+ Macs

**Why:**
- Complete privacy (no API calls)
- No per-query costs
- Works offline
- More flexible than keyword matching
- Can improve with fine-tuning later

**Trade-offs Accepted:**
- Larger app download size
- First-launch model loading time (~2-5 seconds)
- Requires 8GB+ RAM realistically
- Inference slower than cloud APIs

**What This Means:**
- User downloads a ~4GB package on first launch
- AI model is bundled or downloaded separately (decide in M003)
- All intent parsing happens on-device
- No API keys, no network requests for core functionality

### Technology Stack

**Language**: Swift (for macOS native performance and API access)
**UI Framework**: SwiftUI (modern, declarative, fast to iterate)
**LLM Inference**: llama.cpp (via Swift bindings or C bridge)
**Hotkey Management**: Sauce or similar Swift library
**Storage**: SQLite (for command history, aliases, settings)
**Updates**: Sparkle framework (standard macOS auto-updater)
**Build System**: Xcode + SPM (Swift Package Manager)

**Why Swift:**
- Native macOS APIs (Accessibility, AppleScript bridge)
- Best performance for system-level operations
- Smaller binary size than Electron
- Easier code signing and notarization
- Direct access to macOS security APIs

### Permission Model

**Phase 1 Permissions Required:**
1. Accessibility (for window management, UI control)
2. Automation (for app-specific AppleScript control)

**Phase 1 Permissions NOT Required:**
- Screen Recording (not watching screen)
- Full Disk Access (only search what Spotlight can)
- Input Monitoring (not keylogging)
- Microphone (voice input is Phase 5+)

**Expansion Path:**
- Screen Recording: Only if/when adding vision features (Phase 6+)
- Full Disk Access: Only if user explicitly needs deep file access
- Each new permission must justify itself with clear user value

### Execution Model

**All actions follow this flow:**

1. User types command
2. LLM parses intent → structured command
3. System shows preview: "This will do X"
4. User approves or denies
5. If approved: execute and log
6. Show result or error

**Trust Building (Future):**
- After N successful executions of same command type, offer to auto-approve
- User can revoke auto-approval anytime
- Audit log shows auto-approved vs manually approved

### Distribution Strategy

**NOT via Mac App Store** (impossible due to permissions required)

**Direct Download:**
- Notarized .dmg or .pkg
- Standard macOS install flow
- Auto-updates via Sparkle
- Open source or source-available (decide by M020)

**Why:**
- App Store sandboxing prohibits required permissions
- Accessibility access cannot be granted to sandboxed apps
- Direct distribution gives us full control
- Users who need this understand non-App Store installs

---

## What Must Never Regress

Once implemented, these must continue working:

1. **Local-only operation** - Core features must work offline forever
2. **Permission minimalism** - Never require more permissions than Phase 1 without explicit justification
3. **Action transparency** - User must always see what will execute
4. **Audit log** - Every action must be logged (even if log is ephemeral)
5. **Emergency stop** - Global hotkey to pause/disable must always work
6. **No silent failures** - Errors must be surfaced clearly
7. **Deterministic behavior** - Same command should produce same result

---

## What Is NOT Allowed

These are explicitly forbidden in the MVP:

1. **Autonomous operation** - No "always running" background mode
2. **Screen recording without explicit feature** - No watching user's screen
3. **Cloud-first architecture** - No "must connect to server" requirement
4. **Telemetry by default** - No analytics without opt-in
5. **Trying to do everything** - Focus beats scope creep
6. **Auto-fixing bugs without approval** - Too dangerous, too error-prone
7. **Kernel extensions** - No deep system modifications
8. **Obfuscated behavior** - Every action must be explainable

---

## Security Boundaries

### What We Can Access

**Allowed:**
- Running applications list
- Window positions and titles
- UI element hierarchies (via Accessibility API)
- File paths from Spotlight index
- Shell command execution (with user approval)
- AppleScript/JXA control of automatable apps

**Restricted:**
- Only access files when explicitly commanded
- Only control apps when user requests it
- Only read system state when showing info to user
- No background monitoring or logging of user activity

### What We Cannot Access (By Design)

**System Limitations:**
- Cannot bypass macOS security (SIP, Gatekeeper)
- Cannot modify other app's memory or code
- Cannot intercept system calls globally
- Cannot access sandboxed app internals

**Self-Imposed Limits:**
- Will not record screens without explicit vision feature
- Will not log keystrokes or mouse activity
- Will not access files outside user-initiated searches
- Will not phone home with usage data

### Threat Model Assumptions

**We assume:**
- User's macOS install is not compromised
- User trusts us enough to grant Accessibility access
- User understands the permissions they're granting
- User will notice obviously malicious behavior

**We protect against:**
- Accidental destructive commands (via confirmations)
- Command injection in user input (via structured parsing)
- Unintended file access (via explicit path resolution)
- Silent failures that hide errors

**We DO NOT protect against:**
- Intentionally malicious users (they already have Terminal)
- Compromised user accounts (beyond our scope)
- Physical access attacks (not our threat model)

---

## Long-Term Constraints

### Performance Targets

- Hotkey activation: <50ms to show UI
- LLM inference: <2 seconds for command parsing
- Command execution: <500ms for most operations
- UI responsiveness: 60fps, no janky animations

### Compatibility Targets

- macOS: Support current + 2 previous versions (currently: Sequoia, Sonoma, Ventura)
- Hardware: M1 or better (Intel support if trivial, not a priority)
- RAM: Realistic minimum 8GB (will not optimize for 4GB machines)

### Scalability Targets (Not MVP, But Planned)

- Command history: 10,000+ entries without slowdown
- Custom aliases: 1,000+ without performance degradation
- Simultaneous commands: Queue properly, don't crash

---

## Evolution Rules

### When This Document Changes

**Allowed Changes:**
- Clarifications that don't alter meaning
- Adding new constraints that strengthen existing principles
- Documenting new architectural decisions that align with philosophy

**Forbidden Changes:**
- Weakening privacy guarantees
- Removing security boundaries
- Changing core philosophy
- Invalidating previous architectural decisions without migration plan

### How to Propose Changes

1. Document the change in a separate proposal file
2. Explain why it's necessary
3. Show how it aligns with or strengthens core principles
4. Get explicit sign-off
5. Update this document with clear changelog entry

---

## Quick Reference: Core Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Parsing Strategy** | Option A: Local LLM (LLaMA 3 8B) | Privacy, offline, flexibility |
| **Platform** | macOS only (MVP) | Focused scope, deepest integration |
| **Language** | Swift | Native APIs, performance, size |
| **UI** | SwiftUI | Modern, fast iteration |
| **Distribution** | Direct (not App Store) | Permissions impossible in sandbox |
| **Permissions** | Accessibility + Automation only | Minimal for Phase 1 |
| **Execution** | Approval-based → trust-building | Safety + user control |
| **Privacy** | Local-first, cloud optional | Non-negotiable principle |
| **Open Source** | TBD (decide by M020) | Leaning yes for trust |

---

## For Future You

When you come back to this project after a break, remember:

1. **This file is law.** If code contradicts this, code is wrong.
2. **Privacy is non-negotiable.** If a feature requires cloud, it's opt-in.
3. **User approval is required.** No autonomous execution in MVP.
4. **Local LLM is the parsing method.** Don't second-guess this decision.
5. **Scope is intentionally limited.** Do fewer things well.
6. **Start with Phase 1 only.** Don't build Phase 3 features in Phase 1.

When in doubt, choose the more private, more transparent, more conservative option.

---

**End of Foundation Document**

Read `01-ARCHITECTURE.md` next for technical implementation details.
