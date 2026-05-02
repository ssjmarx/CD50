# Current Status: CD50 — Arcade Cabinet

**Last Updated:** 2026-05-01  
**Engine:** Godot 4.x (GDScript)  
**Architecture:** Entity-Component (composition over inheritance)  
**Playable Games:** Pong, Breakout, Asteroids, Pongsteroids, Dogfight, Pongout, Breaksteroids, Space Invaders — ALL componentized, zero game scripts  
**In Progress:** Tetris (Plan 07 — requires tetromino_formation decomposition + gridless grid_movement paradigm)  
**Recent Completed:** Space Invaders (full game + heartbeat audio + barriers), SoundSynth voice leak fix + gameplay_only gate

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
- **Signals FROM components:** `victory`, `defeat`, `group_cleared`, `group_member_removed`, `lives_changed`, `lives_depleted`, `timer_tick`, `timer_expired`, `spawning_wave`, `spawning_wave_complete`
- **Signals TO components/UI:** `on_game_start`, `on_game_end`, `on_game_over`, `on_points_changed`, `on_multiplier_changed`, `state_changed`, `on_p1_score`, `on_p2_score`
- Self-connects `victory` → `p1_win()` and `defeat` → `p1_lose()` in `_ready()`
- Static helper: `find_ancestor(node)` walks tree to find the UGS

### `Scripts/Core/universal_component.gd` — `UniversalComponent extends Node`
- Base class for game-level components. Provides `parent` (owning UGS) and `game` (UGS ancestor) references.
- Auto-resolves parent chain in `_ready()`.

### `Scripts/Core/universal_component_2d.gd` — `UniversalComponent2D extends Node2D`
- Node2D-based variant of UniversalComponent. Used for components that need spatial positioning (WaveSpawner, WaveDirector, etc.).

### `Scripts/Core/collision_matrix.gd` — `CollisionMatrix extends RefCounted`
- Auto-configures collision layers/masks from group definitions. Supports both `UniversalBody` and non-body nodes via `CollisionMarker` children.
- **Known limitation:** Only watches direct children of the UGS root (`child_entered_tree`). Bodies parented to other bodies (e.g., RingSpawner bricks as children of a UFO) will NOT be auto-configured. Workaround: parent spawned entities to the game root and manually track position.

### `Scripts/Core/collision_group.gd` — `CollisionGroup extends Resource`
- Custom resource defining a collision group name and its target groups. Used in UGS `collision_groups` export array.

### `Scripts/Core/property_override.gd` — `PropertyOverride extends Resource`
- Custom resource for spawn-time property configuration. Stores `node_path`, `property_name`, and `value`. Used in WaveSpawner `property_overrides` array. Handles typed array conversion via `Array.assign()`.

### `Scripts/Core/common_enums.gd` — `CommonEnums extends RefCounted`
- Shared enumerations: `Element` (UI identifiers), `State` (ATTRACT/PLAYING/PAUSED/GAME_OVER), `ScoreType` (P1_SCORE/P2_SCORE/GENERIC_SCORE), `Trigger` (GROUP_CLEARED/TIMER_EXPIRED/LIVES_DEPLETED/GAME_START), `SpawnPattern` (SCREEN_EDGES/SCREEN_CENTER/GRID/POSITION), `AdjustmentMode` (ADD/MULTIPLY/SET), `Condition` (GREATER_OR_EQUAL/LESS_OR_EQUAL), `Result` (VICTORY/DEFEAT), `DisplayMode` (P1_P2_SCORE/POINTS_MULTIPLIER).

---

## Body Scripts & Scene Organization

### Design Philosophy

Body scripts (`Scripts/Bodies/*.gd`) contain **drawing code only** — they define the visual shape, colors, and `_draw()` calls. All gameplay behavior is handled by attached components.

Body **scenes** (`Scenes/Bodies/`) are organized into three tiers that tie specific visuals to specific behaviors:

```
Scenes/Bodies/
├── generic/        — Archetype templates (no brain, no faction, no color override)
├── player/         — Pre-rigged for player control (player brain, friendly color, player groups)
└── nonplayer/      — Pre-rigged as threats/obstacles (AI brains, hostile color, enemy groups)
```

**Why three tiers?**
1. **Generic** bodies are close recreations of arcade archetypes — the "canonical" version of an entity with its mechanical components attached but no faction or control scheme assigned. These serve as base templates and are used directly when an entity has no allegiance (e.g., asteroids, bricks).
2. **Player** bodies add a specific friendly color, player control brain, and player collision groups. Games drop these in as the player entity without further configuration.
3. **Nonplayer** bodies add hostile visuals (immediately readable as "threat"), AI brains pre-configured for opposition, and enemy collision groups. Games use these as opponents.

This ensures that **visual identity = behavioral identity** — the player always knows what something does by what it looks like, even as they cycle through dozens of games in rapid succession.

### Current Body Scene Inventory

