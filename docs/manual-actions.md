# Manual Actions Checklist

This file tracks all manual tasks that must be completed during development.
Mark items as complete by changing `[ ]` to `[x]`.

Last Updated: 2026-02-16

---

## IMMEDIATE SETUP (Before M003)

### Development Environment

- [x] **Install Xcode** ✅ (verified - xcodebuild works)
  - Open App Store
  - Search "Xcode"
  - Install (requires ~15GB disk space)
  - Open Xcode once to complete setup

- [x] **Install Xcode Command Line Tools** ✅
  ```bash
  xcode-select --install
  ```

- [x] **Verify Swift is available** ✅
  ```bash
  swift --version
  # Should show Swift 5.9+ (or current version)
  ```

---

## M003: LLM MODEL ACQUISITION ✅

### Download LLaMA 3.1 Model

- [x] **Downloaded LLaMA 3.1 8B Instruct (Q4_K_M)** ✅
  - Source: bartowski/Meta-Llama-3.1-8B-Instruct-GGUF (Hugging Face)
  - File: `Models/model.gguf` (4.6GB)
  - Format: GGUF (verified magic bytes)
  - SHA256: `7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c`

- [x] **Verified download integrity** ✅
  - GGUF header confirmed
  - SHA256 checksum recorded

**Notes:**
- Model file is gitignored (too large for git)
- Each developer must download separately
- Keep model file in `Models/` directory at project root
- Filename used in code: `model.gguf`

---

## M004: DEPENDENCIES ✅

### llama.cpp Integration

- [x] **Research Swift bindings for llama.cpp** ✅
- [x] **Choose approach and document decision** ✅
- [x] **Add llama.cpp dependency** ✅

**Chosen Approach**: **mattt/llama.swift (LlamaSwift) via SPM**

**Rationale** (updated from original plan):
- Official `ggml-org/llama.cpp` removed its `Package.swift` - no longer usable as direct SPM dependency
- `mattt/llama.swift` wraps llama.cpp as precompiled XCFramework
- Supports macOS 13.0+ (matches our deployment target)
- Semantically versioned (currently @ 2.8061.0)
- Re-exports llama.cpp C++ APIs directly via Swift/C++ interop
- Requires `SWIFT_CXX_INTEROP_MODE = default` build setting

**Repository**: https://github.com/mattt/llama.swift
**Import**: `import LlamaSwift`

### Sparkle Framework

- [x] **Add Sparkle via SPM** ✅ (@ 2.8.1)
- [x] **Verified Sparkle imports** ✅ (`import Sparkle` compiles)

### Hotkey Library

- [x] **Chose KeyboardShortcuts** ✅ (by sindresorhus, @ 2.4.0)
  - Modern SwiftUI API
  - Actively maintained
  - Clean integration

**Import**: `import KeyboardShortcuts`

---

## M020: WINDOW MANAGER EXECUTOR ✅

### Accessibility Permission

- [ ] **Grant Accessibility access to aiDAEMON**
  1. Launch `aiDAEMON`.
  2. Trigger a window command (for example: `left half`).
  3. macOS prompts for permission.
  4. Open System Settings → Privacy & Security → Accessibility.
  5. Enable `aiDAEMON`.
  6. Relaunch `aiDAEMON`.

### Manual QA (Window Commands)

- [ ] **Regression: aiDAEMON should not resize itself**
  1. Open Safari and make it the active app.
  2. Press `Cmd+Shift+Space` to open aiDAEMON.
  3. Enter `left half`.
  4. Verify Safari moves to left half.
  5. Verify aiDAEMON floating window size/position is unchanged by the command.

- [ ] **Position coverage on a real app window**
  - `right half`
  - `top half`
  - `bottom half`
  - `full screen`
  - `center`
  - `top left`
  - `top right`
  - `bottom left`
  - `bottom right`

- [ ] **Cross-app behavior**
  1. Repeat 2-3 commands each with Safari, Finder, and TextEdit.
  2. Verify each command affects the previously active external app, not aiDAEMON.

- [ ] **Failure handling**
  1. Disable Accessibility permission for aiDAEMON.
  2. Run `left half`.
  3. Verify a permission error is shown and no window is moved.

