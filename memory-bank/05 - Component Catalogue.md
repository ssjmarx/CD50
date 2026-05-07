# Component Catalogue

**Last Updated:** 2026-05-06  
**Total Scripts:** 88 across 10 categories  
**Total Scene Variants:** 2 (no unique script)  
**Total Shaders:** 2 (crt_light.gdshader, persistence.gdshader)

Each entry includes the script name, class declaration, and a one-line description extracted from the script's top comment.

---

## Core (9)

| Script | Extends | Summary |
|--------|---------|---------|
| `universal_body.gd` | `UniversalBody extends CharacterBody2D` | Universal base class for blackboard architecture. Routes signals between components, provides position clamping and axis locking. |
| `universal_game_script.gd` | `UniversalGameScript extends Node2D` | Master class for game coordinators. State machine, signal routing, score tracking, collision matrix setup. |
| `universal_component.gd` | `UniversalComponent extends Node` | Universal base class for components that do not require 2D positioning. |
| `universal_component_2d.gd` | `UniversalComponent2D extends Node2D` | Universal base class for components that require 2D positioning. |
| `collision_matrix.gd` | `CollisionMatrix extends RefCounted` | Auto-configures collision layers/masks from group definitions. Supports UniversalBody and CollisionMarker. |
| `collision_group.gd` | `CollisionGroup extends Resource` | Defines a collision group with a name and list of target groups it collides with. |
| `group_cache.gd` | `extends Node` | Lazy dirty-flag cache for group node lookups. Avoids repeated get_nodes_in_group() allocations. |
| `property_override.gd` | `PropertyOverride extends Resource` | Defines a single property override: targets a node path and sets a named property to a value. |
| `common_enums.gd` | `CommonEnums extends RefCounted` | Shared enumerations for type safety across the codebase. |

---

## Bodies (12)

Body scripts contain **drawing code only** — visual shape, colors, and `_draw()` calls. All gameplay behavior is handled by attached components.

| Script | Extends | Summary |
|--------|---------|---------|
| `ball.gd` | `extends UniversalBody` | Paddle Ball ball. Draws a colored square and sets up collision shapes from a radius export. |
| `paddle.gd` | `extends UniversalBody` | Paddle Ball paddle. Draws a white rectangle sized from width/height exports. |
| `asteroid.gd` | `extends UniversalBody` | Asteroid with procedural jagged polygon. Three selectable sizes with radius-based generation. |
| `brick.gd` | `extends UniversalBody` | Brick Breaker brick with health-based coloring. Color shifts from green to red as HP decreases. |
| `barrier.gd` | `extends UniversalComponent2D` | Bug Blaster-style barrier. Made from around thirty bricks that individually take damage and die. |
| `bullet_simple.gd` | `extends UniversalBody` | Simple arcade bullet. Draws a white square and sets up collision shapes from a radius export. |
| `bullet_wrapping.gd` | `extends UniversalBody` | Arcade bullet with screen wrapping. Draws a white square and sets up collision shapes from a radius export. |
| `tetromino.gd` | `extends UniversalBody` | Tetromino body composed of tile-sized squares. Supports all 7 standard shapes with collision per tile. |
| `triangle_ship.gd` | `extends UniversalBody` | Space Rocks player ship. Draws a triangular outline with a notched tail. |
| `ufo.gd` | `extends UniversalBody` | Bug Blaster-style UFO. Scales speed and accuracy for the SMALL variant. Draws a three-layer saucer shape. |
| `invader.gd` | `extends UniversalBody` | Space Invader-style enemy with three different sprite-based forms. |
| `paddle_cannon.gd` | `extends UniversalBody` | Paddle cannon. Chunky horizontal base with a narrow turret on top. Drawing code only. |

---

## Brains (8)

Brains read input (player or AI) and emit signals on the parent body.

