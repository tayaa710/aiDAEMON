# aiDAEMON

**Natural language interface for macOS system control**

Control your Mac by typing what you want in plain English. Powered by local AI, no data leaves your machine.

---

## Status

**Current Phase**: Pre-Development
**Next Milestone**: M001 - Project Initialization
**Target**: MVP in 8-12 weeks

---

## What It Does

Type natural language commands:

- `open youtube` → Opens YouTube in your browser
- `find tax documents from 2024` → Searches files with Spotlight
- `left half` → Resizes current window to left 50%
- `what's my ip?` → Shows your IP address
- `empty trash` → Empties trash (with confirmation)

More commands coming as development progresses.

---

## Why aiDAEMON?

### Privacy-First
- 100% local AI processing (LLaMA 3 8B)
- No data sent to cloud services
- No telemetry or tracking
- Your commands stay on your Mac

### Fast & Offline
- Local inference (no API latency)
- Works without internet
- No per-query costs

### Safe & Transparent
- Shows what it will do before executing
- Confirmation for destructive actions
- Complete audit log
- Emergency stop mechanism

### Power User Focused
- Natural language beats keyboard shortcuts
- Faster than hunting through menus
- Extensible and customizable
- Built by developers, for power users

---

## Core Principles

1. **Privacy is non-negotiable** - Local-first, cloud optional
2. **User must stay in control** - No autonomous execution
3. **Transparency over magic** - Show commands, explain actions
4. **Safety by design** - Confirmations, reversibility, audit logs
5. **Start focused** - Do fewer things well

See [docs/00-FOUNDATION.md](docs/00-FOUNDATION.md) for complete philosophy.

---

## Documentation

Complete documentation system in [`docs/`](docs/):

- **[00-FOUNDATION.md](docs/00-FOUNDATION.md)** - Core principles and architectural invariants (READ THIS FIRST)
- **[01-ARCHITECTURE.md](docs/01-ARCHITECTURE.md)** - Technical architecture and implementation details
- **[02-THREAT-MODEL.md](docs/02-THREAT-MODEL.md)** - Security, privacy, and threat mitigation
- **[03-MILESTONES.md](docs/03-MILESTONES.md)** - Complete development roadmap (93+ milestones)
- **[04-SHIPPING.md](docs/04-SHIPPING.md)** - Release strategy and launch plan
- **[manual-actions.md](docs/manual-actions.md)** - Checklist of manual setup tasks

---

## Technology Stack

- **Language**: Swift (macOS native)
- **UI**: SwiftUI (modern, declarative)
- **AI Model**: LLaMA 3 8B (4-bit quantized, ~4GB)
- **Inference**: llama.cpp (local, CPU/Metal)
- **Permissions**: Accessibility + Automation (minimal)
- **Distribution**: Direct download (not App Store)

---

## Development Roadmap

### Phase 1: Core UI (Weeks 1-2)
- Global hotkey activation
- Floating input window
- Text input and results display
- Settings interface

### Phase 2: LLM Integration (Weeks 2-3)
- Load LLaMA 3 model
- Intent parsing (natural language → structured commands)
- JSON output parsing
- Error handling

### Phase 3: Command Execution (Weeks 3-4)
- App launcher
- File search (Spotlight)
- Window management
- System info
- File operations
- Process management

### Phase 4: Polish & Safety (Weeks 5-6)
- Permission flow
- Confirmation dialogs
- Action logging
- Settings persistence
- UI polish

### Phase 5: Distribution (Weeks 7-8)
- Code signing
- Notarization
- DMG packaging
- Auto-updates (Sparkle)

### Phase 6: Testing & Launch (Weeks 9-10)
- Beta testing
- Bug fixes
- Documentation
- Public release

See [docs/03-MILESTONES.md](docs/03-MILESTONES.md) for complete milestone breakdown.

---

## Getting Started (For Developers)

### Prerequisites

- macOS 13.0+ (Ventura or later)
- Xcode 15+
- 8GB+ RAM (for LLM inference)
- Apple Developer account (for distribution)

### Setup

1. **Clone repository**
   ```bash
   git clone https://github.com/[username]/aiDAEMON.git
   cd aiDAEMON
   ```

2. **Read foundation docs**
   ```bash
   open docs/00-FOUNDATION.md
   ```

3. **Follow manual actions**
   ```bash
   open docs/manual-actions.md
   ```
   Complete setup tasks (Xcode, model download, dependencies).

4. **Start with M001**
   See [docs/03-MILESTONES.md](docs/03-MILESTONES.md) for first milestone.

---

## Project Structure

```
aiDAEMON/
├── aiDAEMON/           # Main app source code
│   ├── App/            # App lifecycle, entry point
│   ├── UI/             # SwiftUI views
│   ├── LLM/            # Model loading, inference
│   ├── Commands/       # Executors for each command type
│   ├── Storage/        # Database, settings
│   └── Utilities/      # Helpers, extensions
├── docs/               # Complete documentation
├── Models/             # LLM model files (gitignored)
├── scripts/            # Build, notarize, release scripts
└── README.md           # This file
```

---

## Contributing

**Current Status**: Pre-alpha development

Contributions welcome after initial release. For now:
- Watch this repo for updates
- File issues for ideas/feedback
- Wait for v0.1.0 before submitting PRs

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## FAQ

### Why local AI instead of ChatGPT API?
Privacy. Your commands, file paths, and usage patterns never leave your machine. Also: no API costs, works offline, instant responses.

### Why not use Siri or Shortcuts?
Siri requires internet and is limited. Shortcuts has a clunky UI. aiDAEMON is built for power users who want natural language with full system control.

### Will this work on older Macs?
Minimum: macOS 13.0. Recommended: Apple Silicon (M1+) for best LLM performance. Intel Macs may work but will be slower.

### How big is the download?
App bundle: ~50MB. LLM model: ~4.3GB. Total first install: ~4.5GB.

### Can I use my own LLM model?
Not in MVP. Future versions may support custom models.

### Will this be open source?
Decision pending. Leaning toward open source (MIT license) to build trust and allow community contributions.

### How much will it cost?
Free for MVP. Potential paid features later (cloud vision, advanced workflows), but core will stay free.

### Is this safe?
See [docs/02-THREAT-MODEL.md](docs/02-THREAT-MODEL.md) for complete security analysis. Short answer: Yes, with caveats. You grant Accessibility permission (same as other automation tools). All commands require approval. Local-only processing.

---

## Roadmap

**v1.0** (MVP - Target: Q2 2026)
- Local LLM parsing
- 15-20 command types
- Safe execution with confirmations
- macOS native app

**v1.1** (Post-launch)
- Voice input (Whisper)
- Custom aliases
- Multi-step workflows

**v2.0** (Future)
- Vision features (screen understanding)
- Plugin system
- Cloud sync (optional)

---

## Contact

- Issues: [GitHub Issues](https://github.com/[username]/aiDAEMON/issues)
- Security: security@aidaemon.dev (when set up)
- Twitter: [@aidaemon](https://twitter.com/aidaemon) (when created)

---

## Acknowledgments

- **LLaMA 3** by Meta AI
- **llama.cpp** by Georgi Gerganov
- **Sparkle** update framework
- Inspiration: Alfred, Raycast, Quicksilver

---

**Current Status**: Documentation complete. Beginning development.

**Next Steps**: Complete manual setup tasks, then start Milestone M001.

See [docs/](docs/) for complete development blueprint.
