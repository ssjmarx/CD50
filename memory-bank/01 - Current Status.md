# Current Status: CD50 — Arcade Cabinet

**Last Updated:** 2026-05-02  
**Engine:** Godot 4.x (GDScript)  
**Architecture:** Entity-Component (composition over inheritance)  
**Playable Games:** Pong, Breakout, Asteroids, Pongsteroids, Dogfight, Pongout, Breaksteroids, Space Invaders, Tetris, Modern Tetris — ALL componentized, zero game scripts  
**In Progress:** None — Modern Tetris (Plan 11) complete  
**Recent Completed:** Modern Tetris (Plan 11 — ghost piece, hold piece, T-spin detection, combo/B2B/level scoring, lock delay move limit)

---

## Project Overview

CD50 is a modular arcade game collection built around a composable component architecture. Games are assembled from reusable components (Brains, Legs, Arms, Components, Rules, Flow) attached to generic `UniversalBody` (entity) and `UniversalGameScript` (game) base classes. The signal flow is: **Brains** read input → emit on **UniversalBody** input signals → UniversalBody routes to processed output signals → **Legs/Arms** listen to output signals and act. **Rules** components manage game logic (scores, groups, conditions). **Flow** components manage waves, spawning, and UI.

**All games run as pure scene assemblies** — no game-specific scripts exist. Every game is a `UniversalGameScript` root node with attached components configured in the editor.

---

## Core Scripts

### `Scripts/Core/universal_body.gd` — `UniversalBody extends CharacterBody2D`
- Base class for all physical entities. Routes input signals from Brains to processed output signals (axis locks applied). Provides position clamping and physics-based movement with automatic velocity bouncing.
- **`_physics_process()`** calls `move_parent_physics()` by default — uses `move_and_collide()` for collision detection, auto-bounces velocity on collision, and emits `body_collided`.
- Listens to (internally connected): `left_joystick`, `right_joystick`, `mouse_position`, `button_pressed`, `button_released`
- Emits (routed outputs): `move`, `move_to`, `action`, `end_action`, `shoot`, `end_shoot`, `thrust`, `end_thrust`, `aim`, `aim_at`, `body_collided(collider, normal)`

### `Scripts/Core/universal_game_script.gd` — `UniversalGameScript extends Node2D`
- Master class for game coordinators. Generic container with **zero game-specific logic**. State machine (ATTRACT/PLAYING/PAUSED/GAME_OVER), P1/P2 + generic score tracking, collision matrix setup. All game behavior comes from attached Rule/Flow/Component nodes.
- **Auto-emit property setters:** `current_score`, `current_multiplier` — emit signals on change
- **Signals FROM components:** `victory`, `defeat`, `group_cleared`, `group_member_removed`, `lives_changed`, `lives_depleted`, `timer_tick`, `timer_expired`, `spawning_wave`, `spawning_wave_complete`, `piece_settled`, `hold_requested`, `t_spin_detected(is_t_spin, is_mini)`
- **Signals TO components/UI:** `on_game_start`, `on_game_end`, `on_game_over`, `on_points_changed`, `on_multiplier_changed`, `state_changed`, `on_p1_score`, `on_p2_score`
- Self-connects `victory` → `p1_win()` and `defeat` → `p1_lose()` in `_ready()`
- Static helper: `find_ancestor(node)` walks tree to find the UGS

### `Scripts/Core/universal_component.gd` — `UniversalComponent extends Node`
- Base class for game-level components. Provides `parent` (owning body) and `game` (UGS ancestor) references.
- Auto-resolves parent chain in `_ready()`.

### `Scripts/Core/universal_component_2d.gd` — `UniversalComponent2D extends Node2D`
- Node2D-based variant of UniversalComponent. Used for components that need spatial positioning (WaveSpawner, WaveDirector, etc.).

### `Scripts/Core/collision_matrix.gd` — `CollisionMatrix extends RefCounted`
- Auto-configures collision layers/masks from group definitions. Supports both `UniversalBody` and non-body nodes via `CollisionMarker` children.

### `Scripts/Core/collision_group.gd` — `CollisionGroup extends Resource`
- Custom resource defining a collision group name and its target groups.

### `Scripts/Core/property_override.gd` — `PropertyOverride extends Resource`
- Custom resource for spawn-time property configuration. Stores `node_path`, `property_name`, and `value`.

### `Scripts/Core/common_enums.gd` — `CommonEnums extends RefCounted`
- Shared enumerations: `Element`, `State`, `ScoreType`, `Trigger`, `SpawnPattern`, `AdjustmentMode`, `Condition`, `Result`, `DisplayMode`.

---

## Body Scripts & Scene Organization

### Design Philosophy

Body scripts (`Scripts/Bodies/*.gd`) contain **drawing code only** — they define the visual shape, colors, and `_draw()` calls. All gameplay behavior is handled by attached components.

Body **scenes** (`Scenes/Bodies/`) are organized into three tiers:

