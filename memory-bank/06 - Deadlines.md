# Deadlines: CD50 — Arcade Cabinet

**Last Updated:** 2026-05-20  
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

## Phase 1 — May 6–11 (COMPLETE)

### Steamworks
- [x] Pay the $100 fee and create the App ID
- [x] Fill in tax/bank info
- [ ] Create Coming Soon page (blocked: awaiting identity verification):
  - [ ] Short description (Balatro/WarioWare pitch)
  - [ ] Capsule images (even rough ones)
  - [ ] At least one trailer or gameplay GIF (the crossover moment)

### itch.io
- [x] Create the game page (set to private)
- [x] Decide web vs native: **Web** (HTML export)
- [x] Butler pipeline operational (`deploy.sh` — export → zip → push)
- [x] Build uploaded and tested at 60fps on T480 browser target

---

## Phase 2 — Mid–Late May (May 12–31) — SHIP THE DEMO

**Game roster FINALIZED at 12 games.** No more games will be built for the demo. **One feature remains** (Polybius), then ship.

### Demo Game Roster — FINAL

| Type | Count | Games |
|------|-------|-------|
| Remakes | 5 | Paddle Ball, Brick Breaker, Space Rocks, Bug Blaster, Block Drop |
| Remixes | 5 | Dogfight, Meteor Rally, Rock Breaker, Bug Drop, Space Bugs |
| Inversions | 2 | Planetary Attack!, Space Rocks Inverted |

### Remaining Work — 1 Feature

**1. Polybius Character (Plan 15 Phase 2)**
- [ ] Complete facial frame drawing (Step 2b — in progress)
- [ ] Record voice lines + bitcrush → export as .ogg (Step 2c)
- [ ] Implement typewriter text + voice playback sync (Step 2d)
- [ ] Implement face animations — roll up/down, quick flash (Step 2e)
- [ ] Add INTRO state to AO + face integration on run start (Step 2f)
- [ ] Add quick-comment integration on RESULT state (Step 2g)
- [ ] Add game-over integration on GAME_OVER state (Step 2h)
- [ ] Add random in-game taunt during PLAYING state (Step 2i)
- [ ] Playtest full arcade run with Polybius (Step 2j)

**~~2. 5 Balatro-like Modifiers~~ ✅ COMPLETE (May 19)**
- [x] Shotgun Mode — gun_simple fires 3 bullets with 15° spread
- [x] Overclocked CPU — all Leg components: speed × 1.25, SwarmController timing × 1.25
- [x] Feature Creep — all spawner components: entity_count × 2 (Bug Drop special-cased)
- [x] Crunch Time — lives set to 1, all score values × 3.0
- [x] Scope Creep — player health × 2 (player-only, not enemies)
- [x] ModifierManager node on AO, setup + runtime application

**~~3. Mini Progression System~~ ✅ COMPLETE (May 20)**
- [x] `best_run_score` persists across runs (JSON via `user://cd50_save.json`)
- [x] Score thresholds unlock modifiers: 100 / 1,000 / 10,000 / 50,000 / 100,000
- [x] Top 5 high scores saved with initials + date
- [x] Boot screen: high score display + modifier toggle buttons
- [x] Game over screen: initials entry + unlock notifications

### Then: Ship
- [ ] Flip itch page from private to public
- [ ] Add "Wishlist on Steam" button on the itch page
- [ ] Add teaser line: "This is just the arcade. The full game adds…" with Steam link

### Already Complete
- [x] Export web build
- [x] Upload to itch via Butler
- [x] Test web build on T480 browser target (60fps confirmed)
- [x] Plan 14 — Custom CRT Shader
- [x] Plan 16 Phase 1 — 4 new games built (Bug Drop, Space Bugs, Planetary Attack!, Space Rocks Inverted)
- [x] Game roster locked at 12 games
- [x] 5 Balatro-like modifiers implemented (Plan 16 Phase 2)
- [x] Mini progression system — SaveData autoload (Plan 16 Phase 2b)
- [x] Planetary Attack Remake — scrolling playfield + camera_midpoint (Plan 18)

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
- **Plan 16 Phase 2** — Remaining remix slots (expand roster beyond 12 for full release)
- **Plan 15 remaining** — Post-launch Polybius polish (in-game taunts, deeper commentary)

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