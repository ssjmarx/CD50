# Current Goal: Space Invaders & Tetris (Plan 07)

**Status:** 🔧 In Progress — components built, game scenes not yet composed  
**Active Plan:** `planning/07 - Space Invaders and Tetris.md`  
**Started:** 2026-04-19

---

## Plan 07 Progress

### ✅ Phase 1 — Grid Foundation (Complete)
- [x] `grid_basic` (Flow) — grid coordinate system + active occupancy
- [x] `grid_movement` (Leg) — discrete snap movement with hop_delay, ratchets, hard drop
- [x] `grid_rotation` (Leg) — discrete rotation steps
- [x] Debug test scene: `Scenes/Debug/grid_test.tscn`

### ✅ Phase 2 — Space Invaders Components (Complete)
- [x] `swarm_controller` (Flow) — swarm orchestration with signal bus
- [x] `swarm_ai` (Brain) — antenna brain for swarm commands
- [x] `shoot_ai_swarm` (Brain) — formation-aware edge shooting

### ✅ Phase 3 — Tetris Components (Complete)
- [x] `falling_ai` (Brain) — gravity as input source (emits input_move DOWN on timer)
- [x] `tetromino_formation` (Leg) — multi-cell shape management, lock delay, cell registration
- [x] `tetromino_spawner` (Flow) — piece generation with bag/queue
- [x] `line_clear_monitor` (Rule) — generic line-clear detection

### ✅ Additional Components Built
- [x] `warp_asteroids` (Leg) — emergency teleport with intangibility
- [x] `tetromino` body script + scenes (tetromino.tscn, tetromino_single.tscn)
- [x] `brick_damaging.tscn` — brick variant that deals damage on contact

### 🔲 Phase 4 — Compose Game Scenes (Next)
- [ ] **Space Invaders** game scene — compose from grid_basic + swarm_controller + wave_spawner + shoot_ai_swarm + existing components
- [ ] **Tetris** game scene — compose from grid_basic + tetromino_spawner + line_clear_monitor + falling_ai + existing components

### 🔲 Pending Enhancements
- [ ] `wave_spawner` — add `grid_score_by_row` (same pattern as grid_health_by_row)
- [ ] `universal_body` — add `autofire` toggle for DAS (Delayed Auto Shift)
- [ ] `variable_tuner_global` — group-wide property changes (adjust fall speed on level up)

### 🔲 Phase 5 — Test & Polish
- [ ] Full gameplay loop test: Space Invaders
- [ ] Full gameplay loop test: Tetris
- [ ] Audio for both games (SoundSynth procedural sounds)

---

## Component Catalog: 75 Components

| Category | Count |
|----------|-------|
| Core | 8 |
| Bodies | 9 |
| Brains | 8 |
| Legs | 12 |
| Arms | 3 |
| Components | 14 |
| Rules | 8 |
| Flow | 11 |
| Effects | 2 |

## Game Catalog: 10 Games (7 working, 1 needs remake, 2 in progress)

| Game | Location | Status |
|------|----------|--------|
| Pong | `remakes/pong.tscn` | ✅ Working |
| Breakout | `remakes/breakout.tscn` | ✅ Working |
| Asteroids | `remakes/asteroids.tscn` | ✅ Working (polished) |
| Pongsteroids | `remixes/pongsteroids.tscn` | ✅ Working |
| Dogfight | `originals/dogfight.tscn` | ✅ Working |
| Pongout | `remixes/pongout.tscn` | ✅ Working |
| Breaksteroids | `remixes/breaksteroids.tscn` | ✅ Working |
| Asterout | `remixes/asterout.tscn` | ⚠️ Needs remake |
| Space Invaders | `remakes/` (not yet created) | 🔧 Components built |
| Tetris | `remakes/` (not yet created) | 🔧 Components built |

---

## Known Bugs to Fix

- `patrol_ai.gd`: Start position bug — UFO may not begin at the correct path position
- `ufo_shielded.tscn`: UFO drawing scale may need adjustment
- `ring_spawner.gd`: Bricks parented to non-root bodies bypass CollisionMatrix — needs architectural fix or workaround