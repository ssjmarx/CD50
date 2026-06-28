# Legs

Legs are `CDEntityComponent` scripts that translate intent into **motion requests**. They are the steering layer of an entity: they read input/state (almost always from the entity blackboard), and each frame they push motion requests into the entity (`request_velocity_add`, `request_position_set`, etc.). The actual physics integration happens elsewhere on the entity; legs only **request** changes.

> Every script in this folder was documented from its own source. No external planning docs were used.

---

## Shared conventions (observed across the files)

These patterns recur in **every** script here — they are the contract a leg follows.

### Base class & category
```gdscript
class_name <Name>Leg extends CDEntityComponent

func _ready() -> void:
    component_category = CDEnums.ComponentCategory.STEERING
    super._ready()
```
All legs register themselves under the `STEERING` component category.

### Frame work happens in `_physics_process`
Legs do their work in `_physics_process(delta)`. There is no `_process` use. The first line of most physics loops is a guard such as `if not entity: return`.

### Input comes from the entity blackboard
Legs read their input by polling `entity.blackboard` (a Dictionary). The common idiom is:
```gdscript
var direction: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)
var distance: float  = entity.blackboard.get(distance_key, 0.0)
```
Keys are exposed as `@export var *_key: StringName` with `&"..."` defaults, grouped under `@export_group("Blackboard Keys")`. Observed default key names:
- `move_direction` (Vector2)
- `move_distance` (float, pixels)
- `rotation_spin` (float: +1 CW / -1 CCW)
- `drop_count` (int)
- `captured_by` (CDEntity reference, used by `LeaderTeleportLeg`)

### Output goes through request calls
Legs never mutate position/velocity directly. They call one of these on `entity`:
| Call | Meaning |
|---|---|
| `request_velocity_add(vec)` | Add an impulse/force (momentum-style; accumulates) |
| `request_velocity_set(vec)` | Hard-set velocity (no momentum carryover) |
| `request_position_add(vec)` | Translate by a delta |
| `request_position_set(vec)` | Snap to a world position |
| `request_rotation_add(rad)` | Rotate by an angular delta |
| `request_rotation_set(rad)` | Set absolute rotation |
| `request_angular_set(rad/s)` | Set angular velocity |

