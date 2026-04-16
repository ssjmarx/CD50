# Current Status: GD50 — Arcade Cabinet

**Last Updated:** 2026-04-15  
**Engine:** Godot 4.x (GDScript)  
**Architecture:** Entity-Component (composition over inheritance)  
**Playable Games:** Pong, Breakout, Asteroids, Pongsteroids (hybrid)

---

## Project Overview

GD50 is a modular arcade game collection built around a composable component architecture. Games are assembled from reusable components (Brains, Legs, Arms, Components, Rules, Flow) attached to a generic `UniversalBody` base. The signal flow is: **Brains** read input → emit on **UniversalBody** input signals → UniversalBody routes to processed output signals → **Legs/Arms** listen to output signals and act. **Rules** components manage game logic (lives, groups, timers). **Flow** components manage wave spawning.

---

## Core Scripts

### `Scripts/Core/universal_body.gd` — `UniversalBody extends CharacterBody2D`
- Base class for all physical entities. Routes input signals from Brains to processed output signals (axis locks applied). Provides position clamping within configurable bounds.
- Listens to (internally connected): `left_joystick`, `right_joystick`, `mouse_position`, `button_pressed`, `button_released`
- Emits (routed outputs): `move`, `move_to`, `action`, `end_action`, `shoot`, `end_shoot`, `thrust`, `end_thrust`, `aim`, `aim_at`

### `Scripts/Core/universal_game_script.gd` — `UniversalGameScript extends Node2D`
- Master class for game coordinators. State machine (ATTRACT/PLAYING/PAUSED/GAME_OVER), score/multiplier tracking, collision matrix setup. Subclasses override `_initialize_gameplay()`.
- Listens to: keyboard input in `_unhandled_input` for state transitions
- Emits: `on_game_start`, `on_game_end`, `on_game_over`, `on_points_changed`, `on_multiplier_changed`, `state_changed`

### `Scripts/Core/collision_matrix.gd` — `CollisionMatrix extends RefCounted`
- Auto-configures collision layers/masks from group definitions. Supports both `UniversalBody` and non-body nodes via `CollisionMarker` children.
- Listens to: `child_entered_tree`, `child_exiting_tree` on the game script
- Emits: None

### `Scripts/Core/common_enums.gd` — `CommonEnums extends RefCounted`
- Shared enumerations: `Element` (UI identifiers for show/hide), `State` (ATTRACT, PLAYING, PAUSED, GAME_OVER).
- Listens to: None
- Emits: None

---

## Body Scripts

### `Scripts/Bodies/ball.gd` — extends UniversalBody
- Pong-style ball. Bounces off colliders via `move_and_collide`, plays sounds that change pitch with speed level.
- Listens to: `$PongAcceleration.speed_changed`
- Emits: `BallCollision`

### `Scripts/Bodies/paddle.gd` — extends UniversalBody
- Pong-style paddle. Minimal logic; exposes `bounce_offset()` delegating to child `AngledDeflector`. Collision shape sized from exports.
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
- UFO entity with configurable hitbox sized from exports. All behavior defined by attached components (Brains, Legs, etc.).
- Listens to: None
- Emits: None (beyond inherited UniversalBody signals)

---

## Brain Scripts (Input & AI)

### `Scripts/Brains/player_control.gd` — extends Node
- Player control brain. Reads keyboard/mouse/gamepad every frame and forwards as input signals on parent UniversalBody.
- Listens to: Input system directly (`_unhandled_input`, `Input.get_axis`)
- Emits (on parent): `mouse_position`, `button_pressed`, `button_released`, `left_joystick`, `right_joystick`

### `Scripts/Brains/interceptor_ai.gd` — extends Node
- AI brain that steers toward a target node with adjustable turning speed and random aim inaccuracy.
- Listens to: None (reads target position directly each frame)
- Emits (on parent): `left_joystick`

### `Scripts/Brains/aim_ai.gd` — extends Node
- AI brain that aims at a target for rotation only (emits to `right_joystick`, not movement). Used for AI aiming.
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
- Smoothly rotates toward mouse position or joystick direction. Supports `independant_aim` mode using aim signals instead of move_to.
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

### `Scripts/Components/angled_deflector.gd` — extends Node
- Calculates Pong-style deflection angle based on ball hit position relative to parent center. Configurable x/y bias.
- Listens to: None (called directly via `bounce_offset()`)
- Emits: None

### `Scripts/Components/collision_marker.gd` — `CollisionMarker extends Node`
- Marker node that provides `collision_groups` data for `CollisionMatrix` to auto-configure non-UniversalBody nodes.
- Listens to: None
- Emits: None

### `Scripts/Components/health.gd` — extends Node
- Health tracker. On death: hides parent, disables all colliders, disables child components, plays death sound, calls `queue_free()`.
- Listens to: None (`reduce_health()` called externally)
- Emits: `health_changed(current_health: int, parent: Node)`, `zero_health(parent: Node)`