| Script | Extends | Summary |
|--------|---------|---------|
| `player_control.gd` | `extends UniversalComponent` | Player control brain. Reads keyboard, mouse, and gamepad input, then emits signals directly to the parent body. |
| `interceptor_ai.gd` | `extends UniversalComponent` | AI brain that steers toward the closest target in a group. Emits to move for movement, not rotation. |
| `aim_ai.gd` | `extends UniversalComponent` | AI brain that aims at the closest target in a group. Emits to aim for rotation, not movement. |
| `shoot_ai.gd` | `extends UniversalComponent` | AI brain that fires when a target from the specified group enters its vision cone. |
| `shoot_ai_swarm.gd` | `extends UniversalComponent` | Swarm shooting AI. Fires after a random cooldown with random initial offset, but only when on the specified formation edge. |
| `patrol_ai.gd` | `extends UniversalComponent` | AI brain that follows a path of baked waypoints. Supports looping, retracing, and random path generation. |
| `falling_ai.gd` | `extends UniversalComponent` | AI brain that emits a move signal at regular intervals, used for Block Drop-style falling movement. |
| `swarm_ai.gd` | `extends UniversalComponent` | Swarm AI brain. Connects to a swarm bus node and forwards movement commands to the parent body. |

---

## Legs (13)

Legs listen to processed output signals and handle movement/rotation.

| Script | Extends | Summary |
|--------|---------|---------|
| `direct_movement.gd` | `extends UniversalComponent` | Direct movement leg. Converts move signals to velocity, or follows mouse position. |
| `direct_acceleration.gd` | `extends UniversalComponent` | Adds acceleration to velocity based on input. Like DirectMovement but accelerates instead of sets velocity. |
| `engine_simple.gd` | `extends UniversalComponent` | Simple engine for Space Rocks-style thrust. Accelerates forward, caps at top speed. |
| `engine_complex.gd` | `extends UniversalComponent` | Complex engine with acceleration ramp-up/down (jerk). Smooth thrust response. |
| `friction_linear.gd` | `extends UniversalComponent` | Linear friction that increases with velocity. Proportional resistance up to max_friction. |
| `friction_static.gd` | `extends UniversalComponent` | Static friction that applies constant deceleration until velocity reaches zero. |
| `rotation_direct.gd` | `extends UniversalComponent` | Tank-style rotation based on horizontal input direction. Speed in degrees per second. |
| `rotation_target.gd` | `extends UniversalComponent` | Rotates toward mouse or joystick input. Speed in degrees per second. |
| `grid_movement.gd` | `extends UniversalComponent` | Grid movement leg. Moves parent by fixed step size in response to move signals. Uses physics for occupancy checks. No external grid dependency. |
| `grid_rotation.gd` | `extends UniversalComponent` | Grid rotation leg. Snaps facing direction to discrete rotation steps based on movement input or action button. |
| `grid_gravity.gd` | `extends UniversalComponent` | Grid gravity leg. Timer-based downward movement as a direct force. Bypasses Brain→Body→Leg signal chain. |
| `grid_rotation_advanced.gd` | `extends UniversalComponent` | Advanced grid rotation leg. Rotates multi-cell body offsets with wall kick support. Uses physics queries for validation. |
| `warp_space_rocks.gd` | `extends UniversalComponent` | Emergency teleport with temporary intangibility for Space Rocks-style games. Warps to random position, hides briefly, then reappears. |

---

## Arms (3 scripts + 1 scene variant)

Arms handle weapons and combat interactions.

| Script | Extends | Summary |
|--------|---------|---------|
| `gun_simple.gd` | `extends UniversalComponent` | Simple gun. Spawns bullet scenes on shoot signal with configurable rate of fire. |
| `damage_on_hit.gd` | `extends UniversalComponent` | Deals damage to a target's health component when parent collides with it. |
| `damage_on_joust.gd` | `extends UniversalComponent` | Deals damage based on relative velocity on collision. Higher speed = more damage (joust mechanic). |

**Scene variants:**

| Scene | Script Used | Summary |
|-------|-------------|---------|
| `gun_nosound.tscn` | `gun_simple.gd` | Silent variant of gun_simple. No sound components attached. |

---

## Components (18)

General-purpose gameplay modifier components.

