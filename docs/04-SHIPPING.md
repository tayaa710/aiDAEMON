# 04 - SHIPPING STRATEGY

Release stages, testing operations, and go-live gates for the companion pivot.

Last Updated: 2026-02-17
Version: 2.0

---

## Release Philosophy

Ship in progressive trust bands:
1. Internal dogfood
2. Alpha (small external cohort)
3. Beta (broader external cohort)
4. Public release

The assistant becomes more autonomous only when safety evidence supports it.

---

## Stage 1: Internal Dogfood

**Planned Window**: 2026-03-02 to 2026-05-09
**Milestone Span**: M026-M118

### Entry Criteria
- [ ] Pivot documentation complete (M025)
- [ ] Build baseline restored (M026)
- [ ] Transition gate approved (M034)

### Goals
- Validate agent loop fundamentals
- Validate policy enforcement for all execution paths
- Build confidence in memory/context boundaries
- Reach pre-alpha quality baseline

### Operating Cadence
- Daily smoke checks on core workflows
- Weekly failure review and top-risk triage
- Weekly performance regression snapshot

### Internal Success Metrics
- 90%+ success on defined core scenarios
- No unresolved critical policy bypasses
- Crash-free sessions >=99% in internal usage

### Exit Criteria
- [ ] Agent core gate passed (M052)
- [ ] Tool runtime gate passed (M072)
- [ ] Memory/context gate passed (M086)
- [ ] UX gate passed (M100)
- [ ] Safety gate passed (M110)
- [ ] Pre-alpha gate passed (M118)

---

## Stage 2: Alpha Program

**Planned Window**: 2026-05-11 to 2026-06-26
**Milestone Span**: M119-M123
**Cohort Size**: 15-30 testers

### Entry Criteria
- [ ] Internal dogfood exit criteria complete
- [ ] Installer/update path tested internally
- [ ] Support and issue triage workflow active

### Goals
- Validate real-world usability across varied hardware
- Detect architecture-level misses early
- Validate permission and trust UX with non-developers

### Alpha Operations
- Invite-only distribution
- Weekly alpha survey and issue triage
- Two feedback waves (Wave 1, triage, Wave 2)

### Alpha Success Metrics
- 70%+ testers complete onboarding
- 60%+ weekly active usage during test window
- No unresolved P0 issues at alpha exit

### Exit Criteria
- [ ] Alpha defects triaged and prioritized
- [ ] Blocking reliability issues resolved
- [ ] Alpha exit gate passed (M123)

---

## Stage 3: Beta Program

**Planned Window**: 2026-07-06 to 2026-08-21
**Milestone Span**: M124-M128
**Cohort Size**: 100+ testers

### Entry Criteria
- [ ] Alpha exit gate complete
- [ ] Performance baseline documented
- [ ] Crash/feedback pipeline stable

### Goals
- Validate stability and supportability at broader scale
- Validate update rollout and regression recovery
- Validate autonomy controls under diverse usage patterns

### Beta Operations
- Public waitlist onboarding
- Scheduled updates with release notes
- Two stabilization sprints with measurable burn-down

### Beta Success Metrics
- Crash-free sessions >=99.5%
- Core workflow success >=92%
- Median response latency within targets
- No open P0/P1 issues at exit

### Exit Criteria
- [ ] Beta stabilization sprints complete
- [ ] Metrics meet thresholds
- [ ] Beta exit gate passed (M128)

---

## Stage 4: Public Launch

**Planned Window**: 2026-09-07 to 2026-10-05
**Milestone Span**: M129-M132

### Entry Criteria
- [ ] Beta exit gate complete
- [ ] Security and launch audits complete
- [ ] Release candidate signed and notarized

### Goals
- Deliver a reliable v1 companion experience
- Keep trust high through clear controls and transparency
- Respond rapidly to launch-week issues

### Launch Sequence

#### T-21 to T-14 days
- [ ] Freeze scope
- [ ] Execute launch readiness audit (M130)
- [ ] Validate rollback plan

#### T-7 days
- [ ] Build and verify launch candidate
- [ ] Final docs and onboarding polish
- [ ] Final support playbook review

#### Launch Week
- [ ] Public rollout (M131)
- [ ] Daily monitoring of issues and crash trends
- [ ] Publish known issues and workarounds if needed

#### Post-Launch Week 1
- [ ] Patch planning and rollout (M132)
- [ ] Publish launch retrospective

### Public Success Metrics
- Successful install flow for >95% of sampled users
- No critical unresolved launch defects after week 1
- Early retention and workflow completion above beta baseline

---

## Severity and Response Policy

### Severity Classes
- `P0`: critical safety/privacy/data-loss issue
- `P1`: major reliability/security issue
- `P2`: moderate regression or major UX defect
- `P3`: minor bug or enhancement

### Response Targets
- P0: same day mitigation
- P1: 48-hour mitigation target
- P2: next scheduled patch
- P3: backlog triage

---

## Go/No-Go Rules

Public launch is a no-go if any of the following are true:
- Any unresolved P0 exists
- Any known policy bypass on dangerous actions exists
- Crash-free rate is below target in final pre-launch sample
- Permission/autonomy controls are unclear in usability validation

---

## Required Artifacts by Stage Exit

### Internal Exit
- Core scenario pass report
- Safety and policy validation report
- Performance baseline report

### Alpha Exit
- Alpha issue report and disposition
- Onboarding friction report
- Updated risk register

### Beta Exit
- Stability metrics report
- Security and abuse test summary
- Launch readiness checklist

### Public Week-1 Exit
- Incident and patch report
- Updated roadmap with post-launch priorities

---

## Notes

Dates are planned targets, not guarantees. If quality gates fail, dates move and trust gates remain mandatory.
