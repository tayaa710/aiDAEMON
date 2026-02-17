# 04 - SHIPPING STRATEGY

Release strategy for aiDAEMON.

Last Updated: 2026-02-17
Version: 3.0

---

## Release Philosophy

Ship incrementally. Each phase delivers something usable. Don't wait for perfection.

---

## Stage 1: Internal Dogfood

**Who**: Just you (the owner).
**When**: Throughout development (M025–M057).

**What you're doing**:
- Building and testing each milestone on your own Mac
- Using the app daily as it gains features
- Finding bugs and rough edges by actual usage

**Quality bar**:
- App doesn't crash during normal use
- Core features work reliably (open apps, find files, chat, etc.)
- Cloud brain responds correctly when configured
- No security issues found during use

---

## Stage 2: Private Beta

**Who**: 5-10 trusted testers (friends, fellow developers, etc.)
**When**: After M058 (Beta Build and Distribution)

**What testers need**:
- Signed, notarized .dmg installer
- Installation instructions
- Their own API key for cloud features (or local-only mode)
- A way to report bugs (Google Form, email, or GitHub Issues)

**Quality bar**:
- Installs cleanly on testers' Macs
- Onboarding makes sense without your help
- Core workflows work (not everything, but the main stuff)
- No data loss or security issues
- Crash-free sessions > 95%

**Duration**: 2-4 weeks of active testing

---

## Stage 3: Public Launch

**When**: After M059 + beta feedback addressed

**Requirements before launch**:
- [ ] All critical beta bugs fixed
- [ ] Security hardening pass complete (M054)
- [ ] Landing page live
- [ ] Download link working
- [ ] Payment flow working (for paid tier)
- [ ] Support channel active
- [ ] No known P0 or P1 issues

**Launch checklist**:
- [ ] Final build signed and notarized
- [ ] Appcast XML updated for auto-updates
- [ ] Landing page published
- [ ] Payment integration tested with real transaction
- [ ] First-week monitoring plan ready

---

## Severity Levels

- **P0**: Data loss, security breach, or destructive action without consent. Fix immediately.
- **P1**: Major feature broken, crashes on common workflow. Fix within 48 hours.
- **P2**: Minor bug, cosmetic issue, edge case. Fix in next release.
- **P3**: Enhancement, nice-to-have. Backlog.

---

## Pricing (Planned)

| Tier | Price | What You Get |
|------|-------|-------------|
| Free | $0 | Local AI only. Simple tasks (open apps, find files, move windows, system info) |
| Pro | $15-20/month | Cloud brain for complex tasks, screen vision, multi-step workflows, voice |

Users can start free and upgrade when they want more power. Free tier is fully functional for basic use — it's not a crippled demo.
