# Recent Progress

**Last Updated:** 2026-05-04

---

## Breaksteroids Remix & Bounce Physics (COMPLETE)

Rebuilt Breaksteroids (Breakout + Asteroids hybrid) as a new remix game. Fixed bounce physics issues in UniversalBody that affected all bouncing entities.

### Breaksteroids Game
- **Breakout + Asteroids hybrid:** Player paddle + ball in a bounded arena with bouncing asteroids as additional obstacles
- **Scene:** `Scenes/Games/remixes/breaksteroids.tscn` — pure component assembly, zero game scripts
- **Asteroid variant:** `asteroid_bouncing_nosound.tscn` — bouncing asteroid without ScreenWrap (uses BounceOnHit + walls for bounded playfield)
- **Ball variant:** `ball_combo.tscn` — ball with BounceOnHit, AngledDeflector, PongAcceleration, DamageOnHit (targets bricks + asteroids), ScoreOnHit
- **Layout:** Interior walls create corridors; 4×4 grid of asteroids spawned in center; ball spawns from paddle
- **Collision groups:** balls, paddles, walls, asteroids, floors, paddle_zone, asteroidfloor
- **Wave system:** WaveDirector triggers on game start and on ball/asteroid group clear; WaveSpawner2 spawns asteroids with random-angle initial velocity
- **Scoring:** VariableTuner on paddle_zone entry sets multiplier; ScoreOnHit on paddle; PointsMonitor tracks score
- **Audio:** MusicRamping tied to asteroid count for tension

### Bounce Physics Fix (UniversalBody)
- **Problem:** Bouncing felt "sticky" — velocity lost on every collision, bodies could re-collide with same surface
- **Root cause:** `move_and_collide()` stops at contact point; the remaining movement (`get_remainder()`) was discarded; body sat flush against surface causing re-triggers
- **Fix in `move_parent_physics()`:**
  1. After collision, nudge body 0.5px along collision normal (separation to prevent re-collision)
  2. Re-apply `get_remainder().bounce(normal)` in the same frame (preserves full movement through bounce)
- **Impact:** Improves all games using BounceOnHit (Pong, Breakout, Pongsteroids, Breaksteroids)

### New Body Scenes
- `asteroid_bouncing.tscn` — asteroid with BounceOnHit, ScreenWrap, Health, SplitOnDeath, ScoreOnDeath, DeathEffect, SoundSynth
- `asteroid_bouncing_nosound.tscn` — same without SoundSynth (used in Breaksteroids)
- `ball_combo.tscn` — ball with BounceOnHit + AngledDeflector + PongAcceleration + DamageOnHit + ScoreOnHit + ScreenCleanup + SfxRamping + SoundSynth

### Scripts Modified

| Script | Changes |
|--------|---------|
| `universal_body.gd` | `move_parent_physics()`: added separation nudge (`position += normal * 0.5`) and remainder re-application (`collision.get_remainder().bounce(normal)`) |

### Games Now: 8
Pong, Breakout, Asteroids, Pongsteroids, Dogfight, Space Invaders, Tetris, Breaksteroids

---

## Plan 13 — Arcade Orchestrator (IN PROGRESS)

Building the itch.io arcade demo architecture. Phases 0–1 complete, Phase 2 mostly complete, Phase 3 entries created and tuned.

### Phase 0 — Input Refactoring (COMPLETE)

- Added `start`, `coin`, `pause` actions to Input Map in `project.godot`
- Refactored `player_control.gd` — removed `_unhandled_input`, now pure Input Map-driven (`_input` for mouse, `_physics_process` for buttons/axes)
- Refactored `universal_game_script.gd` — removed `_unhandled_input`, added `_input()` with Mode guard (STANDALONE only)
- Added `Mode` enum (`STANDALONE`, `ARCADE`) and `arcade_bonus` property to UGS
- All 7 games tested and working identically to before

### Phase 1 — Shell (COMPLETE)

- Created `Scripts/Hub/` and `Scenes/Hub/` directories
- Created `arcade_game_entry.gd` — Resource with `game_scene: PackedScene` + `overrides: Array[PropertyOverride]`
- Created `arcade_orchestrator.gd` — Full state machine (BOOT → PLAYING → RESULT → GAME_OVER → restart)
- Created `boot_screen.tscn` — "CD50 ARCADE" title, "INSERT COIN" / "PRESS START" text
- Created `arcade_orchestrator.tscn` — GameContainer, Interface (arcade display mode), BootScreen, GameOverScreen
- Boot → Pong loads → plays → ends → score read: **functional**

### Phase 2 — The Run (MOSTLY COMPLETE)

- **Lives system:** 3 lives, decremented on defeat, `lives_changed` signal
- **Game sequence:** `_current_index` with wrap-to-zero
- **Shuffle mode:** `PlaylistMode.SHUFFLE` with shuffle bag (random without repeats, refills when empty)
- **Score carry:** `_running_score` accumulates across games, live updates via `_on_game_points_changed`
- **Per-game multiplier bonus:** `_game_count` increments on victory, pushed to UGS as `arcade_bonus` so in-game scoring is affected
- **Time bonus:** Victory-only, 1000pts at ≤20s linearly to 0 at ≥60s, scaled by game count
- **Game Over screen:** "GAME OVER", final score, "PRESS START TO PLAY AGAIN", full restart on input
- **NOT DONE:** Scrolling transitions (games load/free instantly), preloading (`ResourceLoader.load_threaded_request`)

