# Current Goal

**Last Updated:** 2026-05-29  
**Status:** Active — Bug Blaster 2 (Galaga) Capture Mechanics + Multi-Wave. Itch.io demo ready to ship.

---

## Active Priority: V2 Architecture Implementation

The itch.io demo is **code-locked** (12 games, all componentized). We are now building the V2 Composable Architecture for the desktop/Steam version. The itch.io demo remains on V1.

**Canonical V2 design reference:** `planning/V2 Rules.md`  
**V1 planning docs archived:** `planning/v1/` (Plans 00–18)

### V2 Implementation Schedule (8 Updates)

| # | Plan | Scope | Status |
|---|------|-------|--------|
| 1 | 19 — V2 Core Infrastructure | CDEntity, CDGame, CDComponent2D, CDCollisionBuffer, CDGroupRegistry, CDCollisionMatrix, CDInputRouter, CDEnums | ✅ Complete |
| 1b | 19.5 — V2 Object Pooling | CDObjectPool, pool-aware activate/deactivate | ✅ Complete |
| 2 | 20 — V2 Stage | CDCueCard, ScoreCard, LivesCard, TimerCard, WaveCard, Goals, CDMarks | ✅ Complete |
| 3 | 21 — V2 Brains + Legs | 14 Brains, 15 Legs, 1 Gut, WallKickResource | ✅ Complete |
| 4 | 22 — V2 Arms + Guts | 10 Arms, 15 Guts — collision response + internal state | ✅ Complete |
| 5 | 23 — V2 Spawners | CDStageTrapdoor, Point/Edge/GridTrapdoor, Spawn Arms, CDGridLayout, CDGridEquation, SafeZoneMark | ✅ Complete |
| 6 | 24 — V2 Faces, Voices, Projections & Speakers | 7 Faces, 2 Voices, 3 Speakers, 2 Projectors, 5 Directors, Triggers, Selectors, Curves, Effects, Resources | ✅ Complete |
| 7 | 25 — V2 Swarm Controllers + Galaga | All components already built in Plans 21–24; document rewritten as architectural reference | ✅ Complete |
| 8 | 26 — Block Drop V2 | Full Block Drop remake proving Pseudogrid pattern | ? Next |

### Immediate Next Step: Ship Itch.io Demo

The itch.io demo is feature-complete. All 12 games, Polybius character, 5 modifiers, and mini progression system are done. Remaining shipping tasks only:

1. Flip itch page from private to public
2. Add "Wishlist on Steam" button on the itch page
3. Add teaser line with Steam link

### After Shipping: Bug Blaster 2 (Galaga) — Capture Mechanics + Multi-Wave

Bug Blaster 2 is partially implemented with formation, swoop/dive, and shooting all functional. Remaining features:

1. **Capture ships** — Bug ship variant with AITractorBeamBrain that attempts to capture the player
2. **Capture mechanics** — Player gets captured by tractor beam, becomes prisoner; rescue the prisoner to get a dual fighter
3. **Multiple waves** — Wave progression with escalating formation sizes, dive patterns, and enemy types
4. **Bonus stages** — Optional bonus waves for extra points

All components already exist (AITractorBeamBrain, TractorBeamArm, PowerupWingmanArm, WaveCard, StageDirector). This is primarily scene assembly work.

**156 V2 scripts written so far.** Full catalogue: `memory-bank/07 - Component Catalogue V2.md`

**After Galaga:** Plan 26 — Block Drop V2 (full Block Drop remake proving Pseudogrid pattern)

### Demo Status

The itch.io demo is **feature-complete and ready to ship**. All 12 games, Polybius character (7 scripts, 5 voice lines, full AO integration), 5 Balatro-like modifiers, and mini progression system are done. Only shipping tasks remain (flip itch to public, add Steam wishlist link).

### Demo Game Roster — FINAL (12 games)

