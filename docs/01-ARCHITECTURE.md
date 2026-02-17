# 01 - ARCHITECTURE

Complete system architecture for the pivoted aiDAEMON companion runtime.

Last Updated: 2026-02-17
Version: 2.0 (Agent Architecture)

---

## System Overview

```
┌───────────────────────────────────────────────────────────────────────────┐
│                                   USER                                    │
│            Text / Hotkey / Voice / (Future) Vision + Context             │
└───────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                        Interaction & Conversation Layer                    │
│  - Floating Command UI                                                     │
│  - Chat transcript                                                         │
│  - Conversation state and turn history                                     │
└───────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                         Orchestrator (Agent Loop)                          │
│  Understand Goal -> Plan -> Policy Check -> Execute -> Reflect -> Respond  │
└───────────────────────────────────────────────────────────────────────────┘
                │                      │                        │
                ▼                      ▼                        ▼
┌───────────────────────┐   ┌──────────────────────┐   ┌─────────────────────┐
│   Planning Engine     │   │    Policy Engine     │   │   Memory Engine      │
│  - Task decomposition │   │  - Risk scoring      │   │  - Working memory    │
│  - Tool selection     │   │  - Capability checks │   │  - Session memory    │
│  - Retry strategy     │   │  - Approval gating   │   │  - Long-term memory  │
└───────────────────────┘   └──────────────────────┘   └─────────────────────┘
                                      │
                                      ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                            Tool Runtime / Router                           │
│  - Schema-based tool definitions                                            │
│  - Tool capability metadata                                                  │
│  - Invocation dispatcher                                                     │
└───────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                                Tool Executors                              │
│  App, Files, Windows, System, Process, Quick Actions, Browser, Finder...  │
└───────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                         Audit, Telemetry, and Replay                        │
│  - Action log                                                               │
│  - Plan trace                                                               │
│  - Approval/denial history                                                   │
│  - Failure diagnostics                                                       │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## Architectural Layers

### 1. Interaction Layer

Responsibilities:
- Capture user intent in conversation form
- Maintain transcript and turn context
- Display plan previews, approvals, and outcomes

Current assets reused:
- `FloatingWindow.swift`
- `CommandInputView.swift`
- `ResultsView.swift`
- `ConfirmationDialog.swift`

### 2. Conversation & Context Layer

Responsibilities:
- Maintain turn-by-turn context
- Normalize user intent into task frames
- Pull real-time environment context (frontmost app, clipboard, selection)

Core concept:
- The assistant interprets goals with context, not one-shot command strings.

### 3. Orchestrator Layer

Responsibilities:
- Runs the agent loop
- Tracks step state and retries
- Coordinates planner, policy, and tool runtime

Loop states:
1. `idle`
2. `understanding`
3. `planning`
4. `awaiting_approval`
5. `executing`
6. `verifying`
7. `responding`
8. `failed`

### 4. Planner Layer

Responsibilities:
- Convert goals into executable step graphs
- Select tools and parameter candidates
- Emit fallback paths

Planner output (example):
```json
{
  "goal": "Prepare my standup update from yesterday's git activity",
  "steps": [
    {"tool": "git_activity", "args": {"window": "yesterday"}},
    {"tool": "summarize", "args": {"style": "brief"}},
    {"tool": "notes_append", "args": {"target": "Daily Standup"}}
  ],
  "risk_level": "caution"
}
```

### 5. Policy Layer

Responsibilities:
- Validate every planned step against policy rules
- Apply autonomy-level gating
- Trigger approvals or deny execution

Policy dimensions:
- Data sensitivity
- Destructiveness
- Reversibility
- Permission scope
- User autonomy level

### 6. Tool Runtime Layer

Responsibilities:
- Register tools with schemas
- Validate arguments
- Route invocations to executors
- Return structured results

Tool contract (target shape):
```swift
struct ToolDefinition {
    let id: String
    let description: String
    let inputSchema: JSONSchema
    let capability: CapabilityClass
    let riskLevel: RiskLevel
}
```

### 7. Executor Layer

Responsibilities:
- Execute system actions through native APIs
- Return deterministic and parseable outputs
- Never bypass policy or schema checks

Legacy compatibility:
- Existing `CommandRegistry` and implemented executors remain active while tool runtime is introduced.

### 8. Memory Layer

Responsibilities:
- Store relevant history and preferences
- Support recall without over-retention
- Respect memory boundaries and deletion controls

Memory tiers:
- Working: task-local scratch data
- Session: same-run context
- Long-term: explicit user-approved memories

### 9. Audit & Replay Layer

Responsibilities:
- Persist step-by-step execution traces
- Support debugging and user trust
- Enable "why did it do that" introspection

---

## Compatibility and Migration Plan

### Why a Migration Layer Exists

The app currently runs a parser -> validator -> registry -> executor flow.
That stack is useful and should not be discarded immediately.

### Migration strategy

1. Keep existing command pipeline operational.
2. Introduce tool runtime in parallel.
3. Add orchestrator that can call either:
   - Legacy command dispatch
   - New tool-call dispatch
4. Gradually retire one-shot-only pathways.

### Immediate bridge milestones

- M025-M032 are transition milestones.
- They stabilize current code and introduce agent scaffolding without destructive rewrites.

---

## Data Model Targets

### Conversation Turn

```json
{
  "turn_id": "uuid",
  "timestamp": "ISO8601",
  "user_input": "string",
  "assistant_goal": "string",
  "plan": [],
  "actions": [],
  "result": "string",
  "status": "success|partial|failed"
}
```

### Action Record

```json
{
  "action_id": "uuid",
  "tool": "string",
  "args": {},
  "risk": "safe|caution|dangerous",
  "approval": "auto|manual|denied",
  "outcome": "success|error",
  "details": "string"
}
```

---

## Performance Targets

### Interaction
- Hotkey to visible UI: <150 ms
- Text submit to first token: <700 ms (steady-state)

### Planning
- Basic plan generation: <1.5 s (local)
- Complex multi-step plan: <3.0 s target

### Execution
- Safe single tool action: <1.0 s median
- Multi-step workflow (3-5 steps): <8.0 s median

### Stability
- Crash-free sessions in beta: >=99.5%
- Tool-call success for supported tasks: >=92%

---

## Permissions and Capabilities

### Required now
- Accessibility
- Automation (Apple Events)

### Optional later (explicitly gated)
- Microphone (voice input)
- Screen Recording (vision/context features)

Each permission must map to user-visible value and policy enforcement.

---

## Release Readiness Architecture Gates

### Alpha Gate
- Orchestrator + tool runtime functional for core workflows
- Policy engine v1 active for all actions
- Memory tiering functional (working + session)

### Beta Gate
- Long-term memory controls complete
- Multimodal path stable (voice minimum)
- Recovery and retry strategies validated

### Public Gate
- Full audit/replay reliability
- Security hardening complete
- Clear autonomy UX and fail-safe controls

---

## Architecture Decision Summary

1. Pivot is an additive migration, not a restart.
2. Agent loop is the new core execution model.
3. Policy engine is mandatory runtime infrastructure.
4. Tool schemas replace ad-hoc command dispatch over time.
5. Existing completed milestones are foundational migration assets.
