# Current Status: GD50 — Arcade Cabinet

**Last Updated:** 2026-04-16  
**Engine:** Godot 4.x (GDScript)  
**Architecture:** Entity-Component (composition over inheritance)  
**Playable Games:** Pong (componentized), Breakout, Asteroids, Pongsteroids (hybrid)

---

## Project Overview

GD50 is a modular arcade game collection built around a composable component architecture. Games are assembled from reusable components (Brains, Legs, Arms, Components, Rules, Flow) attached to generic `UniversalBody` (entity) and `UniversalGameScript` (game) base classes. The signal flow is: **Brains** read input → emit on **UniversalBody** input signals → UniversalBody routes to processed output signals → **Legs/Arms** listen to output signals and act. **Rules** components manage game logic (scores, groups, conditions). **Flow** components manage waves, spawning, and UI.

---

## Core Scripts

### `Scripts/Core/universal_body.gd` — `UniversalBody extends CharacterBody2D`
- Base class for all physical entities. Routes input signals from Brains to processed output signals (axis locks applied). Provides position clamping and physics-based movement with automatic velocity bouncing.
- **`_physics_process()`** calls `move_parent_physics()` by default — uses `move_and_collide()` for collision detection, auto-bounces velocity on collision, and emits `body_collided`.
- Listens to (internally connected): `left_joystick`, `right_joystick`, `mouse_position`, `button_pressed`, `button_released`
- Emits (routed outputs): `move`, `move_to`, `action`, `end_action`, `shoot`, `end_shoot`, `thrust`, `end_thrust`, `aim`, `aim_at`, `body_collided(collider, normal)`

### `Scripts/Core/universal_game_script.gd` — `UniversalGameScript extends Node2D`
- Master class for game coordinators. Generic container with **zero game-specific logic**. State machine (ATTRACT/PLAYING/PAUSED/GAME_OVER), P1/P2 + generic score tracking, collision matrix setup. All game behavior comes from attached Rule/Flow/Component nodes.
- **Signals FROM components:** `victory`, `defeat`, `group_cleared`, `lives_changed`, `lives_depleted`, `timer_tick`, `timer_expired`, `spawning_wave`, `spawning_wave_complete`
- **Signals TO components/UI:** `on_game_start`, `on_game_end`, `on_game_over`, `on_points_changed`, `on_multiplier_changed`, `state_changed`, `on_p1_score`, `on_p2_score`
- Self-connects `victory` → `p1_win()` and `defeat` → `p1_lose()` in `_ready()`
- Static helper: `find_ancestor(node)` walks tree to find the UGS

### `Scripts/Core/collision_matrix.gd` — `CollisionMatrix extends RefCounted`
- Auto-configures collision layers/masks from group definitions. Supports both `UniversalBody` and non-body nodes via `CollisionMarker` children.
- Listens to: `child_entered_tree`, `child_exiting_tree` on the game script
- Emits: None

### `Scripts/Core/collision_group.gd` — `CollisionGroup extends Resource`
- Custom resource defining a collision group name and its target groups. Used in UGS `collision_groups` export array.

### `Scripts/Core/property_override.gd` — `PropertyOverride extends Resource`
- Custom resource for spawn-time property configuration. Stores `node_path`, `property_name`, and `value`. Used in WaveSpawner `property_overrides` array.

### `Scripts/Core/common_enums.gd` — `CommonEnums extends RefCounted`
- Shared enumerations: `Element` (UI identifiers), `State` (ATTRACT/PLAYING/PAUSED/GAME_OVER), `ScoreType` (P1_SCORE/P2_SCORE/GENERIC_SCORE), `Trigger` (GROUP_CLEARED/TIMER_EXPIRED/LIVES_DEPLETED), `SpawnPattern` (SCREEN_EDGES/SCREEN_CENTER/GRID), `AdjustmentMode` (ADD/MULTIPLY/SET), `Condition` (GREATER_OR_EQUAL/LESS_OR_EQUAL), `Result` (VICTORY/DEFEAT), `DisplayMode` (P1_P2_SCORE/POINTS_MULTIPLIER).

---

## Body Scripts