```
Scenes/Bodies/generic/
├── asteroid.tscn
├── ball.tscn
├── brick.tscn
├── brick_damaging.tscn          — Brick variant that deals damage on contact
├── bullet_simple.tscn
├── bullet_simple_smallsound.tscn — Small bullet variant for Space Invaders
├── bullet_wrapping.tscn
├── invader.tscn                 — Space Invaders alien (base archetype)
├── mystery_ship.tscn            — Space Invaders mystery/UFO ship
├── paddle.tscn
├── tetromino.tscn               — Multi-block tetromino piece (4 cells)
├── tetromino_single.tscn        — Single tetromino cell/block
├── triangle_ship.tscn           — Classic Asteroids ship
├── triangle_ship_modern.tscn    — Modern twin-stick ship
├── ufo.tscn
└── ufo_shielded.tscn            — UFO with RingSpawner brick shield

Scenes/Bodies/player/
├── player_paddle.tscn
├── player_paddle_cannon.tscn    — Space Invaders player cannon
├── player_triangle_ship.tscn
└── player_triangle_ship_modern.tscn

Scenes/Bodies/nonplayer/
├── nonplayer_invader.tscn       — Space Invaders alien (enemy-rigged)
├── nonplayer_paddle.tscn
├── nonplayer_triangle_ship.tscn
└── nonplayer_triangle_ship_modern.tscn
```

**Note:** Player/nonplayer bullet scenes were removed — bullets use generic scenes with collision groups configured per-game instead.

### `Scripts/Bodies/asteroid.gd` — extends UniversalBody
- Asteroid with procedural jagged polygon, three sizes (SMALL/MEDIUM/LARGE). **Drawing code only** — all behavior handled by attached components (Health, SplitOnDeath, ScoreOnDeath, ScreenWrap, DamageOnHit).
- Scene: `generic/asteroid.tscn` only (asteroids are factionless — no player/nonplayer variant)

### `Scripts/Bodies/ball.gd` — extends UniversalBody
- Pong-style ball. Minimal script — sets up collision shapes and draws a white square. All bouncing, deflection, acceleration, sound, and cleanup handled by attached components.
- Scene: `generic/ball.tscn` (balls are neutral — no player/nonplayer variant)

### `Scripts/Bodies/brick.gd` — extends UniversalBody
- Breakout brick with health-based coloring (green=1hp, yellow=2hp, orange=3hp, red=4hp). Redraws on health change. **Drawing code only** — all gameplay behavior handled by attached components.
- Scenes: `generic/brick.tscn`, `generic/brick_damaging.tscn` (variant that deals damage on contact)

### `Scripts/Bodies/bullet_simple.gd` — extends UniversalBody
- Simple bullet. Flies straight, despawns on physics hit or screen exit. All behavior via components (DamageOnHit, DieOnHit).
- Scene: `generic/bullet_simple.tscn` (player/nonplayer variants removed — use generic with per-game collision groups)

### `Scripts/Bodies/bullet_wrapping.gd` — extends UniversalBody
- Bullet with timer-based lifetime instead of screen exit detection. Otherwise identical to bullet_simple.
- Scene: `generic/bullet_wrapping.tscn` (player/nonplayer variants removed — use generic with per-game collision groups)

### `Scripts/Bodies/paddle.gd` — extends UniversalBody
- Pong-style paddle. Sets collision shape from exports. All movement, AI, and deflection handled by attached components.
- Scenes: `generic/paddle.tscn`, `player/player_paddle.tscn`, `nonplayer/nonplayer_paddle.tscn`

### `Scripts/Bodies/invader.gd` — extends UniversalBody
- Space Invaders alien invader. Draws one of three invader types (SQUID, NAUTILUS, CRAB) with 2-frame animation. **Drawing code only** — all behavior handled by attached components (SwarmAi, ShootAiSwarm, GridMovement, Health, ScoreOnDeath).
- Scenes: `generic/invader.tscn` (base), `nonplayer/nonplayer_invader.tscn` (pre-rigged with enemy AI + collision groups)

### `Scripts/Bodies/paddle_cannon.gd` — extends UniversalBody
- Space Invaders player cannon. Horizontal paddle shape with upward shooting. **Drawing code only** — all behavior handled by attached components (PlayerControl, DirectMovement, GunSimple, Health, DeathEffect).
- Scene: `player/player_paddle_cannon.tscn`

### `Scripts/Bodies/mystery_ship.gd` — extends UniversalBody
- Space Invaders mystery/UFO ship. Draws a rectangular UFO shape. **Drawing code only** — behavior from PatrolAi, ScoreOnDeath, and screen cleanup components.
- Scene: `generic/mystery_ship.tscn`

### `Scripts/Bodies/tetromino.gd` — extends UniversalBody
- Tetromino piece for Tetris and Tetris-remix games. **Drawing code only** — visual representation of a multi-cell grid piece. Grid snap movement, rotation, formation tracking, and line clearing handled by attached components (GridMovement, GridRotation, TetrominoFormation, FallingAI).
- Scenes: `generic/tetromino.tscn` (full tetromino), `generic/tetromino_single.tscn` (single cell)

### `Scripts/Bodies/triangle_ship.gd` — extends UniversalBody
- Triangular polyline ship shape with configurable color export. **Drawing code only** — all behavior handled by attached components.
- Scenes (two variants, each with all three tiers):
  - **Classic:** `generic/triangle_ship.tscn`, `player/player_triangle_ship.tscn`, `nonplayer/nonplayer_triangle_ship.tscn`
  - **Modern:** `generic/triangle_ship_modern.tscn`, `player/player_triangle_ship_modern.tscn`, `nonplayer/nonplayer_triangle_ship_modern.tscn`
  - Classic = EngineSimple + RotationDirect (original Asteroids controls)
  - Modern = EngineComplex + RotationTarget + DirectAcceleration + FrictionLinear (twin-stick controls)