### `Scripts/Components/pong_acceleration.gd` — extends Node
- Ramps ball velocity through configurable speed levels (default 8) on each `accelerate()` call. Changes ball sound pitch via `speed_changed`.
- Listens to: None (`accelerate()`/`reset()` called externally)
- Emits: `speed_changed(speed_level)`

### `Scripts/Components/screen_wrap.gd` — extends Node
- Asteroids-style screen wrapping. Warps parent to opposite edge when beyond viewport bounds plus margin.
- Listens to: None (reads `parent.global_position` each frame)
- Emits: None

### `Scripts/Components/split_on_death.gd` — extends Node
- Spawns smaller fragment scenes when parent dies. Decrements size enum (LARGE→MEDIUM→SMALL) if present. Skips at minimum size.
- Listens to: `$Health.zero_health`
- Emits: None (instantiates scenes directly)

---

## Rule Scripts (Game Logic)

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

### `Scripts/Rules/interface.gd` — extends Control
- Reusable HUD. Shows/hides UI elements by enum. Auto-connects to parent game script's score/lives/multiplier/timer signals.
- Listens to: `parent.on_points_changed`, `parent.on_multiplier_changed`, `parent.lives_changed`, `parent.timer_tick`
- Emits: None

---

## Flow Scripts (Wave Management)

### `Scripts/Flow/wave_director.gd` — extends Node
- Connects to a game script signal (group_cleared, timer_expired, or lives_depleted) and triggers wave spawning after a delay.
- Listens to: `parent.group_cleared` OR `parent.timer_expired` OR `parent.lives_depleted` (configurable trigger_type)
- Emits (on parent): `spawning_wave`

### `Scripts/Flow/wave_spawner.gd` — extends Node2D
- Spawns entities in patterns (screen edges, center, or grid). Uses expression-based count equations with wave_number variable. Staggers spawns with delay.
- Listens to: `parent.spawning_wave`
- Emits (on parent): `spawning_wave_complete`

---

## Game Scripts (Scene-Level Controllers)

### `Scripts/Games/pong.gd` — extends UniversalGameScript
- Pong. Two-player competitive, first to 11 wins. Attract mode with AI vs AI (randomized difficulty). Player 1 swaps from AI to player controls on game start.
- Listens to: `ball.BallCollision`, P1/P2 Goal `body_entered`
- Emits: `on_game_over`

### `Scripts/Games/breakout.gd` — extends UniversalGameScript
- Breakout. Break brick grid with ball, lives system, score multiplier that increases on paddle hits. Attract mode with AI paddle.
- Listens to: `ball.BallCollision`, Floor `body_entered`, tree `node_added` (bricks), brick `Health.zero_health`, `group_cleared`, `lives_depleted`, `lives_changed`
- Emits: `on_points_changed`, `on_multiplier_changed`, `on_game_over`

### `Scripts/Games/asteroids.gd` — extends UniversalGameScript
- Asteroids with two control schemes (Original: rotation_direct + engine_simple; Modern: rotation_target + engine_complex + direct_acceleration + friction_linear). Wave-based spawning, attract mode with AI ship.
- Listens to: `gun.target_hit`, `group_cleared`, `lives_depleted`, `lives_changed`, tree `node_added` (asteroids), asteroid `Health.zero_health`
- Emits: `on_points_changed`, `on_multiplier_changed`

### `Scripts/Games/pongsteroids.gd` — extends UniversalGameScript
- Pong + Asteroids hybrid. Pong mechanics with asteroid obstacles that spawn periodically and deflect the ball. First to 11 wins.
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
RULES (group_monitor, lives_counter, timer) → emit game events on parent game script
FLOW (wave_director → wave_spawner) → manage wave spawning
INTERFACE → update HUD from game script signals
```

**Key signals on UniversalBody:**
- Input (Brains emit these): `left_joystick`, `right_joystick`, `mouse_position`, `button_pressed`, `button_released`
- Output (Legs/Arms listen): `move`, `move_to`, `action`, `end_action`, `shoot`, `end_shoot`, `thrust`, `end_thrust`, `aim`, `aim_at`

**Key signals on UniversalGameScript:**
- From Rules (emitted by child components): `group_cleared`, `victory`, `defeat`, `lives_changed`, `lives_depleted`, `timer_tick`, `timer_expired`, `spawning_wave`, `spawning_wave_complete`
- To Rules/UI (emitted by game script): `on_game_start`, `on_game_end`, `on_game_over`, `on_points_changed`, `on_multiplier_changed`, `state_changed`

---

## Assets

- **Audio:** Kenney game audio pack (lasers, power-ups, zaps, phase jumps, space trash, pep sounds, tones)
- **Fonts:** Kenney retro fonts (Pixel, High, Mini, Rocket, Future, Blocks, Square — regular and narrow variants)
- **CRT Addon:** Custom CRT post-processing effect