### `Scripts/Bodies/ball.gd` — extends UniversalBody
- Pong-style ball. Minimal script — sets up collision shapes and draws a white square. All bouncing, deflection, acceleration, sound, and cleanup handled by attached components (AngledDeflector, PongAcceleration, SoundOnHit, ScreenCleanup).
- Listens to: None (all behavior via components)
- Emits: None (beyond inherited `body_collided` from physics movement)

### `Scripts/Bodies/paddle.gd` — extends UniversalBody
- Pong-style paddle. Sets collision shape from exports. All movement, AI, and deflection handled by attached components.
- Listens to: None
- Emits: None (beyond inherited UniversalBody signals)

### `Scripts/Bodies/asteroid.gd` — extends UniversalBody
- Asteroid with procedural jagged polygon, physics bouncing, three sizes (SMALL/MEDIUM/LARGE). Damages colliders that have a Health component.
- Listens to: None
- Emits: `AsteroidCollision`

### `Scripts/Bodies/brick.gd` — extends UniversalBody
- Breakout brick with health-based coloring (green=1hp, yellow=2hp, orange=3hp, red=4hp). Redraws on health change.
- Listens to: `$Health.health_changed`
- Emits: None

### `Scripts/Bodies/bullet_simple.gd` — extends UniversalBody
- Simple bullet. Flies straight, despawns on physics hit or screen exit, disables colliders and plays sound before freeing.
- Listens to: `$HitBox.body_entered`, `$VisibleOnScreenNotifier2D.screen_exited`
- Emits: `BulletCollision`

### `Scripts/Bodies/bullet_wrapping.gd` — extends UniversalBody
- Bullet with timer-based lifetime instead of screen exit detection. Otherwise identical to bullet_simple.
- Listens to: `$HitBox.body_entered`, `$Timer.timeout`
- Emits: `BulletCollision`

### `Scripts/Bodies/triangle_ship.gd` — extends UniversalBody
- Asteroids player ship with triangular polyline shape. Bounces on collision, damages colliders with Health component.
- Listens to: None
- Emits: `TriangleShipCollision`

### `Scripts/Bodies/ufo.gd` — extends UniversalBody
- UFO entity with configurable hitbox sized from exports. All behavior defined by attached components.
- Listens to: None
- Emits: None (beyond inherited UniversalBody signals)

---

## Brain Scripts (Input & AI)

### `Scripts/Brains/player_control.gd` — extends Node
- Player control brain. Reads keyboard/mouse/gamepad every frame and forwards as input signals on parent UniversalBody.
- Listens to: Input system directly (`_unhandled_input`, `Input.get_axis`)
- Emits (on parent): `mouse_position`, `button_pressed`, `button_released`, `left_joystick`, `right_joystick`

### `Scripts/Brains/interceptor_ai.gd` — extends Node
- AI brain that steers toward closest node in a target group with adjustable turning speed and random aim inaccuracy. Group-based targeting (finds closest valid node each frame). Emits `Vector2.ZERO` when no target exists. Initializes aim angle on first acquisition to avoid sweeping.
- Listens to: None (reads group nodes directly each frame)
- Emits (on parent): `left_joystick`

### `Scripts/Brains/aim_ai.gd` — extends Node
- AI brain that aims at a target for rotation only (emits to `right_joystick`, not movement).
- Listens to: None (reads target position directly each frame)
- Emits (on parent): `right_joystick`

---

## Leg Scripts (Movement)

### `Scripts/Legs/direct_movement.gd` — extends Node
- Direct movement leg. Sets velocity from `move` direction or follows mouse position via `move_to`. Supports optional physics collision.
- Listens to: `parent.move`, `parent.move_to`
- Emits: None

### `Scripts/Legs/direct_acceleration.gd` — extends Node
- Adds input direction as acceleration to velocity each frame. Supports optional mouse following.
- Listens to: `parent.move`, `parent.move_to`
- Emits: None

### `Scripts/Legs/engine_simple.gd` — extends Node
- Simple Asteroids-style thrust engine. Accelerates in body's forward direction on thrust button, caps at top speed.
- Listens to: `parent.move`, `parent.thrust`, `parent.end_thrust`
- Emits: None

### `Scripts/Legs/engine_complex.gd` — extends Node
- Engine with acceleration ramp-up/down via jerk. Smooth thrust response for modern control feel.
- Listens to: `parent.move`, `parent.thrust`, `parent.end_thrust`
- Emits: None

