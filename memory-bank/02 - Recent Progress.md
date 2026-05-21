# Recent Progress

**Last Updated:** 2026-05-20

---

## Plan 18 — Planetary Attack Remake (COMPLETE)

Major upgrade to the existing `planetary_attack.tscn` inversion game. The player now controls a Mystery Ship protecting an advancing invader formation on a scrolling playfield with opposing cannons, triangle ship hunters, and asteroid fields.

### New Foundation: Playfield Size

- **New export on UGS:** `playfield_size: Vector2 = Vector2(640, 360)` — default matches viewport, zero behavioral change for existing games
- **`universal_body.gd`** updated: resolves `-1` sentinel bounds from `game.playfield_size` or viewport fallback
- **`screen_cleanup.gd`** updated: uses `game.playfield_size` instead of viewport size
- **`screen_wrap.gd`** updated: uses `game.playfield_size` instead of viewport size

### New Component: Scrolling Camera

- **New `camera_midpoint.gd`:** UniversalComponent2D that tracks midpoint between player entity and mouse position. Configurable lerp speed, clamped to playfield bounds. Finds tracked entity via group name.
- **New scene:** `Scenes/Components/camera_midpoint.tscn`

### Planetary Attack Rebuild

- **Playfield:** 2× viewport size (1280×720), scrolling camera
- **Player:** UFO body with player_control, direct_acceleration, gun_simple (mouse aiming), ring_spawner shield, health
- **Invaders:** Auto-marching swarm with `bottom_action = VICTORY`
- **Opposition:** Paddle cannons with AI, barriers, triangle ship hunters (targeting invaders), asteroid field
- **Friendly fire ON:** Player can accidentally shoot own invaders — skill element
- **No game script changes:** Pure scene assembly from existing + 1 new component

### Files Created

| File | Purpose |
|------|---------|
| `Scripts/Components/camera_midpoint.gd` | Scrolling camera — midpoint of ship + mouse, clamped to playfield |
| `Scenes/Components/camera_midpoint.tscn` | Scene wrapper for camera_midpoint |

### Files Modified

| File | Changes |
|------|---------|
| `Scripts/Core/universal_game_script.gd` | Added `playfield_size` export with editor redraw |
| `Scripts/Core/universal_body.gd` | Resolves sentinel bounds from `game.playfield_size` |
| `Scripts/Components/screen_cleanup.gd` | Uses `game.playfield_size` with viewport fallback |
| `Scripts/Components/screen_wrap.gd` | Uses `game.playfield_size` with viewport fallback |
| `Scenes/Games/inversions/planetary_attack.tscn` | Major rebuild — scrolling playfield, mystery ship, cannons, hunters, asteroids |

---

## Plan 16 Phase 2b — Mini Progression System (COMPLETE)

Persistent progression system using JSON save/load. Modifiers unlock as the player's best run score crosses thresholds. Top 5 high scores with initials entry. Works on both desktop and web (IndexedDB).

### Architecture

- **New autoload:** `SaveData` (`Scripts/Core/save_data.gd`) — manages persistent data via `user://cd50_save.json`
- **Score-gated unlocks:** Best run score compared against hardcoded thresholds. New modifiers unlock when thresholds are crossed.
- **High scores:** Top 5 with initials + date. Default entries at each threshold (set by "PLY"). Sorted descending.
- **Modifier state:** Three-tier system — defined → unlocked (by score) → active (player toggle). Save/load persists all three tiers.

### Modifier Unlock Thresholds

| Modifier | Threshold | Description |
|----------|-----------|-------------|
| Scope Creep | 100 | Player health × 2 |
| Shotgun Mode | 1,000 | Bullets and balls × 3 |
| Overclocked CPU | 10,000 | Speed × 1.25, multiplier × 1.5 |
| Feature Creep | 50,000 | Spawns × 1.5 |
| Crunch Time | 100,000 | Score × 3, 1 life |

### Integration Points