- [ ] **Optional multi-monitor check**
  1. Move an app window to secondary display.
  2. Run `left half` and `right half`.
  3. Verify results stay on the same display with correct geometry.

---

## M052: CODE SIGNING SETUP

### Apple Developer Account

- [ ] **Enroll in Apple Developer Program**
  - Go to: https://developer.apple.com/programs/enroll/
  - Cost: $99/year (required for distribution)
  - Complete enrollment (takes 24-48 hours)

- [ ] **Verify enrollment**
  - Log in to: https://developer.apple.com/account/
  - Should see "Membership" status as active

### Developer ID Certificate

- [ ] **Generate Certificate Signing Request (CSR)**
  1. Open Keychain Access
  2. Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority
  3. Enter email and name
  4. Choose "Saved to disk"
  5. Save CSR file

- [ ] **Create Developer ID Application Certificate**
  1. Go to: https://developer.apple.com/account/resources/certificates/add
  2. Choose "Developer ID Application"
  3. Upload CSR
  4. Download certificate
  5. Double-click to install in Keychain

- [ ] **Verify certificate in Keychain**
  - Open Keychain Access
  - Search: "Developer ID Application"
  - Should see certificate with your name
  - Verify expiration date (valid for 5 years)

### Xcode Signing Configuration

- [ ] **Configure automatic signing in Xcode**
  1. Select project in Xcode
  2. Select target "aiDAEMON"
  3. Signing & Capabilities tab
  4. Uncheck "Automatically manage signing" (we need manual for Developer ID)
  5. Choose "Developer ID Application" certificate
  6. Set Team to your Apple Developer account

- [ ] **Verify signing works**
  ```bash
  # Build app
  # Then verify signature:
  codesign -dv --verbose=4 build/Release/aiDAEMON.app

  # Should show:
  # Authority=Developer ID Application: [Your Name]
  # Signature valid
  ```

---

## M053: ENTITLEMENTS

### Entitlements File

- [ ] **Create entitlements file**
  1. Xcode → File → New → File
  2. Choose "Property List"
  3. Name: `aiDAEMON.entitlements`
  4. Add to target: aiDAEMON

