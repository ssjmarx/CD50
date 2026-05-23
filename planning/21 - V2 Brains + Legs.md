# Plan 21: V2 Brains + Legs

## Overview

Build the complete library of V2 Brain and Leg components. Brains are pure intent generators (Priority 10) that emit signals on the entity bus. Legs are movement executors (Priority 20) that consume those signals and submit requests to the entity's velocity/position accumulator.

No gameplay is built. The goal is a complete, tested catalog of components that can be composed into any game entity.

**Depends on:** Plan 19 (Core Infrastructure), Plan 19.5 (Object Pools), Plan 20 (Stage)

---

## V2 Signal Pattern: Configurable Names, Fixed Types

Entity components use Godot's native C++ signal system for performance. Every component that consumes or emits signals follows this contract:

- **Signal type is fixed** — defined by `add_user_signal()` with explicit parameter types
- **Signal name is configurable** — `@export var` with sensible defaults
- **Compatibility is by convention** — components must agree on both signal name AND type
- **Mismatch handling** — `push_error()` and skip (entity-level error policy)

### Canonical Signal Types

| Type | Signature | Semantic Contract |
|------|-----------|-------------------|
| `directional` | `(Vector2)` | Normalized direction vector. "Go this way." |
| `positional` | `(Vector2)` | World-space coordinates. "Go to this point." |
| `action` | `(StringName)` | Named action trigger (e.g., `&"shoot"`, `&"thrust"`) |
| `action_end` | `(StringName)` | Named action release |
| `rotate` | `(float)` | Spin direction (-1.0, 0.0, 1.0) |
| `curve` | `(Curve2D, float)` | Path to follow and speed |
| `drop` | `(int)` | Number of grid cells to drop |

### Code Pattern

Every Brain/Leg follows this template:

```gdscript
extends CDComponent2D

# --- Exports (configurable signal names) ---
@export var move_signal: StringName = &"move"
@export var speed: float = 200.0

# --- Internal State ---
var _direction: Vector2 = Vector2.ZERO

# --- Phase 1: Priority + references ---
func _ready():
    super._ready()

# --- Phase 2: Signal connections ---
func _on_initialize():
    super._on_initialize()
    entity.ensure_signal(move_signal)
    entity.connect(move_signal, _on_move)

# --- Signal Handler ---
func _on_move(direction: Vector2) -> void:
    _direction = direction

# --- Physics Process ---
func _physics_process(delta: float) -> void:
    if not entity:
        return
    entity.request_velocity_set(_direction * speed)

# --- Pool Lifecycle ---
func _on_entity_deactivating() -> void:
    super._on_entity_deactivating()
    _direction = Vector2.ZERO
```

---

## Brains (14 Components)

Category: `BRAIN` (Priority 10). Pure intent generators. Never touch velocity, never move the entity, never affect other entities directly.

### Player Brains (3)

These consume `CDInputRouter` global signals and re-emit on the entity bus. Each has a single concern.

#### PlayerMoveBrain
**Role:** Routes directional input from CDInputRouter to entity bus as a directional signal.

| Aspect | Detail |
|--------|--------|
| **Consumes** | `CDInputRouter.input_move(player_id, direction: Vector2)` |
| **Emits** | Entity bus: configurable name, type `(Vector2)` |
| **Exports** | `player_id: int = 0` <br> `move_signal: StringName = &"move"` |

#### PlayerAimBrain
**Role:** Routes aim input from CDInputRouter to entity bus as a directional signal.

| Aspect | Detail |
|--------|--------|
| **Consumes** | `CDInputRouter.input_aim(player_id, direction: Vector2)` |
| **Emits** | Entity bus: configurable name, type `(Vector2)` |
| **Exports** | `player_id: int = 0` <br> `aim_signal: StringName = &"aim"` |

#### PlayerActionBrain
**Role:** Routes action button presses/releases from CDInputRouter to entity bus as named action signals.

| Aspect | Detail |
|--------|--------|
| **Consumes** | `CDInputRouter.input_action_pressed(player_id, action: StringName)` <br> `CDInputRouter.input_action_released(player_id, action: StringName)` |
| **Emits** | Entity bus: configurable name + action StringName, type `(StringName)` |
| **Exports** | `player_id: int = 0` <br> `action_mappings: Array[StringName] = [&"shoot"]` <br> `action_signal: StringName = &"action"` <br> `action_end_signal: StringName = &"action_end"` |
| **Setup** | Filters by `player_id`. Emits `action_signal` with the action StringName on press, `action_end_signal` with the action StringName on release. |

