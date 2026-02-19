# aiDAEMON

Native JARVIS-style AI companion for macOS.

## Current Status

- Completed milestones: `M001-M034`
- Current implementation includes:
  - Chat-first floating UI with conversation persistence
  - Local model + cloud model providers
  - Anthropic Claude as primary cloud provider
  - Native tool schema/registry with policy validation
  - Reactive orchestrator loop using Claude `tool_use`
  - Kill switch (`Cmd+Shift+Escape`) + in-window stop button
- Next planned milestone: `M035` (MCP Client Integration)

## What Works Today

- Open apps and URLs
- Search files (Spotlight)
- Move/resize windows
- Query system information
- Multi-step agent turns through orchestrator + tool-use loop
- Local fallback path when cloud is unavailable

## Documentation

- Start here for agent workflow: `docs/README.md`
- Product and non-negotiables: `docs/00-FOUNDATION.md`
- Technical architecture: `docs/01-ARCHITECTURE.md`
- Security/privacy model: `docs/02-THREAT-MODEL.md`
- Milestone roadmap: `docs/03-MILESTONES.md`
- Shipping/release strategy: `docs/04-SHIPPING.md`
- Historical manual setup log: `docs/manual-actions.md`

## Development Workflow

1. Read `docs/README.md` and `docs/00-FOUNDATION.md`.
2. Find next `PLANNED` milestone in `docs/03-MILESTONES.md`.
3. Implement that milestone only.
4. Update milestone status/notes in `docs/03-MILESTONES.md`.
5. Provide exact manual setup + tests, then stop.

## Tech Stack

- Swift + SwiftUI (macOS native)
- `llama.cpp` via `LlamaSwift` (local model)
- Anthropic Messages API (cloud model/tool use)
- KeyboardShortcuts
- Sparkle

## Distribution

Direct download distribution (outside the Mac App Store), signed and notarized.