- **Boot screen:** Displays top 5 high scores + modifier toggle buttons (greyed out if locked)
- **Game over screen:** Initials entry when new high score achieved, displays unlock notifications
- **Arcade orchestrator:** Reports `_running_score` to `SaveData.add_score()` on run end, checks for new unlocks, passes `is_new_high_score` to game over screen

### Files Created

| File | Purpose |
|------|---------|
| `Scripts/Core/save_data.gd` | SaveData autoload — JSON persistence, high scores, modifier unlocks |

### Files Modified

| File | Changes |
|------|---------|
| `Scripts/Hub/boot_screen.gd` | High score display, modifier toggle buttons, lifetime score label |
| `Scripts/Hub/game_over_screen.gd` | Initials entry for new high scores, unlock notification display |
| `Scripts/Hub/arcade_orchestrator.gd` | Score reporting to SaveData, unlock detection, new high score check |
| `project.godot` | SaveData autoload registration |

---

## Plan 16 Phase 2 — Arcade Modifiers (COMPLETE)

Implemented 5 Balatro-like modifiers that apply across all arcade games. All toggled via editor exports on the ArcadeOrchestrator for now; player-selectable UI deferred to next step.

### Modifier System Architecture

- **New script:** `Scripts/Hub/modifier_manager.gd` — Node child of ArcadeOrchestrator. Receives orchestrator reference via `set_orchestrator()`.
- **Two-phase application:** Setup-time modifiers run once after game instance is added to tree (`apply_setup_modifiers`). Runtime modifiers listen to `get_tree().node_added` during gameplay (`start_listening`/`stop_listening`).
- **ArcadeOrchestrator changes:** Added `@export_group("Modifiers")` with 5 bool toggles. Creates ModifierManager in `_ready()`. Crunch Time affects initial lives and score multiplier. Manager lifecycle tied to game transitions.

### The 5 Modifiers

| Modifier | Implementation | Phase |
|----------|---------------|-------|
| **Shotgun Mode** — 3 bullets instead of 1 | Detects bullet CharacterBody2D nodes entering tree, clones with 15° spread and perpendicular offset | Runtime |
| **Overclocked CPU** — 25% faster | Speeds up Leg components (speed/accel/top_speed × 1.25, hop_delay/fall_interval ÷ 1.25) and SwarmController (base_tick_interval ÷ 1.25). Timing-only for grid games to preserve alignment. | Setup + Runtime |
| **Feature Creep** — Double enemies | Doubles wave_spawner grid_columns or spawn_count_equation, doubles ring_spawner spawn_count. Bug Drop special case: also doubles line_clear_monitor columns + repositions origin. | Setup |
| **Crunch Time** — 1 life, ×3 score | Starting lives = 1, all score values multiplied by 3 via `get_score_multiplier()` in AO scoring callbacks | Setup (lives) + Runtime (multiplier) |
| **Scope Creep** — Double player health | Doubles max_health on Health components, but only for player-controlled entities (checks sibling for player_control script) | Setup + Runtime |

### Bug Fixes During Implementation

| Issue | Fix |
|-------|-----|
| Overclocked CPU broke Bug Drop grid alignment | Removed `step_size` and `swarm_step_size` overclocking — only timing properties overclocked for grid-based games |
| Feature Creep broke Bug Drop line detection | Added `_fix_bug_drop_line_clear()` — doubles line_clear_monitor columns + shifts origin left for Bug Drop only |
| Scope Creep was anti-fun (doubled enemy health) | Added `_has_player_control()` check — only boosts health on player-controlled entities |
| Shotgun spread too wide (45°) | Reduced to 15° (`PI / 12.0`) |

### Files Created

| File | Purpose |
|------|---------|
| `Scripts/Hub/modifier_manager.gd` | Modifier manager — all 5 modifiers, setup + runtime application |

### Files Modified

| File | Changes |
|------|---------|
| `Scripts/Hub/arcade_orchestrator.gd` | Added 5 modifier export toggles, ModifierManager creation in `_ready()`, Crunch Time lives/multiplier integration |
| `README` | Updated modifiers section with actual names/descriptions, updated game list (removed COMING SOON, added Space Rocks Inverted) |