The **adders vs setters** split in this folder's structure mirrors the request calls they prefer:
- **adders/** → legs that *accumulate* motion via `request_velocity_add` (momentum, friction, thrust).
- **setters/** → legs that *snap* motion via `request_velocity_set` / `request_position_set` / `request_rotation_set` (direct, grid, target).

### Signals
Legs communicate results over the **entity bus**:
- `entity.bus_emit(sig)` to fire a signal.
- `entity.ensure_signal(sig)` to declare a signal exists (used by `GridRotationLeg`).
- `self.bus_connect(sig, callable)` / `self.bus_disconnect(sig, callable)` to subscribe/unsubscribe (used by `EngineLeg`, `LeaderTeleportLeg`).
- Emit lists are exposed as `@export var *_signals: Array[StringName]` under `@export_group("Emit Signals")`.
- "After" signals (e.g. post-teleport, post-wrap) are deferred with `Callable.call_deferred()` so the requested motion settles first.

### Game-level access
Some legs reach up to the game:
- `game.game_bounds` — `Rect2` playfield, used by `ScreenWrapLeg`.
- `game.blackboard` — game-wide blackboard, used by `LeaderTeleportLeg` (selectable via its `BlackboardSource` enum).

### Lifecycle hooks used
- `_ready()` — set `component_category`, call `super._ready()`.
- `_on_initialize()` — optional setup (e.g. wire signals). Often empty `pass`.
- `_on_entity_deactivating()` — cleanup; always calls `super._on_entity_deactivating()` first, then resets internal state for pool reuse. **Not all legs override this** — `BoomerangLeg`, `LinearFrictionLeg`, and `StaticFrictionLeg` have no cleanup hook.

### Sibling discovery (loosely typed)
Two grid legs find sibling components by script global name rather than by typed reference:
```gdscript
child.get_script().get_global_name() == &"TetrominoGuts"
child.get_script().get_global_name() == &"GridMovementLeg"
```
This avoids hard dependencies between components.

### Collision probes
Grid legs test occupancy with a `PhysicsPointQueryParameters2D` point-cast against `entity.get_world_2d().direct_space_state`, excluding the entity's own RID.

---

## Folder layout

```
legs/
├── directional adders/      # momentum-based motion from a direction
│   ├── acceleration_movement_leg.gd   -> AccelerationLeg
│   ├── direct_movement_leg.gd         -> DirectMovementLeg
│   └── engine_leg.gd                  -> EngineLeg
├── directional setters/      # snap-to motion from a direction
│   ├── direct_rotation_leg.gd         -> DirectRotationLeg
│   ├── grid_movement_leg.gd           -> GridMovementLeg
│   └── grid_rotation_leg.gd           -> GridRotationLeg
├── positional adders/        # momentum-based motion toward a target distance
│   └── acceleration_target_leg.gd     -> AccelerationTargetLeg
├── positional setters/       # snap-to motion toward a target distance
│   ├── direct_target_leg.gd           -> DirectTargetLeg
│   └── target_rotation_leg.gd         -> TargetRotationLeg
└── other/                    # friction, wrapping, alignment, teleports
    ├── boomerang_leg.gd               -> BoomerangLeg
    ├── grid_alignment_leg.gd          -> GridAlignmentLeg
    ├── grid_drop_leg.gd               -> GridDropLeg
    ├── leader_teleport_leg.gd         -> LeaderTeleportLeg
    ├── linear_friction_leg.gd         -> LinearFrictionLeg
    ├── screen_wrap_leg.gd             -> ScreenWrapLeg
    └── static_friction_leg.gd         -> FrictionStatic
```

> ⚠️ Two filenames don't match their `class_name`:
> - `acceleration_movement_leg.gd` declares `class_name AccelerationLeg`
> - `static_friction_leg.gd` declares `class_name FrictionStatic`

---

## Directional Adders

Momentum legs: they **add** force each frame from a direction on the blackboard. Pair them with a friction leg (see `other/`) for speed control.

### `acceleration_movement_leg.gd` — `AccelerationLeg`
Adds acceleration force in `move_direction` every frame, building momentum over time.

- **Exports**
  - `acceleration: float = 800.0` — px/s².
  - `direction_key: StringName = &"move_direction"` — Vector2 read from blackboard.
- **Behavior**: reads direction; if non-zero, `request_velocity_add(direction.normalized() * acceleration * delta)`. Does nothing when direction is zero — relies on a friction leg to stop the entity.
- **Cleanup**: resets nothing (stateless).

### `direct_movement_leg.gd` — `DirectMovementLeg`
Hard-sets velocity from `move_direction`, zeroing it when there's no input (no drift). Optionally caps per-frame travel so the entity can't overshoot a remaining distance.

- **Exports**
  - `speed: float = 200.0` — px/s.
  - `direction_key: StringName = &"move_direction"`.
  - `distance_key: StringName = &"move_distance"` — optional float; if present and set, the leg caps this frame's velocity so total travel doesn't exceed the remaining distance.
- **Behavior**:
  - Direction non-zero → `target_velocity = direction.normalized() * speed`. If `distance_key` is set and `speed * delta > max_distance`, velocity is scaled by `max_distance / frame_distance`. Then `request_velocity_set(...)`.
  - Direction zero → `request_velocity_set(Vector2.ZERO)`.
- **Note**: this leg is a *setter* of velocity but lives in `adders/` (it builds no momentum; "direct" in the name refers to non-accelerated movement).

### `engine_leg.gd` — `EngineLeg`
Asteroids-style thrust: adds forward velocity based on the entity's **facing** (`entity.rotation`), gated by entity-bus signals rather than a blackboard key.

- **Exports**
  - `thrust_power: float = 400.0` — force/s while thrusting.
  - `thrust_signal: StringName = &"thrust"`.
  - `end_thrust_signal: StringName = &"thrust_end"`.
- **Behavior**: in `_on_initialize()` it connects the two signals and **disables** `_physics_process`. On `thrust` it sets `_is_thrusting = true` and enables physics processing; on `thrust_end` it stops. While thrusting, computes forward = `Vector2(cos(rotation), sin(rotation))` and `request_velocity_add(forward * thrust_power * delta)`.
- **Cleanup**: disconnects both signals, clears state, disables physics processing.

---

## Directional Setters

Snap legs: they **set** velocity, position, or rotation directly from a direction (continuous or grid-stepped).

### `direct_rotation_leg.gd` — `DirectRotationLeg`
Tank-style continuous spin driven by `move_direction.x`.

- **Exports**
  - `rotation_speed: float = 180.0` — deg/s.
  - `direction_key: StringName = &"move_direction"` — only the **x** component is used as spin (-1..1).
- **Behavior**: `spin = direction.x`; if non-zero, `request_angular_set(spin * deg_to_rad(rotation_speed))`, else `request_angular_set(0.0)`.

### `grid_movement_leg.gd` — `GridMovementLeg`
Moves the entity by fixed grid steps. Supports two input modes and queues/buffers discrete presses.

- **Exports**
  - `cell_size: Vector2 = Vector2(16, 16)` — pixel size of one cell.
  - `check_collision: bool = true` — point-cast the target cell before moving.
  - `hop_delay: float = 0.0` — seconds between queue drains (`0` = every frame).
  - `max_queue_size: int = 4` — buffered inputs (`0` = no buffering, execute immediately).
  - `allow_diagonal: bool = false`.
  - Keys: `direction_key = &"move_direction"`, `distance_key = &"move_distance"`, `step_direction_key = &"step_direction"` (written after a successful step).
  - Emits: `step_blocked_signals = [&"step_blocked"]`, `step_taken_signals = [&"step_taken"]`.
- **Modes** (chosen per-frame by presence of `distance_key`):
  - **Continuous** (`distance_key >= 0`): chops continuous intent into discrete steps via an accumulator (`_accumulated_step_distance`), bypassing the input queue. If a step is blocked, the accumulator resets.
  - **Discrete**: edge-detects changes in `move_direction` (compared to `_prev_direction`), converts to a `Vector2i` step, and either enqueues it (if `max_queue_size > 0`) or executes immediately.
- **Step execution** (`_try_step`): computes `target = position + step * cell_size`; if `check_collision` and the cell is occupied → emit `step_blocked` and return false; else `request_position_add(displacement)`, write `step_direction_key`, emit `step_taken`.
- **Queue drain**: `hop_delay <= 0` drains every frame; otherwise drains when `_hop_timer >= hop_delay`. Draining pops entries until one succeeds.
- **Direction → step**: dominant axis wins; diagonals only when `allow_diagonal` and both axes exceed 0.5.
- **Cleanup**: clears queue, `_prev_direction`, timers, accumulator.

### `grid_rotation_leg.gd` — `GridRotationLeg`
Tetris-style rotation with SRS wall-kick offsets, driven by edge detection on `rotation_spin`.

- **Exports**
  - `kick_table: CDWallKick` — wall-kick offset resource.
  - `rotation_step: float = PI / 2.0` — radians per step.
  - `spin_key: StringName = &"rotation_spin"` — float (+1 CW / -1 CCW).
  - Emits: `rotation_blocked_signals = [&"rotation_blocked"]`.
- **Dependencies** (both discovered by script-name lookup, may be absent):
  - `TetrominoGuts` sibling — provides per-rotation cell offsets and `get_rotation_index()`.
  - `GridMovementLeg` sibling — its `cell_size` is read for world-space validation.
- **Behavior**: on `_on_initialize`, ensures the blocked signal exists and finds `TetrominoGuts`. Each frame, if `spin != 0` and differs from `_prev_spin`, it rotates once.
  - **Without** `TetrominoGuts`: simple `request_rotation_add(spin * rotation_step)`.
  - **With** `TetrominoGuts`: computes target rotation index (mod 4), fetches offsets, tries the base position, then each kick from `kick_table.get_kicks(current, target)`. First valid position (all cells unoccupied) → `set_rotation(index)` and `request_position_add(kick * cell_size)`. If all fail → emit `rotation_blocked`.
- **Validation**: each candidate offset+kick is point-cast for occupancy.
- **Cleanup**: resets `_prev_spin`, drops the guts reference.

---

## Positional Adders

### `acceleration_target_leg.gd` — `AccelerationTargetLeg`
Accelerates toward a target by reading `move_direction` + `move_distance`, tapering the force as it approaches.

- **Exports**
  - `acceleration: float = 800.0` — px/s².
  - `slow_distance: float = 100.0` — distance at which tapering begins.
  - `stop_distance: float = 5.0` — distance at which force reaches zero (and the leg stops applying).
  - Keys: `direction_key = &"move_direction"` (assumed normalized), `distance_key = &"move_distance"`.
- **Behavior**: no-op if `distance <= stop_distance` or direction is zero. Otherwise computes
  `accel_factor = clamp((distance - stop_distance) / (slow_distance - stop_distance), 0, 1)` and
  `request_velocity_add(direction * acceleration * accel_factor * delta)`.
- **Note**: does **not** write back to `move_distance`; an external system is expected to update it.

---

## Positional Setters

### `direct_target_leg.gd` — `DirectTargetLeg`
Constant-speed travel in `move_direction`, consuming `move_distance` until arrival.

- **Exports**
  - `speed: float = 200.0` — px/s.
  - `arrival_threshold: float = 2.0` — stop distance.
  - Keys: `direction_key = &"move_direction"`, `distance_key = &"move_distance"`.
- **Behavior**: if `distance <= arrival_threshold` → `request_velocity_set(Vector2.ZERO)` and return. Else `request_velocity_set(direction * speed)` and **write back** `move_distance = max(0, distance - speed * delta)`. (It is the only leg here that decrements its own distance key.)
- **Note**: the `step` variable (`speed * delta`) is computed but only used for the writeback; the actual velocity is unscaled.

### `target_rotation_leg.gd` — `TargetRotationLeg`
Rotates to face the `move_direction` vector.

- **Exports**
  - `rotation_speed: float = 360.0` — deg/s (`<= 0` = instant snap).
  - `direction_key = &"move_direction"`.
- **Behavior**: no-op if direction is zero. `target_angle = direction.angle()`. If `rotation_speed <= 0` → `request_rotation_set(target_angle)`. Otherwise step toward the target by at most `deg_to_rad(rotation_speed) * physics_delta`, with overshoot prevention: if within one step, snap exactly; else move `sign(diff) * max_step`.

---

## Other (friction, wrapping, alignment, teleports)

### `boomerang_leg.gd` — `BoomerangLeg`
Applies a constant return force toward the entity's spawn position.

- **Exports**: `return_force: float = 5.0` — force/s toward spawn.
- **Behavior**: `to_origin = entity._spawn_position - entity.global_position`; if non-zero, `request_velocity_add(to_origin.normalized() * return_force * delta)`. (Note the underscore-prefixed `_spawn_position` member on the entity.)
- **Cleanup**: none (no `_on_entity_deactivating` override).

### `grid_alignment_leg.gd` — `GridAlignmentLeg`
Snaps the entity back onto a pseudo-grid, correcting drift past a threshold.

- **Exports**
  - `cell_size: Vector2 = Vector2(16, 16)`.
  - `grid_origin: Vector2 = Vector2.ZERO`.
  - `check_interval: float = 1.0` — seconds between checks (`0` = every frame).
  - `drift_threshold: float = 0.01` — minimum drift to correct.
- **Behavior**: on `_on_initialize`, immediately `request_position_set(_snap(pos))`. Each tick (gated by `check_interval`), if the current position is ≥ `drift_threshold` from its snapped position, snap it. Snapping rounds `(pos - origin) / cell_size` then scales back.
- **Cleanup**: resets `_check_timer`.

### `grid_drop_leg.gd` — `GridDropLeg`
Instantly drops the entity N cells, edge-triggered on `drop_count`. Intended for line-clear settling.

- **Exports**
  - `cell_size_y: float = 18.0` — height of one cell.
  - `drop_count_key: StringName = &"drop_count"` — int.
- **Behavior**: edge-detects `drop_count` changes. When `drop_count > 0` and differs from `_prev_drop_count`, performs `request_position_add(Vector2(0, drop_count * cell_size_y))`, then **erases** `drop_count` from the blackboard and resets `_prev_drop_count` to 0. Otherwise records `_prev_drop_count`.
- **Cleanup**: resets `_prev_drop_count`.

### `leader_teleport_leg.gd` — `LeaderTeleportLeg`
Follows a "leader" entity: connects to one of the leader's signals and teleports this entity to `leader.position + offset` when it fires (e.g. to stay attached through a screen wrap).

- **Enum**: `BlackboardSource { ENTITY, GAME }` — which blackboard to read the leader from.
- **Exports**
  - `blackboard_source: BlackboardSource = ENTITY`.
  - `leader_key: StringName = &"captured_by"` — key holding the leader `CDEntity`.
  - `teleport_signal: StringName = &"screen_wrapped"` — signal on the leader that triggers the jump.
  - `teleport_offset: Vector2 = Vector2(0.0, -16.0)`.
  - Emits: `teleported_signals = [&"teleported_by_leader"]` — fired **after** teleport, deferred to idle.
- **Behavior**: every frame `_check_leader()` polls the chosen blackboard; if the leader reference changed, it disconnects the old and connects the new (guarding with `is_instance_valid` and `has_signal`). On the leader's signal: `request_position_set(leader.global_position + offset)`, then deferred `bus_emit` of `teleported_signals`.
- **Cleanup**: disconnects the current leader.

### `linear_friction_leg.gd` — `LinearFrictionLeg`
Speed-proportional deceleration: friction grows linearly from 0 (at speed 0) to `max_friction` (at `max_speed`), yielding a natural terminal velocity.

- **Exports**: `max_friction: float = 800.0` (px/s² at max speed), `max_speed: float = 300.0`.
- **Behavior**: `t = clamp(speed / max_speed, 0, 1)`; `request_velocity_add(-vel.normalized() * max_friction * t * delta)`. No-op at zero speed.
- **Cleanup**: none.

### `screen_wrap_leg.gd` — `ScreenWrapLeg`
Wraps the entity to the opposite side of `game.game_bounds` when it leaves the playfield.

- **Exports**
  - `wrap_margin: float = 20.0` — how far past the edge before wrapping.
  - `check_interval: float = 0.1` — seconds between checks.
  - Emits: `wrapping_signals = [&"screen_wrapping"]` (fired **before** the move), `wrapped_signals = [&"screen_wrapped"]` (fired **after**, deferred).
- **Behavior**: on each interval, tests X and Y against `bounds` ± `wrap_margin`. If wrapping, emits `wrapping_signals`, `request_position_set(pos)`, then deferred-emits `wrapped_signals`. X and Y are checked independently, so a corner exit wraps both axes.
- **Cleanup**: resets `_check_timer`.

### `static_friction_leg.gd` — `FrictionStatic`
Constant deceleration to a dead stop.

- **Exports**: `deceleration: float = 100.0` — px/s².
- **Behavior**: `brake_force = deceleration * delta`. If braking would overshoot (`brake_force >= speed`), `request_velocity_add(-vel)` to snap to zero; otherwise `request_velocity_add(-vel.normalized() * brake_force)`. No-op at zero velocity.
- **Cleanup**: none.
- ⚠️ `class_name FrictionStatic` does **not** match the filename `static_friction_leg.gd`.

---

## How to create a new leg

1. **Pick the right subfolder.** Decide add (momentum via `request_velocity_add`) vs set (snap via `request_*_set`), and directional (reads `move_direction`) vs positional (reads `move_distance` too). Put utility legs in `other/`.
2. **Create `<name>_leg.gd`** extending `CDEntityComponent` and declaring a `class_name`. Keep the two in sync (mind the existing mismatches above).
3. **Standard scaffolding** (copy from any existing leg):
   ```gdscript
   class_name MyLeg extends CDEntityComponent

   @export var my_param: float = 100.0

   @export_group("Blackboard Keys")
   @export var direction_key: StringName = &"move_direction"

   func _ready() -> void:
       component_category = CDEnums.ComponentCategory.STEERING
       super._ready()

   func _on_initialize() -> void:
       pass

   func _physics_process(delta: float) -> void:
       if not entity:
           return
       var dir: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)
       if dir != Vector2.ZERO:
           entity.request_velocity_add(dir * my_param * delta)

   func _on_entity_deactivating() -> void:
       super._on_entity_deactivating()
       # reset any internal state for pool reuse
   ```
4. **Input via blackboard, output via requests.** Read state with `entity.blackboard.get(key, default)`; drive motion only through the `request_*` calls (never mutate `entity.velocity`/position directly).
5. **Expose keys and signals as exports.** Use `@export_group("Blackboard Keys")` and `@export_group("Emit Signals")` with `Array[StringName]` lists; fire them with `entity.bus_emit(sig)` (defer with `.call_deferred()` for "after" signals).
6. **If you subscribe to signals** (`bus_connect`), always `bus_disconnect` in `_on_entity_deactivating()`.
7. **Reset all internal state in `_on_entity_deactivating()`** — these entities are pooled.
8. **Document the file with `##` header comments** at the top, matching the house style.