- [ ] **Configure required entitlements**
  Edit `aiDAEMON.entitlements`:
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>com.apple.security.automation.apple-events</key>
      <true/>
  </dict>
  </plist>
  ```

- [ ] **Link entitlements in Xcode**
  1. Select target
  2. Build Settings
  3. Search "Code Signing Entitlements"
  4. Set to: `aiDAEMON/aiDAEMON.entitlements`

- [ ] **Verify entitlements are embedded**
  ```bash
  codesign -d --entitlements - build/Release/aiDAEMON.app
  # Should show the entitlements XML
  ```

---

## M054: NOTARIZATION

### App-Specific Password

- [ ] **Generate app-specific password**
  1. Go to: https://appleid.apple.com/account/manage
  2. Sign in with Apple ID
  3. Security → App-Specific Passwords
  4. Generate new password
  5. Name it: "aiDAEMON Notarization"
  6. **SAVE PASSWORD SECURELY** (1Password, Keychain, etc.)

- [ ] **Store password in Keychain**
  ```bash
  xcrun notarytool store-credentials "aiDAEMON-notary" \
    --apple-id "your.email@example.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "app-specific-password"
  ```
  Replace with your actual email, team ID, and password.

### Notarization Script

- [ ] **Create notarization script**
  File: `scripts/notarize.sh`
  ```bash
  #!/bin/bash
  set -e

  APP_PATH="$1"

  if [ -z "$APP_PATH" ]; then
    echo "Usage: ./notarize.sh /path/to/aiDAEMON.app"
    exit 1
  fi

  echo "Creating ZIP for notarization..."
  ditto -c -k --keepParent "$APP_PATH" aiDAEMON.zip

  echo "Submitting to Apple..."
  xcrun notarytool submit aiDAEMON.zip \
    --keychain-profile "aiDAEMON-notary" \
    --wait

  echo "Stapling ticket..."
  xcrun stapler staple "$APP_PATH"

  echo "Verifying..."
  spctl -a -v "$APP_PATH"

  echo "✓ Notarization complete!"
  rm aiDAEMON.zip
  ```

- [ ] **Make script executable**
  ```bash
  chmod +x scripts/notarize.sh
  ```

- [ ] **Test notarization** (when app is built)
  ```bash
  ./scripts/notarize.sh build/Release/aiDAEMON.app
  ```

---

## M055: DMG CREATION

### Install create-dmg Tool

- [ ] **Install create-dmg via Homebrew**
  ```bash
  brew install create-dmg
  ```

### DMG Creation Script

- [ ] **Create DMG build script**
  File: `scripts/create-dmg.sh`
  ```bash
  #!/bin/bash
  set -e

  VERSION="$1"
  if [ -z "$VERSION" ]; then
    echo "Usage: ./create-dmg.sh 1.0.0"
    exit 1
  fi

  APP_PATH="build/Release/aiDAEMON.app"
  DMG_NAME="aiDAEMON-${VERSION}.dmg"

  echo "Creating DMG..."
  create-dmg \
    --volname "aiDAEMON" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "aiDAEMON.app" 175 190 \
    --hide-extension "aiDAEMON.app" \
    --app-drop-link 425 185 \
    "$DMG_NAME" \
    "$APP_PATH"

  echo "✓ DMG created: $DMG_NAME"
  ```

- [ ] **Make script executable**
  ```bash
  chmod +x scripts/create-dmg.sh
  ```

- [ ] **Test DMG creation** (when app is built)
  ```bash
  ./scripts/create-dmg.sh 1.0.0-test
  ```

---

## M056: SPARKLE UPDATE FEED

### Generate EdDSA Keys

- [ ] **Generate signing keys for updates**
  ```bash
  # Sparkle includes a key generator
  ./Frameworks/Sparkle.framework/Resources/generate_keys

  # Save the output:
  # Public key: [copy to safe place - goes in Info.plist]
  # Private key: [KEEP VERY SECURE - used to sign updates]
  ```

- [ ] **Store private key securely**
  - DO NOT commit to git
  - Store in password manager
  - Or in secure environment variable

- [ ] **Add public key to Info.plist**
  ```xml
  <key>SUPublicEDKey</key>
  <string>[YOUR_PUBLIC_KEY]</string>
  ```

### Set Up Update Feed

- [ ] **Choose hosting for appcast.xml**
  - Option A: GitHub Releases (free, reliable)
  - Option B: Own server
  - **Recommended**: GitHub Releases

- [ ] **Create initial appcast.xml**
  File: `appcast.xml` (will be hosted on GitHub)
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
      <title>aiDAEMON Updates</title>
      <link>https://github.com/[username]/aiDAEMON/releases.atom</link>
      <description>Updates for aiDAEMON</description>
      <language>en</language>
      <!-- Items will be added here for each release -->
    </channel>
  </rss>
  ```

- [ ] **Add Sparkle feed URL to Info.plist**
  ```xml
  <key>SUFeedURL</key>
  <string>https://[your-username].github.io/aiDAEMON/appcast.xml</string>
  ```

---

## M069: WEBSITE

### Domain (Optional)

- [ ] **Decide on domain**
  - Option A: Use GitHub Pages (free): `[username].github.io/aiDAEMON`
  - Option B: Buy custom domain (e.g., aidaemon.app)

**Decision**: [TO BE FILLED]

### GitHub Pages Setup

- [ ] **Enable GitHub Pages**
  1. Create `docs/` folder in repo (or separate `gh-pages` branch)
  2. Add `index.html` with landing page
  3. GitHub → Settings → Pages
  4. Source: Deploy from a branch
  5. Branch: main, folder: /docs

- [ ] **Create landing page**
  - File: `docs/index.html` (or use Jekyll, etc.)
  - Include: Features, download link, screenshots, docs link

- [ ] **Test site**
  - Visit: https://[username].github.io/aiDAEMON
  - Verify download link works
  - Test on mobile

---

## M070: GITHUB REPOSITORY

### Repository Setup

- [ ] **Create GitHub repository**
  1. Go to: https://github.com/new
  2. Name: `aiDAEMON`
  3. Description: "Natural language interface for macOS system control"
  4. Public or Private: [decide based on open-source decision]
  5. Create repository

