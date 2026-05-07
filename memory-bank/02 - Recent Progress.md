# Recent Progress

**Last Updated:** 2026-05-06

---

## Plan 15 — Arcade Orchestrator Juice (IN PROGRESS)

Visual and gameplay polish pass across Bug Blaster and Block Drop.

### Bug Blaster Formation Change (COMPLETE)
- Changed from 5×11 grid (55 invaders across 3 mixed rows) to 3×18 single-row formation (54 invaders)
- **WaveSpawner3** (nautilus): `grid_columns=18, grid_rows=1`, pos=(320,32) — top row, 3pts each
- **WaveSpawner** (squid/default): `grid_columns=18, grid_rows=1`, pos=(320,56) — middle row, 2pts each
- **WaveSpawner2** (crab): `grid_columns=18, grid_rows=1`, pos=(320,80) — bottom row
- `SwarmController.step_down_distance` increased from 4→6 (1.5× for wider formation)

### Block Drop Juice (COMPLETE)
- **Single brick warm color default:** `tetromino_single.tscn` color changed from blue to orange `Color(1, 0.45, 0, 1)`
- **Line clear death effect:** New `death_brick_explode` effect — 4 spinning line segments + 8 particle dots, color-inherited from parent brick. Creates satisfying colored explosions on line clears.
- **Health-based sequential kill:** `line_clear_monitor.gd` now supports `use_health_kill` mode — instead of flash+queue_free, it reduces each brick's Health to zero sequentially with configurable delay. This triggers each brick's DeathEffect naturally, producing a cascading explosion effect row by row.
- **Preview/hold smooth rotation:** Preview and hold pieces now continuously rotate via looping Tween (4s per revolution, ease-in-out). Rotation tween is killed and snapped to 0 when pieces become active.

### New Files Created

| File | Purpose |
|------|---------|
| `Scripts/Effects/death_brick_explode.gd` | Draw-based death effect with spinning line fragments + colored particles |
| `Scenes/Effects/death_brick_explode.tscn` | Scene wrapper for death_brick_explode + Timer |
| `Scenes/Components/death_effect_brick.tscn` | Pre-configured DeathEffect with death_brick_explode attached |

### Files Modified

| File | Changes |
|------|---------|
| `tetromino_single.tscn` | Default color → warm orange |
| `line_clear_monitor.gd` | Added `use_health_kill`, `sequential_kill_delay` exports; `_kill_rows_sequential()`, `_find_health_component()`, `_get_body_at()` methods |
| `block_drop.tscn` | Added Health + DeathEffectBrick to settled_cell_components; `use_health_kill=true`, `enable_line_flash=false` on LineClearMonitor |
| `tetromino_spawner.gd` | Added `_preview_tween`/`_hold_tween` vars; `_start_preview_rotation()`/`_start_hold_rotation()` methods; tween kill on piece activation |
| `bug_blaster.tscn` | All 3 wave spawners → 18×1 single row; positions adjusted; step_down_distance 4→6 |

---

## Plan 14 — Arcade Juice Part 1: Custom CRT Shader (COMPLETE)

Replaced the heavy open-source CRT addon with a custom ultra-lightweight CRT post-processing system. Added vector monitor mode with shader-based phosphor persistence for vector-based games (Space Rocks, Dogfight, Meteor Rally).