### `Scripts/Legs/friction_linear.gd` — extends Node
- Linear friction proportional to current velocity up to max_friction. Runs at priority 50 (after engines, before body).
- Listens to: None (reads `parent.velocity` directly)
- Emits: None

### `Scripts/Legs/friction_static.gd` — extends Node2D
- Constant deceleration friction that moves velocity toward zero at a fixed rate. Runs at priority 50.
- Listens to: None (reads `parent.velocity` directly)
- Emits: None

### `Scripts/Legs/rotation_direct.gd` — extends Node
- Tank-style rotation. Turns left/right based on horizontal component of `move` input direction.
- Listens to: `parent.move`
- Emits: None

### `Scripts/Legs/rotation_target.gd` — extends Node
- Smoothly rotates toward mouse position or joystick direction. Supports `independant_aim` mode.
- Listens to: `parent.move_to` (default) OR `parent.aim` + `parent.aim_at` (independent aim mode)
- Emits: None

---

## Arm Scripts (Weapons)

### `Scripts/Arms/gun_simple.gd` — extends Node
- Classic arcade gun. Spawns bullet scenes with configurable max count, muzzle offset, and speed. Supports joystick and mouse aiming.
- Listens to: `parent.shoot`, `parent.aim`, `parent.aim_at`
- Emits: `target_hit(target: Node2D)`

---

## Component Scripts (Gameplay Modifiers)

### `Scripts/Components/angled_deflector.gd` — extends UniversalComponent
- Calculates Pong-style deflection angle based on hit position relative to parent. Auto-connects to `parent.body_collided` and filters by `target_group`. Configurable x/y `deflection_bias` for angle weighting.
- Listens to: `parent.body_collided`
- Emits: None (modifies `parent.velocity` directly)

### `Scripts/Components/collision_marker.gd` — `CollisionMarker extends Node`
- Marker node that provides `collision_groups` data for `CollisionMatrix` to auto-configure non-UniversalBody nodes (StaticBody2D walls, Area2D goals, etc.).
- Exports: `collision_groups: Array[String]`
- Listens to: None
- Emits: None

### `Scripts/Components/health.gd` — extends Node
- Health tracker. On death: hides parent, disables all colliders, disables child components, plays death sound, calls `queue_free()`.
- Listens to: None (`reduce_health()` called externally)
- Emits: `health_changed(current_health: int, parent: Node)`, `zero_health(parent: Node)`

### `Scripts/Components/pong_acceleration.gd` — extends UniversalComponent
- Ramps ball velocity through configurable speed levels (default 8) on paddle collision. Auto-connects to `parent.body_collided` and filters by `target_group`.
- Exports: `acceleration_factor: float = 1.2`, `acceleration_levels: int = 8`, `target_group: String`
- Listens to: `parent.body_collided`
- Emits: None (modifies `parent.velocity` directly)

### `Scripts/Components/screen_cleanup.gd` — extends UniversalComponent
- Removes (queue_free) parent entity when it moves outside the viewport bounds plus configurable margin. Gets viewport size dynamically via `get_viewport().get_visible_rect().size`.
- Exports: `margin: int = 16`
- Listens to: None (reads `parent.global_position` each frame)
- Emits: None (calls `parent.queue_free()`)

### `Scripts/Components/screen_wrap.gd` — extends Node
- Asteroids-style screen wrapping. Warps parent to opposite edge when beyond viewport bounds plus margin.
- Listens to: None (reads `parent.global_position` each frame)
- Emits: None

### `Scripts/Components/split_on_death.gd` — extends Node
- Spawns smaller fragment scenes when parent dies. Decrements size enum (LARGE→MEDIUM→SMALL).
- Listens to: `$Health.zero_health`
- Emits: None (instantiates scenes directly)

---

## Rule Scripts (Game Logic)

### `Scripts/Rules/goal.gd` — extends UniversalComponent
- Marks a parent Area2D as a scoring zone. On `body_entered`, increments the appropriate score on the UGS based on `score_type` (P1_SCORE, P2_SCORE, or GENERIC_SCORE).
- Exports: `score_type: CommonEnums.ScoreType`, `score_amount: int = 1`
- Listens to: `parent.body_entered`
- Emits: Calls `game.add_p1_score()` / `game.add_p2_score()` / `game.add_score()`