### `Scripts/Bodies/ufo.gd` — extends UniversalBody
- UFO entity with configurable hitbox sized from exports. **Drawing code only** — all behavior defined by attached components.
- Scenes: `generic/ufo.tscn` (standard UFO), `generic/ufo_shielded.tscn` (UFO with RingSpawner brick shield for Asterout)

---

## Brain Scripts (Input & AI)

### `Scripts/Brains/player_control.gd` — extends Node
- Player control brain. Reads keyboard/mouse/gamepad every frame and forwards as input signals on parent UniversalBody.

### `Scripts/Brains/interceptor_ai.gd` — extends Node
- AI brain that steers toward closest node in a target group with adjustable turning speed and random aim inaccuracy. Group-based targeting. Emits `Vector2.ZERO` when no target exists.

### `Scripts/Brains/aim_ai.gd` — extends Node
- AI brain that aims at a target for rotation only (emits to `right_joystick`, not movement).

### `Scripts/Brains/shoot_ai.gd` — extends UniversalComponent
- AI brain that scans for targets in a vision cone and auto-fires when a target is detected. Checks angle difference and distance to determine if a target is in the cone, then emits `shoot` on a fire rate timer.
- Exports: `target_group: String`, `vision_cone_angle: float = 30`, `vision_range: float = 500`, `fire_rate: float = 2.0`
- Emits: `parent.shoot`

### `Scripts/Brains/shoot_ai_swarm.gd` — extends Node
- Formation-aware shooting AI for Space Invaders-style games. Checks that the body is on the edge of its formation before firing, preventing friendly fire and controlling which row shoots. Random roll odds ramp up to 100% as time approaches `max_shot_interval`, then reset on firing.
- Exports: `fire_directions`, `max_shot_interval`, `edge_margin`, `fire_direction: Vector2`
- **Plan 07 component** — designed for Space Invaders invader shooting

### `Scripts/Brains/patrol_ai.gd` — extends Node
- AI brain that follows a Curve2D path. Used for UFO patrol patterns in Asteroids. Generates random closed-loop paths and moves along them at configurable speed.
- **Known bug:** Start position may not be correctly set — needs user fix.

### `Scripts/Brains/falling_ai.gd` — extends Node
- Gravity as an input source. Emits `body.input_move(DOWN)` on a timer. Designed so gravity flows through the same signal chain as player input — everything routes through one movement leg. Can be paused (when piece is locked, during line clear animation).
- Exports: `fall_interval: float`, `paused: bool`
- **Plan 07 component** — designed for Tetris piece gravity

### `Scripts/Brains/swarm_ai.gd` — extends Node
- Antenna brain that receives commands from `swarm_controller` via signal bus and relays them as body movement signals. Intentionally thin — the intelligence lives in `swarm_controller`. Individual invaders remain autonomous and die independently.
- Exports: `bus_group: String` — which signal bus to connect to
- **Plan 07 component** — designed for Space Invaders invader movement

---

## Leg Scripts (Movement)

### `Scripts/Legs/direct_movement.gd` — extends Node
- Direct movement leg. Sets velocity from `move` direction or follows mouse position via `move_to`.

### `Scripts/Legs/direct_acceleration.gd` — extends Node
- Adds input direction as acceleration to velocity each frame. Supports optional mouse following.

### `Scripts/Legs/engine_simple.gd` — extends Node
- Simple Asteroids-style thrust engine. Accelerates in body's forward direction on thrust button, caps at top speed.

### `Scripts/Legs/engine_complex.gd` — extends Node
- Engine with acceleration ramp-up/down via jerk. Smooth thrust response for modern control feel.

### `Scripts/Legs/friction_linear.gd` — extends Node
- Linear friction proportional to current velocity up to max_friction. Runs at priority 50.

### `Scripts/Legs/friction_static.gd` — extends Node2D
- Constant deceleration friction that moves velocity toward zero at a fixed rate. Runs at priority 50.

### `Scripts/Legs/rotation_direct.gd` — extends Node
- Tank-style rotation. Turns left/right based on horizontal component of `move` input direction.

### `Scripts/Legs/rotation_target.gd` — extends Node
- Smoothly rotates toward mouse position or joystick direction. Supports `independant_aim` mode.

### `Scripts/Legs/grid_movement.gd` — extends UniversalComponent
- Self-contained step-based movement. Moves parent by a fixed `step_size` when `move` signal fires. Uses Godot `test_move()` for physics-based occupancy checks (no external grid dependency) and `UniversalBody.move_parent()` for boundary clamping. Supports hop delay, input queueing, direction locks, and hard drop.
- Exports: `step_size`, `hop_delay`, `allow_diagonal`, `block_on_collision`, `prevent_movement_up/down/left/right`, `enable_hard_drop`, `use_input_queue`, `max_queue_size`
- **Plan 07 component** — used by Space Invaders invaders, planned for Tetris pieces

### `Scripts/Legs/grid_rotation.gd` — extends Node
- Discrete rotation in configurable steps (default 90°, optional 45°). Ties facing direction to movement input and locks it to the grid. Purely handles rotation — does not move the body.
- Exports: `rotation_step: int`, `clockwise: bool`
- **Plan 07 component** — designed for Tetris tetromino rotation