---

### AI: Targeting Brains (4)

These query `CDGroupRegistry` for world state and emit movement/aim signals.

#### ChaseNearestBrain
**Role:** Emits directional signal toward the closest entity in a target group.

| Aspect | Detail |
|--------|--------|
| **Consumes** | `CDGroupRegistry.get_nearest()` |
| **Emits** | Entity bus: configurable name, type `(Vector2)` |
| **Exports** | `target_group: StringName = &"enemies"` <br> `stop_distance: float = 10.0` <br> `move_signal: StringName = &"move"` |
| **Process** | Polls `game.group_registry.get_nearest()`. If target exists and distance > `stop_distance`, normalizes vector and emits. Otherwise emits `Vector2.ZERO`. |

#### FleeNearestBrain
**Role:** Emits directional signal away from the closest entity in a threat group.

| Aspect | Detail |
|--------|--------|
| **Consumes** | `CDGroupRegistry.get_nearest()` |
| **Emits** | Entity bus: configurable name, type `(Vector2)` |
| **Exports** | `threat_group: StringName = &"player"` <br> `flee_distance: float = 150.0` <br> `move_signal: StringName = &"move"` |
| **Process** | Finds nearest entity in `threat_group`. If within `flee_distance`, calculates vector away from threat, normalizes, and emits. Otherwise emits `Vector2.ZERO`. |

#### AimAtNearestBrain
**Role:** Emits directional signal pointing toward the closest entity in a target group.

| Aspect | Detail |
|--------|--------|
| **Consumes** | `CDGroupRegistry.get_nearest()` |
| **Emits** | Entity bus: configurable name, type `(Vector2)` |
| **Exports** | `target_group: StringName = &"enemies"` <br> `aim_signal: StringName = &"aim"` |
| **Process** | Polls `game.group_registry.get_nearest()`. If target exists, calculates direction from entity's global position and emits. |

#### OrbitBrain
**Role:** Calculates a target position on a circle around a target entity and emits positional signal toward it.

| Aspect | Detail |
|--------|--------|
| **Consumes** | `CDGroupRegistry.get_group()` |
| **Emits** | Entity bus: configurable name, type `(Vector2)` |
| **Exports** | `target_group: StringName = &"leader"` <br> `orbit_radius: float = 50.0` <br> `orbit_speed: float = 2.0` <br> `move_signal: StringName = &"move_to"` |
| **Process** | Finds first entity in `target_group`. Calculates desired position on a circle around it based on elapsed time. Emits positional signal toward that point. |

---

### AI: Action Brains (2)

These decide when to fire an action signal based on world state.

#### ShootWhenAimedBrain
**Role:** Fires an action signal when a target falls within a vision cone relative to the entity's facing direction.

| Aspect | Detail |
|--------|--------|
| **Consumes** | `CDGroupRegistry.get_nearest()` |
| **Emits** | Entity bus: type `(StringName)` |
| **Exports** | `target_group: StringName = &"player"` <br> `vision_cone_angle: float = 15.0` (degrees) <br> `fire_action: StringName = &"shoot"` <br> `cease_action: StringName = &"shoot"` <br> `action_signal: StringName = &"action"` <br> `action_end_signal: StringName = &"action_end"` |
| **Process** | Finds nearest target. Calculates angle between entity's forward vector and direction to target. If angle < `vision_cone_angle`, emits `action_signal` with `fire_action`. Otherwise emits `action_end_signal` with `cease_action`. |

#### TimedStepBrain
**Role:** Emits a directional signal at a regular interval. Used for Block Drop / Tetris-style gravity.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Internal timer. Game bus `speed_up_signal` for dynamic adjustment. |
| **Emits** | Entity bus: configurable name, type `(Vector2)` |
| **Exports** | `step_interval: float = 1.0` <br> `step_direction: Vector2 = Vector2.DOWN` <br> `step_signal: StringName = &"move"` <br> `speed_up_signal: StringName = &"speed_up"` <br> `speed_up_factor: float = 0.9` |
| **Process** | Counts down `step_interval`. On zero, emits `step_signal` with `step_direction` and resets timer. Listens to game bus `speed_up_signal` to multiply `step_interval` by `speed_up_factor`. |

