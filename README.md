# aiDAEMON

**Local-first AI companion for macOS**

aiDAEMON is pivoting from a command parser into a supervised JARVIS-style desktop companion.

---

## Current Status

**Strategic Phase**: Pivot Transition

- Completed foundation work: `M001-M025`
- Current milestone: `M026 - Build Stability Recovery`
- Roadmap scope: `M001-M132` (plus `M133-M140` future)

Planned external testing windows:
- Alpha: 2026-05-11 to 2026-06-26
- Beta: 2026-07-06 to 2026-08-21
- Public rollout target window: 2026-09-07 to 2026-10-05

---

## What Works Today

The current app can already:
- Open apps and URLs
- Search files with ranked Spotlight results
- Manage window positions
- Report core system information
- Parse natural language through a local model

This is now treated as a migration base, not the final product shape.

---

## New Product Direction

aiDAEMON is now scoped as a companion that can:
- Hold conversation context across turns
- Plan multi-step workflows
- Use a schema-based tool runtime
- Apply runtime safety policy before every action
- Operate with explicit autonomy levels and approval gates
- Build memory and context with user controls

See `docs/00-FOUNDATION.md` for non-negotiable boundaries.

---

## Principles

1. Local-first default behavior
2. User authority over autonomy
3. Transparent planning and execution
4. Runtime safety enforcement
5. Memory with explicit controls

---

## Documentation

- `docs/00-FOUNDATION.md` - strategic source of truth
- `docs/01-ARCHITECTURE.md` - agent architecture and migration model
- `docs/02-THREAT-MODEL.md` - security/privacy model
- `docs/03-MILESTONES.md` - detailed milestone roadmap
- `docs/04-SHIPPING.md` - stage gates and release operations
- `docs/manual-actions.md` - manual task checklist

---

## Development Workflow

1. Read `docs/00-FOUNDATION.md`
2. Confirm active milestone in `docs/03-MILESTONES.md`
3. Complete manual dependencies in `docs/manual-actions.md`
4. Implement and verify one milestone at a time

---

## Technical Stack

- Swift + SwiftUI (macOS native)
- Local LLM inference (`llama.cpp` via `LlamaSwift`)
- Accessibility + Automation APIs
- Sparkle for updates (release track)

---

## Distribution

Direct distribution (outside the Mac App Store), with code signing and notarization requirements tracked in milestones.

---

## License

MIT License. See `LICENSE`.
