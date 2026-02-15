# 04 - SHIPPING STRATEGY

Release stages, testing phases, and distribution plan for aiDAEMON.

Last Updated: 2026-02-15
Version: 1.0

---

## Release Philosophy

**Principle**: Ship early, ship often, but never ship broken.

We follow a staged release approach:
1. **Internal** - Developer only, unstable
2. **Alpha** - Close friends/testers, expect bugs
3. **Beta** - Broader audience, mostly stable
4. **Public** - General availability, production-ready

Each stage has specific entry criteria and goals.

---

## STAGE 1: INTERNAL TESTING

**Timeline**: Weeks 1-4 (Milestones M001-M030)

### Entry Criteria
- [ ] Project builds without errors (M001)
- [ ] LLM model loads and generates text (M013)
- [ ] Basic UI shows and accepts input (M008)
- [ ] At least one command type works (M018)

### Goals
- Validate core architecture
- Prove LLM parsing works
- Test basic execution flow
- Find obvious bugs

### Testing Approach
**Who**: Developer only

**What to Test**:
- Build on clean machine
- Test each command type as implemented
- Try malicious inputs (injection attempts)
- Verify permissions flow
- Test error handling

**Success Metrics**:
- No crashes during normal use
- LLM parses 80%+ of test commands correctly
- Execution works for implemented command types
- Permissions can be granted

### Exit Criteria
- [ ] All Phase 1-3 milestones complete (M001-M024)
- [ ] 5+ command types working
- [ ] No known critical bugs
- [ ] App is usable for developer daily work

**Decision Point**: If not usable by developer, architecture may be flawed. Reevaluate before proceeding.

---

## STAGE 2: ALPHA TESTING

**Timeline**: Weeks 5-6 (Milestones M031-M050)

### Entry Criteria
- [ ] Internal testing complete
- [ ] All core executors implemented (M018-M021)
- [ ] Permissions system working (M025-M030)
- [ ] Data persistence working (M031-M036)
- [ ] App is code signed (M052)

### Goals
- Get feedback on UX and feature set
- Find bugs developer missed
- Validate usefulness to others
- Test on different hardware/macOS versions

### Testing Approach
**Who**: 5-10 close friends or colleagues

**Recruitment**:
- Personal invitations
- Mix of technical and non-technical users
- Ideally: different Macs (Intel, M1, M2, etc.)

**Distribution**:
- Send DMG directly (email, Dropbox, etc.)
- Include installation instructions
- Provide feedback form (Google Form or similar)

**What to Test**:
- Installation process (any issues?)
- Permission granting (confusing?)
- Daily use (for 1-2 weeks)
- Specific commands (provide test list)
- Performance (slow on their machine?)
- Bugs (crash reports, unexpected behavior)

**Feedback Collection**:
```
Google Form Questions:
1. How easy was installation? (1-5)
2. Did you grant all permissions? Any issues?
3. How often did you use aiDAEMON? (daily, few times/week, once, never)
4. What commands did you use most?
5. What commands did you expect to work but didn't?
6. Did you experience any crashes? Describe.
7. How fast did commands feel? (instant, fast, acceptable, slow)
8. Would you keep using this? Why/why not?
9. Any other feedback?
```

**Success Metrics**:
- 80%+ successfully install and grant permissions
- 60%+ use it more than once
- 40%+ would use daily (if it was polished)
- Average rating 3.5+/5

### Exit Criteria
- [ ] 5+ alpha testers actively using
- [ ] Feedback collected and reviewed
- [ ] High-priority bugs fixed
- [ ] UX improvements made based on feedback
- [ ] No known crashes

**Decision Point**: If <40% would use daily, feature set or UX may be insufficient. Consider pivots.

---

## STAGE 3: BETA TESTING

**Timeline**: Weeks 7-9 (Milestones M051-M066)

### Entry Criteria
- [ ] Alpha feedback addressed
- [ ] All Phase 1-7 milestones complete
- [ ] App is notarized (M054)
- [ ] Auto-update system working (M056)
- [ ] Beta test program set up (M065)

### Goals
- Validate stability at scale
- Find edge cases and rare bugs
- Test on wide variety of systems
- Build word-of-mouth
- Collect feature requests for v1.1

### Testing Approach
**Who**: 20-50 beta testers

**Recruitment**:
- Post on Twitter, Reddit, Hacker News
- Invite alpha testers to refer friends
- Create simple landing page with signup form

**Distribution**:
- Public download link (GitHub Releases or website)
- Auto-updates via Sparkle
- Email list for announcements