---

### AI: Path & Patrol Brains (4)

These generate movement targets from paths, patterns, or waypoints.

#### PatrolPathBrain
**Role:** Follows a pre-defined `Curve2D` resource, emitting positional targets along the path.

| Aspect | Detail |
|--------|--------|
| **Consumes** | `Curve2D` resource data. Internal state for path progress. |
| **Emits** | Entity bus: configurable name, type `(Vector2)` |
| **Exports** | `path_curve: Curve2D` <br> `use_global_coords: bool = false` <br> `loop: bool = true` <br> `retrace: bool = false` (ping-pong) <br> `speed: float = 100.0` <br> `arrival_distance: float = 5.0` <br> `move_signal: StringName = &"move_to"` <br> `complete_signal: StringName = &"patrol_complete"` |
| **Process** | Calculates target point on the `Curve2D` based on `speed` and delta. Emits `move_signal` with the target coordinate. If end is reached, handles `loop`, `retrace`, or emits `complete_signal`. |

#### RandomSweepBrain
**Role:** Generates a three-phase "enter, sweep, exit" flight path across the screen.

| Aspect | Detail |
|--------|--------|
| **Consumes** | CDGame bounds. Internal phase state. |
| **Emits** | Entity bus: type `(Vector2)` |
| **Exports** | `entry_edge: CDEnums.Edge` (TOP, LEFT, RIGHT, BOTTOM) <br> `exit_edge: CDEnums.Edge` <br> `entry_depth: float = 100.0` <br> `speed: float = 100.0` <br> `loop: bool = false` <br> `move_signal: StringName = &"move_to"` <br> `complete_signal: StringName = &"sweep_complete"` |
| **Process** | On `_on_initialize`, calculates 3 waypoints: (1) just inside `entry_edge` at `entry_depth`, (2) lateral sweep point, (3) just outside `exit_edge`. Emits `move_signal` for current target. When entity reaches target, advances phase. On phase 3 completion, either loops or emits `complete_signal`. |

#### IdleWanderBrain
**Role:** Picks random nearby points and meanders toward them.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Internal timer/state. Spawn position. |
| **Emits** | Entity bus: type `(Vector2)` |
| **Exports** | `wander_radius: float = 100.0` <br> `idle_time: float = 2.0` <br> `arrival_distance: float = 5.0` <br> `move_signal: StringName = &"move_to"` |
| **Process** | Picks a random point within `wander_radius` of spawn position. Emits `move_signal`. When entity arrives (within `arrival_distance`), waits `idle_time`, picks a new point. |

#### FormationBrain
**Role:** Calculates a target position as an offset from a "leader" entity and emits positional signal.

| Aspect | Detail |
|--------|--------|
| **Consumes** | `CDGroupRegistry.get_group()` |
| **Emits** | Entity bus: type `(Vector2)` |
| **Exports** | `leader_group: StringName = &"leader"` <br> `offset: Vector2 = Vector2(20, 0)` <br> `move_signal: StringName = &"move_to"` |
| **Process** | Queries group registry for first entity in `leader_group`. Calculates leader position + offset. Emits `move_signal` with calculated global position. |

---

### AI: Galaga-Specific Brain (1)