---

## Plan 16 — Cambrian Remix Explosion (Phase 1 COMPLETE)

Four new remix/inversion games assembled from existing components. All pure scene assemblies — no new game scripts.

### New Games Built

| Game | Type | Scene | Description |
|------|------|-------|-------------|
| Bug Drop | Remix | `Scenes/Games/remixes/bug_drop.tscn` | Block Drop + Bug Blaster hybrid. Tetrominos fall while invaders shoot up at them. |
| Space Bugs | Remix | `Scenes/Games/remixes/space_bugs.tscn` | Bug Blaster + Space Rocks hybrid. Invaders in formation, asteroids as additional hazards. |
| Planetary Attack! | Inversion | `Scenes/Games/inversions/planetary_attack.tscn` | Space Invaders inverted — the player controls the invader swarm, paddle cannons defend below. |
| Space Rocks Inverted | Inversion | `Scenes/Games/inversions/space_rocks_inverted.tscn` | Space Rocks inverted — player controls the asteroids, ships are the threat. |

### New Arcade Settings

4 new `.tres` entries in `Scenes/Hub/ArcadeSettings/` (total now 12):
- `bug_drop.tres`, `space_bugs.tres`, `planetary_attack.tres`, `space_rocks_inverted.tres`

### New Scripts Created

| Script | Category | Purpose |
|--------|----------|---------|
| `clear_shot_ai.gd` | Brains | Clear shot AI for paddle cannons — only fires when line of sight to target is clear |
| `cover_ai.gd` | Brains | Cover AI for paddle cannons — seeks bunker cover when under threat |
| `swarm_controller_player.gd` | Brains | Player-driven swarm controller — DAS input for invader movement + broadside firing |
| `hit_effect.gd` | Components | Spawns effect scenes at parent position when parent is removed from tree |
| `vector_thruster_exhaust.gd` | Components | Four diagonal maneuvering thruster flames with noise audio |
| `group_kill_on_signal.gd` | Rules | Kills all members of a target group on game signal, supports health-based sequential kills |
| `polybius_nose.gd` | Hub | Custom resource for Polybius nose shape frame data |

### New Body Scene Variants

| Scene | Purpose |
|-------|---------|
| `ball_arcade.tscn` | Arcade ball variant |
| `ball_combo_arcade.tscn` | Arcade combo ball variant |
| `brick_barrier.tscn` | Barrier brick variant |
| `mystery_ship_colliding.tscn` | Mystery ship with collision |
| `mystery_ship_patrolling.tscn` | Mystery ship with patrol AI |
| `tetromino_rigged_reversed.tscn` | Reverse-rigged tetromino |
| `tetromino_single_swarm.tscn` | Swarm tetromino single |
| `player_invader.tscn` | Player-controlled invader body |
| `ufo_player.tscn` | Player-controlled UFO body |
| `nonplayer_invader_independant.tscn` | Independent invader (non-formation) |
| `nonplayer_paddle_cannon.tscn` | AI paddle cannon |
| `nonplayer_paddle_cannon_protected.tscn` | AI paddle cannon with barrier protection |

### New Music Added

| Track | Artist | License |
|-------|--------|---------|
| `Karl Casey - Hunted by Machines.ogg` | Karl Casey / White Bat Audio | CC-BY 4.0 |
| `Karl Casey - The Devil's Eyes.ogg` | Karl Casey / White Bat Audio | CC-BY 4.0 |

With corresponding `MusicTrack` resources: `hunted_by_machines.tres`, `the_devils_eyes.tres`

### Games Now: 12
Paddle Ball, Brick Breaker, Space Rocks, Meteor Rally, Dogfight, Bug Blaster, Block Drop, Rock Breaker, Bug Drop, Space Bugs, Planetary Attack!, Space Rocks Inverted

---

## Plan 15 — Arcade Orchestrator Juice (Phase 2 IN PROGRESS)

