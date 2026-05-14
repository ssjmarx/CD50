# Current Goal

**Last Updated:** 2026-05-14  
**Status:** Active — Plan 15 Phase 2 (Polybius Character) + preparing itch.io demo for public launch

---

## Active Priority: Ship the Demo (May 2026)

The project has pivoted from building new games to shipping what we have. The immediate goal is a public itch.io demo and a Steam "Coming Soon" page by end of May 2026.

**Full deadline schedule:** `memory-bank/06 - Deadlines.md`

### Completed This Phase (May 6–14)
- ✅ Steamworks: Fee paid, App ID created, tax/bank info submitted — awaiting identity verification
- ✅ itch.io: Game page created (private), build uploaded and tested at 60fps on T480 browser target
- ✅ Butler pipeline: `deploy.sh` fully operational (export → zip → push)
- ✅ Web performance: All 9 optimizations implemented and verified

### Current Focus (May 14–31)
- **Plan 15 Phase 2:** Polybius Character — currently drawing facial frames
- **Public itch launch:** Flip page to public once Polybius is integrated
- **Steam Coming Soon:** Live as soon as identity verification completes

---

## Near-Term Plans

### Plan 14 — Arcade Juice Part 1: Custom CRT Shader
**Status:** COMPLETE  
**Timeline:** Completed May 6, 2026  

### Plan 15 — Arcade Orchestrator Juice
**Status:** IN PROGRESS  
**Timeline:** Before itch public launch (late May)  

**Phases 1, 1.5, 1.7, 1.8 COMPLETE:**
- Phase 1: All games renamed (copyright-safe bootleg names), first itch.io export
- Phase 1.5: Bug Blaster 3×18 formation, Block Drop color/juice rework, Brick Breaker flag coloring + wider layout, Space Rocks ship+UFO redesign, Paddle Ball checkerboard center line
- Phase 1.7: Music system (MusicPlayer + MusicTrack resources), flag palette overhaul, Brick Breaker random launch angle
- Phase 1.8: All 9 web perf optimizations — 60fps on T480 browser target. SoundBank autoload, flag palette web fix.

**Phase 2 IN PROGRESS — Polybius Character:**
- Step 2a ✅: `polybius_face.gd`, `polybius_eyes.gd`, `polybius_mouth.gd`, `polybius_face.tscn` created
- **Step 2b (ACTIVE):** Drawing facial frames — filling in point data for expression/mouth resources
- Remaining: voice lines, typewriter text, animations, AO integration (steps 2c–2j)

### Plan 16 — Cambrian Remix Explosion
**Status:** Not started  
**Timeline:** June–July 2026 (shifted from original mid-May target)  
**Scope:** 3 new games (Bug Drop, Space Bugs, Planetary Attack!), 5 Balatro-like modifiers, semi-random playlist, local high score persistence

### Plan 17 — Arcade Juice Post-Launch
**Status:** Not started  
**Timeline:** After itch launch  
**Scope:** VRAM Boot Screen, Attract Mode System, Coin Drop Boot Sequence

---

## Mid-Term (June–October 2026)

### June–July — Vertical Slice Content
- Expand modifier system beyond the initial 5
- Score progression / ranking system (10k → 1m → 1b)
- Polish core loop to 20–30 second snappy runs
- Fill remaining 4 remix slots from Plan 16

### August 1–17 — Steamworks Integration
- GodotSteam integration
- Stats, leaderboards, achievements
- In-game UI for all of the above

### August 18–31 — Next Fest Registration
- Register for October Next Fest
- Finalize store page, capsule images, trailer

### September — Steam Demo Build + Press
- Steam demo build (with Steam backend features)
- Submit for review by Sep 21
- Press preview window Sep 21–30

### October — Launch + Next Fest
- Demo goes live on Steam before Oct 19
- Next Fest Oct 19–26
- Leave demo up after fest

---

## Deferred

The following plans have been **deleted** from the active pipeline:

- ~~Plan 14 — Snake + Light Cycles~~ (trail_spawner, cycle_ai, food_spawner)
- ~~Plan 15 — Qix + Xonix~~ (territory_grid, line_drawer, area_filler)

---

## Complete

| Plan | Description | Completed |
|------|-------------|-----------|
| 14 | Arcade Juice Part 1 (Custom CRT Shader, Vector Monitor, Phosphor Trails) | 2026-05-06 |
| 13 | Arcade Orchestrator (Interface Takeover, Scrolling Transitions, Fast Rules) | 2026-05-05 |