# Current Goal

**Last Updated:** 2026-05-20  
**Status:** Active — Final push to ship the itch.io demo by May 31

---

## Active Priority: Ship the Demo by May 31

The game roster is **finalized at 12 games** — no more games will be built for the demo. Only **one feature remains** (Polybius Character), then flip the itch.io page to public.

**Full deadline schedule:** `memory-bank/06 - Deadlines.md`

### Demo Game Roster — FINAL (12 games)

| Type | Games |
|------|-------|
| Remakes (5) | Paddle Ball, Brick Breaker, Space Rocks, Bug Blaster, Block Drop |
| Remixes (5) | Dogfight, Meteor Rally, Rock Breaker, Bug Drop, Space Bugs |
| Inversions (2) | Planetary Attack!, Space Rocks Inverted |

### Completed This Phase (May 6–19)
- ✅ Steamworks: Fee paid, App ID created, tax/bank info submitted — awaiting identity verification
- ✅ itch.io: Game page created (private), build uploaded and tested at 60fps on T480 browser target
- ✅ Butler pipeline: `deploy.sh` fully operational (export → zip → push)
- ✅ Web performance: All 9 optimizations implemented and verified
- ✅ Plan 16 Phase 1: 4 new games built (Bug Drop, Space Bugs, Planetary Attack!, Space Rocks Inverted)
- ✅ Karl Casey music tracks added (2 new licensed OGG + MusicTrack resources)
- ✅ New components: clear_shot_ai, cover_ai, swarm_controller_player, hit_effect, vector_thruster_exhaust, group_kill_on_signal, polybius_nose
- ✅ Game roster finalized — 12 games locked for demo
- ✅ 5 Balatro-like modifiers implemented (Shotgun Mode, Overclocked CPU, Feature Creep, Crunch Time, Scope Creep)
- ✅ Mini Progression System — SaveData autoload with high scores, modifier unlocks, JSON persistence (May 20)
- ✅ Planetary Attack Remake — scrolling playfield, camera_midpoint component, playfield_size on UGS (May 20)

### Remaining Work (May 20–31) — 1 feature, then ship

**1. Polybius Character (Plan 15 Phase 2)**
- Currently drawing facial frames (Step 2b)
- Remaining: voice lines, typewriter text, animations, AO integration (steps 2c–2j)
- Scope: run intros, taunts between games, game-over commentary

**~~2. 5 Balatro-like Modifiers~~ ✅ COMPLETE**

**~~3. Mini Progression System~~ ✅ COMPLETE** (May 20)
- `SaveData` autoload (`Scripts/Core/save_data.gd`) — JSON persistence via `user://cd50_save.json`
- Best run score gates modifier unlocks at 5 thresholds (100 → 100,000)
- Top 5 high scores with initials entry + date
- Boot screen: high score display + modifier toggle buttons
- Game over screen: initials entry + unlock notifications
- AO integration: score reporting + new high score detection

**~~4. Planetary Attack Remake~~ ✅ COMPLETE** (May 20)
- Scrolling 2× playfield (1280×720) with `camera_midpoint` component
- Player controls Mystery Ship protecting invader formation
- Opposing paddle cannons, triangle ship hunters, asteroid field
- `playfield_size` export on UGS — backward-compatible, zero change to existing games

**Then: Ship**
- Flip itch.io page from private to public
- Steam Coming Soon page live as soon as identity verification completes

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
**Status:** Planning doc complete, implementation not started  
**Timeline:** Post-demo code lock (after May 31)  
**Scope:** Foundation of the V2 Composable Architecture — CDEntity, CDGame, CDComponent2D, CDCollisionBuffer, CDGroupRegistry, CDCollisionMatrix, CDInputRouter, CDEnums, CDCollisionGroup. First of 8 V2 updates. V1 architecture moves to `Godot/v1/`.

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