### `Scripts/Rules/points_monitor.gd` — extends UniversalComponent
- Monitors a UGS score signal against a configurable threshold. When the condition is met (GREATER_OR_EQUAL or LESS_OR_EQUAL), emits `victory()` or `defeat()` on the UGS. Multiple instances can monitor different scores (P1, P2, generic).
- Exports: `score_type: CommonEnums.ScoreType`, `target_score: int = 11`, `condition: CommonEnums.Condition`, `result: CommonEnums.Result`
- Listens to: `parent.on_p1_score` / `parent.on_p2_score` / `parent.on_points_changed` (depending on score_type)
- Emits: `parent.victory` or `parent.defeat`

### `Scripts/Rules/variable_tuner.gd` — extends UniversalComponent
- Listens for a signal on a configurable source node and adjusts a property on the parent node. Used for AI difficulty ramping (e.g., increase InterceptorAi `turning_speed` after each goal).
- Exports: `source_node: Node`, `source_signal: String`, `target_property: String`, `adjustment_amount: float`, `adjustment_mode: CommonEnums.AdjustmentMode`
- Listens to: Configurable signal via `source_node.connect(source_signal, ...)`
- Emits: None (modifies `parent[target_property]` directly)

### `Scripts/Rules/group_monitor.gd` — extends Node
- Polls a named group each frame. Emits signals on parent game script when group count transitions from >0 to 0.
- Listens to: None (polls `get_tree().get_nodes_in_group()` each frame)
- Emits (on parent): `group_cleared`, optionally `victory`, `defeat`

### `Scripts/Rules/lives_counter.gd` — extends Node
- Manages player lives. Decrements on `lose_life()`, emits when lives change or reach zero.
- Listens to: None (`lose_life()` called externally)
- Emits (on parent): `lives_changed`, `lives_depleted`

### `Scripts/Rules/timer.gd` — extends Node
- Game timer with count-up or count-down modes. Emits tick events at configurable intervals, expires at duration.
- Listens to: Internal `Timer.timeout`
- Emits (on parent): `timer_tick`, `timer_expired`

---

## Flow Scripts (Wave Management & UI)

### `Scripts/Flow/interface.gd` — extends Control
- Reusable HUD with two display modes (`P1_P2_SCORE` for competitive, `POINTS_MULTIPLIER` for single-player). Auto-connects to parent UGS score/lives/multiplier/timer signals. Responds to `state_changed` to show/hide appropriate UI elements per game state. Shows attract text in ATTRACT, scores in PLAYING, win/lose text in GAME_OVER.
- Exports: `display_mode: CommonEnums.DisplayMode`
- Listens to: `parent.on_points_changed`, `parent.on_multiplier_changed`, `parent.lives_changed`, `parent.timer_tick`, `parent.on_p1_score`, `parent.on_p2_score`, `parent.state_changed`
- Emits: None

### `Scripts/Flow/sound_on_hit.gd` — extends UniversalComponent
- Plays a sound when the parent experiences a collision. Works on both Area2D parents (listens to `body_entered`) and UniversalBody parents (listens to `body_collided`). Uses `has_signal()` to auto-detect which signal to connect.
- Exports: `sound: AudioStreamPlayer2D`
- Listens to: `parent.body_entered` (Area2D) OR `parent.body_collided` (UniversalBody)
- Emits: None (plays sound directly)

### `Scripts/Flow/wave_director.gd` — extends Node
- Connects to a game script signal (group_cleared, timer_expired, or lives_depleted) and triggers wave spawning after a configurable delay.
- Listens to: `parent.group_cleared` OR `parent.timer_expired` OR `parent.lives_depleted`
- Emits (on parent): `spawning_wave`

### `Scripts/Flow/wave_spawner.gd` — extends UniversalComponent
- Spawns entities in patterns (screen edges, center, or grid). Uses expression-based count equations with `wave_number` variable. Supports staggered spawning, initial velocity with random angles, horizontal/vertical flipping, and `PropertyOverride` resources for spawn-time configuration. Can spawn on game start or on wave signals.
- Exports: `spawn_scene`, `spawn_pattern`, `spawn_count_equation`, `spawn_at_game_start`, `initial_velocity`, `use_random_angle`, `random_angle_min/max`, `random_flip_h/v`, `property_overrides`, `director`, `stagger_delay`
- Listens to: `game.spawning_wave`, `game.on_game_start` (if `spawn_at_game_start`)
- Emits (on game): `spawning_wave_complete`

