# Quick Start

Use this checklist to continue development safely and consistently.

## 1. Read Core Docs

1. `docs/README.md`
2. `docs/00-FOUNDATION.md`
3. `docs/03-MILESTONES.md` (find next `PLANNED`)
4. `docs/01-ARCHITECTURE.md`
5. `docs/02-THREAT-MODEL.md`

## 2. Confirm Current Milestone State

- Completed: `M001-M034`
- Next: `M035` (MCP Client Integration)

Always verify in `docs/03-MILESTONES.md` before coding.

## 3. Implement One Milestone Only

For the active milestone:

1. Implement scoped code changes
2. Verify build/tests
3. Update `docs/03-MILESTONES.md`:
   - status
   - deliverables checklist
   - success criteria
   - implementation notes
4. Provide exact manual setup + manual tests
5. Stop and wait for owner approval

## 4. Safety Rules

- No raw shell interpolation with untrusted input
- Keychain only for secrets
- HTTPS only for network calls
- Dangerous actions must require confirmation
- Keep kill switch behavior intact

## 5. Helpful Commands

```bash
# List docs
rg --files docs

# Find next planned milestone
rg -n "Status\\*\\*: PLANNED" docs/03-MILESTONES.md
```