### Phase 1 — Copyright Rename (COMPLETE)
- All game names renamed across the entire codebase (scenes, scripts, resources, docs)
- Rename map: `pong` → `paddle_ball`, `breakout` → `brick_breaker`, `asteroids` → `space_rocks`, `space_invaders` → `bug_blaster`, `tetris` → `block_drop`, `pongsteroids` → `meteor_rally`, `breaksteroids` → `rock_breaker`
- All `.tscn` game scenes, `.tres` arcade settings, and internal references updated
- First export to itch.io completed (commit `8703f0a`)

### Phase 1.5 — Copyright-Safety Visual Changes (COMPLETE)

Targeted visual/mechanical tweaks to make each remake look distinct from its inspiration.

#### Bug Blaster — Formation Change
- Changed from 5×11 grid (55 invaders across 3 mixed rows) to 3×18 single-row formation (54 invaders)
- **WaveSpawner3** (nautilus): `grid_columns=18, grid_rows=1`, pos=(320,32) — top row, 3pts each
- **WaveSpawner** (squid/default): `grid_columns=18, grid_rows=1`, pos=(320,56) — middle row, 2pts each
- **WaveSpawner2** (crab): `grid_columns=18, grid_rows=1`, pos=(320,80) — bottom row
- `SwarmController.step_down_distance` increased from 4→6 (1.5× for wider formation)

#### Block Drop — Color Scheme + Juice Rework
- **Single brick warm color default:** `tetromino_single.tscn` color changed from blue to orange `Color(1, 0.45, 0, 1)`
- **Line clear death effect:** New `death_brick_explode` effect — 4 spinning line segments + 8 particle dots, color-inherited from parent brick
- **Health-based sequential kill:** `line_clear_monitor.gd` now supports `use_health_kill` mode — cascading explosion effect row by row
- **Preview/hold smooth rotation:** Preview and hold pieces continuously rotate via looping Tween (4s per revolution)

#### Brick Breaker — Flag Coloring + Wider Layout
- **New `FlagResource` core class:** Custom resource defining a flag color grid
- **New `flag_palette.gd` component:** Colors bricks via `modulate` from a randomly selected flag pattern. 20 flag `.tres` resources in `Resources/Flags/`
- **Layout widened:** Playfield and brick layout expanded
- **All bricks start white** — flag_palette applies themed colors on wave spawn

#### Space Rocks — Ship + UFO Redesign
- **Ship shape redrawn:** Blunt nose, extended wings (stealth bomber vs arrowhead). Comment in `triangle_ship.gd`: "blunt nose, extended wings"
- **UFO shape redesigned:** Updated visual shape

#### Paddle Ball — Center Line Change
- **New `checkerboard_line.gd` component:** Draws a checkerboard pattern of alternating squares (3 columns × 64 rows, configurable)
- Replaced classic dashed center line with checkerboard center zone

### New Files Created

| File | Purpose |
|------|---------|
| `Scripts/Core/flag_resource.gd` | Custom resource defining a flag color grid for brick palettes |
| `Scripts/Components/flag_palette.gd` | Colors bricks from a randomly selected flag pattern |
| `Scenes/Components/flag_palette.tscn` | Scene wrapper for flag_palette |
| `Scripts/Components/checkerboard_line.gd` | Draws checkerboard pattern (Paddle Ball center line) |
| `Scenes/Components/checkerboard_line.tscn` | Scene wrapper for checkerboard_line |
| `Scripts/Effects/death_brick_explode.gd` | Draw-based death effect with spinning line fragments + colored particles |
| `Scenes/Effects/death_brick_explode.tscn` | Scene wrapper for death_brick_explode + Timer |
| `Scenes/Components/death_effect_brick.tscn` | Pre-configured DeathEffect with death_brick_explode attached |
| `Godot/export_presets.cfg` | First export configuration |
| 20 × `Resources/Flags/*.tres` | Flag color palette resources |

### Files Modified

