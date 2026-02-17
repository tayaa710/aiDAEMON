# aiDAEMON Documentation

This directory is the source of truth for the aiDAEMON companion roadmap.

## Documentation Structure

### Core Foundation
- **[00-FOUNDATION.md](./00-FOUNDATION.md)** - Strategic direction, non-negotiables, autonomy boundaries
- **[01-ARCHITECTURE.md](./01-ARCHITECTURE.md)** - Agent architecture, migration model, runtime layers
- **[02-THREAT-MODEL.md](./02-THREAT-MODEL.md)** - Security model for tool-using companion behavior

### Execution and Release
- **[03-MILESTONES.md](./03-MILESTONES.md)** - Atomic roadmap with pivot transition + alpha/beta/public windows
- **[04-SHIPPING.md](./04-SHIPPING.md)** - Release gates, metrics, and stage operations
- **[manual-actions.md](./manual-actions.md)** - Manual task checklist tied to active milestones

## Reading Order

### First time
1. Read `00-FOUNDATION.md` (mandatory)
2. Read `01-ARCHITECTURE.md`
3. Read `02-THREAT-MODEL.md`
4. Review `03-MILESTONES.md`
5. Use `manual-actions.md` for execution

### Before starting any milestone work
1. Confirm current milestone in `03-MILESTONES.md`
2. Check risks/constraints in `00-FOUNDATION.md`
3. Verify required manual tasks in `manual-actions.md`

### Before release decisions
1. Review `04-SHIPPING.md`
2. Check stage entry/exit gates
3. Confirm severity response readiness

## Update Protocol

- `00-FOUNDATION.md`: Update only when strategic invariants change.
- `01-ARCHITECTURE.md`: Update when architecture contracts or layers change.
- `02-THREAT-MODEL.md`: Update when permission, autonomy, or attack surface changes.
- `03-MILESTONES.md`: Update continuously as milestones complete or split.
- `04-SHIPPING.md`: Update when stage criteria or target windows change.
- `manual-actions.md`: Update whenever manual dependencies are found/closed.

## Current Project Phase

**Status**: Pivot transition initiated
**Completed Milestones**: M001-M025
**Next Milestone**: M026 - Build Stability Recovery
**Release Target Track**: M131 public rollout window (target week of 2026-09-28)