#### DiveBombBrain
**Role:** Listens for a `begin_dive` signal (typically from a stage controller) and generates a swooping attack path toward a target.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"begin_dive(target_position: Vector2)"`. CDGroupRegistry for target position fallback. |
| **Emits** | Entity bus: type `(Curve2D, float)` |
| **Exports** | `target_group: StringName = &"player"` <br> `dive_signal: StringName = &"begin_dive"` <br> `curve_signal: StringName = &"follow_curve"` <br> `dive_speed: float = 200.0` |
| **Process** | On `dive_signal`, calculates a bezier swooping curve from entity position toward the target. Emits `curve_signal` with the generated Curve2D and speed. |

---

## Legs (18 Components)

Category: `LEGS` (Priority 20). Movement executors. Consume entity bus signals and submit velocity/position requests. Never generate intent.

### Continuous Physics Legs (7)

These build a velocity vector over time using the velocity accumulator API.

#### EightWayWalk
**Role:** Hard-sets velocity from a directional input signal. Instant response, no inertia.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: type `(Vector2)` |
| **Generates** | `entity.request_velocity_set(direction * speed)` |
| **Exports** | `speed: float = 200.0` <br> `move_signals: Array[StringName] = [&"move"]` |
| **Process** | On signal, normalizes direction and requests velocity. If signal hasn't fired this frame, requests `Vector2.ZERO`. |
| **V1 Predecessor** | `direct_movement.gd` |

#### AccelDecel
**Role:** Accelerates toward an input direction. Requires Friction to slow down.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: type `(Vector2)` |
| **Generates** | `entity.request_velocity_add(direction * acceleration * delta)` |
| **Exports** | `acceleration: float = 800.0` <br> `max_speed: float = 300.0` <br> `move_signals: Array[StringName] = [&"move"]` |
| **Process** | On signal, adds acceleration. Clamps current speed to prevent exceeding `max_speed`. |
| **V1 Predecessor** | `direct_acceleration.gd` |

#### EngineThrust
**Role:** Adds forward velocity based on the entity's current facing direction (Asteroids-style).

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: action type `(StringName)` — filters for configured thrust action name |
| **Generates** | `entity.request_velocity_add(transform.x * thrust_power * delta)` |
| **Exports** | `thrust_action: StringName = &"thrust"` <br> `action_signal: StringName = &"action"` <br> `action_end_signal: StringName = &"action_end"` <br> `thrust_power: float = 400.0` <br> `max_speed: float = 350.0` |
| **Process** | Listens for `action_signal` with matching `thrust_action`. While thrusting, adds forward acceleration. Caps at `max_speed`. |
| **V1 Predecessor** | `engine_simple.gd`, `engine_complex.gd` |

#### FrictionLinear
**Role:** Proportional drag — higher speed = more deceleration. Slides to a stop.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Reads `entity.velocity` per frame. |
| **Generates** | `entity.request_velocity_add(-drag_force)` |
| **Exports** | `friction_coefficient: float = 2.0` |
| **Process** | Every frame, calculates drag as `entity.velocity * friction_coefficient * delta` and requests the negative force. |
| **V1 Predecessor** | `friction_linear.gd` |

#### FrictionStatic
**Role:** Constant deceleration until velocity reaches zero. Heavy, sticky feel.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Reads `entity.velocity` per frame. |
| **Generates** | `entity.request_velocity_add(-drag_force)` |
| **Exports** | `deceleration: float = 100.0` |
| **Process** | Every frame, calculates deceleration vector opposite to velocity. If deceleration would overshoot zero, requests exactly `-entity.velocity` to snap to stop. |
| **V1 Predecessor** | `friction_static.gd` |

#### SteeringLeg
**Role:** Adds a steering force toward a desired direction, smoothly blending with current velocity. For Boids/flocking or organic movement.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: type `(Vector2)` |
| **Generates** | `entity.request_velocity_add(steering_force)` |
| **Exports** | `steering_force: float = 5.0` <br> `max_speed: float = 200.0` <br> `move_signals: Array[StringName] = [&"move"]` |
| **Process** | Calculates desired velocity (`direction * max_speed`). Calculates steering (`desired - current_velocity`). Limits force to `steering_force`, adds to accumulator. |

#### BoomerangLeg
**Role:** Applies a force that returns the entity toward its spawn point (or spawner entity) with damping.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Internal state. Reads `entity.velocity`. |
| **Generates** | `entity.request_velocity_add(return_force_vector)` |
| **Exports** | `return_force: float = 5.0` <br> `damping: float = 0.98` |
| **Process** | Calculates vector to return target (spawn position by default). Adds `return_force` toward it. Applies `damping` to current velocity so entity eventually stops at target instead of orbiting. |

---

### Rotation Legs (2)

#### RotationDirect
**Role:** Tank-style continuous rotation from spin direction input.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: type `(float)` |
| **Generates** | Modifies `entity.rotation` directly |
| **Exports** | `rotation_speed: float = 3.0` (radians/sec) <br> `rotate_signals: Array[StringName] = [&"rotate"]` |
| **Process** | Adds `spin_direction * rotation_speed * delta` to `entity.rotation`. |
| **V1 Predecessor** | `rotation_direct.gd` |

#### RotationTarget
**Role:** Interpolates or snaps toward an aim direction.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: type `(Vector2)` |
| **Generates** | Modifies `entity.rotation` |
| **Exports** | `interpolation_speed: float = 10.0` (0 = instant snap) <br> `aim_signals: Array[StringName] = [&"aim"]` |
| **Process** | Calculates target angle from direction. Interpolates `entity.rotation` toward target using `lerp_angle` and `interpolation_speed`. |
| **V1 Predecessor** | `rotation_target.gd` |

---

### Grid Legs (4)

Discrete instant displacement. These bypass the velocity accumulator and use the position API.

#### GridMovementLeg
**Role:** Moves entity by a fixed grid step, only if target cell is unoccupied.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: type `(Vector2)` |
| **Generates** | `entity.request_position_add(step_vector)` if valid |
| **Exports** | `cell_size: Vector2 = Vector2(16, 16)` <br> `check_collision: bool = true` <br> `move_signals: Array[StringName] = [&"move"]` |
| **Process** | On signal, calculates target position: `entity.global_position + (direction * cell_size)`. If `check_collision`, runs physics shape query at target. If clear, calls `entity.request_position_add()`. |
| **V1 Predecessor** | `grid_movement.gd` |

#### GridRotationLeg
**Role:** Snaps rotation to discrete intervals (default 90°).

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: type `(float)` |
| **Generates** | Modifies `entity.rotation` |
| **Exports** | `rotation_step: float = PI / 2.0` <br> `rotate_signals: Array[StringName] = [&"rotate"]` |
| **Process** | Adds `spin_direction * rotation_step` to `entity.rotation`. |
| **V1 Predecessor** | `grid_rotation.gd` |

#### GridRotationAdvanced
**Role:** Tetris-style rotation with wall-kick offset tables.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: type `(float)` |
| **Generates** | `entity.request_position_add(kick_offset)` and modifies `entity.rotation` |
| **Exports** | `kick_table: WallKickResource` (custom resource) <br> `rotation_step: float = PI / 2.0` <br> `rotate_signals: Array[StringName] = [&"rotate"]` |
| **Process** | On signal, calculates target rotation. Iterates through `kick_table`. Performs physics query at `entity.pos + offset` with new rotation. First valid offset is applied. |
| **V1 Predecessor** | `grid_rotation_advanced.gd` |

**Note:** `WallKickResource` is a custom Resource defined alongside this component. Contains an `Array[Array[Vector2]]` mapping rotation state to kick offsets.

#### GridDropLeg
**Role:** Tweens entity down by N cells (used for line clear settling, piece locking).

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: type `(int)` |
| **Generates** | Tweens `entity.global_position` |
| **Exports** | `cell_size_y: float = 18.0` <br> `tween_duration: float = 0.1` <br> `drop_signals: Array[StringName] = [&"grid_drop"]` |
| **Process** | On signal, calculates target Y: `entity.global_position.y + (drop_count * cell_size_y)`. Creates tween for smooth visual drop. |
| **V1 Predecessor** | `grid_gravity.gd` |

---

### Spatial Utility Legs (3)

#### ScreenWrapLeg
**Role:** Wraps entity to opposite side of screen when out of bounds.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity `global_position` per frame |
| **Generates** | `entity.request_position_set(wrapped_position)` |
| **Exports** | `wrap_margin: float = 20.0` |
| **Process** | Checks if position exceeds `game.game_bounds` + margin. If so, calculates offset to opposite side and sets position. |
| **V1 Predecessor** | `warp_asteroids.gd` |

#### ScreenClampLeg
**Role:** Prevents entity from leaving screen boundaries.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity `global_position` per frame |
| **Generates** | `entity.request_position_set(clamped_position)` |
| **Exports** | `margin: float = 0.0` |
| **Process** | Checks if position + margin exceeds `game.game_bounds`. If so, clamps position. (Note: CDEntity has a hard safety clamp, but this Leg provides smooth, configurable gameplay clamping.) |

#### GridAlignmentLeg
**Role:** Ensures entity stays snapped to a pseudo-grid. Snaps on init, corrects drift periodically. Eliminates the need for pixel-perfect editor placement of grid entities.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity `global_position` (at configurable interval) |
| **Generates** | `entity.request_position_set(snapped_position)` |
| **Exports** | `cell_size: Vector2 = Vector2(16, 16)` <br> `grid_origin: Vector2 = Vector2.ZERO` (where the grid begins) <br> `check_interval: float = 0.0` (0 = every frame, >0 = timer-based) <br> `drift_threshold: float = 0.5` (only correct if drift exceeds this) |
| **Process** | On `_on_initialize()`, immediately snaps to nearest grid cell: `grid_origin + round((pos - grid_origin) / cell_size) * cell_size`. During `_physics_process()`, if `check_interval` has elapsed and drift exceeds `drift_threshold`, snaps back to grid. |
| **Does NOT** | Check occupancy. Make gameplay decisions. Search for alternative positions. |
| **Use Case** | Tetris playfields, grid-based puzzle games, any entity that must stay on-grid but doesn't necessarily use GridMovementLeg (e.g., playfield boundaries, spawn markers, settled blocks). |

---

### Path & Formation Legs (2)

#### PathFollowerLeg
**Role:** Follows a Curve2D path at a given speed. Emits a signal on completion.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: type `(Curve2D, float)` |
| **Generates** | `entity.request_position_set(path_position)` per frame |
| **Exports** | `curve_signals: Array[StringName] = [&"follow_curve"]` <br> `arrival_distance: float = 5.0` <br> `complete_signal: StringName = &"path_finished"` |
| **Process** | On curve signal, stores curve and speed. Each frame, advances along curve based on speed * delta. Sets position to curve point. When end is reached, emits `complete_signal`. |

#### SmoothToLeg
**Role:** Smoothly interpolates toward a moving target position. Used for formation breathing, settling into slots.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: type `(Vector2)` |
| **Generates** | `entity.request_position_set(interpolated_position)` |
| **Exports** | `interpolation_speed: float = 5.0` <br> `move_signals: Array[StringName] = [&"move_to"]` |
| **Process** | On signal, stores target. Each frame, interpolates `entity.global_position` toward target using `lerp` and `interpolation_speed * delta`. Continuously chases moving targets. |

---

## V1 → V2 Migration Map

| V1 Script | V2 Component(s) | Key Changes |
|-----------|----------------|-------------|
| `player_control.gd` | PlayerMoveBrain + PlayerAimBrain + PlayerActionBrain | Split into 3 single-concern brains. Input routes through CDInputRouter. |
| `interceptor_ai.gd` | ChaseNearestBrain + AimAtNearestBrain | V1 monolith split into two single-purpose brains |
| `aim_ai.gd` | AimAtNearestBrain | Direct migration, now uses group registry |
| `clear_shot_ai.gd` | ShootWhenAimedBrain | Vision cone logic extracted cleanly |
| `cover_ai.gd` | FleeNearestBrain + PatrolPathBrain | flee + patrol hybrid split into two |
| `falling_ai.gd` | RandomSweepBrain | V1 "fall into screen" → V2 3-phase sweep |
| `patrol_ai.gd` | PatrolPathBrain | Now uses Curve2D resources |
| `shoot_ai.gd` | ShootWhenAimedBrain | Direct migration |
| `shoot_ai_swarm.gd` | (Eliminated — stage controllers handle this) | Controller emits directly on entity bus |
| `swarm_ai.gd` | (Eliminated — stage controllers handle this) | Controller emits directly on entity bus |
| `swarm_controller_player.gd` | (Eliminated — decomposed into stage controllers) | See Plan 20 amendment below |
| `direct_movement.gd` | EightWayWalk | Now uses velocity accumulator |
| `direct_acceleration.gd` | AccelDecel | Now uses velocity accumulator |
| `engine_simple.gd` | EngineThrust | Now uses velocity accumulator + action signals |
| `engine_complex.gd` | EngineThrust + RotationDirect | V1 combined engine split into two legs |
| `friction_linear.gd` | FrictionLinear | Direct migration, now uses accumulator |
| `friction_static.gd` | FrictionStatic | Direct migration |
| `grid_gravity.gd` | TimedStepBrain + GridDropLeg | V1 combined gravity/step → Brain + Leg |
| `grid_movement.gd` | GridMovementLeg | Direct migration |
| `grid_rotation.gd` | GridRotationLeg | Direct migration |
| `grid_rotation_advanced.gd` | GridRotationAdvanced | Direct migration, wall-kick now via Resource |
| `rotation_direct.gd` | RotationDirect | Direct migration |
| `rotation_target.gd` | RotationTarget | Direct migration |
| `warp_asteroids.gd` | ScreenWrapLeg | Direct migration |

---

## Swarm Controllers — Deferred to Plan 25

The following Stage controllers were previously listed as a Plan 20 amendment. They are now deferred to **Plan 25 (V2 Controllers)**, which will spec them fully with exports, signal contracts, and behavior descriptions. They were previously conflated with entity-level brains.

| Component | Category | Description |
|-----------|----------|-------------|
| `SwarmGridStepController` | Stage (Priority 70) | Emits discrete `move(Vector2)` on a timer to all entities in a configured group |
| `SwarmBottomRowShootController` | Stage (Priority 70) | Emits `action(StringName)` to the bottom row of a formation group |
| `SwarmFormationController` | Stage (Priority 70) | Emits `move_to(Vector2)` to direct entities into formation slots (defined by a FormationResource) |
| `SwarmFlockMovementController` | Stage (Priority 70) | Emits `move(Vector2)` based on Boid-style rules (separation, alignment, cohesion) |

**Rationale for Stage placement:** Controllers emit directly on entity buses. They ARE the brain for formation entities. No entity-level SwarmMemberBrain is needed — entities just need Legs that respond to the signals these controllers emit.

**Why deferred:** These controllers are critical for Space Invaders and Galaga, but they had no concrete specs (no exports, signal contracts, or behavior descriptions). Plan 25 will provide full specifications before implementation.

---

## Implementation Order

### Phase 1: Foundation (verify patterns work)
1. PlayerMoveBrain + EightWayWalk → prove directional signal flow
2. PlayerAimBrain + RotationTarget → prove aim signal flow
3. PlayerActionBrain (stub) → prove action signal flow
4. FrictionLinear → prove accumulator coexistence with set/add

### Phase 2: AI Targeting
5. ChaseNearestBrain → prove CDGroupRegistry integration
6. FleeNearestBrain → inverse of chase
7. AimAtNearestBrain → directional + rotation chain
8. OrbitBrain → positional target generation

### Phase 3: AI Action + Path
9. ShootWhenAimedBrain → action signal generation
10. TimedStepBrain → interval-based directional
11. PatrolPathBrain → Curve2D + positional signal
12. RandomSweepBrain → multi-phase positional
13. IdleWanderBrain → random positional
14. FormationBrain → leader offset positional

### Phase 4: Additional Legs
15. AccelDecel → accumulator add pattern
16. EngineThrust → action-triggered accumulator
17. FrictionStatic → accumulator subtract pattern
18. SteeringLeg → desired-velocity pattern
19. BoomerangLeg → return-force pattern

### Phase 5: Rotation + Grid
20. RotationDirect → float signal pattern
21. GridMovementLeg → position_add pattern
22. GridRotationLeg → discrete rotation
23. GridRotationAdvanced + WallKickResource → complex grid movement
24. GridDropLeg → tween-based drop

### Phase 6: Spatial + Path
25. ScreenWrapLeg → bounds check pattern
26. ScreenClampLeg → bounds clamp pattern
27. GridAlignmentLeg → grid snap + drift correction
28. PathFollowerLeg → Curve2D consumption
29. SmoothToLeg → interpolation pattern

### Phase 7: Galaga-Specific
30. DiveBombBrain → curve generation + game bus listen

---

## Proof / Testing

After all components are built, create test scenes that prove:

### Test 1: Player Control Chain
- PlayerMoveBrain + EightWayWalk on a CDEntity
- WASD input → CDInputRouter → PlayerMoveBrain → entity bus → EightWayWalk → entity moves
- Verify configurable signal names: change `move_signal` to `&"custom_move"` on both, verify it still works

### Test 2: AI Chase Chain
- ChaseNearestBrain + AccelDecel + FrictionLinear on entity A
- Entity B (static) in `"player"` group
- Verify entity A accelerates toward B, friction slows it when B moves away

### Test 3: Accumulator Non-Conflict
- AccelDecel + FrictionLinear on same entity
- AccelDecel adds velocity, FrictionLinear subtracts
- Verify both contribute to final velocity without order-dependent bugs
- Verify entity reaches a terminal velocity (acceleration balanced by friction)

### Test 4: Multi-Signal Leg
- EightWayWalk with `move_signals = [&"move", &"push"]`
- Two different brains emit on different signal names
- Verify leg responds to both

### Test 5: Grid Movement
- TimedStepBrain + GridMovementLeg on entity
- Verify entity steps down one cell per interval
- Verify collision check prevents stepping into occupied cell

### Test 6: Patrol Path
- PatrolPathBrain + SmoothToLeg on entity
- Curve2D with 3 points, `loop = true`
- Verify entity follows path and loops

### Test 7: Pool Lifecycle
- Entity with ChaseNearestBrain, pulled from pool
- `activate()` → brain re-initializes, connects to game bus
- `deactivate()` → brain resets state, disconnects
- Re-activate from pool → brain works again

### Test 8: Signal Mismatch Graceful Degradation
- Brain emits `(Vector2)` on signal `"move"`
- Leg expects `(float)` on signal `"move"`
- Verify `push_error()` in console, entity continues running

### Test 9: Grid Alignment
- Place entity at approximately (33, 17) in the editor
- GridAlignmentLeg with `cell_size = (16, 16)`, `grid_origin = (0, 0)`
- On init, verify entity snaps to (32, 16)
- Move entity slightly off-grid (simulate drift), verify correction
- GridMovementLeg + GridAlignmentLeg on same entity: step fires, GridAlignmentLeg corrects any residual drift

---

## File Structure

```
Godot/Scripts/
├── Brains/
│   ├── player_move_brain.gd
│   ├── player_aim_brain.gd
│   ├── player_action_brain.gd
│   ├── chase_nearest_brain.gd
│   ├── flee_nearest_brain.gd
│   ├── aim_at_nearest_brain.gd
│   ├── orbit_brain.gd
│   ├── shoot_when_aimed_brain.gd
│   ├── timed_step_brain.gd
│   ├── patrol_path_brain.gd
│   ├── random_sweep_brain.gd
│   ├── idle_wander_brain.gd
│   ├── formation_brain.gd
│   └── dive_bomb_brain.gd
├── Legs/
│   ├── eight_way_walk.gd
│   ├── accel_decel.gd
│   ├── engine_thrust.gd
│   ├── friction_linear.gd
│   ├── friction_static.gd
│   ├── steering_leg.gd
│   ├── boomerang_leg.gd
│   ├── rotation_direct.gd
│   ├── rotation_target.gd
│   ├── grid_movement_leg.gd
│   ├── grid_rotation_leg.gd
│   ├── grid_rotation_advanced.gd
│   ├── grid_drop_leg.gd
│   ├── screen_wrap_leg.gd
│   ├── screen_clamp_leg.gd
│   ├── grid_alignment_leg.gd
│   ├── path_follower_leg.gd
│   └── smooth_to_leg.gd
├── Resources/
│   └── wall_kick_resource.gd     # Custom resource for GridRotationAdvanced
```

---

## Risks & Open Questions

1. **Signal type at registration:** Godot's `add_user_signal()` lets you define parameter types, but the enforcement is advisory (prints a warning, doesn't crash). Our entity-level error policy handles this — components `push_error()` on type mismatch. This is acceptable for development velocity.

2. **EightWayWalk + request_velocity_set:** This is the only common component that uses `set` instead of `add`. If both EightWayWalk and FrictionLinear are on the same entity, set would override friction's add. This is by design — EightWayWalk entities don't use friction. If an entity needs both inertia and directional control, use AccelDecel instead. This should be documented clearly in the component catalog.

3. **PathFollowerLeg uses position API:** Path following sets position directly via `request_position_set`, not velocity. This means it bypasses the accumulator and friction. A path-following entity should not have friction legs. This is correct behavior — you don't want friction slowing down a path-following enemy.

4. **WallKickResource complexity:** The wall-kick offset table for Tetris rotation is game-specific (different tables for SRS, NES, etc.). `WallKickResource` should be designed as a data-only resource that can be swapped in the editor without code changes.

5. **DiveBombBrain curve generation:** This component dynamically generates a Curve2D at runtime based on the dive request. Curve2D is typically an editor resource, but programmatic creation is fully supported. This is an acceptable pattern for runtime AI.

6. **GridAlignmentLeg + other position legs:** GridAlignmentLeg uses `request_position_set` on a timer/interval. If combined with other position-setting legs (SmoothToLeg, PathFollowerLeg), the last `set` call wins at Priority 30. GridAlignmentLeg is intended for entities whose primary movement is grid-based (via GridMovementLeg or GridDropLeg), not for entities using continuous position interpolation. If both are needed, set GridAlignmentLeg's `check_interval` high enough that it only corrects accumulated drift between movements, not mid-interpolation.
