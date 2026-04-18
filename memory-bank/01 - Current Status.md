# Current Status: GD50 — Arcade Cabinet

**Last Updated:** 2026-04-17  
**Engine:** Godot 4.x (GDScript)  
**Architecture:** Entity-Component (composition over inheritance)  
**Playable Games:** Pong, Breakout, Asteroids, Pongsteroids, Dogfight — ALL componentized, zero game scripts

---

## Project Overview

GD50 is a modular arcade game collection built around a composable component architecture. Games are assembled from reusable components (Brains, Legs, Arms, Components, Rules, Flow) attached to generic `UniversalBody` (entity) and `UniversalGameScript` (game) base classes. The signal flow is: **Brains** read input → emit on **UniversalBody** input signals → UniversalBody routes to processed output signals → **Legs/Arms** listen to output signals and act. **Rules** components manage game logic (scores, groups, conditions). **Flow** components manage waves, spawning, and UI.

**All five games run as pure scene assemblies** — no game-specific scripts exist. Every game is a `UniversalGameScript` root node with attached components configured in the editor.

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
- **Signals FROM components:** `victory`, `defeat`, `group_cleared`, `lives_changed`, `lives_depleted`, `timer_tick`, `timer_expired`, `spawning_wave`, `spawning_wave_complete`
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

### `Scripts/Core/collision_group.gd` — `CollisionGroup extends Resource`
- Custom resource defining a collision group name and its target groups. Used in UGS `collision_groups` export array.

### `Scripts/Core/property_override.gd` — `PropertyOverride extends Resource`
- Custom resource for spawn-time property configuration. Stores `node_path`, `property_name`, and `value`. Used in WaveSpawner `property_overrides` array. Handles typed array conversion via `Array.assign()`.

### `Scripts/Core/common_enums.gd` — `CommonEnums extends RefCounted`
- Shared enumerations: `Element` (UI identifiers), `State` (ATTRACT/PLAYING/PAUSED/GAME_OVER), `ScoreType` (P1_SCORE/P2_SCORE/GENERIC_SCORE), `Trigger` (GROUP_CLEARED/TIMER_EXPIRED/LIVES_DEPLETED/GAME_START), `SpawnPattern` (SCREEN_EDGES/SCREEN_CENTER/GRID/POSITION), `AdjustmentMode` (ADD/MULTIPLY/SET), `Condition` (GREATER_OR_EQUAL/LESS_OR_EQUAL), `Result` (VICTORY/DEFEAT), `DisplayMode` (P1_P2_SCORE/POINTS_MULTIPLIER).

---

## Body Scripts

### `Scripts/Bodies/ball.gd` — extends UniversalBody
- Pong-style ball. Minimal script — sets up collision shapes and draws a white square. All bouncing, deflection, acceleration, sound, and cleanup handled by attached components.

### `Scripts/Bodies/paddle.gd` — extends UniversalBody
- Pong-style paddle. Sets collision shape from exports. All movement, AI, and deflection handled by attached components.

### `Scripts/Bodies/asteroid.gd` — extends UniversalBody
- Asteroid with procedural jagged polygon, three sizes (SMALL/MEDIUM/LARGE). **Drawing code only** — all behavior handled by attached components (Health, SplitOnDeath, ScoreOnDeath, ScreenWrap, DamageOnHit).

### `Scripts/Bodies/brick.gd` — extends UniversalBody
- Breakout brick with health-based coloring (green=1hp, yellow=2hp, orange=3hp, red=4hp). Redraws on health change. **Drawing code only** — all gameplay behavior handled by attached components.

### `Scripts/Bodies/bullet_simple.gd` — extends UniversalBody
- Simple bullet. Flies straight, despawns on physics hit or screen exit. All behavior via components (DamageOnHit, DieOnHit).

### `Scripts/Bodies/bullet_wrapping.gd` — extends UniversalBody
- Bullet with timer-based lifetime instead of screen exit detection. Otherwise identical to bullet_simple.