### `Scripts/Legs/tetromino_formation.gd` — extends Node
- Manages a multi-cell shape on the grid. The tetromino is one body that occupies 4 grid cells via an offsets array. Handles rotation of offsets, landing detection, lock delay, cell registration in grid occupancy map, and visual sprite creation on lock. Interactable followers for remix scenarios.
- Exports: `offsets: Array[Vector2i]`, `lock_delay: float`, `formation_group: String`
- **Plan 07 component** — designed for Tetris, future Centipede-style games

### `Scripts/Legs/warp_asteroids.gd` — extends Node
- Emergency teleport with intangibility for Asteroids-style games. Warps the parent to a random position and grants temporary invulnerability.
- **Previously listed as "Asteroids Warp — Skipped/Future"** — now built.

---

## Arm Scripts (Weapons)

### `Scripts/Arms/gun_simple.gd` — extends Node
- Classic arcade gun. Spawns bullet scenes with configurable max count, muzzle offset, and speed. Supports joystick and mouse aiming.

### `Scripts/Arms/damage_on_hit.gd` — extends UniversalComponent
- Deals damage to colliders in `target_groups` that have a Health component. Generic collision handler — connects to configurable `listen_signal` on parent.
- Exports: `target_groups: Array[String]`, `damage_amount: int = 1`, `listen_signal: String = "body_collided"`
- Listens to: `parent.body_collided` (default)
- Emits: None (calls `collider.Health.reduce_health()` directly)

### `Scripts/Arms/damage_on_joust.gd` — extends UniversalComponent
- Compares parent and collider velocity on collision — faster body wins, slower body takes damage. Tie resolved by configurable `tie_breaker` (both damage or no damage).
- Exports: `damage_amount: int = 1`, `tie_breaker: Tie` (BOTH_DAMAGE / NO_DAMAGE)
- Listens to: `parent.body_collided`
- Emits: None (calls `collider.Health.reduce_health()` directly)

---

## Component Scripts (Gameplay Modifiers)

### `Scripts/Components/angled_deflector.gd` — extends UniversalComponent
- Calculates Pong-style deflection angle based on hit position relative to parent. Auto-connects to `parent.body_collided` and filters by `target_group`.

### `Scripts/Components/collision_marker.gd` — `CollisionMarker extends Node`
- Marker node that provides `collision_groups` data for `CollisionMatrix` to auto-configure non-UniversalBody nodes.

### `Scripts/Components/damage_on_hit.gd` → moved to `Scripts/Arms/damage_on_hit.gd`

### `Scripts/Components/death_effect.gd` — extends UniversalComponent
- Spawns visual effect scenes on parent death. Listens to sibling Health's `zero_health` signal and instantiates configured effect scenes at the parent's position.
- Exports: `effect_scenes: Array[PackedScene]`

### `Scripts/Components/die_on_hit.gd` — extends UniversalComponent
- Kills parent entity on collision. Separate from DamageOnHit for composition flexibility (bullets deal damage AND die, asteroids just take damage).
- Exports: `listen_signal: String = "body_collided"`
- Listens to: configurable signal on parent
- Emits: None (calls `parent.queue_free()`)

### `Scripts/Components/die_on_timer.gd` — extends UniversalComponent
- Kills parent entity after a configurable timer expires.

### `Scripts/Components/health.gd` — extends Node
- Health tracker. On death: hides parent, disables all colliders, disables child components, plays death sound, calls `queue_free()`.
- Emits: `health_changed(current_health, parent)`, `zero_health(parent)`

### `Scripts/Components/pong_acceleration.gd` — extends UniversalComponent
- Ramps ball velocity through configurable speed levels on paddle collision. Auto-connects to `parent.body_collided` and filters by `target_group`.

### `Scripts/Components/ring_spawner.gd` — extends UniversalComponent
- Spawns entities (typically bricks) in a ring pattern around the parent body. Supports configurable radius, count, brick size, health, and optional orbit rotation.
- Exports: `spawn_scene: PackedScene`, `ring_radius: float = 30.0`, `spawn_count: int = 12`, `brick_size: Vector2`, `brick_health: int = 1`, `spawn_groups: Array[String]`, `orbit_speed: float = 0.0` (radians/sec; 0 = static, positive = orbit)
- **Known issue:** Bricks must be parented to game root (not the UFO body) for CollisionMatrix to detect them. Requires manual position tracking in `_process()` to follow parent movement.