---

## Game Scenes (Assemblies)

### `Scenes/Games/pong.tscn` — UniversalGameScript root + components
- **Pong (componentized).** No game-specific script. Assembled entirely from UGS + components.
- Root: `UniversalGameScript` with 4 collision groups (balls, walls, paddles, goals)
- Player paddle: PlayerControl + DirectMovement
- Opponent paddle: InterceptorAi + DirectMovement + VariableTuner (difficulty ramping)
- Ball: AngledDeflector + PongAcceleration + ScreenCleanup + SoundOnHit
- Goals: Area2D + Goal + CollisionMarker + SoundOnHit
- Flow: GroupMonitor (balls) → WaveDirector → WaveSpawner (spawn at game start, random angle)
- Rules: PointsMonitor × 2 (P1 score ≥ 11 = victory, P2 score ≥ 11 = defeat)
- UI: Interface (P1_P2_SCORE mode)
- Audio: AudioStreamPlayer2D (shared sound resource)

### `Scripts/Games/breakout.gd` — extends UniversalGameScript
- Breakout. Break brick grid with ball, lives system, score multiplier that increases on paddle hits.
- Listens to: `ball.BallCollision`, Floor `body_entered`, tree `node_added`, brick `Health.zero_health`, `group_cleared`, `lives_depleted`, `lives_changed`
- Emits: `on_points_changed`, `on_multiplier_changed`, `on_game_over`

### `Scripts/Games/asteroids.gd` — extends UniversalGameScript
- Asteroids with two control schemes. Wave-based spawning, attract mode with AI ship.
- Listens to: `gun.target_hit`, `group_cleared`, `lives_depleted`, `lives_changed`, tree `node_added`, asteroid `Health.zero_health`
- Emits: `on_points_changed`, `on_multiplier_changed`

### `Scripts/Games/pongsteroids.gd` — extends UniversalGameScript
- Pong + Asteroids hybrid. Pong mechanics with asteroid obstacles.
- Listens to: `ball.BallCollision`, P1/P2 Goal `body_entered`, asteroid `Health.zero_health`
- Emits: `on_game_over`

---

## Signal Flow Architecture

```
INPUT (keyboard/mouse/gamepad)
  ↓
BRAINS (player_control, interceptor_ai, aim_ai)
  ↓ emit on UniversalBody input signals
UNIVERSAL BODY (routes input → output with axis locks)
  ↓ emit processed output signals
LEGS (direct_movement, engine_simple, etc.) → modify parent velocity/position
ARMS (gun_simple) → spawn bullets
  ↓
COMPONENTS (angled_deflector, pong_acceleration, screen_cleanup) → react to body_collided
RULES (goal, points_monitor, group_monitor, lives_counter, variable_tuner) → emit game events on UGS
FLOW (wave_director → wave_spawner, sound_on_hit, interface) → manage spawning, sounds, HUD
```

**Key signals on UniversalBody:**
- Input (Brains emit these): `left_joystick`, `right_joystick`, `mouse_position`, `button_pressed`, `button_released`
- Output (Legs/Arms listen): `move`, `move_to`, `action`, `end_action`, `shoot`, `end_shoot`, `thrust`, `end_thrust`, `aim`, `aim_at`
- Collision (Components listen): `body_collided(collider, normal)`

**Key signals on UniversalGameScript:**
- From Rules (emitted by child components): `victory`, `defeat`, `group_cleared`, `lives_changed`, `lives_depleted`, `timer_tick`, `timer_expired`, `spawning_wave`, `spawning_wave_complete`
- To Rules/UI (emitted by game script): `on_game_start`, `on_game_end`, `on_game_over`, `on_points_changed`, `on_multiplier_changed`, `state_changed`, `on_p1_score`, `on_p2_score`

---

## Assets

- **Audio:** Kenney game audio pack (lasers, power-ups, zaps, phase jumps, space trash, pep sounds, tones)
- **Fonts:** Kenney retro fonts (Pixel, High, Mini, Rocket, Future, Blocks, Square — regular and narrow variants)
- **CRT Addon:** Custom CRT post-processing effect