### `Scripts/Bodies/triangle_ship.gd` — extends UniversalBody
- Asteroids player ship with triangular polyline shape. **Drawing code only** — all behavior handled by attached components (Health, ScreenWrap, GunSimple, EngineSimple/Complex, etc.). Note: some older functional code may still exist here but is being migrated to components.

### `Scripts/Bodies/ufo.gd` — extends UniversalBody
- UFO entity with configurable hitbox sized from exports. All behavior defined by attached components.

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
- Removes (queue_free) parent entity when it moves outside the viewport bounds plus configurable margin.

### `Scripts/Components/screen_wrap.gd` — extends Node
- Asteroids-style screen wrapping. Warps parent to opposite edge when beyond viewport bounds plus margin.

### `Scripts/Components/split_on_death.gd` — extends Node
- Spawns smaller fragment scenes when parent dies. Decrements size enum (LARGE→MEDIUM→SMALL).

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
- Polls a named group each frame. Emits signals on parent game script when group count transitions from >0 to 0.

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

---

## Flow Scripts (Wave Management & UI)

### `Scripts/Flow/interface.gd` — extends Control
- Reusable HUD with two display modes (`P1_P2_SCORE` for competitive, `POINTS_MULTIPLIER` for single-player). Auto-connects to parent UGS signals.

### `Scripts/Flow/sound_on_hit.gd` — extends UniversalComponent
- Plays a sound when the parent experiences a collision. Auto-detects Area2D vs UniversalBody parents.

### `Scripts/Flow/wave_director.gd` — extends UniversalComponent2D
- Connects to a game signal and triggers wave spawning after a configurable delay. Supports four trigger types: `GROUP_CLEARED`, `TIMER_EXPIRED`, `LIVES_DEPLETED`, `GAME_START`. Has `max_waves` limit and game_over guard.
- Exports: `trigger_type`, `trigger_value`, `wave_delay`, `max_waves`
- Listens to: Configured trigger signal
- Emits (on parent): `spawning_wave`

### `Scripts/Flow/wave_spawner.gd` — extends UniversalComponent2D
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

## Game Scenes (All Componentized)

### `Scenes/Games/pong.tscn` — UniversalGameScript root + components
- **Pong.** No game-specific script. Assembled entirely from UGS + components.
- Root: `UniversalGameScript` with collision groups (balls, walls, paddles, goals)
- Player paddle: PlayerControl + DirectMovement
- Opponent paddle: InterceptorAi + DirectMovement + VariableTuner (difficulty ramping)
- Ball: AngledDeflector + PongAcceleration + ScreenCleanup + SoundOnHit
- Goals: Area2D + Goal + CollisionMarker + SoundOnHit
- Flow: GroupMonitor (balls) → WaveDirector → WaveSpawner (spawn at game start, random angle)
- Rules: PointsMonitor × 2 (P1 score ≥ 11 = victory, P2 score ≥ 11 = defeat)
- UI: Interface (P1_P2_SCORE mode)

### `Scenes/Games/breakout.tscn` — UniversalGameScript root + components
- **Breakout.** No game-specific script. Assembled entirely from UGS + components.
- Uses GRID spawn pattern for brick layout with health-by-row
- Ball: DamageOnHit (target_groups: bricks) + ScoreOnHit + DieOnHit + ScreenCleanup
- Bricks: Health + ScoreOnDeath
- Goals: Area2D + Goal (lose_life mode)
- Rules: GroupMonitor (bricks) → WaveDirector → WaveSpawner
- UI: Interface (POINTS_MULTIPLIER mode)