| File | Changes |
|------|---------|
| All 8 game `.tscn` files | Renamed from old names, updated internal references |
| All 7 `.tres` arcade settings | Renamed to match new game names |
| `triangle_ship.gd` | Ship polygon redrawn (blunt nose, extended wings) |
| `tetromino_single.tscn` | Default color → warm orange |
| `line_clear_monitor.gd` | Added `use_health_kill`, `sequential_kill_delay` exports; health-based sequential kill |
| `block_drop.tscn` | Added Health + DeathEffectBrick to settled_cell_components; health kill mode |
| `tetromino_spawner.gd` | Preview/hold rotation tweens |
| `bug_blaster.tscn` | 3×18 single-row formation, wider step-down |
| `brick_breaker.tscn` | Added flag_palette, widened layout |
| `paddle_ball.tscn` | Replaced center line with checkerboard_line |
| Multiple body scenes | Updated references after rename |

### Phase 1.7 — Music System + Polish (COMPLETE)

#### Music System
- **New `music_player.gd`:** Flow component that shuffles and plays through an array of `MusicTrack` resources with fade in/out and a floating credit overlay. Only plays in STANDALONE mode. Supports optional speed ramping (listens for a signal and increases `pitch_scale` per fire, capped at 3.0).
- **New `music_track.gd`:** `MusicTrack` custom resource — pairs an OGG stream with `song_title`, `song_credit`, and `render_credit` attribution fields.
- **2 OGG tracks (Phase 1.7):** `el_manisero.ogg` (Moisés Simons, 1928 — Public Domain) and `son_de_la_loma.ogg` — both rendered with 8-bit NES soundfont (CC-BY 3.0)
- **2 MusicTrack resources:** `Resources/Music/el_manisero.tres`, `Resources/Music/son_de_la_loma.tres`
- **2 OGG tracks (Plan 16):** `Karl Casey - Hunted by Machines.ogg` and `Karl Casey - The Devil's Eyes.ogg` by Karl Casey / White Bat Audio (CC-BY 4.0)
- **2 MusicTrack resources:** `Resources/Music/hunted_by_machines.tres`, `Resources/Music/the_devils_eyes.tres`
- **Block Drop integration:** MusicPlayer wired to Block Drop with speed ramping — `speed_ramp_source` connected to `LineClearMonitor`, `speed_per_level = 0.1`. Music speeds up with each line clear (Tetris-style).
- **Credit overlay:** Floating text with song title + credit, fade in/hold/fade out animation. Black outline (2px) on labels for readability without blocking play area.

#### Flag Palette Overhaul
- **Flag count reduced from 20 → 11** real-world country flags: algeria, cuba, cuba_10x5, egypt, ethiopia, ghana, india, indonesia, tanzania, yugoslavia, zambia
- **Black replaced with dark grey** (`Color(0.25, 0.25, 0.25, 1)`) in 4 flags that used pure black (cuba, egypt, ghana, tanzania) — bricks were invisible against black backgrounds

#### Brick Breaker Tweaks
- **Random launch angle:** Both ball WaveSpawners (initial spawn + paddle respawn) now fire at random angle ±45° from vertical (`random_angle_min = -2.356`, `random_angle_max = -0.785`)

#### New Files Created

| File | Purpose |
|------|---------|
| `Scripts/Flow/music_player.gd` | Music player component — shuffles playlist, fades, shows credits, speed ramping |
| `Scripts/Flow/music_track.gd` | MusicTrack resource — OGG stream + attribution metadata |
| `Scenes/Flow/music_player.tscn` | Scene wrapper for music_player |
| `Resources/Music/el_manisero.tres` | MusicTrack for El Manisero |
| `Resources/Music/son_de_la_loma.tres` | MusicTrack for Son de la Loma |
| `Assets/Music/el_manisero.ogg` | OGG audio file |
| `Assets/Music/son_de_la_loma.ogg` | OGG audio file |

#### Files Modified

