# Quick Start Guide

**You have complete documentation. Here's what to do next.**

---

## Step 1: Read Foundation (10 minutes)

```bash
open docs/00-FOUNDATION.md
```

**This is the most important file.** It contains:
- Core philosophy and principles
- Architectural decisions (including local LLM choice)
- What is and isn't allowed
- Non-negotiable constraints

**Do not skip this.** Every decision flows from this document.

---

## Step 2: Review Architecture (15 minutes)

```bash
open docs/01-ARCHITECTURE.md
```

Understand:
- System components and data flow
- Technology stack (Swift, SwiftUI, llama.cpp)
- File structure
- Command execution pipeline

---

## Step 3: Scan Milestones (5 minutes)

```bash
open docs/03-MILESTONES.md
```

You don't need to read all 93 milestones now. Just:
- Understand the phase structure
- Note that development is broken into atomic tasks
- Bookmark this file - you'll reference it constantly

---

## Step 4: Complete Manual Setup Tasks (30-60 minutes)

```bash
open docs/manual-actions.md
```

**Required before coding:**

1. **Install Xcode** (if not already)
   - App Store → Xcode → Install
   - Open once to complete setup

2. **Download LLM Model** (~4GB download)
   - See M003 section in manual-actions.md
   - Download LLaMA 3 8B (4-bit quantized)
   - Place in `Models/` directory
   - Verify integrity

3. **Research llama.cpp Swift bindings**
   - Search GitHub for Swift packages
   - Document your chosen approach
   - This will inform M004 and M012

---

## Step 5: Continue From Current Milestone (15 minutes)

```bash
open docs/03-MILESTONES.md
# Navigate to M011: LLM Model File Loader
```

**Tasks:**
1. Build and run current app state
2. Navigate to M011 requirements in `03-MILESTONES.md`
3. Implement M011 deliverables
4. Verify all M011 success criteria
5. Commit: "M011: LLM Model File Loader complete"

**Success**: Model loader handles valid, missing, and corrupted model files per M011 criteria.

---

## Step 6: Proceed Sequentially

**Do NOT skip milestones.**

Each milestone builds on previous ones. The order is intentional.

Current sequence:
- M011: LLM Model File Loader
- M012: llama.cpp Swift Bridge
- M013: Basic Inference Test
- ...and so on

---

## Daily Workflow

### Before Starting Work

1. **Read current milestone** in `03-MILESTONES.md`
2. **Check manual-actions.md** for any pending tasks
3. **Reference architecture doc** if implementing new component

### During Work

- **One milestone at a time** - complete fully before moving on
- **Test success criteria** before marking complete
- **Commit after each milestone** - clear commit messages
- **Update manual-actions.md** if you discover manual tasks

### After Completing Work

- **Mark milestone complete** with ✓ in `03-MILESTONES.md`
- **Update manual-actions.md** - check off completed tasks
- **Commit documentation updates** along with code
- **Review next milestone** to prepare for tomorrow

---

## When You Get Stuck

### Technical Questions
→ Check `01-ARCHITECTURE.md` for implementation details

### Architectural Decisions
→ Check `00-FOUNDATION.md` - does this align with principles?

### Security Concerns
→ Check `02-THREAT-MODEL.md` for threat analysis

### "Should I ship this?"
→ Check `04-SHIPPING.md` for release criteria

### Process Questions
→ Check `03-MILESTONES.md` - am I following the order?

---

## Key Reminders

### Never Compromise On:
- Privacy (local-first, always)
- User control (no autonomous execution in MVP)
- Transparency (show commands before running)
- Safety (confirmations for destructive actions)

### You Can Ship Without:
- Perfect UI (polish later)
- All command types (start with 15-20)
- Voice input (Phase 5+)
- Vision features (Phase 6+)

### Red Flags:
- Skipping milestones → Don't. Follow the order.
- Not testing success criteria → You'll ship broken code.
- Weakening privacy guarantees → Violates foundation.
- Adding features not in roadmap → Scope creep.

---

## Progress Tracking

### Update These Files Regularly:

**03-MILESTONES.md**
- Mark completed milestones: `[ ]` → `[x]`
- Add discovered sub-tasks if needed
- Update estimates based on reality

**manual-actions.md**
- Check off completed manual tasks
- Add new manual tasks as discovered
- Document decisions made

**Git Commits**
- Commit after each milestone
- Message format: "M0XX: [Milestone name] - [brief description]"
- Example: "M001: Project Initialization - Created Xcode project, configured git"

---

## Estimated Timeline

**Part-time (10-15 hours/week):**
- Phase 0-3: 2-3 weeks
- Phase 4-6: 2-3 weeks
- Phase 7-9: 2-3 weeks
- Phase 10-11: 1-2 weeks
- **Total: 8-12 weeks to MVP**

**Full-time (40 hours/week):**
- Phases 0-6: 1.5-2 weeks
- Phases 7-11: 1.5-2 weeks
- **Total: 3-4 weeks to MVP**

These are estimates. Reality will vary.

---

## Next Actions (Right Now)

1. [x] Read `docs/00-FOUNDATION.md` completely
2. [x] Skim `docs/01-ARCHITECTURE.md`
3. [x] Open `docs/manual-actions.md`
4. [ ] Download LLM model (M003)
5. [x] Install Xcode (if needed)
6. [x] Create Xcode project (M001) ✅
7. [x] Commit initial setup ✅
8. [ ] Move to M002

---

## Important Files at a Glance

| File | Purpose | When to Read |
|------|---------|--------------|
| `00-FOUNDATION.md` | Core truth, principles, decisions | First, and when making architectural choices |
| `01-ARCHITECTURE.md` | Technical implementation details | When implementing new components |
| `02-THREAT-MODEL.md` | Security, privacy, safety | When touching permissions or user data |
| `03-MILESTONES.md` | Complete development roadmap | Daily - current milestone |
| `04-SHIPPING.md` | Release strategy | When approaching alpha/beta/launch |
| `manual-actions.md` | Setup tasks checklist | Beginning, and throughout development |

---

## Support

**If you're confused:**
1. Re-read the relevant doc section
2. Check if answer is in another doc
3. Document your question - it may help others

**If you find errors:**
- Fix them immediately
- Update the docs
- Commit with clear message

**If you make architectural changes:**
- Document in `00-FOUNDATION.md` with rationale
- Update affected sections in other docs
- Commit separately from code changes

---

## You're Ready

You have:
- ✅ Complete philosophy and principles
- ✅ Detailed technical architecture
- ✅ Comprehensive threat model
- ✅ 93+ atomic milestones
- ✅ Release strategy
- ✅ Manual task checklist

**Everything you need to build this is documented.**

**Start with:** `docs/manual-actions.md` → Complete setup → `M001`

**Remember:** Follow the order, test thoroughly, commit frequently.

Good luck. Build something great.
