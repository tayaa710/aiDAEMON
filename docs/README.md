# aiDAEMON Documentation

## FOR LLM AGENTS: READ THIS FIRST

**You are building a JARVIS-style AI companion for macOS.** The owner of this project does not write code — all development is done by LLM agents (you). The owner will build via Xcode and perform manual testing.

### Your Workflow (MANDATORY for every milestone)

```
1. READ    → Read 00-FOUNDATION.md first. Then read the current milestone in 03-MILESTONES.md.
2. BUILD   → Complete the milestone. Write clean, secure code.
3. UPDATE  → Update 03-MILESTONES.md (mark complete, add notes).
4. SETUP   → Tell the owner EXACTLY what manual steps they need to do:
             - Any Xcode settings to change
             - Any files to download or move
             - Any permissions to grant in System Settings
             - Any accounts to create or API keys to obtain
             - Any terminal commands to run
             - Step-by-step, assume they have ZERO cloud/backend experience
5. TEST    → Tell the owner EXACTLY what manual tests to perform:
             - What to click, type, or say
             - What they should see on screen
             - What counts as a pass vs fail
             - Screenshots or screen recordings to take if useful
6. WAIT    → Stop. Do NOT start the next milestone until the owner says so.
```

### Critical Rules

- **CAPABILITY FIRST.** The assistant should be maximally capable. Cloud AI (Claude) is on by default. Privacy is preserved through architecture (TLS, ephemeral data, no training on user data), not through restrictions that cripple the product. Read 00-FOUNDATION.md for the full principles.
- **SECURITY IS NON-NEGOTIABLE.** No command injection. No raw shell interpolation. No unvalidated inputs. No hardcoded secrets. Every external API call must use HTTPS. Every credential must use Keychain. Read 02-THREAT-MODEL.md.
- **The owner is not a cloud/backend expert.** When a milestone requires cloud setup (AWS, API keys, server config), provide instructions a non-technical person can follow. Include screenshots references, exact URLs, exact button names.
- **Do not skip manual setup or test instructions.** This is the most important part of your output after code. The owner cannot verify your work without them.
- **Do not start the next milestone without being told.** The owner needs to build in Xcode and manually verify before moving on.
- **For permission-sensitive testing (Accessibility, Microphone, Screen Recording), use signed builds.** Avoid `CODE_SIGNING_ALLOWED=NO` for those tests, or macOS may re-prompt/reset permissions.

---

## Documentation Structure

| File | Purpose | When to Read |
|------|---------|--------------|
| [00-FOUNDATION.md](./00-FOUNDATION.md) | Product vision, principles, what this is and isn't | **Always read first** |
| [01-ARCHITECTURE.md](./01-ARCHITECTURE.md) | Technical architecture, system layers, data flow | Before building any milestone |
| [02-THREAT-MODEL.md](./02-THREAT-MODEL.md) | Security and privacy requirements | Before any feature involving data, network, or permissions |
| [03-MILESTONES.md](./03-MILESTONES.md) | Complete roadmap with detailed milestones | To find what to build next |
| [04-SHIPPING.md](./04-SHIPPING.md) | Release strategy and quality gates | Before alpha/beta/launch work |
| [manual-actions.md](./manual-actions.md) | Historical record of completed setup tasks | Reference only |

## Reading Order for a New LLM Agent

1. **This README** (you're here)
2. **00-FOUNDATION.md** (mandatory — understand the product and rules)
3. **03-MILESTONES.md** (find the next incomplete milestone)
4. **01-ARCHITECTURE.md** (understand how the system fits together)
5. **02-THREAT-MODEL.md** (understand security/privacy requirements)

## Current Status

**Completed**: M001–M044 (foundation, UI, local/cloud model layer, chat interface, tool schema system, Anthropic Claude provider, Level 1 autonomy, native orchestrator + tool-use loop, MCP client integration, voice I/O, screenshot-based computer control, accessibility service foundation, UI state provider + AX tools, foreground context lock + ComputerControl AX integration)
**Next**: M045 — Codebase Cleanup + Architecture Consolidation. See 03-MILESTONES.md for details.