| Script | Extends | Summary |
|--------|---------|---------|
| `angled_deflector.gd` | `extends UniversalComponent` | Angled deflector. Reflects the parent's velocity on collision based on the collision normal and a configurable angle offset. |
| `bounce_on_hit.gd` | `extends UniversalComponent` | Bounces the parent's velocity on collision using the collision normal. |
| `collision_marker.gd` | `extends UniversalComponent` | Collision marker. Allows non-UniversalBody nodes to participate in the CollisionMatrix system. |
| `death_effect.gd` | `extends UniversalComponent` | Spawns a self-destructing effect scene when the parent's health reaches zero. |
| `die_on_hit.gd` | `extends UniversalComponent` | Destroys the parent body immediately on collision with a target group. |
| `die_on_timer.gd` | `extends UniversalComponent` | Destroys the parent body after a configurable timer expires. |
| `ghost_piece.gd` | `extends UniversalComponent` | Ghost piece component. Projects the active piece downward to show its landing position as a transparent outline. Updates on move and rotation signals. |
| `health.gd` | `extends UniversalComponent` | Health component. Tracks HP, emits signals on change, and handles death by disabling colliders and freeing the parent. |
| `hold_relay.gd` | `extends UniversalComponent` | Hold relay component. Forwards the body's action signal to the game's hold_requested signal. Pure signal relay — no game logic. |
| `lock_detector.gd` | `extends UniversalComponent` | Lock detector component. Detects when a multi-cell body can't fall further, manages lock delay, and emits settlement signals. |
| `paddle_ball_acceleration.gd` | `extends UniversalComponent` | Paddle Ball-style acceleration. Ramps velocity through discrete levels on paddle collision. |
| `ring_spawner.gd` | `extends UniversalComponent` | Spawns bodies in a ring pattern around the parent. Supports optional orbiting movement. |
| `score_on_death.gd` | `extends UniversalComponent` | Awards score to the game when the parent's health reaches zero. |
| `score_on_hit.gd` | `extends UniversalComponent` | Awards score to the game when the parent collides with a member of the target group. |
| `screen_cleanup.gd` | `extends UniversalComponent` | Screen cleanup. Destroys the parent body after an activation delay if it moves outside the visible screen area. |
| `screen_wrap.gd` | `extends UniversalComponent` | Space Rocks-style screen wrapping. Warps parent to opposite side when off-screen. |
| `split_on_death.gd` | `extends UniversalComponent` | Spawns smaller fragments when parent dies. Reduces size enum if present (e.g., LARGE → MEDIUM). |
| `t_spin_detector.gd` | `extends UniversalComponent` | T-spin detector component. Uses the SRS 3-corner rule to detect T-spins when a T-shaped piece locks after a rotation. |
| `vector_engine_exhaust.gd` | `extends UniversalComponent2D` | Visual engine exhaust flame drawn as a flickering triangle behind the parent body. Shows/hides on thrust signals. |

---

## Rules (11)

Game logic and condition components.

| Script | Extends | Summary |
|--------|---------|---------|
| `goal.gd` | `extends UniversalComponent` | Goal zone that awards score, causes life loss, or grants extra lives when a body enters. Attaches to an Area2D parent. |
| `points_monitor.gd` | `extends UniversalComponent` | Monitors a score value and emits victory or defeat when it meets a condition. Connects to the appropriate score signal based on score type. |
| `variable_tuner.gd` | `extends UniversalComponent` | Adjusts a property on the parent entity when a signal is received from a source node. Supports add, multiply, and set modes. |
| `variable_tuner_global.gd` | `extends UniversalComponent` | Adjusts a property on all entities in a group when a signal is received. Like VariableTuner but targets every member of a group. |
| `group_monitor.gd` | `extends UniversalComponent` | Monitors a group and emits victory/defeat when all nodes in that group are destroyed. |
| `group_count_multiplier.gd` | `extends UniversalComponent` | Sets the game score multiplier to the count of entities in a target group. |
| `lives_counter.gd` | `extends UniversalComponent` | Manages player lives for games with lives systems (Space Rocks, Brick Breaker). |
| `timer.gd` | `extends UniversalComponent` | Game timer with count-up or count-down modes. Emits tick events at configurable intervals. |
| `line_clear_monitor.gd` | `extends UniversalComponent2D` | Line clear monitor. Physics-based line detection using world-space queries. Zero grid data structure dependency. |
| `wave_director.gd` | `extends UniversalComponent2D` | Wave director. Connects to a game trigger signal and emits a wave-spawning signal after a configurable delay, with optional wave count limits. |
| `wave_spawner.gd` | `extends UniversalComponent2D` | Wave spawner. Instantiates entities in patterns (screen edges, center, grid, position) with optional stagger timing, safe zones, and component/property attachment. |