### Lightweight CRT System
- **New shader:** `Shaders/crt_light.gdshader` — ~80 lines of GLSL replacing the old ~500-line addon. Effects: barrel warp, chromatic aberration, bloom (bright-pixel sampling), vignette, hum bar (scrolling brightness band), flicker, brightness/contrast, persistence blend
- **Persistence shader:** `Shaders/persistence.gdshader` — Frame accumulation shader running inside a `CLEAR_MODE_NEVER` SubViewport. Uses `max(prev * decay, game)` for physically-motivated phosphor decay. Provides full-screen phosphor trails in vector mode without any per-body components
- **CRT Controller:** `Scripts/Flow/crt_controller.gd` — Self-building Node2D (not CanvasLayer — CanvasLayer + SCREEN_TEXTURE doesn't work in GL Compatibility mode). Creates its own BackBufferCopy, persistence SubViewport + ColorRect, CRT shader ColorRect, and 3 TextureRect overlays programmatically. No .tscn needed — fully portable
- **PNG overlays:** 3 generated textures in `Assets/CRT/`:
  - `scanlines.png` — Scanline overlay (raster mode)
  - `phosphor_grid.png` — Phosphor dot grid overlay (vector mode)
  - `noise.png` — Static noise texture (always on, scrolls for animated effect)
- **Per-game display modes:** `vector_monitor` export on UGS. When true: brighter bloom, stronger warp, phosphor grid overlay, persistence phosphor trails. When false: scanlines, milder bloom, no persistence
- **All shader parameters are inspector-tunable** — exported as grouped presets (Raster Mode, Vector Mode, Persistence, Overlay Opacity, Animation) for live tweaking via the CRT Tuner debug scene

### Files Created
| File | Purpose |
|------|---------|
| `Shaders/crt_light.gdshader` | Lightweight CRT post-processing shader |
| `Shaders/persistence.gdshader` | Frame accumulation shader for phosphor persistence |
| `Scripts/Flow/crt_controller.gd` | Self-building CRT controller (Node2D + SubViewport) |
| `Assets/CRT/scanlines.png` | Scanline overlay texture |
| `Assets/CRT/phosphor_grid.png` | Phosphor dot grid texture |
| `Assets/CRT/noise.png` | Static noise texture |

### Files Modified
| File | Changes |
|------|---------|
| `universal_game_script.gd` | Added `vector_monitor` export |
| `arcade_orchestrator.gd` | Creates CRT controller, calls `set_vector_mode()` on game start |
| `project.godot` | Removed CRT plugin from enabled plugins |
| 7 game scene `.tscn` files | Removed old CRT CanvasLayer + WorldEnvironment nodes |

### Files Deleted
| File | Reason |
|------|--------|
| `addons/crt/` (entire directory) | Replaced by custom lightweight system |

### Design Decision: Shader-Based Phosphor vs Per-Body Component
The original plan called for a `PhosphorTrail` component attached to each vector body, with body `_draw()` rendering ghost images from a position ring buffer. After testing, this was replaced with a **shader-based persistence approach**: a SubViewport with `CLEAR_MODE_NEVER` accumulates previous frames with exponential decay (`persistence.gdshader`). This provides full-screen phosphor trails automatically — no per-body components, no body script modifications, and it affects everything on screen (including bullets, particles, etc.) which looks more authentic for a vector monitor.

---

## Priority Pivot: Shipping Over Building (May 6, 2026)

The project pivoted from building new games to shipping what exists. Deadlines have been set from May through October 2026 targeting an itch.io demo, Steam Coming Soon page, and October Next Fest.

### What Changed
- **Deleted plans:** Snake + Light Cycles (old Plan 14), Qix + Xonix (old Plan 15) — removed from pipeline
- **Renumbered:** Arcade Juice & Attract Mode is now Plan 14 (was Plan 16)
- **New plans:** Plan 15 (Arcade Orchestrator Juice), Plan 16 (Cambrian Remix Explosion)
- **Moved up:** itch.io export (was "Phase 7 — Ship" in old planning) is now the active priority
- **New file:** `memory-bank/06 - Deadlines.md` — full May–October commercial schedule

### Immediate Focus
- This week: Steamworks setup + itch.io pipeline
- Late May: Plans 14–15 (arcade juice) + export to itch
- June–July: Plan 16 (Cambrian Remix) + modifier system + scoring
- August: Steamworks integration
- October: Next Fest launch

---

## Rock Breaker Remix & Bounce Physics (COMPLETE)

Rebuilt Rock Breaker (Brick Breaker + Space Rocks hybrid) as a new remix game. Fixed bounce physics issues in UniversalBody that affected all bouncing entities.

### Rock Breaker Game
- **Brick Breaker + Space Rocks hybrid:** Player paddle + ball in a bounded arena with bouncing space_rocks as additional obstacles
- **Scene:** `Scenes/Games/remixes/rock_breaker.tscn` — pure component assembly, zero game scripts
- **Asteroid variant:** `asteroid_bouncing_nosound.tscn` — bouncing asteroid without ScreenWrap (uses BounceOnHit + walls for bounded playfield)
- **Ball variant:** `ball_combo.tscn` — ball with BounceOnHit, AngledDeflector, Paddle BallAcceleration, DamageOnHit (targets bricks + space_rocks), ScoreOnHit
- **Layout:** Interior walls create corridors; 4×4 grid of space_rocks spawned in center; ball spawns from paddle
- **Collision groups:** balls, paddles, walls, space_rocks, floors, paddle_zone, asteroidfloor
- **Wave system:** WaveDirector triggers on game start and on ball/asteroid group clear; WaveSpawner2 spawns space_rocks with random-angle initial velocity
- **Scoring:** VariableTuner on paddle_zone entry sets multiplier; ScoreOnHit on paddle; PointsMonitor tracks score
- **Audio:** MusicRamping tied to asteroid count for tension

### Bounce Physics Fix (UniversalBody)
- **Problem:** Bouncing felt "sticky" — velocity lost on every collision, bodies could re-collide with same surface
- **Root cause:** `move_and_collide()` stops at contact point; the remaining movement (`get_remainder()`) was discarded; body sat flush against surface causing re-triggers
- **Fix in `move_parent_physics()`:**
  1. After collision, nudge body 0.5px along collision normal (separation to prevent re-collision)
  2. Re-apply `get_remainder().bounce(normal)` in the same frame (preserves full movement through bounce)
- **Impact:** Improves all games using BounceOnHit (Paddle Ball, Brick Breaker, Meteor Rally, Rock Breaker)

### New Body Scenes
- `asteroid_bouncing.tscn` — asteroid with BounceOnHit, ScreenWrap, Health, SplitOnDeath, ScoreOnDeath, DeathEffect, SoundSynth
- `asteroid_bouncing_nosound.tscn` — same without SoundSynth (used in Rock Breaker)
- `ball_combo.tscn` — ball with BounceOnHit + AngledDeflector + Paddle BallAcceleration + DamageOnHit + ScoreOnHit + ScreenCleanup + SfxRamping + SoundSynth

### Scripts Modified

| Script | Changes |
|--------|---------|
| `universal_body.gd` | `move_parent_physics()`: added separation nudge (`position += normal * 0.5`) and remainder re-application (`collision.get_remainder().bounce(normal)`) |

### Games Now: 8
Paddle Ball, Brick Breaker, Space Rocks, Meteor Rally, Dogfight, Bug Blaster, Block Drop, Rock Breaker

---

## Plan 13 — Arcade Orchestrator (COMPLETE)

Full itch.io arcade cabinet architecture. All phases complete — Interface Takeover, Scrolling Transitions, fast rule tuning, lives/scoring/multiplier system.

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
- Boot → Paddle Ball loads → plays → ends → score read: **functional**

### Phase 2 — The Run (MOSTLY COMPLETE)

- **Lives system:** 3 lives, decremented on defeat, `lives_changed` signal
- **Game sequence:** `_current_index` with wrap-to-zero
- **Shuffle mode:** `PlaylistMode.SHUFFLE` with shuffle bag (random without repeats, refills when empty)
- **Score carry:** `_running_score` accumulates across games, live updates via `_on_game_points_changed`
- **Per-game multiplier bonus:** `_game_count` increments on victory, pushed to UGS as `arcade_bonus` so in-game scoring is affected
- **Time bonus:** Victory-only, 1000pts at ≤20s linearly to 0 at ≥60s, scaled by game count
- **Game Over screen:** "GAME OVER", final score, "PRESS START TO PLAY AGAIN", full restart on input
- **Scrolling transitions:** All four scenarios implemented (boot→game, game→game, game→gameover, gameover→boot). 0.4s cubic ease via `position:y` tween. AO uses `PROCESS_MODE_ALWAYS` so tweens run during UGS tree pause.
- **Interface Takeover:** Removed AO's own Interface node. Each game's child Interface is hijacked — disconnected from UGS signals, connected to AO signals. AO is sole source of truth for displayed score/multiplier/lives. Timer signals stay connected to UGS for tree walking.
- **Preloading:** Assessed and deferred — `PackedScene` refs are already in memory. `load_threaded_request()` doesn't help on itch.io (no `SharedArrayBuffer`). Multi-pack `.pck` split is the real optimization but premature for 8 lightweight games.

### Phase 3 — Fast Rules (ENTRIES CREATED & TUNED)

- Created 7 `ArcadeGameEntry` .tres resources in `Scenes/Hub/ArcadeSettings/`:
  - `paddle_ball.tres` — PointsMonitor target_score=1, score_type=P2, AI turning speed tuned, initial velocity set
  - `space_rocks.tres` — WaveDirector max_waves=1
  - `block_drop.tres` — Starting level and gravity tuned for fast play
  - `brick_breaker.tres` — LivesCounter lives=1
  - `bug_blaster.tres` — WaveDirector max_waves=1
  - `meteor_rally.tres` — PointsMonitor threshold tuned
  - `dogfight.tres` — WaveDirector max_waves=1
- Override application via `_apply_overrides()` with graceful warning fallback
- All entries have been tuned for 15–45s arcade pacing
- **Optional deferred:** Separate `arcade_default_playlist.tres` resource (playlist is inline in orchestrator scene)

### Interface Takeover Architecture

- **Signal chain:** `UGS.on_points_changed → AO._on_game_points_changed → AO.on_points_changed.emit(arcade_total) → Interface.set_points(arcade_total)`
- **Interface never hears from UGS directly** — AO is the sole source of truth
- **Timer discovery still works** because Interface.parent is UGS (set in `@onready`), and timer_tick stays connected to UGS
- **Cleanup:** when game is freed, its Interface is freed too — Godot auto-disconnects freed nodes from signals
- **No changes to:** `interface.gd`, game scenes, `ArcadeGameEntry` resources

### Scrolling Transition Details

- **`TRANSITIONING` state** added to `OrchestratorState` enum — all input ignored during transitions
- **`process_mode = PROCESS_MODE_ALWAYS`** on AO — tweens keep running when UGS `_ready()` pauses the scene tree
- **`_scroll_transition(outgoing, incoming, callback)`** — parallel tween: old `y:0→-360`, new `y:360→0`, cubic ease-in-out
- **`_setup_game_instance()` + `_finalize_game_start()`** — split from old `_load_and_start_game()`. Setup adds to tree (triggering UGS `_ready()`) without starting. Finalize resets position and calls `start_game()`.
- **BootScreen/GameOverScreen** changed from `anchors_preset = 15` to `layout_mode = 0` with fixed 640×360 offsets so `position.y` can be tweened

### Scripts Modified

| Script | Changes |
|--------|---------|
| `arcade_orchestrator.gd` | Major rewrite: Interface Takeover (`_takeover_interface`), Scrolling Transitions (`_scroll_transition`, `TRANSITIONING` state), split game loading (`_setup_game_instance` + `_finalize_game_start`), `PROCESS_MODE_ALWAYS`, `_get_ugs_from` helper |
| `arcade_orchestrator.tscn` | Removed AO's own Interface node. BootScreen/GameOverScreen changed to position-based layout. Removed `visible = false` from GameOverScreen (positioned off-screen instead). |

### Games Removed

- **Paddle Ballout** removed from codebase — didn't turn out interesting enough
- **Rock Breaker** was previously removed but has been rebuilt (see Rock Breaker section above)
- Active game count: **8** (Paddle Ball, Brick Breaker, Space Rocks, Meteor Rally, Dogfight, Bug Blaster, Block Drop, Rock Breaker)

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

## Block Drop Final Polish & Bug Fixes (COMPLETE)

Closing fixes after Plans 10–12 to call Block Drop "done."

### Bug Fixes
1. **Hard drop sound gating** — Hard drop sound fired on every key press instead of only when a drop actually occurred. Added `signal hard_dropped` to `grid_movement.gd` (only emits when `total_displacement != Vector2.ZERO`). Updated `tetromino_spawner.gd` to listen for `hard_dropped` instead of `piece.shoot`.
2. **Ghost piece lingering** — Hold piece's ghost offsets persisted when moved to hold box, projecting a ghost from the hold position back onto the playfield. Fixed by clearing `ghost_offsets` and calling `queue_redraw()` in `_position_hold_piece()`.
3. **Hold piece missing juice signals** — `_swap_in_held_piece()` didn't call `_connect_piece_signals()`, so swapped-in pieces had no move/rotate/drop sounds. Added the call.
4. **Grid alignment gap** — Spawner y-position was at row edge (18) instead of row center (27), causing a half-cell gap between where pieces land and where `line_clear_monitor` scans. Fixed in `block_drop.tscn`: spawner `(338, 27)`, `playfield_origin.x = 239`.
5. **Unused export cleanup** — Removed unused `margin` export from `line_clear_monitor.gd`.

### Visual Touches
6. **Preview/hold rotation** — Preview and hold pieces display rotated 90° clockwise; rotation resets to 0 when pieces become active.

### Scripts Modified
- **`grid_movement.gd`** — Added `signal hard_dropped`, emit only on actual drop
- **`tetromino_spawner.gd`** — Switch to `hard_dropped` signal; ghost offset cleanup in `_position_hold_piece()`; `_connect_piece_signals()` in `_swap_in_held_piece()`; preview/hold rotation (PI/2) with active reset (0)
- **`line_clear_monitor.gd`** — Removed unused `margin` export