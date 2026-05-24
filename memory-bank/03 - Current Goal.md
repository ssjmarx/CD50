# Current Goal

**Last Updated:** 2026-05-23  
**Status:** Active — V2 Object Pooling (Plan 19.5)

---

## Active Priority: V2 Architecture Implementation

The itch.io demo is **code-locked** (12 games, all componentized). We are now building the V2 Composable Architecture for the desktop/Steam version. The itch.io demo remains on V1.

**Canonical V2 design reference:** `planning/V2 Rules.md`  
**V1 planning docs archived:** `planning/v1/` (Plans 00–18)

### V2 Implementation Schedule (8 Updates)

| # | Plan | Scope | Status |
|---|------|-------|--------|
| 1 | 19 — V2 Core Infrastructure | CDEntity, CDGame, CDComponent2D, CDCollisionBuffer, CDGroupRegistry, CDCollisionMatrix, CDInputRouter, CDEnums | ✅ Complete |
| 1b | 19.5 — V2 Object Pooling | CDObjectPool, pool-aware activate/deactivate | 🔲 Next |
| 2 | 20 — V2 Stage | CDCueCard, ScoreCard, LivesCard, TimerCard, WaveCard, Goals, CDMarks | 🔲 Planned |
| 3 | 21 — V2 Brains + Legs | 14 Brains, 18 Legs — complete movement catalog | 🔲 Planned |
| 4 | 22 — V2 Arms + Guts | 11 Arms, 12 Guts — collision response + internal state | 🔲 Planned |
| 5 | 23 — V2 Spawners | CDStageSpawner, Point/Edge/GridSpawner, CDGridLayout, CDSafeZone | 🔲 Planned |
| 6 | 24 — V2 Faces, Voices, Projections & Speakers | CDFace, CDFaceBinding, CDVoice, CDSpeaker, CDSoundBank, CDProjection | 🔲 Planned |
| 7 | 25 — V2 Swarm Controllers + Galaga | SwarmGridStep, Formation, Flock, Shoot controllers + Galaga proof | 🔲 Planned |
| 8 | 26 — Block Drop V2 | Full Block Drop remake proving Pseudogrid pattern | 🔲 Planned |

### Immediate Next Step: Plan 19.5 — V2 Object Pooling

Build CDObjectPool and pool-aware activate/deactivate lifecycle. CDEntity already has the DEACTIVATING→INACTIVE state machine from Plan 19; this plan adds the pool manager and spawn/return flow.

### Demo Status

The itch.io demo is code-locked at 12 games. The only unimplemented feature is the Steam wishlist link. Polybius character work (Plan 15 Phase 2) is paused — voice lines remain unrecorded but the face drawing system exists and works.

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

**Phase 2 IN PROGRESS — Polybius Character:**
- Step 2a ✅: `polybius_face.gd`, `polybius_eyes.gd`, `polybius_mouth.gd`, `polybius_nose.gd`, `polybius_face.tscn` created
- **Step 2b (ACTIVE):** Drawing facial frames — filling in point data for expression/mouth resources
- Remaining: voice lines, typewriter text, animations, AO integration (steps 2c–2j)

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

### Plan 20 — V2 Stage (Cue Cards, Goals, Interface)
**Status:** Planning doc complete, implementation not started  
**Timeline:** After Plan 19 implementation  
**Scope:** First consumers of CDGame's game bus. CDCueCard base class, 5 Cue Cards (ScoreCard, MultiplierCard, LivesCard, TimerCard, WaveCard), 4 Goals (GroupCountGoal, ScoreThresholdGoal, LivesDepletedGoal, TimerExpiredGoal). Eliminates GroupCountCard (CDGroupRegistry emits directly). Cue Cards are Controls with `is_interface` bool for optional display.

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
| 18 | Planetary Attack Remake (scrolling playfield, camera_midpoint, playfield_size) | 2026-05-20 |
| 16 | Cambrian Remix Explosion (4 games, 5 modifiers, progression system) | 2026-05-20 |
| 14 | Arcade Juice Part 1 (Custom CRT Shader, Vector Monitor, Phosphor Trails) | 2026-05-06 |
| 13 | Arcade Orchestrator (Interface Takeover, Scrolling Transitions, Fast Rules) | 2026-05-05 |