### `Scripts/Components/score_on_death.gd` — extends UniversalComponent
- Awards points to the game score when the parent entity dies (listens to sibling Health's `zero_health` signal).
- Exports: `score_amount: int`
- Listens to: `$Health.zero_health`
- Emits: Calls `game.add_score()`

### `Scripts/Components/score_on_hit.gd` — extends UniversalComponent
- Awards points when the parent entity collides with something. Must be on the scoring entity (e.g., the ball, not the paddle).
- Exports: `score_amount: int`, `listen_signal: String`
- Listens to: configurable signal on parent
- Emits: Calls `game.add_score()`

### `Scripts/Components/screen_cleanup.gd` — extends UniversalComponent
- Removes (queuefree) parent entity when it moves outside the viewport bounds plus configurable margin.

### `Scripts/Components/screen_wrap.gd` — extends Node
- Asteroids-style screen wrapping. Warps parent to opposite edge when beyond viewport bounds plus margin.

### `Scripts/Components/split_on_death.gd` — extends Node
- Spawns smaller fragment scenes when parent dies. Decrements size enum (LARGE→MEDIUM→SMALL).

### `Scripts/Components/vector_engine_exhaust.gd` — extends UniversalComponent
- Visual-only component that draws engine exhaust flame behind the parent ship when thrusting. Adds to the ship's visual feedback without affecting gameplay.

---

## Effect Scripts (Visual Effects)

### `Scripts/Effects/death_particles.gd`
- Self-destructing particle burst effect. Plays on entity death and frees itself when complete.

### `Scripts/Effects/death_broken_triangle_ship.gd`
- Self-destructing ship debris effect. Spawns broken triangle line fragments that drift apart. Plays on ship death and frees itself when complete.

---

## Rule Scripts (Game Logic)

### `Scripts/Rules/goal.gd` — extends UniversalComponent
- Marks a parent Area2D as a scoring zone. On `body_entered`, increments the appropriate score on the UGS. Supports `lose_life` and `extra_life` modes.
- Exports: `score_type: CommonEnums.ScoreType`, `score_amount: int = 1`
- Listens to: `parent.body_entered`

### `Scripts/Rules/points_monitor.gd` — extends UniversalComponent
- Monitors a UGS score signal against a configurable threshold. When the condition is met, emits `victory()` or `defeat()` on the UGS.

### `Scripts/Rules/variable_tuner.gd` — extends UniversalComponent
- Listens for a signal on a configurable source node and adjusts a property on the parent node. Used for AI difficulty ramping.

### `Scripts/Rules/group_monitor.gd` — extends Node
- Polls a named group each frame. Emits signals on parent game script when group count transitions:
  - `group_cleared` — when count drops from >0 to 0 (existing behavior)
  - `group_member_removed` — when count decreases by any amount (fires on each individual removal)
- Both signals include the group name as an argument. `group_member_removed` supports per-death tracking (e.g., boosting AI difficulty each time a brick is destroyed).

### `Scripts/Rules/group_count_multiplier.gd` — extends UniversalComponent
- Sets the game's score multiplier to the count of entities in a target group. Used for Asteroids-style risk/reward (more asteroids = higher multiplier).
- Exports: `target_group: String`
- Listens to: None (polls group count each physics frame)

### `Scripts/Rules/lives_counter.gd` — extends Node
- Manages player lives. Decrements on `lose_life()`, emits when lives change or reach zero.

### `Scripts/Rules/timer.gd` — extends UniversalComponent
- Game timer with count-up or count-down modes. Supports `auto_start` (starts on `game.on_game_start`), `loop_timer`, and configurable `tick_interval`.
- Exports: `duration`, `count_up`, `tick_interval`, `loop_timer`, `auto_start`
- Emits (on parent): `timer_tick`, `timer_expired`

### `Scripts/Rules/line_clear_monitor.gd` — extends UniversalComponent
- Generic line-clear detection. Monitors a `grid_basic` for completed lines (horizontal, vertical, or both) and clears them. On detection: clears the line, shifts remaining cells, emits score signal. Configurable for horizontal/vertical/both directions.
- Exports: `grid_name`, `check_horizontal`, `check_vertical`, `clear_direction`, `score_per_line`
- **Plan 07 component** — designed for Tetris, future puzzle/remix games

### `Scripts/Rules/wave_director.gd` — extends UniversalComponent2D
- Connects to a game signal and triggers wave spawning after a configurable delay. Supports four trigger types: `GROUP_CLEARED`, `TIMER_EXPIRED`, `LIVES_DEPLETED`, `GAME_START`. Has `max_waves` limit and game over guard.
- Exports: `trigger_type`, `trigger_value`, `wave_delay`, `max_waves`
- Listens to: Configured trigger signal
- Emits (on parent): `spawning_wave`

### `Scripts/Rules/wave_spawner.gd` — extends UniversalComponent2D
- Spawns entities in patterns (SCREEN_EDGES, SCREEN_CENTER, GRID, POSITION). Expression-based count equations with `wave_number` variable. Features:
  - **Safe zone:** Waits for unsafe groups to vacate a radius around the spawner before spawning
  - **Spawn groups:** Adds spawned entities to configurable groups via `add_to_group()`
  - **Spawn components:** Attaches additional component scenes to spawned entities
  - **Property overrides:** Configures spawned entity properties with typed array support
  - **Game over guards:** Checks game state before spawning and on each staggered spawn
  - **GRID pattern:** Configurable columns, rows, spacing, and health-by-row
- Exports: `spawn_scene`, `spawn_pattern`, `spawn_count_equation`, `spawn_radius`, `stagger_delay`, `director`, `spawn_components`, `property_overrides`, `spawn_groups`, `use_safe_zone`, `unsafe_groups`, `safety_radius`, grid exports, velocity/angle/flip exports
- Listens to: `game.spawning_wave`
- Emits (on game): `spawning_wave_complete`

---

## Flow Scripts (Wave Management, Grid, Audio & UI)

### `Scripts/Flow/interface.gd` — extends Control
- Reusable HUD with two display modes (`P1_P2_SCORE` for competitive, `POINTS_MULTIPLIER` for single-player). Auto-connects to parent UGS signals.

### `Scripts/Flow/sound_on_hit.gd` — extends UniversalComponent
- Plays a sound when the parent experiences a collision. Auto-detects Area2D vs UniversalBody parents.

### `Scripts/Flow/sound_synth.gd` — extends UniversalComponent2D
- Procedural audio synthesis component. Generates audio waveforms programmatically (SQUARE, TRIANGLE, SAWTOOTH, SINE, NOISE) with configurable frequency, duration, effects (WARBLE, TREMOLO, SWEEP_DOWN, DECAY), and volume. Supports CONTINUOUS and ON_SIGNAL play modes with exclusive option.
- **Performance features (Plan 09):** Voice limiting (`MAX_VOICES=6`), fill rate cap (`MAX_FILL_PER_FRAME=256`), and CONTINUOUS deduplication registry — modeled after arcade hardware polyphony caps. Only one synth per unique sound profile plays at a time; excess instances stay silent and automatically take over if the active synth dies.
- The foundation of the audio system — all game sounds are generated procedurally, no audio files needed.

### `Scripts/Flow/music_ramping.gd` — extends UniversalComponent
- Reactive music component that adjusts playback based on a monitored group's count. Uses SoundSynth instances as "templates" — loops a sound with pitch scaling as group count → 0. Creates the classic "music speeds up as danger decreases" effect (Asteroids style).
- Exports: `target_group: String`, synth template configuration

### `Scripts/Flow/sfx_ramping.gd` — extends UniversalComponent
- Dynamic SFX component that plays sounds with pitch/volume scaling based on group count or other parameters.

### `Scripts/Flow/beep.gd` — extends UniversalComponent
- Simple procedural beep sound. Lightweight alternative to SoundSynth for basic audio feedback.

### `Scripts/Flow/grid_basic.gd` — extends UniversalComponent
- Defines a grid in the scene with active occupancy tracking. Exposes coordinate conversion (`grid_to_world`, `world_to_grid`), bounds checking, and a 2D occupancy array where bodies register/unregister cells. Foundation for all grid-based games.
- Exports: `rows: int`, `columns: int`, `cell_size: Vector2`, `origin: Vector2`
- **Plan 07 component** — shared foundation for Space Invaders and Tetris

### `Scripts/Flow/swarm_controller.gd` — extends UniversalComponent
- Orchestrates synchronized movement of all invaders in a swarm. Signal bus pattern — emits `swarm_move(direction)` that each `swarm_ai` brain connects to. Tracks member positions, detects boundary hits for direction reversal + step-down, and speed-ramps tick interval as members die.
- Exports: `base_tick_interval`, `min_tick_interval`, `speed_ramp_enabled`, `step_down_distance`, `invader_group`, `bus_group`
- **Plan 07 component** — designed for Space Invaders, future swarm-based games

### `Scripts/Flow/tetromino_spawner.gd` — extends UniversalComponent
- Spawns the next tetromino piece at the top of the grid. Maintains a bag/queue of upcoming pieces, configures `falling_ai` fall interval on each new piece, and signals the next piece to `interface` for preview display.
- Exports: `piece_pool`, `spawn_position`, `randomizer_mode`
- **Plan 07 component** — designed for Tetris

---

## Game Scenes (All Componentized)

Games are organized into three categories:

```
Scenes/Games/
├── originals/     — New games unique to CD50
├── remakes/       — Classic arcade recreations
└── remixes/       — Mashups combining elements from multiple games
```

### `Scenes/Games/remakes/pong.tscn` — UniversalGameScript root + components
- **Pong.** No game-specific script. Assembled entirely from UGS + components.
- Root: `UniversalGameScript` with collision groups (balls, walls, paddles, goals)
- Player paddle: PlayerControl + DirectMovement
- Opponent paddle: InterceptorAi + DirectMovement + VariableTuner (difficulty ramping)
- Ball: AngledDeflector + PongAcceleration + ScreenCleanup + SoundOnHit
- Goals: Area2D + Goal + CollisionMarker + SoundOnHit
- Flow: GroupMonitor (balls) → WaveDirector → WaveSpawner (spawn at game start, random angle)
- Rules: PointsMonitor × 2 (P1 score ≥ 11 = victory, P2 score ≥ 11 = defeat)
- UI: Interface (P1_P2_SCORE mode)

### `Scenes/Games/remakes/breakout.tscn` — UniversalGameScript root + components
- **Breakout.** No game-specific script. Assembled entirely from UGS + components.
- Uses GRID spawn pattern for brick layout with health-by-row
- Ball: DamageOnHit (target_groups: bricks) + ScoreOnHit + DieOnHit + ScreenCleanup
- Bricks: Health + ScoreOnDeath
- Goals: Area2D + Goal (lose_life mode)
- Rules: GroupMonitor (bricks) → WaveDirector → WaveSpawner
- UI: Interface (POINTS_MULTIPLIER mode)

### `Scenes/Games/remakes/asteroids.tscn` — UniversalGameScript root + components
- **Asteroids (polished).** No game-specific script. Full recreation with death effects, UFO, reactive music.
- Player ship: PlayerControl + EngineSimple + FrictionLinear + RotationDirect + GunSimple + ScreenWrap + DeathEffect + VectorEngineExhaust
- Bullets: DamageOnHit (target_groups: asteroids) + DieOnHit + ScreenCleanup + SoundSynth (shoot sound)
- Asteroids: Health + SplitOnDeath + ScoreOnDeath + ScreenWrap + DeathEffect (particles)
- UFO: PatrolAi + AimAi + ShootAi + GunSimple + Health + ScoreOnDeath + ScreenWrap + DeathEffect
- Flow: WaveDirector (GAME_START trigger) → WaveSpawner (SCREEN_EDGES, safe zone) + Timer (auto_start, loop) → WaveDirector → WaveSpawner + Timer → WaveSpawner (UFO spawn)
- Rules: GroupMonitor (asteroids) + GroupCountMultiplier (asteroids) + LivesCounter
- Audio: MusicRamping (reactive pitch scaling based on asteroid count)
- UI: Interface (POINTS_MULTIPLIER mode)

### `Scenes/Games/remixes/pongsteroids.tscn` — UniversalGameScript root + components
- **Pongsteroids.** No game-specific script. Pong + Asteroids hybrid assembled from both games' components.
- Pong layer: paddles, ball, goals (same as pong.tscn)
- Asteroids layer: asteroid spawner + asteroid entities with Health + SplitOnDeath + ScreenWrap
- Validates cross-game component mixing — zero new components needed

### `Scenes/Games/originals/dogfight.tscn` — UniversalGameScript root + components
- **Dogfight.** Player triangle ship vs escalating waves of AI triangle ships, with asteroids as neutral obstacles. No game-specific script.
- Collision groups: players, enemies, players_bullets, enemies_bullets, asteroids (5-way factional warfare)
- Player ship: TriangleShipModern + PlayerControl + ScoreOnDeath (enemy scores on player death)
- Enemy ships: TriangleShipModern + InterceptorAi (chases player, turning_speed=360) + AimAi (aims at player) + ShootAi (auto-fires in vision cone) + ScoreOnDeath (player scores on enemy death)
- Asteroids: AngledDeflector + random velocity + Timer-spawned every 6 seconds
- Flow: GroupMonitor(players) → WaveDirector → WaveSpawner (respawn 1 player); GroupMonitor(enemies) → WaveDirector → WaveSpawner (spawn wave_number enemies); Timer → WaveSpawner (1 asteroid per tick)
- Rules: LivesCounter (10 lives, Asteroids-style game over on depletion)
- Uses factional bullets — players_bullets hit enemies/asteroids, enemies_bullets hit players/asteroids, asteroids hit everyone

### `Scenes/Games/remixes/pongout.tscn` — UniversalGameScript root + components
- **Pongout.** Pong where goals are shielded by Breakout bricks. One goal ends the game. No game-specific script.
- Two paddles (player + InterceptorAi opponent) with DirectMovement
- Ball with DamageOnHit (bricks) + AngledDeflector + PongAcceleration
- Two brick grids shielding each goal — player must break through opponent's bricks to score
- VariableTuner on AI: boosts turning_speed as player destroys opponent's bricks (defensive ramping)
- Goals: Area2D + Goal (first to score wins)
- Rules: PointsMonitor × 2 (first goal = victory/defeat)
- Flow: WaveDirector/WaveSpawner for ball respawn + brick grid spawn
- UI: Interface (P1_P2_SCORE mode)

### `Scenes/Games/remixes/breaksteroids.tscn` — UniversalGameScript root + components
- **Breaksteroids.** Paddle + ball vs asteroid grid. Asteroids have health and split. No game-specific script.
- Paddle at bottom with PlayerControl + DirectMovement + AngledDeflector
- Ball with DamageOnHit (asteroids) + ScreenCleanup
- Asteroid grid spawned via WaveSpawner (GRID pattern, random velocities for "pinball" feel)
- Bottom Goal = lose life (ball falls off screen)
- Rules: LivesCounter + GroupMonitor (asteroids cleared = next wave)
- Audio: MusicRamping (reactive music based on asteroid count)
- Notable emergent property: randomized asteroid collision shapes create unpredictable deflections — plays like "space pinball"

### `Scenes/Games/remakes/space_invaders.tscn` — UniversalGameScript root + components
- **Space Invaders.** No game-specific script. Assembled entirely from UGS + components.
- Root: `UniversalGameScript` with 4 collision groups (players, enemies, players_bullets, enemies_bullets)
- Player cannon: PaddleCannon (PlayerControl + DirectMovement + GunSimple + Health + DeathEffect)
- Invaders: 5×11 formation (3 WaveSpawners — SQUID row, NAUTILUS rows, CRAB rows) with SwarmAi + ShootAiSwarm + GridMovement + Health + ScoreOnDeath
- SwarmController: Signal bus movement with speed ramping, boundary reversal + step-down
- Mystery ship: Timer-spawned (20s loop) via WaveDirector + WaveSpawner, PatrolAi movement
- Barriers: 4 grids of 1-HP bricks (use_health_color=false for white coloring), invaders crush them on contact via DamageOnHit
- Flow: GroupMonitor (enemies) → WaveDirector → WaveSpawner loop; GroupMonitor (players) → respawn with safe zone
- Audio: SoundSynth (ON_SIGNAL) connected to SwarmController.swarm_move for heartbeat bass riff, gameplay_only gate
- Rules: LivesCounter + SwarmController bottom_action=LOSE_LIFE
- UI: Interface (POINTS_MULTIPLIER mode)

### `Scenes/Games/remixes/asterout.tscn` — UniversalGameScript root + components
- **Asterout.** ⚠️ EXISTS BUT NOT WORKING WELL — needs to be remade. Modern controls + UFO dogfighting with brick shields.
- Current issues: RingSpawner bricks don't collide with player bullets (CollisionMatrix blindspot — bricks parented to UFO body instead of game root)
- Design concept: player ship vs shielded UFOs (brick ring around UFO), break through shield to damage UFO
- Should be rebuilt with RingSpawner fix (parent to game root + manual position tracking)

---

## Debug Scenes

### `Scenes/Debug/grid_test.tscn`
- Test scene for validating grid-based components (GridBasic, GridMovement, GridRotation). Used during Plan 07 development.

---

## Signal Flow Architecture

```
INPUT (keyboard/mouse/gamepad)
  ↓
BRAINS (player_control, interceptor_ai, aim_ai, patrol_ai, shoot_ai, shoot_ai_swarm, swarm_ai, falling_ai)
  ↓ emit on UniversalBody input signals
UNIVERSAL BODY (routes input → output with axis locks)
  ↓ emit processed output signals
LEGS (direct_movement, engine_simple, grid_movement, grid_rotation, tetromino_formation, warp_asteroids, etc.) → modify parent velocity/position
ARMS (gun_simple, damage_on_hit, damage_on_joust) → spawn bullets, deal damage
  ↓
COMPONENTS (angled_deflector, pong_acceleration, die_on_hit, score_on_death, screen_cleanup, death_effect, ring_spawner, vector_engine_exhaust) → react to collisions/life events
RULES (goal, points_monitor, group_monitor, group_count_multiplier, lives_counter, variable_tuner, timer, line_clear_monitor, wave_director, wave_spawner) → emit game events on UGS
FLOW (interface, sound_on_hit, sound_synth, music_ramping, sfx_ramping, beep, grid_basic, swarm_controller, tetromino_spawner) → manage spawning, grids, sounds, HUD, timing
  ↓
EFFECTS (death_particles, death_broken_triangle_ship) → self-destructing visual effects
```

**Key signals on UniversalBody:**
- Input (Brains emit these): `left_joystick`, `right_joystick`, `mouse_position`, `button_pressed`, `button_released`
- Output (Legs/Arms listen): `move`, `move_to`, `action`, `end_action`, `shoot`, `end_shoot`, `thrust`, `end_thrust`, `aim`, `aim_at`
- Collision (Components listen): `body_collided(collider, normal)`

**Key signals on UniversalGameScript:**
- From Rules: `victory`, `defeat`, `group_cleared`, `group_member_removed`, `lives_changed`, `lives_depleted`, `timer_tick`, `timer_expired`, `spawning_wave`, `spawning_wave_complete`
- To Rules/UI: `on_game_start`, `on_game_end`, `on_game_over`, `on_points_changed`, `on_multiplier_changed`, `state_changed`, `on_p1_score`, `on_p2_score`

---

## Assets

- **Audio:** Procedural synthesis via SoundSynth component (all game audio generated at runtime)
- **Audio files:** Kenney game audio pack (lasers, power-ups, zaps, phase jumps, space trash, pep sounds, tones) — available but largely superseded by procedural synthesis
- **Fonts:** Kenney retro fonts (Pixel, High, Mini, Rocket, Future, Blocks, Square — regular and narrow variants)
- **CRT Addon:** Custom CRT post-processing effect
- **Effects:** Self-destructing effect scenes (death_particles, death_broken_triangle_ship)

---

## Component Catalog

| Category | Count | Components |
|----------|-------|------------|
| Core | 8 | universal_body, universal_game_script, universal_component, universal_component_2d, collision_matrix, collision_group, property_override, common_enums |
| Bodies | 12 | ball, paddle, asteroid, brick, bullet_simple, bullet_wrapping, tetromino, triangle_ship, ufo, invader, paddle_cannon, mystery_ship |
| Brains | 8 | player_control, interceptor_ai, aim_ai, shoot_ai, shoot_ai_swarm, patrol_ai, falling_ai, swarm_ai |
| Legs | 12 | direct_movement, direct_acceleration, engine_simple, engine_complex, friction_linear, friction_static, rotation_direct, rotation_target, grid_movement, grid_rotation, tetromino_formation, warp_asteroids |
| Arms | 3 | gun_simple, damage_on_hit, damage_on_joust |
| Components | 14 | angled_deflector, collision_marker, death_effect, die_on_hit, die_on_timer, health, pong_acceleration, ring_spawner, score_on_death, score_on_hit, screen_cleanup, screen_wrap, split_on_death, vector_engine_exhaust |
| Rules | 8 | goal, points_monitor, variable_tuner, group_monitor, group_count_multiplier, lives_counter, timer, line_clear_monitor |
| Flow | 11 | interface, sound_on_hit, sound_synth, music_ramping, sfx_ramping, beep, grid_basic, swarm_controller, tetromino_spawner, wave_director*, wave_spawner* |
| Effects | 2 | death_particles, death_broken_triangle_ship |
| **Total** | **75** | |

*\* wave_director and wave_spawner scripts live in `Scripts/Rules/` but are categorized as Flow by function (wave/spawn management).*
</task_progress>
</task_progress>
</write_to_file>
</invoke>