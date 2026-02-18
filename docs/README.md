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

- **PRIVACY IS NON-NEGOTIABLE.** Read 02-THREAT-MODEL.md. Every feature must protect user data. When in doubt, keep data local. Never send data to any external service without explicit user opt-in AND encryption in transit.
- **SECURITY IS NON-NEGOTIABLE.** No command injection. No raw shell interpolation. No unvalidated inputs. No hardcoded secrets. Every external API call must use HTTPS. Every credential must use Keychain.
- **The owner is not a cloud/backend expert.** When a milestone requires cloud setup (AWS, API keys, server config), provide instructions a non-technical person can follow. Include screenshots references, exact URLs, exact button names.
- **Do not skip manual setup or test instructions.** This is the most important part of your output after code. The owner cannot verify your work without them.
- **Do not start the next milestone without being told.** The owner needs to build in Xcode and manually verify before moving on.

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

**Completed**: M001–M030 (foundation, UI, local LLM, command executors, hybrid model layer, conversation data model, chat UI)
**Next**: See 03-MILESTONES.md for the current milestone
