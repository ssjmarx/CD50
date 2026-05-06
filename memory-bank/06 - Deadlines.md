# Deadlines: CD50 — Arcade Cabinet

**Last Updated:** 2026-05-06  
**Source:** Commercial shipping schedule — itch.io demo + Steam Coming Soon + Next Fest

---

## Overview

| Phase | Timeline | Milestone |
|-------|----------|-----------|
| 1 | May 6–11 | Steamworks setup + itch.io pipeline |
| 2 | May 12–31 | Finalize arcade content + export + publish |
| 3 | June–July | Vertical slice content (modifiers + scoring) |
| 4 | August 1–17 | Steamworks integration (stats, leaderboards, achievements) |
| 5 | August 18–31 | Next Fest registration + store page finalization |
| 6 | September 1–20 | Steam demo build + submission for review |
| 7 | September 21–30 | Press preview window + bug fixes |
| 8 | October 1–18 | Final polish + demo goes live |
| 9 | October 19–26 | Next Fest live + hotfixes |

---

## Phase 1 — This Week (May 6–11)

### Steamworks
- [ ] Pay the $100 fee and create the App ID
- [ ] Fill in tax/bank info
- [ ] Create Coming Soon page:
  - [ ] Short description (Balatro/WarioWare pitch)
  - [ ] Capsule images (even rough ones)
  - [ ] At least one trailer or gameplay GIF (the crossover moment)

### itch.io
- [ ] Create the game page; set to unlisted for now
- [ ] Decide web vs native for the demo:
  - Web: HTML export + Cross-Origin Isolation
  - Native: Windows build + Butler
- [ ] Install Butler and do a test push of a tiny Godot project to confirm the pipeline works

---

## Phase 2 — Mid–Late May (May 12–31)

### Finalize Arcade Mode Content
- [ ] Export web and/or Windows builds
- [ ] Upload to itch via Butler
- [ ] Test web build on a low-end machine if possible

### itch.io Page Polish
- [ ] Add "Wishlist on Steam" button on the itch page:
  - Big CTA above the download/play button
  - Use Steam widget or link to Coming Soon page

### Optional (This Phase)
- [ ] Implement simple local high scores
- [ ] Add teaser line: "This is just the arcade. The full game adds…" with Steam link

### Dev Plans Targeting This Phase
- **Plan 14** — Arcade Juice & Attract Mode (pared down to essentials)
- **Plan 15** — Arcade Orchestrator Juice (win/loss effects, rapid scoring juice)

**Note:** Can safely ship the itch demo without online leaderboards and without Steamworks integration. Keep it simple.

---

## Phase 3 — June–July 2026

### Vertical Slice Content
Focus on game content, not platforms.

- [ ] Design and implement the Balatro-style modifier system:
  - Double bullets, double enemies, speed multiplier, score multipliers, etc.
- [ ] Build the score progression / ranking system:
  - Scoring thresholds (10k → 1m → 1b)
  - Unlockable modifiers, playlists, lore bits
- [ ] Polish the core loop so a typical run is 20–30 seconds and feels snappy

### Dev Plans Targeting This Phase
- **Plan 16** — Cambrian Remix Explosion (push to 5 remakes + 15 originals/remixes)

---

## Phase 4 — August 1–17, 2026

### Steamworks Integration
- [ ] Integrate GodotSteam (or Steam API addon) into the Godot project
- [ ] Define Stats in Steamworks backend:
  - e.g., HighestScore, TotalRuns, MaxMultiplier
- [ ] Define Leaderboards:
  - One per "rank tier" or one global board with multiple sorts
- [ ] Define Achievements:
  - "Broke 10k", "Broke 1m", "Broke 1b", "Unlocked all modifiers", etc.
- [ ] Implement in-game:
  - Uploading stats/leaderboards on run end
  - Showing leaderboards in ranking UI
  - Triggering achievements when conditions are met

**Key:** Must publish stats/achievements in Steamworks for them to be visible to the API.

---

## Phase 5 — August 18–31, 2026

### Next Fest Registration
- [ ] Register for October Next Fest via Steamworks event page
- [ ] Finalize store page and capsule images:
  - Valve uses these for marketing materials (trailer, genre hubs, etc.)
- [ ] Upload Next Fest trailer (must be up before Sep 7 for official pull)

---

## Phase 6 — September 1–20, 2026

### Steam Demo Build
- [ ] Create Steam demo build:
  - Same base as itch vertical slice
  - Steam stats/leaderboards/achievements enabled
  - Optional: "Demo" splash screen noting progress doesn't carry over
- [ ] Set up demo branch / depot in Steamworks:
  - Easiest: same App ID, separate depot/branch for demo
  - Alternative: separate demo App ID under a parent
- [ ] Submit by Sep 21:
  - Demo build for review
  - Store page for review (if not already approved)

---

## Phase 7 — September 21–30, 2026

### Press Preview Window
- [ ] If in Press Preview: monitor press coverage, fix major issues
- [ ] If not in Press Preview: submit everything by Oct 5 deadline

---

## Phase 8 — October 1–18, 2026

### Launch Prep
- [ ] Final polish and bug fixing
- [ ] Set demo to live on Steam before Oct 19, 10am PDT
- [ ] Ensure itch page clearly links to Steam page and demo

---

## Phase 9 — October 19–26, 2026

### Next Fest Live
- [ ] Be available to fix last-minute issues
- [ ] Optional: small mid-fest update if something critical appears
- After Oct 26: leave the demo up (Valve explicitly encourages this)