| Type | Games |
|------|-------|
| Remakes (5) | Paddle Ball, Brick Breaker, Space Rocks, Bug Blaster, Block Drop |
| Remixes (5) | Dogfight, Meteor Rally, Rock Breaker, Bug Drop, Space Bugs |
| Inversions (2) | Planetary Attack!, Space Rocks Inverted |

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

**Phase 2 COMPLETE — Polybius Character:**
- ✅ All 7 scripts written (polybius_face, polybius_eyes, polybius_mouth, polybius_nose, polybius_beat, polybius_line, polybius_phrase)
- ✅ 5 voice lines recorded (again, for_score, i_hunger, leaderboard, pathetic)
- ✅ Full AO integration (intro before first game, outro after final defeat, SubViewport slide transitions)

### Plan 16 — Cambrian Remix Explosion
**Status:** COMPLETE  
**Phase 1 Completed:** 4 new games built (Bug Drop, Space Bugs, Planetary Attack!, Space Rocks Inverted) + 7 new scripts + 12 new body scene variants + 2 new music tracks + 4 new arcade settings
**Phase 2 Modifiers COMPLETE:** 5 Balatro-like modifiers via `modifier_manager.gd`
**Phase 2 Progression COMPLETE:** SaveData autoload with high scores + modifier unlocks (May 20)
**Game roster locked:** No more games for demo. Expansion deferred to post-launch.

### Plan 17 — Arcade Juice Post-Launch
**Status:** Not started  
**Timeline:** After itch launch  
**Scope:** VRAM Boot Screen, Attract Mode System, Coin Drop Boot Sequence

### Plan 19 — V2 Core Infrastructure
**Status:** COMPLETE (May 23, 2026)  
**Scope:** Foundation of the V2 Composable Architecture — CDEntity, CDGame, CDComponent2D, CDCollisionBuffer, CDGroupRegistry, CDCollisionMatrix, CDInputRouter, CDEnums, CDCollisionGroup. All 10 scripts written. V1 architecture moves to `Godot/v1/`.

### Plan 20 — V2 Stage (Cue Cards, Goals, Marks)
**Status:** COMPLETE (May 24, 2026)  
**Scope:** CDCueCard base class, 4 Cue Cards (ScoreCard, LivesCard, TimerCard, WaveCard), 2 Goals (GroupCountGoal, ScoreThresholdGoal), 4 Marks (CDMark, CountMark, MobileMark, TimedMark). All 10 scripts written.

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
| 25 | V2 Swarm Controllers + Galaga (0 new scripts — all components already built in Plans 21–24; document rewritten as architectural reference) | 2026-05-29 |
| 24 | V2 Faces, Voices, Projections & Speakers (63 scripts — Faces, Voices, Speakers, Projectors, Directors, Curves, Triggers, Selectors, Effects, Resources) | 2026-05-29 |
| 23 | V2 Spawners (4 Trapdoors, 3 Spawn Arms, 2 Marks, 4 Resources — 14 scripts) | 2026-05-27 |
| 22 | V2 Arms + Guts (10 Arms, 15 Guts — 25 scripts) | 2026-05-26 |
| 21 | V2 Brains + Legs (14 Brains, 15 Legs, 1 Gut, WallKickResource — 31 scripts) | 2026-05-24 |
| 20 | V2 Stage (4 CueCards, 2 Goals, 4 Marks — 10 scripts) | 2026-05-24 |
| 19.5 | V2 Object Pooling (CDObjectPool) | 2026-05-24 |
| 19 | V2 Core Infrastructure (CDEntity, CDGame, CDInputRouter, etc. — 13 scripts) | 2026-05-23 |
| 18 | Planetary Attack Remake (scrolling playfield, camera_midpoint, playfield_size) | 2026-05-20 |
| 16 | Cambrian Remix Explosion (4 games, 5 modifiers, progression system) | 2026-05-20 |
| 14 | Arcade Juice Part 1 (Custom CRT Shader, Vector Monitor, Phosphor Trails) | 2026-05-06 |
| 13 | Arcade Orchestrator (Interface Takeover, Scrolling Transitions, Fast Rules) | 2026-05-05 |