| File | Changes |
|------|---------|
| `block_drop.tscn` | Added MusicPlayer with playlist + speed ramping wired to LineClearMonitor |
| `brick_breaker.tscn` | Random launch angle on both ball spawners |
| `Resources/Flags/cuba.tres` | Black → dark grey (0.25) |
| `Resources/Flags/egypt.tres` | Black → dark grey (0.25) |
| `Resources/Flags/ghana.tres` | Black → dark grey (0.25) |
| `Resources/Flags/tanzania.tres` | Black → dark grey (0.25) |

### Phase 1.8 — Web Performance Optimization (COMPLETE)

Target: **ThinkPad T480 running in a browser** (Intel UHD 620, WebGL). Optimize the synth-heavy audio pipeline and CRT rendering for smooth 60fps on integrated graphics. **All 9 optimizations implemented and verified — game runs at 60fps on target hardware.** Tested via private itch.io upload.

#### Planned Changes (9 optimizations)

| # | Optimization | File | Impact |
|---|-------------|------|--------|
| 1 | Cap `max_fps=60` for web export | `export_presets.cfg` | Halves render workload |
| 2 | Reduce `MAX_VOICES` 16→8 | `sound_synth.gd` | 50% fewer active synths |
| 3 | Cache `_get_frequency()` (pre-compute on note change, not per-sample) | `sound_synth.gd` | Eliminates pow() in hot loop |
| 4 | Fix NOISE dead code (redundant randf() overwritten by lerp) | `sound_synth.gd` | Saves randf() in hot path |
| 5 | Lower `MIX_RATE` 22050→11025 (arcade-accurate) | `sound_synth.gd` | 50% fewer samples to generate |
| 6 | Signal-based continuous dedup (`tree_exiting` instead of per-frame polling) | `sound_synth.gd` | Eliminates 54 wasted _process calls in Bug Blaster |
| 7 | Dirty-flag CRT shader params (push on mode switch, not every frame) | `crt_controller.gd` | Eliminates 20+ WASM bridge calls/frame |
| 8 | Disable persistence VP in raster mode | `crt_controller.gd` | Eliminates wasted full-screen shader pass |
| 9 | Enable thread support in export (progressive enhancement) | `export_presets.cfg` | Offloads audio to Web Worker |

#### Key Decisions
- **No runtime `OS.has_feature("web")` checks** — MIX_RATE 11025 sounds fine on desktop too; max_fps and thread support are export-preset-specific
- **CRT shader quality deferred** — 7-sample shader acceptable after other optimizations; revisit only if needed post-testing
- **Thread support as progressive enhancement** — enabled in export but game must perform well without it (itch.io header compatibility concerns)
- **Signal-based dedup uses `tree_exiting`** — blocked continuous synths connect to the active synth's `tree_exiting` signal, then `set_process(false)` until woken up. Zero per-frame cost.

Full implementation details: `planning/15 - Arcade Orchestrator Juice.md` Phase 1.8

#### SoundBank Autoload (Phase 1.8 — COMPLETE)

Performance optimization: pre-warmed audio pool eliminates per-entity node creation/destruction for one-shot synthesized sounds.

- **New `sound_bank.gd` autoload:** Pre-warms 8 `AudioStreamPlayer2D` + `AudioStreamGenerator` pairs at startup. Centralized `_process` loop fills all active voices in one pass (replacing N separate per-synth `_process` calls). Voice reuse by `source_id` matches old per-synth restart behavior.
- **Modified `sound_synth.gd`:** ON_SIGNAL mode no longer creates `AudioStreamGenerator` or `AudioStreamPlayer2D` nodes — routes `play_one_shot()` through `SoundBank.play()` instead. SoundSynth becomes a lightweight config holder + signal relay. CONTINUOUS mode unchanged.
- **Modified `project.godot`:** Registered `SoundBank` autoload.

| File | Changes |
|------|---------|
| `Scripts/Core/sound_bank.gd` | **NEW** — Pre-warmed 8-voice audio pool, centralized fill loop, waveform generation |
| `Scripts/Flow/sound_synth.gd` | ON_SIGNAL mode: no audio node creation, routes through SoundBank |
| `project.godot` | Added SoundBank autoload registration |

