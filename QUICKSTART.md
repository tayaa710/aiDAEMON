# Quick Start Guide

Use this guide to continue from the strategic pivot without losing momentum.

---

## Step 1: Read the Pivot Foundation

```bash
open docs/00-FOUNDATION.md
```

Focus on:
- New companion scope
- Autonomy levels
- Non-negotiable safety and privacy rules

---

## Step 2: Review the New Architecture

```bash
open docs/01-ARCHITECTURE.md
```

Focus on:
- Agent loop model
- Planner/policy/tool runtime layers
- Migration path from legacy command pipeline

---

## Step 3: Check Active Milestone

```bash
open docs/03-MILESTONES.md
```

Current sequence after pivot:
1. `M026` Build Stability Recovery
2. `M027` Legacy Capability Inventory
3. `M028-M031` Transition design milestones
4. `M034` Transition exit gate

---

## Step 4: Confirm Manual Dependencies

```bash
open docs/manual-actions.md
```

Complete all pending `M026-M034` manual tasks before coding the agent core milestones.

---

## Step 5: Execute One Milestone at a Time

For each milestone:
1. Read objective + dependencies in `03-MILESTONES.md`
2. Implement only that milestone scope
3. Verify success criteria
4. Update docs/checklist
5. Commit with milestone reference

Example commit format:
- `M026: restore build baseline and smoke checklist`

---

## Testing Windows (Planning)

- Alpha: 2026-05-11 to 2026-06-26
- Beta: 2026-07-06 to 2026-08-21
- Public rollout target: week of 2026-09-28

Dates move if quality gates fail.

---

## Operating Rules

- Do not bypass safety gates for speed.
- Do not skip transition milestones.
- Keep local-first behavior intact.
- Keep all high-impact actions user-controlled.

---

## If You Are Unsure

1. Re-read `00-FOUNDATION.md`
2. Re-check current milestone dependencies
3. Add missing manual tasks to `manual-actions.md`
4. Prefer smaller milestone splits over large speculative changes