**What to Test**:
- Everything (it's nearly feature-complete)
- Edge cases (unusual commands, rare workflows)
- Integration with different apps (Safari, Chrome, VSCode, etc.)
- Long-term use (multiple weeks)
- Update mechanism (push a beta update mid-test)

**Feedback Collection**:
- GitHub Issues for bug reports
- Email for general feedback
- Optional: Survey after 2 weeks
- Optional: Crash reporting (opt-in)

**Communication**:
- Welcome email with getting started guide
- Mid-test email: "How's it going? Any issues?"
- End email: "Final feedback before public launch?"

**Success Metrics**:
- 70%+ use it weekly
- <5% crash rate
- 50%+ would recommend to others
- Net Promoter Score (NPS) >30

### Exit Criteria
- [ ] 20+ active beta testers
- [ ] All critical bugs fixed (M066)
- [ ] NPS >30 or clear path to improve
- [ ] Documentation complete (M067)
- [ ] Performance benchmarks met (M062)
- [ ] Security audit passed (M064)

**Decision Point**: If NPS <20 or crashes >10%, not ready for public. Extend beta.

---

## STAGE 4: PUBLIC RELEASE

**Timeline**: Week 10+ (Milestone M075)

### Entry Criteria
- [ ] Beta testing complete with positive results
- [ ] All MVP milestones complete (M001-M074)
- [ ] Launch checklist complete (M074)
- [ ] Website live (M069)
- [ ] Documentation published (M067)
- [ ] Privacy policy published (M068)

### Launch Plan

**T-7 Days** (One Week Before):
- [ ] Final code freeze
- [ ] Final QA pass (M073)
- [ ] Build release candidate
- [ ] Test on fresh Macs
- [ ] Prepare announcement content

**T-3 Days**:
- [ ] Upload final DMG to GitHub Releases
- [ ] Update website with download link (but keep hidden)
- [ ] Prepare social media posts
- [ ] Email beta testers: "Public launch in 3 days, thank you"

**T-1 Day**:
- [ ] Final smoke test of download link
- [ ] Verify auto-update feed is correct
- [ ] Queue social posts
- [ ] Get some sleep

**Launch Day (T-0)**:
- [ ] Make download link public
- [ ] Publish announcement blog post
- [ ] Post to Twitter, Hacker News, Reddit (/r/macapps, /r/MacOS)
- [ ] Email beta testers with public link
- [ ] Monitor GitHub issues closely
- [ ] Monitor social media for feedback
- [ ] Be ready to pull if critical bug found

**T+1 Day**:
- [ ] Respond to all issues/questions
- [ ] Monitor crash reports (if enabled)
- [ ] Triage any bugs found
- [ ] Post "thank you" to community

**T+1 Week**:
- [ ] Assess launch success
- [ ] Plan first patch release if needed (M077)
- [ ] Collect feature requests for v1.1
- [ ] Write retrospective

### Distribution Channels

**Primary**:
- GitHub Releases (free, reliable)
- Website download link (hosted on GitHub Pages or similar)

**Secondary** (cross-post):
- Hacker News "Show HN: aiDAEMON - natural language control for macOS"
- Reddit: /r/macapps, /r/MacOS, /r/apple
- Twitter/X with demo video
- Product Hunt (optional, can be later)

**Not Yet**:
- Mac App Store (impossible due to permissions)
- Homebrew Cask (can add after launch if popular)
- SetApp (can approach if successful)

### Launch Announcement Template

```markdown
# Introducing aiDAEMON: Control Your Mac with Natural Language

I built aiDAEMON because I was tired of clicking through menus and remembering keyboard shortcuts.

## What it does:
- Type "open YouTube" → YouTube opens
- Type "find tax documents" → Spotlight search, better
- Type "left half" → Window snaps to left 50%
- Type "what's my IP?" → Shows your IP address

## What makes it different:
- 100% local AI (no data sent to cloud)
- Privacy-first (no telemetry, no tracking)
- Fast (local LLaMA 3 model)
- Safe (shows what it'll do before doing it)

## Download:
[aiDAEMON v1.0.0.dmg](https://github.com/yourname/aiDAEMON/releases/latest)

macOS 13.0+, M1 or newer recommended

## Open Questions:
I'd love feedback on:
- What commands would you want?
- Is local AI worth the 4GB download?
- Would you pay for this? How much?

Built in Swift, powered by LLaMA 3. Source code [here/coming soon].
```

### Success Metrics (First Week)

**Adoption**:
- Downloads: 100+ (realistic), 500+ (success), 1000+ (viral)
- Daily active users: 20+ (realistic), 100+ (success)
- Return rate: 30%+ after 7 days

**Engagement**:
- GitHub stars: 50+ (realistic), 200+ (success)
- Hacker News points: 50+ (realistic), 200+ (front page)
- Comments/issues: Active discussion

**Quality**:
- Crash rate: <2%
- Critical bugs: 0
- High-priority bugs: <3

**Sentiment**:
- Positive feedback: 60%+
- Negative feedback: <20%
- Constructive feedback: Welcome

### Failure Scenarios & Mitigation

**Scenario 1: Critical Bug Found Day 1**
- Response: Pull download link immediately
- Fix within 24 hours
- Push v1.0.1 with fix
- Announce: "We found a critical bug, please update"
- Learn: Improve testing process

**Scenario 2: Very Low Adoption (<50 downloads)**
- Response: Analyze why (bad positioning? wrong audience? timing?)
- Iterate: Improve website, demos, messaging
- Re-launch: Post again with improvements
- Learn: May need to pivot or add features

**Scenario 3: High Crash Rate (>10%)**
- Response: Immediately investigate top crashes
- Push hotfix if possible
- If unfixable quickly: Roll back, extend beta
- Learn: Need more testing on varied systems

**Scenario 4: Gatekeeper/Security Issues**
- Response: Verify code signing and notarization
- If valid: User education (how to approve)
- If invalid: Fix and re-release
- Learn: Test on more strict security settings

---

## RECRUITMENT & ADVERTISING STRATEGY

### Where to Find Alpha Testers (5-10 people)

**Goal**: Close friends, colleagues who will give honest feedback

**Free Methods** (Use these):

1. **Your Personal Network**
   - Text/email 10-15 friends who use Macs
   - Message: "I built something, want to try it? It's rough but I need feedback."
   - Best if they're in tech, design, or heavy Mac users
   - **Cost**: Free
   - **Time**: 30 minutes

2. **Twitter/X - Direct Outreach**
   - Tweet: "Built a macOS app that lets you control your Mac with natural language. Looking for 5 Mac users to alpha test. DM if interested."
   - DM people who engage with your tweet
   - Look for people who tweet about: #macOS, productivity tools, AI
   - **Cost**: Free
   - **Time**: 1-2 hours

3. **LinkedIn**
   - Post to your network about looking for alpha testers
   - Target: Developers, designers, product managers
   - Message: Professional but casual
   - **Cost**: Free
   - **Time**: 30 minutes

4. **Local Tech Meetups** (if you attend any)
   - Mention you're looking for testers
   - Hand out your email/contact
   - **Cost**: Free (if you already attend)
   - **Time**: During next meetup

5. **Your Company/School** (if applicable)
   - Slack message: "Built a side project, need alpha testers"
   - Post in #random or #general
   - **Cost**: Free
   - **Time**: 15 minutes

**What NOT to do for Alpha**:
- ❌ Post on Reddit (too public, you'll get more than you need)
- ❌ Post on Hacker News (save for beta or launch)
- ❌ Cold email strangers (waste of time)
- ❌ Paid ads (unnecessary at this stage)

**Success Target**: 5-10 testers who actually install and try it

---

### Where to Find Beta Testers (20-50 people)

**Goal**: Broader audience, mix of technical and non-technical

**Free Methods** (Primary):

1. **Reddit - Targeted Subreddits**

   **Best Subreddits**:
   - r/macapps (~150k members) - Post: "I built [app], looking for beta testers"
   - r/MacOS (~500k members) - Post: "[Beta] New macOS automation tool"
   - r/SideProject (~300k members) - Post: "Built a local AI control system for macOS"
   - r/LocalLLaMA (~200k members) - Post: "Built a macOS app powered by local LLaMA 3"
   - r/productivity (~2M members) - Post: "Beta testing macOS productivity tool"

   **Posting Strategy**:
   ```markdown
   Title: [Beta Testing] aiDAEMON - Control your Mac with natural language (100% local AI)

   Hey r/macapps! I built a tool that lets you control your Mac by typing what you want in plain English.

   Examples:
   - "open youtube" → opens YouTube
   - "find tax documents" → searches files
   - "left half" → resizes window

   What's different:
   - 100% local AI (LLaMA 3, no cloud)
   - Privacy-first (no telemetry)
   - Works offline

   Looking for 20-30 beta testers (macOS 13+, M1+ recommended).

   Interested? Fill out this form: [Google Form link]

   Or download directly: [GitHub Release link]

   Feedback welcome! This is early beta.
   ```

   **Rules to Follow**:
   - Read subreddit rules first (some don't allow beta posts)
   - Don't spam multiple subs same day (space out by 24 hours)
   - Engage with comments (respond to questions)
   - **Cost**: Free
   - **Time**: 2-3 hours (writing + engagement)

2. **Hacker News - Ask HN**

   Post as "Ask HN: Looking for beta testers for local AI macOS tool"

   ```
   I built aiDAEMON, a macOS app that interprets natural language commands using local AI (LLaMA 3).

   Instead of clicking through menus or remembering shortcuts, you type what you want:
   - "open youtube"
   - "find tax docs from 2024"
   - "resize window to left half"

   Privacy-first: 100% local processing, no data leaves your Mac.

   Looking for 20-30 beta testers. macOS 13+, M1+ recommended (4GB model download).

   Beta link: [GitHub Releases]
   Feedback: [GitHub Issues or Google Form]

   Questions:
   1. Is 4GB local model too big?
   2. What commands would you want?
   3. Would you use this daily?
   ```

   **Timing**: Post Tuesday-Thursday, 8-10am PT (best HN traffic)
   **Cost**: Free
   **Time**: 1 hour to write, 4-6 hours to engage with comments

3. **Twitter/X - Public Thread**

   Create a demo video first (30-60 seconds):
   - Screen recording of you using the app
   - Show 4-5 commands working
   - Use QuickTime or screen recording tool
   - Upload to Twitter directly or YouTube unlisted

   **Tweet Thread**:
   ```
   I spent 2 months building aiDAEMON - control your Mac with natural language, powered by local AI. 🧵

   [1/6] Instead of clicking menus, just type what you want:
   • "open youtube"
   • "find my tax docs"
   • "left half"
   [demo video]

   [2/6] What makes it different:
   100% local AI (LLaMA 3)
   No cloud, no API calls
   Your data never leaves your Mac

   [3/6] It's built in Swift, uses Accessibility API for window control, and runs LLaMA 3 locally (~4GB)

   Privacy-first. Fast. Offline.

   [4/6] Looking for 20-30 beta testers to try it before public launch.

   macOS 13+, M1+ recommended

   [5/6] Interested?
   Download: [link]
   Feedback: [link]

   It's rough but functional. Your feedback will shape v1.0.

   [6/6] Why I built this:
   Siri sucks. Shortcuts are clunky. I wanted natural language that actually works.

   RT if you want more local AI tools like this. 🙏
   ```

   **Hashtags**: #macOS #LocalAI #Privacy #ProductivityTools
   **Tag**: Relevant accounts (@viticci, @gruber, etc. - but don't spam)
   **Cost**: Free
   **Time**: 1-2 hours to create, ongoing engagement

4. **Product Hunt - Ship Page** (Optional)

   Create a "Coming Soon" page for free
   - Collects email signups
   - Good for beta interest
   - Can convert to launch later

   **Steps**:
   1. Go to producthunt.com/ship
   2. Create free Ship page
   3. Add description, screenshots
   4. Share link on Twitter, Reddit
   5. Emails go to you for beta invites

   **Cost**: Free (Ship page), $80+ for featured launch (skip for now)
   **Time**: 1 hour setup

5. **Discord/Slack Communities**

   **Communities to Join** (all free):
   - Mac Power Users Discord
   - /r/macOS Discord
   - Indie Hackers Slack
   - ProductHunt Ship Discord
   - Local LLaMA Discord

   **Strategy**:
   - Join and lurk for 1-2 weeks first (don't spam immediately)
   - Engage authentically
   - When appropriate, mention you're looking for testers
   - Share in #promote or #show-and-tell channels

   **Cost**: Free
   **Time**: 1-2 hours/week engagement

**Paid Methods** (Optional, not recommended yet):

- **BetaList** ($129 one-time) - Gets you in front of early adopters
- **Twitter Ads** ($50-100) - Promote beta announcement tweet
- **Product Hunt Featured** ($80-300) - Save for actual launch

**Recommendation**: Stick with free methods for beta. You'll get enough testers.

**Success Target**: 20-50 beta signups, 15-30 active testers

---

### Where to Launch Publicly (100-1000+ users)

**Free Methods** (All of these):

1. **Hacker News - Show HN**

   **Title Format**:
   - "Show HN: aiDAEMON - Control Your Mac with Natural Language (Local AI)"
   - Keep under 80 characters
   - Mention key differentiator (Local AI / Privacy-first)

   **Submission Tips**:
   - Post Tuesday-Thursday, 8-10am PT
   - Upvote immediately (ask 2-3 friends to upvote in first 5 min)
   - Engage with ALL comments for first 6 hours
   - Be humble, accept criticism
   - Explain technical choices
   - If it doesn't get traction, you can try again in 2+ weeks with improvements

   **Expected Results**:
   - Good post: 50-150 points, 30-80 comments
   - Great post: 200-400 points, front page for 4-8 hours
   - Viral post: 500+ points, #1 for a day

   **Cost**: Free
   **Time**: 8-12 hours of engagement on launch day

2. **Reddit - Multiple Subreddits**

   **Primary Subreddits** (post to all, space out by 12-24 hours):
   - r/macapps (150k) - Best fit
   - r/MacOS (500k) - Larger audience
   - r/apple (4M) - Strict rules, check first
   - r/LocalLLaMA (200k) - AI enthusiasts
   - r/productivity (2M) - Broad appeal
   - r/SideProject (300k) - Indie makers

   **Title Format**:
   "[Open Source] aiDAEMON - Control macOS with natural language, powered by local LLaMA 3"

   **Post Template**:
   ```markdown
   I built aiDAEMON because I was tired of clicking through macOS menus.

   **What it does:**
   Type natural language → Mac does it
   - "open youtube" → opens YouTube
   - "find tax documents from 2024" → Spotlight search
   - "left half" → window management

   **What makes it different:**
   - 100% local AI (LLaMA 3, no cloud)
   - Privacy-first (no telemetry, no tracking)
   - Free and [open source if true]
   - Works offline

   **Download:** [GitHub Releases link]
   **Docs:** [Link]
   **Source:** [GitHub link if open source]

   Took 2 months to build. Your feedback welcome!

   Demo video: [link]
   ```

   **Expected Results per subreddit**:
   - 50-200 upvotes
   - 10-40 comments
   - 20-100 downloads from each

   **Cost**: Free
   **Time**: 2-3 hours writing + 6-8 hours engaging

3. **Twitter/X - Launch Thread**

   **Requirements**:
   - Demo video (60-90 seconds, polished)
   - Screenshots
   - GIFs of key features
   - Website/landing page

   **Thread Structure** (8-10 tweets):
   ```
   [1/10] Launching aiDAEMON today 🚀

   After 2 months of building, I'm releasing a macOS app that lets you control your computer with natural language.

   100% local AI. Privacy-first. Free.

   [Demo video]

   [2/10] The problem:
   - Siri requires internet
   - Shortcuts are clunky
   - Keyboard shortcuts are hard to remember
   - Clicking through menus is slow

   I wanted: just type what I want, Mac does it.

   [3/10] How it works:
   - Global hotkey (Cmd+Shift+Space)
   - Type command in plain English
   - Local AI (LLaMA 3) interprets it
   - Shows what it'll do
   - You approve → it executes

   [Screenshot]

   [4/10] Examples:
   "open youtube" → browser opens
   "find my screenshots from today" → files appear
   "left half" → window resizes
   "what's my IP?" → shows IP
   "empty trash" → empties after confirmation

   [GIF demo]

   [5/10] Privacy:
   - Local LLaMA 3 model (~4GB)
   - No cloud, no API calls
   - No telemetry, no tracking
   - Your data never leaves your Mac

   This was non-negotiable.

   [6/10] Tech stack:
   - Swift + SwiftUI (native macOS)
   - llama.cpp (local inference)
   - Accessibility API (window control)
   - ~4GB model download

   [If open source:] Fully open source (MIT license)

   [7/10] Why local AI?
   - Privacy (commands can reveal sensitive info)
   - Speed (no network latency)
   - Reliability (works offline)
   - Cost (no API fees)

   Trade-off: 4GB download. Worth it?

   [8/10] Download:
   🔗 [website link or GitHub]

   macOS 13.0+
   M1 or newer recommended
   Free, [open source if true]

   [9/10] Feedback wanted:
   - What commands would you add?
   - Is 4GB too big?
   - Should this have voice input?
   - Would you pay for premium features?

   GitHub Issues: [link]

   [10/10] This started as a weekend project.

   2 months later, I use it 50+ times/day.

   If you like local AI, privacy-first tools, or just cool Mac apps - give it a try.

   RT to spread the word 🙏

   [link]
   ```

   **Amplification**:
   - Ask friends to RT
   - Tag relevant accounts (1-2 max, don't spam)
   - Cross-post to LinkedIn
   - Post in relevant Discord/Slack communities

   **Cost**: Free
   **Time**: 3-4 hours to create content, ongoing engagement

4. **Product Hunt**

   **When to Launch**: 1-2 weeks AFTER initial launch
   - Gives you time to fix any critical bugs
   - Collect initial testimonials
   - Refine messaging based on feedback

   **Requirements**:
   - Tagline (60 chars): "Control your Mac with natural language, powered by local AI"
   - Description (260 chars)
   - Gallery images (5-8 screenshots/GIFs)
   - Maker video (optional but recommended)
   - First comment explaining the product

   **Launch Strategy**:
   - Launch on Tuesday-Thursday (best days)
   - Submit at 12:01am PT (start of day)
   - Get 5-10 friends to upvote in first hour
   - Respond to ALL comments
   - Share PH link on Twitter, Reddit

   **Expected Results**:
   - Average: 50-150 upvotes, #5-20 of day
   - Good: 200-400 upvotes, #3-10 of day
   - Great: 500+ upvotes, top 3, Product of the Day

   **Cost**: Free (basic), $80-300 (promoted, skip this)
   **Time**: 4 hours prep, 12 hours engagement on launch day

5. **Tech Blogs/Press** (Reach out AFTER launch if traction)

   **Who to Contact** (if you get traction first):
   - MacStories (federico@macstories.net) - Email with demo
   - 9to5Mac (tips@9to5mac.com) - News tip format
   - The Verge - Use their tip form
   - iMore - Similar to 9to5Mac

   **When to Reach Out**:
   - ONLY if you hit front page of HN
   - OR if Product Hunt Product of the Day
   - OR if 500+ downloads in first week

   **Email Template**:
   ```
   Subject: New macOS app: Local AI for system control (100% privacy-first)

   Hi [Name],

   I'm [Your Name], and I just launched aiDAEMON - a macOS app that lets users control their computer with natural language using local AI.

   What makes it newsworthy:
   - 100% local AI (LLaMA 3) - no cloud, privacy-first
   - Built in Swift, native macOS
   - [Open source if true]
   - Hit [Hacker News front page / Product Hunt #1]

   It's a response to Siri requiring internet and Shortcuts being clunky.

   Demo video: [link]
   Download: [link]
   Press kit: [if you make one]

   Happy to answer questions or provide a demo.

   Best,
   [Your Name]
   ```

   **Don't spam**:
   - Only reach out if you have traction
   - Personalize each email
   - Respect if they don't respond

   **Cost**: Free
   **Time**: 1-2 hours

6. **YouTube Tech Reviewers** (Long shot, try if successful)

   **Who to Contact** (after 1000+ downloads):
   - Snazzy Labs (Mac content)
   - MKBHD (if it goes viral)
   - Quinn Nelson (Snazzy Labs)
   - iJustine (casual Mac user audience)

   **How**:
   - Email or Twitter DM
   - "Built a Mac app, thought you might find it interesting"
   - Send demo video
   - No pressure

   **Expected Response Rate**: 5-10%
   **If they cover it**: Huge boost (10k+ downloads possible)

7. **Indie Hacker Communities**

   **Free Communities**:
   - IndieHackers.com - Post in "Show IH"
   - Makerlog - Daily updates
   - BetaPage - Free listing
   - LaunchingNext - Free listing

   **Strategy**:
   - Post launch announcement
   - Share journey/build story
   - Engage with community
   - These bring modest traffic but good feedback

   **Cost**: Free
   **Time**: 2-3 hours across platforms

---

### Timeline for Advertising

**Alpha Stage** (Week 5):
- Monday: Text/email 10 friends
- Tuesday: Tweet about looking for testers
- Wednesday: Post in work Slack/Discord
- **Goal**: 5-10 testers by end of week

**Beta Stage** (Week 7):
- Monday: Post to r/macapps
- Tuesday: Post to r/MacOS (24 hours after Reddit 1)
- Wednesday: Ask HN post
- Thursday: Tweet beta announcement with demo video
- Friday: Post to r/LocalLLaMA
- **Goal**: 20-50 signups, 15-30 active testers

**Public Launch** (Week 10):
- **T-7 days**: Prepare all content (videos, screenshots, posts)
- **T-3 days**: Pre-write all posts in drafts
- **T-1 day**: Final testing, queue posts

- **Launch Day (Tuesday, 8am PT)**:
  - 8:00am: Submit to Hacker News
  - 8:15am: Post Twitter thread
  - 8:30am: Post to r/macapps
  - 9:00am: Email beta testers
  - 10:00am: Post to r/MacOS
  - 11:00am: Post to r/productivity
  - 1:00pm: Post to other subreddits
  - All day: Engage with comments/questions

- **T+1 Week**: Product Hunt launch
- **T+2 Weeks**: Reach out to press if traction

---

### Budget Breakdown

**If you spend $0** (recommended for MVP):
- Personal network (alpha): Free
- Reddit posts: Free
- Hacker News: Free
- Twitter: Free
- Discord communities: Free
- **Total spend**: $0
- **Expected reach**: 500-2,000 people
- **Expected downloads**: 100-500

**If you spend $100-200** (optional):
- Everything above: $0
- Product Hunt promoted: $80
- Twitter ad for demo video: $50-100
- **Total spend**: $130-180
- **Expected reach**: 2,000-5,000 people
- **Expected downloads**: 300-1,000

**If you spend $500+** (not recommended for MVP):
- BetaList: $129
- Product Hunt promoted: $80
- Twitter ads: $200
- Reddit ads: $100+
- **Total spend**: $500+
- **Expected reach**: 5,000-10,000
- **Diminishing returns** - free methods work fine

**Recommendation**: Spend $0 for alpha/beta. Spend $0-80 for public launch (optional PH promoted). Let quality drive organic growth.

---

### Content to Prepare

**For Beta**:
- [ ] 30-second demo video (screen recording)
- [ ] 3-5 screenshots
- [ ] Google Form for tester signup
- [ ] Installation instructions PDF
- [ ] Beta announcement post (Reddit/HN/Twitter)

**For Public Launch**:
- [ ] 60-90 second polished demo video
- [ ] 5-8 high-quality screenshots
- [ ] 2-3 GIFs of key features
- [ ] Landing page (website)
- [ ] GitHub README with clear instructions
- [ ] Press kit (if reaching out to press)
- [ ] Launch announcement (blog post style)
- [ ] Twitter thread (pre-written)
- [ ] Reddit posts (customized for each subreddit)
- [ ] Hacker News post
- [ ] Product Hunt submission (draft)

**Tools** (all free):
- Screen recording: QuickTime (built-in macOS)
- Video editing: iMovie (free) or DaVinci Resolve (free)
- GIF creation: Gifski (free Mac app)
- Screenshots: Cmd+Shift+4 (built-in)
- Landing page: GitHub Pages (free) or Carrd ($19/year)

---

### Anti-Patterns (Don't Do This)

❌ **Spam**:
- Don't post to same subreddit twice
- Don't post to 10 subreddits same day
- Don't DM strangers unsolicited

❌ **Overhype**:
- Don't claim "revolutionary" or "game-changing"
- Don't compare to Siri/Shortcuts unless backed up
- Don't promise features you haven't built

❌ **Paid Ads Too Early**:
- Don't run ads before product-market fit
- Don't spend money before free methods proven
- Don't boost social posts (waste of money)

❌ **Press Too Early**:
- Don't email TechCrunch before you have traction
- Don't cold email journalists without traction
- Don't hire PR firm (way too expensive for MVP)

❌ **Launching Everywhere at Once**:
- Don't submit to 20 directories on day 1
- Don't cross-post identical content everywhere
- Space out launches (HN, then PH, etc.)

✅ **Do This Instead**:
- Ship to close friends first
- Get feedback and improve
- Build in public (share journey)
- Let quality speak for itself
- Engage authentically
- Be helpful in communities before asking for help

---

## POST-LAUNCH: ONGOING RELEASES

### Versioning Scheme

**Semantic Versioning**: `MAJOR.MINOR.PATCH`

- **MAJOR** (1.x.x → 2.x.x): Breaking changes, major features
- **MINOR** (1.0.x → 1.1.x): New features, backward compatible
- **PATCH** (1.0.0 → 1.0.1): Bug fixes, minor improvements

**Examples**:
- `1.0.0` - Initial public release
- `1.0.1` - First bug fix patch
- `1.1.0` - Added voice input
- `2.0.0` - Complete redesign or architecture change

### Release Cadence

**Patch Releases** (1.0.x):
- As needed for critical bugs (within 24-48 hours)
- Bi-weekly for minor bugs (if accumulated)
- Changelog: List of bugs fixed

**Minor Releases** (1.x.0):
- Every 1-2 months
- Include new features from roadmap
- Beta test for 1 week before release
- Changelog: New features, improvements, bug fixes

**Major Releases** (x.0.0):
- Yearly (or when justified)
- Significant new capabilities
- Extended beta period (2-4 weeks)
- Changelog: Major changes, migration guide

### Update Rollout Strategy

**Sparkle Auto-Updates**:
- Check for updates daily (can be disabled)
- Show release notes before update
- Download in background
- Prompt user to install
- Option to skip version

**Staged Rollout** (for major updates):
- Day 1: 10% of users
- Day 2: 25% of users
- Day 3: 50% of users
- Day 5: 100% of users
- Allows catching issues before full rollout

**Hotfix Fast-Track**:
- Critical bugs bypass staged rollout
- 100% of users immediately
- Mark as "critical update" in release notes

---

## SHIPPING GATES

### What Must Exist Before ANY Shipping

**Minimum Requirements**:
- [ ] App builds and runs without crashing
- [ ] Core functionality works (LLM parsing + basic execution)
- [ ] Permissions can be granted
- [ ] No known data loss or security bugs
- [ ] Code signed and notarized
- [ ] Some form of documentation exists

**If any of these are missing, DO NOT SHIP.**

### What Can Ship Incomplete

**Acceptable for v1.0**:
- Incomplete command coverage (start with 15-20 commands)
- No voice input (marked as "coming soon")
- No cloud features (local-only is the goal)
- Basic UI (polish later)
- Incomplete documentation (can expand post-launch)
- No analytics (privacy-first approach)

**Not Acceptable for v1.0**:
- Crashes on normal use
- Data loss bugs
- Security vulnerabilities
- Broken permissions flow
- Non-functional core features
- Unnotarized app (Gatekeeper will block)

---

## SHIPPING CHECKLIST

Before launching each stage, verify:

### Alpha Checklist
- [ ] M001-M030 complete
- [ ] App is code signed
- [ ] Tested on at least 2 different Macs
- [ ] Known bugs documented
- [ ] Feedback form created
- [ ] Testers identified and contacted

### Beta Checklist
- [ ] M001-M050 complete
- [ ] App is code signed AND notarized
- [ ] Tested on 3+ different Macs, 2+ macOS versions
- [ ] Auto-update mechanism tested
- [ ] Public download link works
- [ ] Documentation at least 80% complete
- [ ] Beta signup form created

### Public Launch Checklist
- [ ] M001-M074 complete
- [ ] All security checks passed (M064)
- [ ] Performance benchmarks met (M062)
- [ ] Beta testing successful (NPS >30)
- [ ] Website live with download link
- [ ] Privacy policy published
- [ ] Documentation complete
- [ ] Announcement content prepared
- [ ] Support channel ready (GitHub Issues)
- [ ] Monitoring in place (crash reports if enabled)
- [ ] Rollback plan if critical bug found

---

## COMMUNICATION PLAN

### Target Audiences

**Primary**: Mac power users (developers, designers, productivity enthusiasts)
**Secondary**: Early adopters of AI tools
**Tertiary**: General Mac users (later, after refinement)

### Messaging Pillars

1. **Privacy-First**: "Your data never leaves your Mac"
2. **Fast & Local**: "No API calls, instant responses"
3. **Transparent**: "See what it'll do before it does it"
4. **Powerful**: "Natural language for power users"

### Launch Channels

**Hacker News**:
- Best for developer audience
- Post as "Show HN: [title]"
- Engage in comments all day
- Demo video helps

**Reddit**:
- /r/macapps - primary
- /r/MacOS - secondary
- /r/apple - if gaining traction
- /r/LocalLLaMA - for AI community
- Follow subreddit rules (no spam)

**Twitter/X**:
- Thread with screenshots/video
- Tag relevant accounts (@gruber, @viticci, etc.)
- Use hashtags: #macOS #productivity #AI

**Product Hunt** (optional):
- Can launch 1-2 weeks after initial release
- Requires more prep (graphics, video)
- Good for broader visibility

**Tech Press** (if interest):
- Don't pitch initially
- If traction: reach out to MacStories, 9to5Mac
- Focus on privacy angle

---

## SUPPORT STRATEGY

### Support Channels

**Primary**: GitHub Issues
- Fastest response
- Public visibility (helps others)
- Can track bugs systematically

**Secondary**: Email (if set up)
- For private issues
- Slower response time
- Forward to GitHub Issues if appropriate

**Not Providing** (at launch):
- Discord/Slack (too much overhead)
- Phone support (not realistic)
- Live chat (too demanding)

### Response Time Goals

- Critical bugs: <24 hours
- High-priority: <3 days
- Medium: <1 week
- Low/feature requests: Best effort

### Issue Triage

**Critical** (fix immediately):
- App crashes on launch
- Data loss
- Security vulnerability
- Cannot grant permissions (blocking)

**High** (fix in next patch):
- Feature doesn't work as documented
- Frequent crashes in specific scenario
- Performance regression

**Medium** (fix in next minor release):
- UI glitches
- Missing convenience features
- Confusing error messages

**Low** (backlog):
- Feature requests
- Nice-to-have improvements
- Edge cases

---

## SUCCESS CRITERIA

### Definition of Success (v1.0)

**Minimum Success**:
- 100+ downloads
- 20+ daily active users after 30 days
- <5% crash rate
- Positive feedback outweighs negative
- 1-2 feature requests indicate real usage

**Solid Success**:
- 500+ downloads
- 100+ daily active users after 30 days
- <2% crash rate
- NPS >40
- Community contributors (issues, PRs)
- Some press coverage

**Viral Success**:
- 2000+ downloads
- 500+ daily active users
- Hacker News front page
- Press coverage (MacStories, 9to5Mac)
- Monetization interest

### When to Call It

**Pivot If**:
- <50 downloads after 2 weeks (no interest)
- <10% retention after 7 days (not useful)
- Overwhelmingly negative feedback (wrong approach)

**Double Down If**:
- >500 downloads in first week (demand exists)
- >50% retention after 30 days (sticky product)
- Active community engagement (issues, discussions)
- Press interest

---

## FUTURE ROADMAP (Post-v1.0)

**v1.1** (1-2 months after launch):
- Voice input (Phase 13)
- Custom aliases improvements
- More command types based on feedback
- UI polish from user feedback

**v1.2** (3-4 months):
- Multi-step command workflows
- Plugin system (if community interest)
- Performance optimizations

**v2.0** (6-12 months):
- Vision features (screen understanding)
- Cloud sync (optional)
- Advanced features based on usage data

**Monetization** (when?):
- Start free, always have free tier
- Potential paid features:
  - Cloud vision API access
  - Advanced workflows
  - Team/enterprise features
  - Premium support
- Consider after 1000+ active users

---

## LESSONS TO CAPTURE

After each release stage, document:

1. What went well
2. What went poorly
3. What we'd do differently
4. Unexpected learnings
5. User feedback themes

Store in: `docs/retrospectives/[stage]-[date].md`

---

**This document evolves with the project. Update after each release stage.**

---

**You are now ready to begin development.**

Start with: `manual-actions.md` for immediate setup tasks.
Then: `03-MILESTONES.md` for milestone M001.