---

## Flow (8)

Wave management, spawning, UI, audio, and CRT post-processing components.

| Script | Extends | Summary |
|--------|---------|---------|
| `interface.gd` | `extends Control` | Reusable user interface. Parent shows/hides elements and calls update methods on score/lives events. |
| `sound_on_hit.gd` | `extends UniversalComponent` | Plays a sound effect when the parent body is hit (via body_entered or body_collided). |
| `sound_synth.gd` | *(not shown — unique)* | Synthesized audio generator. Produces real-time waveforms (sine, square, sawtooth, triangle, noise) with optional effects. Supports continuous playback or signal-triggered one-shots. |
| `music_ramping.gd` | `extends UniversalComponent2D` | Music ramping. Accelerates a two-voice synth beat as the count of a target group decreases, creating tension. |
| `sfx_ramping.gd` | `extends UniversalComponent` | Maps a property value from a source node to a semitone range and plays a synth note. Useful for dynamic pitch-shifting based on game state. |
| `swarm_controller.gd` | `extends UniversalComponent2D` | Swarm controller. Drives Bug Blaster-style group movement with tick-based horizontal stepping, edge detection, step-down shifts, and speed ramping. |
| `tetromino_spawner.gd` | `extends UniversalComponent2D` | Tetromino spawner. Manages the lock-spawn cycle for Block Drop-style games. Handles piece locking, next piece spawning, preview display, bag system, and defeat detection. |
| `crt_controller.gd` | `extends Node2D` | Self-building CRT post-processing controller. Creates BackBufferCopy, persistence SubViewport + ColorRect, CRT shader ColorRect, and 3 PNG overlay TextureRects programmatically. Toggles vector/raster mode per game. Persistence shader provides phosphor trails in vector mode via SubViewport frame accumulation with exponential decay. |

---

## Hub (2 scripts + 1 scene variant)

Meta-level scripts for the arcade orchestrator system.

| Script | Extends | Summary |
|--------|---------|---------|
| `arcade_orchestrator.gd` | `extends Node2D` | State machine: BOOT → PLAYING → RESULT → GAME_OVER → TRANSITIONING → RESTART. Loads games, tracks lives/score/multiplier. Interface Takeover: hijacks child Interface from each game, connects to AO signals. Scrolling transitions between all screens via `position:y` tween. `PROCESS_MODE_ALWAYS` so tweens survive UGS tree pause. |
| `arcade_game_entry.gd` | `ArcadeGameEntry extends Resource` | Defines a single game entry in the arcade playlist. Contains the game scene and property overrides for arcade fast rules. |

**Scene variants:**

| Scene | Script Used | Summary |
|-------|-------------|---------|
| `boot_screen.tscn` | *(scene only — no script)* | Arcade boot screen. "CD50 ARCADE" title, black background. Position-based layout for scroll tweening. |

---

## Effects (3)

Self-destructing visual effect scenes.

| Script | Extends | Summary |
|--------|---------|---------|
| `death_particles.gd` | `extends UniversalComponent2D` | Death effect that spawns particles that fly outward and fade after a set lifetime. Draws particles as single-pixel dots using custom _draw. |
| `death_broken_triangle_ship.gd` | `extends UniversalComponent2D` | Death effect for the triangle ship. Spawns spinning line fragments that drift outward and fade after a randomized lifetime. |
| `death_brick_explode.gd` | `extends UniversalComponent2D` | Death effect for settled brick cells. Spawns spinning line fragments and colored particle dots that drift outward and fade, color-inherited from parent brick. |
