# Manual Actions Checklist

This file tracks manual tasks required across milestones.
Mark completed items by changing `[ ]` to `[x]`.

Last Updated: 2026-02-17

---

## Completed Setup (Historical)

These are retained as completed foundation tasks.

- [x] Install Xcode
- [x] Install Xcode Command Line Tools
- [x] Verify Swift toolchain is available
- [x] Download `Models/model.gguf` (LLaMA 3.1 8B Instruct Q4_K_M)
- [x] Verify model integrity (GGUF header + SHA256)
- [x] Add SPM dependencies (`LlamaSwift`, `Sparkle`, `KeyboardShortcuts`)

---

## M026-M034 Pivot Transition (Immediate)

### M026: Build Stability Recovery
- [ ] Resolve active compile blockers on current branch
- [ ] Run clean Debug build
- [ ] Run clean Release build
- [ ] Record baseline smoke workflow list

### M027: Legacy Capability Inventory
- [ ] List all currently working command families
- [ ] Mark each family with reliability score (A/B/C)
- [ ] Document known limitations and recurring failure modes
- [ ] Publish inventory in project notes/docs

### M028: Legacy-to-Tool Adapter Design
- [ ] Document mapping from current `CommandType` to future tool IDs
- [ ] Document fallback behavior when tool call fails
- [ ] Document adapter error surface and logging fields

### M029: Conversation State Model
- [ ] Define canonical turn schema
- [ ] Define task and step lifecycle states
- [ ] Define storage location and retention policy for session state

### M030: Orchestrator State Model
- [ ] Define orchestrator states and transitions
- [ ] Define timeout/cancellation behavior
- [ ] Define how approval states pause/resume plans

### M031: Policy Ruleset v1
- [ ] Define risk matrix by tool category
- [ ] Define autonomy-level gating rules
- [ ] Define deny-by-default behavior for unknown actions

### M032: Permission UX Refresh
- [ ] Draft permission rationale copy for Accessibility and Automation
- [ ] Draft degraded-mode copy for missing permissions
- [ ] Validate clarity with at least one non-technical reviewer

### M033: Observability Baseline
- [ ] Define local structured log fields for plan and action traces
- [ ] Define redaction policy for sensitive fields
- [ ] Confirm correlation IDs across one conversation turn

### M034: Transition Exit Gate
- [ ] Run transition checklist review
- [ ] Confirm migration risks and owners
- [ ] Approve start of M035 implementation track

---

## Alpha/Beta Program Operations (Planned)

### Alpha Prep (M119)
- [ ] Build alpha onboarding instructions
- [ ] Prepare feedback form + issue template
- [ ] Prepare tester communication cadence

### Beta Prep (M124)
- [ ] Prepare waitlist and distribution pipeline
- [ ] Prepare release notes template
- [ ] Prepare support triage playbook

---

## Release Infrastructure (Planned)

### Signing and Distribution (M116-M117)
- [ ] Confirm Apple Developer membership is active
- [ ] Verify Developer ID certificate validity
- [ ] Verify notarization credentials in keychain
- [ ] Rehearse notarization and update channel process

### Public Rollout (M129-M131)
- [ ] Final launch checklist review
- [ ] Final rollback plan review
- [ ] Week-1 incident response rota assigned

---

## Ongoing Maintenance

- [ ] Update this file when a new manual dependency is discovered
- [ ] Link each manual task to milestone IDs
- [ ] Remove obsolete tasks after milestone renumbering changes
