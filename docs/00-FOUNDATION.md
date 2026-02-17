# 00 - FOUNDATION

**This document is the permanent source of truth.**

When in doubt, this file overrides issues, chat messages, code comments, and secondary docs.

Last Updated: 2026-02-17
Version: 2.0 (Strategic Pivot)

---

## Pivot Notice

As of 2026-02-17, aiDAEMON is no longer scoped as only a "natural language command launcher."

The project is now scoped as a **local-first, supervised AI companion for macOS**:
- Conversational
- Tool-using
- Multi-step
- Context-aware
- Explicitly safety-governed

This is an intentional product pivot, not a reset. Existing completed milestones remain valid foundation work.

---

## Core Philosophy

### What This Project Is

**aiDAEMON** is a JARVIS-style desktop companion with strict safety rails.

It should:
- Understand open-ended user intent
- Plan and execute multi-step workflows
- Use tools on the user's behalf
- Explain what it is doing
- Ask before high-impact actions
- Improve with memory and context over time

### What This Project Is Not

It is not:
- A hidden autonomous background monitor
- A spyware-like surveillance system
- A "run anything silently" root agent
- A cloud-first product that requires external APIs to function
- A replacement for user consent or system permissions

---

## Non-Negotiable Principles

### 1. User Authority Over Agent Autonomy

The user is always the final authority.

- High-impact actions require explicit approval
- Autonomy level is visible and adjustable
- User can interrupt, pause, or disable agent execution instantly
- No irreversible action is silently executed

### 2. Local-First by Default

Core assistant behavior must run locally.

- Local model path is first-class
- Local tools remain functional offline
- Cloud augmentation is optional, explicit, and scoped

### 3. Transparent Planning and Execution

The assistant must show intent, plan, and result.

- Show what it thinks the goal is
- Show the selected tools/actions
- Show what succeeded and what failed
- Keep a complete action/audit trail

### 4. Safety as a Runtime System

Safety is not a prompt-only feature.

- Policy engine evaluates every proposed action
- Tool permissions are capability-based and revocable
- Risk scoring determines approval path
- Dangerous operations are blocked or escalated

### 5. Memory With Boundaries

Memory should help, not overreach.

- Separate short-term context from long-term memory
- Allow per-memory deletion and full wipe
- Never retain sensitive content without explicit user consent

### 6. Progressive Trust, Not Instant Full Access

Trust should be earned by behavior and user decisions.

- Start with minimal permissions
- Expand access only when justified
- Keep the permission surface understandable

---

## Autonomy Levels

Autonomy is explicit and user-controlled.

### Level 0: Ask-First (Default)
- Every action requires confirmation
- Best for first-time users and risky workflows

### Level 1: Safe Auto-Execute
- Read-only and low-risk actions auto-run
- Caution/danger actions still require confirmation

### Level 2: Scoped Auto-Execute
- Auto-execution allowed inside user-approved scopes
- Example scope: "Finder + file organization in ~/Downloads"

### Level 3: Routine Autonomy (Advanced)
- Scheduled and recurring workflows permitted
- Strict policy checks, audit logs, and emergency stop required

No level allows silent privilege escalation.

---

## Architectural Invariants

These are locked unless explicitly revised here.

### 1. Agent Loop Replaces Single-Shot Parsing

The core interaction model is:

1. Understand goal
2. Build/adjust plan
3. Execute step(s)
4. Validate outcome
5. Continue or recover
6. Report clearly

### 2. Tool Runtime Is Schema-Driven

Tools are registered with explicit schemas, capabilities, and safety metadata.

- No ad-hoc shell string execution path
- Structured arguments only
- Per-tool policy enforcement

### 3. Policy Engine Sits Between Planner and Executor

All proposed actions pass through policy gates before execution.

### 4. Memory Is Layered

- Working memory: current turn/task
- Session memory: current session context
- Long-term memory: user-approved durable preferences/facts

### 5. Existing Milestones Are Foundational Assets

Completed work M001-M024 is retained as a compatibility layer and migration base.

### 6. Distribution Remains Direct (Not App Store)

App Store sandbox restrictions still conflict with required automation capabilities.

---

## Privacy Boundaries

### Always Local by Default

- Command content
- Tool-call payloads
- Action history
- Local context snapshots

### Optional Cloud Usage (Future)

Cloud routing may be enabled for complex reasoning, but must be:
- Explicitly enabled
- Clearly indicated per request/session
- Redactable where possible
- Disable-able at any time

---

## What Must Never Regress

1. Visibility into what the assistant is about to do
2. Explicit approval for high-impact actions
3. Reliable kill switch / emergency stop
4. Local-first baseline capability
5. Action logging and explainability
6. Deterministic safety policy behavior
7. Permission minimalism and revocability

---

## What Is Explicitly Forbidden

1. Silent destructive actions
2. Hidden continuous surveillance modes
3. Implicit cloud upload of private user context
4. Prompt-only safety with no runtime enforcement
5. Unbounded tool access without capability checks
6. Shipping with known critical policy bypasses

---

## Success Definition (New Direction)

aiDAEMON is successful when it feels like a capable desktop companion while still being auditable, interruptible, and safe.

It should feel powerful, but never opaque.

---

## Restart vs Pivot Decision

**Decision**: Pivot, do not restart.

Rationale:
- M001-M024 already provide substantial reusable infrastructure (UI shell, local inference, parsing, validation, executor registry, confirmations).
- Restarting would destroy momentum and reimplement solved primitives.
- A staged migration preserves velocity and reduces risk.

This decision is reflected in the updated milestones.
