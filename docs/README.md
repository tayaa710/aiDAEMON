# aiDAEMON Documentation

This directory contains the complete source of truth for the aiDAEMON project.

## Documentation Structure

### Core Foundation
- **[00-FOUNDATION.md](./00-FOUNDATION.md)** - Permanent truth anchor. Read this first. Always.
- **[01-ARCHITECTURE.md](./01-ARCHITECTURE.md)** - Complete system architecture and technical decisions
- **[02-THREAT-MODEL.md](./02-THREAT-MODEL.md)** - Security boundaries, privacy guarantees, risk mitigation

### Development Planning
- **[03-MILESTONES.md](./03-MILESTONES.md)** - Complete development roadmap broken into atomic milestones
- **[04-SHIPPING.md](./04-SHIPPING.md)** - Release strategy, testing phases, distribution plan
- **[manual-actions.md](./manual-actions.md)** - Checklist of manual tasks required throughout development

## Reading Order

**First time:**
1. Start with `00-FOUNDATION.md` to understand core principles
2. Read `01-ARCHITECTURE.md` for technical understanding
3. Review `02-THREAT-MODEL.md` for security context
4. Scan `03-MILESTONES.md` to understand development phases
5. Check `manual-actions.md` for immediate setup tasks

**Before starting work:**
1. Re-read relevant sections of `00-FOUNDATION.md`
2. Check current milestone in `03-MILESTONES.md`
3. Review `manual-actions.md` for pending tasks

**When making architectural decisions:**
1. Consult `00-FOUNDATION.md` for invariants
2. Check `01-ARCHITECTURE.md` for existing patterns
3. Verify against `02-THREAT-MODEL.md` for security implications

## File Update Protocol

- **00-FOUNDATION.md**: Only update when core philosophy or invariants change (rare)
- **01-ARCHITECTURE.md**: Update when adding new system components or changing tech stack
- **02-THREAT-MODEL.md**: Update when adding new permissions or expanding system access
- **03-MILESTONES.md**: Update frequently - mark completed, add discovered sub-tasks
- **04-SHIPPING.md**: Update when release criteria change
- **manual-actions.md**: Update constantly - add new tasks, check off completed ones

## Version Control

All documentation files are version controlled with the codebase. Changes to foundation documents should be committed with detailed explanations.

## Current Project Phase

**Status**: Phase 1 (Core UI) in progress
**Completed Milestones**: M001-M009
**Next Milestone**: M010 - Settings Window
**Target**: Complete Phase 1 core UI milestones