### `Scenes/Games/asteroids.tscn` — UniversalGameScript root + components
- **Asteroids.** No game-specific script. Assembled entirely from UGS + components.
- Player ship: PlayerControl + EngineSimple + FrictionLinear + RotationDirect + GunSimple + ScreenWrap
- Bullets: DamageOnHit (target_groups: asteroids) + DieOnHit + ScreenCleanup
- Asteroids: Health + SplitOnDeath + ScoreOnDeath + ScreenWrap
- Flow: WaveDirector (GAME_START trigger) → WaveSpawner (SCREEN_EDGES, safe zone) + Timer (auto_start, loop) → WaveDirector → WaveSpawner
- Rules: GroupMonitor (asteroids) + GroupCountMultiplier (asteroids) + LivesCounter
- UI: Interface (POINTS_MULTIPLIER mode)

### `Scenes/Games/pongsteroids.tscn` — UniversalGameScript root + components
- **Pongsteroids.** No game-specific script. Pong + Asteroids hybrid assembled from both games' components.
- Pong layer: paddles, ball, goals (same as pong.tscn)
- Asteroids layer: asteroid spawner + asteroid entities with Health + SplitOnDeath + ScreenWrap
- Validates cross-game component mixing — zero new components needed

### `Scenes/Games/dogfight.tscn` — UniversalGameScript root + components
- **Dogfight.** Player triangle ship vs escalating waves of AI triangle ships, with asteroids spawning as neutral obstacles. No game-specific script.
- Collision groups: players, enemies, players_bullets, enemies_bullets, asteroids (5-way factional warfare)
- Player ship: TriangleShipModern + PlayerControl + ScoreOnDeath (enemy scores on player death)
- Enemy ships: TriangleShipModern + InterceptorAi (chases player, turning_speed=360) + AimAi (aims at player) + ShootAi (auto-fires in vision cone) + ScoreOnDeath (player scores on enemy death)
- Asteroids: AngledDeflector + random velocity + Timer-spawned every 6 seconds
- Flow: GroupMonitor(players) → WaveDirector → WaveSpawner (respawn 1 player); GroupMonitor(enemies) → WaveDirector → WaveSpawner (spawn wave_number enemies); Timer → WaveSpawner (1 asteroid per tick)
- Rules: LivesCounter (10 lives, Asteroids-style game over on depletion)
- Uses factional bullets — players_bullets hit enemies/asteroids, enemies_bullets hit players/asteroids, asteroids hit everyone

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
ARMS (gun_simple, damage_on_hit) → spawn bullets, deal damage
  ↓
COMPONENTS (angled_deflector, pong_acceleration, die_on_hit, score_on_death, screen_cleanup) → react to collisions/life events
RULES (goal, points_monitor, group_monitor, group_count_multiplier, lives_counter, variable_tuner) → emit game events on UGS
FLOW (wave_director → wave_spawner, sound_on_hit, interface, timer) → manage spawning, sounds, HUD, timing
```

**Key signals on UniversalBody:**
- Input (Brains emit these): `left_joystick`, `right_joystick`, `mouse_position`, `button_pressed`, `button_released`
- Output (Legs/Arms listen): `move`, `move_to`, `action`, `end_action`, `shoot`, `end_shoot`, `thrust`, `end_thrust`, `aim`, `aim_at`
- Collision (Components listen): `body_collided(collider, normal)`

**Key signals on UniversalGameScript:**
- From Rules: `victory`, `defeat`, `group_cleared`, `lives_changed`, `lives_depleted`, `timer_tick`, `timer_expired`, `spawning_wave`, `spawning_wave_complete`
- To Rules/UI: `on_game_start`, `on_game_end`, `on_game_over`, `on_points_changed`, `on_multiplier_changed`, `state_changed`, `on_p1_score`, `on_p2_score`

---

## Assets

- **Audio:** Kenney game audio pack (lasers, power-ups, zaps, phase jumps, space trash, pep sounds, tones)
- **Fonts:** Kenney retro fonts (Pixel, High, Mini, Rocket, Future, Blocks, Square — regular and narrow variants)
- **CRT Addon:** Custom CRT post-processing effect