#### Flag Palette Web Fix (Phase 1.8 bonus)

**Bug:** Brick Breaker bricks had no colors on web export. Block Drop (which explicitly sets `flag_resource`) worked fine.

**Root cause:** `flag_palette.gd` used `DirAccess.open()` + `list_dir_begin()` to scan for flag resources at runtime. This directory scanning doesn't work in web exports (packed `.pck` bundles), so the flags array was always empty → no colors applied.

**Fix:**
- **`flag_palette.gd`**: Removed `flags_dir` export and `_load_flags()` runtime scanning. Replaced with `@export var flag_resources: Array[FlagResource] = []` — resources loaded at scene parse time (web-safe). Also uses position-based node matching instead of physics queries for coloring.
- **`brick_breaker.tscn`**: Added all 11 flag resources (algeria, cuba, cuba_10x5, egypt, ethiopia, ghana, india, indonesia, tanzania, yugoslavia, zambia) as ext_resources and set on FlagPalette's `flag_resources` array. Random flag picked each wave.

#### Files Modified

| File | Changes |
|------|---------|
| `Scripts/Components/flag_palette.gd` | Removed `flags_dir`/`_load_flags()`. Added `flag_resources: Array[FlagResource]` export. Position-based node matching replaces physics queries. |
| `Scenes/Games/remakes/brick_breaker.tscn` | Added 11 flag ext_resources. FlagPalette `flag_resources` array set with all flags. |

### Phase 2 — Polybius Character (IN PROGRESS)

Vector CRT face that introduces runs, taunts between games, and delivers game-over commentary.

#### Two-Channel Architecture
- **Eyes channel:** Face outline, eyes, pupils, eyebrows — controlled by `PolybiusEyes` resources (one per expression)
- **Mouth channel:** Mouth shape — controlled by `PolybiusMouth` resources (one per mouth position for lip sync)
- Both channels combine freely via independent frame indices

#### Files Created

| File | Purpose |
|------|---------|
| `Scripts/Hub/polybius_eyes.gd` | Custom Resource — eye/expression frame data (`PolybiusEyes`) |
| `Scripts/Hub/polybius_mouth.gd` | Custom Resource — mouth frame data (`PolybiusMouth`) |
| `Scripts/Hub/polybius_nose.gd` | Custom Resource — nose frame data (`PolybiusNose`) |
| `Scripts/Hub/polybius_face.gd` | `@tool` Control — vector face drawing, two-channel frame system |
| `Scenes/Hub/polybius_face.tscn` | Face scene (Control + script) |

#### Current Status
- Step 2a ✅: `polybius_face.gd` created — vector face drawing + expression states
- **Step 2b (ACTIVE):** Drawing facial frames — filling in point data for `PolybiusEyes` + `PolybiusMouth` resource instances (neutral/displeased expressions, mouth positions)

#### Remaining Steps
- 2c: Record voice lines + bitcrush → export as .ogg
- 2d: Implement typewriter text + voice playback sync
- 2e: Implement face animations (roll up/down, quick flash)
- 2f: Add INTRO state to AO + face integration on run start
- 2g: Add quick-comment integration on RESULT state
- 2h: Add game-over integration on GAME_OVER state
- 2i: Add random in-game taunt during PLAYING state
- 2j: Playtest full arcade run with Polybius

See `planning/15 - Arcade Orchestrator Juice.md` Phase 2 for full plan.

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

### Games Now: 12
Paddle Ball, Brick Breaker, Space Rocks, Meteor Rally, Dogfight, Bug Blaster, Block Drop, Rock Breaker, Bug Drop, Space Bugs, Planetary Attack!, Space Rocks Inverted

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
- Active game count: **12** (Paddle Ball, Brick Breaker, Space Rocks, Meteor Rally, Dogfight, Bug Blaster, Block Drop, Rock Breaker, Bug Drop, Space Bugs, Planetary Attack!, Space Rocks Inverted)

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