```
Scenes/Bodies/
├── generic/        — Archetype templates (no brain, no faction, no color override)
├── player/         — Pre-rigged for player control
└── nonplayer/      — Pre-rigged as threats/obstacles
```

### Current Body Scene Inventory

```
Scenes/Bodies/generic/
├── asteroid.tscn
├── ball.tscn
├── brick.tscn, brick_damaging.tscn
├── bullet_simple.tscn, bullet_simple_smallsound.tscn, bullet_wrapping.tscn
├── invader.tscn, mystery_ship.tscn
├── paddle.tscn
├── tetromino.tscn, tetromino_single.tscn
├── triangle_ship.tscn, triangle_ship_modern.tscn
├── ufo.tscn, ufo_shielded.tscn

Scenes/Bodies/player/
├── player_paddle.tscn, player_paddle_cannon.tscn
├── player_triangle_ship.tscn, player_triangle_ship_modern.tscn

Scenes/Bodies/nonplayer/
├── nonplayer_invader.tscn
├── nonplayer_paddle.tscn
├── nonplayer_triangle_ship.tscn, nonplayer_triangle_ship_modern.tscn
```

---

## Component Catalog

| Category | Count | Components |
|----------|-------|------------|
| Core | 8 | universal_body, universal_game_script, universal_component, universal_component_2d, collision_matrix, collision_group, property_override, common_enums |
| Bodies | 12 | ball, paddle, asteroid, brick, bullet_simple, bullet_wrapping, tetromino, triangle_ship, ufo, invader, paddle_cannon, mystery_ship |
| Brains | 8 | player_control, interceptor_ai, aim_ai, shoot_ai, shoot_ai_swarm, patrol_ai, falling_ai, swarm_ai |
| Legs | 13 | direct_movement, direct_acceleration, engine_simple, engine_complex, friction_linear, friction_static, rotation_direct, rotation_target, grid_movement, grid_rotation, grid_gravity, grid_rotation_advanced, warp_asteroids |
| Arms | 3 | gun_simple, damage_on_hit, damage_on_joust |
| Components | 18 | angled_deflector, collision_marker, death_effect, die_on_hit, die_on_timer, ghost_piece, health, hold_relay, lock_detector, pong_acceleration, ring_spawner, score_on_death, score_on_hit, screen_cleanup, screen_wrap, split_on_death, t_spin_detector, vector_engine_exhaust |
| Rules | 8 | goal, points_monitor, variable_tuner, group_monitor, group_count_multiplier, lives_counter, timer, line_clear_monitor |
| Flow | 11 | interface, sound_on_hit, sound_synth, music_ramping, sfx_ramping, beep, grid_basic, swarm_controller, tetromino_spawner, wave_director*, wave_spawner* |
| Effects | 2 | death_particles, death_broken_triangle_ship |
| **Total** | **83** | |

*\* wave_director and wave_spawner scripts live in `Scripts/Rules/` but are categorized as Flow by function.*

---

## Signal Flow Architecture

```
INPUT (keyboard/mouse/gamepad)
  ↓
BRAINS (player_control, interceptor_ai, aim_ai, patrol_ai, shoot_ai, shoot_ai_swarm, swarm_ai, falling_ai)
  ↓ emit on UniversalBody input signals
UNIVERSAL BODY (routes input → output with axis locks)
  ↓ emit processed output signals
LEGS (direct_movement, engine_simple, grid_movement, grid_rotation, grid_gravity, grid_rotation_advanced, etc.)
ARMS (gun_simple, damage_on_hit, damage_on_joust)
  ↓
COMPONENTS (angled_deflector, ghost_piece, hold_relay, lock_detector, t_spin_detector, etc.)
RULES (goal, points_monitor, line_clear_monitor, group_monitor, lives_counter, timer, etc.)
FLOW (interface, sound_synth, tetromino_spawner, swarm_controller, wave_director, wave_spawner, etc.)
  ↓
EFFECTS (death_particles, death_broken_triangle_ship)
```

**Key signals on UniversalGameScript:**
- From Components: `victory`, `defeat`, `group_cleared`, `group_member_removed`, `lives_changed`, `lives_depleted`, `timer_tick`, `timer_expired`, `spawning_wave`, `spawning_wave_complete`, `piece_settled`, `hold_requested`, `t_spin_detected(is_t_spin, is_mini)`
- To Components/UI: `on_game_start`, `on_game_end`, `on_game_over`, `on_points_changed`, `on_multiplier_changed`, `state_changed`, `on_p1_score`, `on_p2_score`

---

## Assets

- **Audio:** Procedural synthesis via SoundSynth component (all game audio generated at runtime)
- **Fonts:** Kenney retro fonts (Pixel, High, Mini, Rocket, Future, Blocks, Square — regular and narrow variants)
- **CRT Addon:** Custom CRT post-processing effect
- **Effects:** Self-destructing effect scenes (death_particles, death_broken_triangle_ship)