- [ ] **Push local repo to GitHub**
  ```bash
  git remote add origin https://github.com/[username]/aiDAEMON.git
  git branch -M main
  git push -u origin main
  ```

### Repository Configuration

- [ ] **Add LICENSE file**
  - If open source: Choose license (MIT, Apache 2.0, etc.)
  - Add LICENSE file to repo

- [ ] **Create issue templates**
  ```bash
  mkdir -p .github/ISSUE_TEMPLATE
  ```

  Bug report template: `.github/ISSUE_TEMPLATE/bug_report.md`
  Feature request template: `.github/ISSUE_TEMPLATE/feature_request.md`

- [ ] **Create CONTRIBUTING.md** (if open source)

- [ ] **Add repository topics**
  GitHub → Settings → Topics
  Suggested: `macos`, `swift`, `llm`, `local-ai`, `productivity`

---

## M071: ANALYTICS DECISION

- [ ] **Decide: Include analytics?**
  - [ ] Yes, with opt-in → Implement M072
  - [ ] No → Document decision, skip M072

**Decision**: [TO BE FILLED]

**Rationale**: [TO BE FILLED]

---

## TESTING HARDWARE

### Recommended Test Configurations

- [ ] **Primary development machine**
  - Model: [fill in]
  - Chip: [M1/M2/M3/Intel]
  - RAM: [fill in]
  - macOS version: [fill in]

- [ ] **Secondary test machine** (if available)
  - Model: [fill in]
  - Chip: [fill in]
  - RAM: [fill in]
  - macOS version: [fill in]

- [ ] **Borrow/access machines for testing**
  - [ ] Intel Mac (if primary is Apple Silicon)
  - [ ] Older macOS version (Ventura if primary is Sequoia)
  - [ ] Low-RAM machine (8GB) to test performance

---

## COMMUNITY SETUP (Optional)

### Communication Channels

- [ ] **Decide on support channels**
  - [x] GitHub Issues (primary)
  - [ ] Email (if yes, set up email)
  - [ ] Discord/Slack (if yes, create)
  - [ ] Twitter/X (if yes, create account)

**Email** (if using):
- [ ] Set up email: support@[domain]
- [ ] Configure email forwarding/inbox

**Social Media** (if using):
- [ ] Create Twitter/X account
- [ ] Create placeholder posts
- [ ] Prepare launch content

---

## BETA TESTING

### Tester Recruitment

- [ ] **Identify alpha testers** (5-10 people)
  - [ ] [Name 1]
  - [ ] [Name 2]
  - [ ] [Name 3]
  - [ ] [Name 4]
  - [ ] [Name 5]

- [ ] **Create feedback form**
  - Tool: Google Forms or Typeform
  - Questions from `04-SHIPPING.md`

- [ ] **Prepare beta signup** (for broader beta)
  - Landing page with email signup
  - Or: Google Form for applications

---

## LAUNCH DAY

- [ ] **Final build verification**
  ```bash
  # Verify app is signed
  codesign -dv --verbose=4 aiDAEMON.app

  # Verify notarization
  spctl -a -v aiDAEMON.app

  # Test on clean Mac
  ```

- [ ] **Upload to GitHub Releases**
  - Tag: `v1.0.0`
  - Title: "aiDAEMON v1.0.0 - Initial Release"
  - Upload DMG
  - Write release notes

- [ ] **Update website download link**

- [ ] **Post announcements**
  - [ ] Hacker News
  - [ ] Reddit (/r/macapps)
  - [ ] Twitter/X
  - [ ] Email beta testers

- [ ] **Monitor for issues**
  - Watch GitHub Issues
  - Monitor social media
  - Check crash reports (if enabled)

---

## NOTES & DECISIONS

### Design Decisions
- [Date] - [Decision]: [Rationale]

### Blocked Items
- [Item]: Blocked because [reason]

### Deferred Tasks
- [Task]: Deferred to [version/date] because [reason]

---

**Keep this file updated as you progress through milestones.**
**Document all manual steps so future you (or contributors) can follow.**