### Phase 3 — Fast Rules (ENTRIES CREATED & TUNED)

- Created 7 `ArcadeGameEntry` .tres resources in `Scenes/Hub/ArcadeSettings/`:
  - `pong.tres` — PointsMonitor target_score=1, score_type=P2, AI turning speed tuned, initial velocity set
  - `asteroids.tres` — WaveDirector max_waves=1
  - `tetris.tres` — Starting level and gravity tuned for fast play
  - `breakout.tres` — LivesCounter lives=1
  - `space_invaders.tres` — WaveDirector max_waves=1
  - `pongsteroids.tres` — PointsMonitor threshold tuned
  - `dogfight.tres` — WaveDirector max_waves=1
- Override application via `_apply_overrides()` with graceful warning fallback
- All entries have been tuned for 15–45s arcade pacing
- **NOT DONE:** Separate `arcade_default_playlist.tres` resource (playlist is inline in orchestrator scene)

### Games Removed

- **Pongout** removed from codebase — didn't turn out interesting enough
- **Breaksteroids** was previously removed but has been rebuilt (see Breaksteroids section above)
- Active game count: **8** (Pong, Breakout, Asteroids, Pongsteroids, Dogfight, Space Invaders, Tetris, Breaksteroids)

### New Scripts Created

| Script | Location | Purpose |
|--------|----------|---------|
| `arcade_orchestrator.gd` | `Scripts/Hub/` | State machine: BOOT→PLAYING→RESULT→GAME_OVER. Loads games, tracks lives/score, detects game end, applies property overrides. |
| `arcade_game_entry.gd` | `Scripts/Hub/` | Resource: PackedScene + property overrides array. |

### Scripts Modified

| Script | Changes |
|--------|---------|
| `universal_game_script.gd` | Added `Mode` enum, `arcade_bonus` property, `set_arcade_bonus()`, `_input()` with Mode guard, Interface suppression in ARCADE mode |
| `player_control.gd` | Removed `_unhandled_input`, pure Input Map-driven via `_input` + `_physics_process` |
| `project.godot` | Added `start`, `coin`, `pause` Input Map actions |

### Architecture Decisions Beyond Plan

- **Time bonus system:** Not in original plan. Rewards fast victories: 1000pts at ≤20s, scaling down to 0 at ≥60s, multiplied by game count
- **Arcade bonus passthrough:** Orchestrator pushes `_game_count` as `arcade_bonus` to UGS so in-game scoring is multiplied — the UGS `add_score()` uses `current_multiplier + arcade_bonus`
- **Shuffle bag:** Proper random-without-repeats implementation instead of simple shuffle
- **Inline playlist:** No separate `arcade_playlist.gd` resource — playlist is an array of `ArcadeGameEntry` directly on the orchestrator, configurable in the editor

---

## Tetris Final Polish & Bug Fixes (COMPLETE)

Closing fixes after Plans 10–12 to call Tetris "done."

### Bug Fixes
1. **Hard drop sound gating** — Hard drop sound fired on every key press instead of only when a drop actually occurred. Added `signal hard_dropped` to `grid_movement.gd` (only emits when `total_displacement != Vector2.ZERO`). Updated `tetromino_spawner.gd` to listen for `hard_dropped` instead of `piece.shoot`.
2. **Ghost piece lingering** — Hold piece's ghost offsets persisted when moved to hold box, projecting a ghost from the hold position back onto the playfield. Fixed by clearing `ghost_offsets` and calling `queue_redraw()` in `_position_hold_piece()`.
3. **Hold piece missing juice signals** — `_swap_in_held_piece()` didn't call `_connect_piece_signals()`, so swapped-in pieces had no move/rotate/drop sounds. Added the call.
4. **Grid alignment gap** — Spawner y-position was at row edge (18) instead of row center (27), causing a half-cell gap between where pieces land and where `line_clear_monitor` scans. Fixed in `tetris.tscn`: spawner `(338, 27)`, `playfield_origin.x = 239`.
5. **Unused export cleanup** — Removed unused `margin` export from `line_clear_monitor.gd`.

### Visual Touches
6. **Preview/hold rotation** — Preview and hold pieces display rotated 90° clockwise; rotation resets to 0 when pieces become active.

### Scripts Modified
- **`grid_movement.gd`** — Added `signal hard_dropped`, emit only on actual drop
- **`tetromino_spawner.gd`** — Switch to `hard_dropped` signal; ghost offset cleanup in `_position_hold_piece()`; `_connect_piece_signals()` in `_swap_in_held_piece()`; preview/hold rotation (PI/2) with active reset (0)
- **`line_clear_monitor.gd`** — Removed unused `margin` export