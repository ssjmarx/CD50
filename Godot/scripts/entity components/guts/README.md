# Guts

`Guts` are **stateful entity components** that implement the *internals* of an entity — the systems that manage its health, timers, detection, death conditions, input translation, physics helpers, and resource pools.

Every script in this folder follows the same base contract and shares a common communication style. This README documents each script as it actually exists, then describes how to author a new one.

---

## Shared Architecture (observed in every script)

> These patterns are extracted directly from the existing `.gd` files. Nothing here is aspirational.

### Base class

Every Guts component:

```gdscript
class_name XxxGuts extends CDEntityComponent
```

…and sets its category in `_ready()`:

```gdscript
func _ready() -> void:
    component_category = CDEnums.ComponentCategory.STATE
    super._ready()
```

All current Guts report `ComponentCategory.STATE`.

### Lifecycle hooks used

| Hook | Purpose | Present in |
|---|---|---|
| `_ready()` | Set `component_category`, call `super._ready()` | All |
| `_on_initialize()` | Read blackboard defaults, connect listen signals, build nodes | Most |
| `_on_entity_deactivating()` | Disconnect signals, erase blackboard keys, reset state, stop processing | All |
| `_on_entity_activated()` | Re-init for pool reuse (only when the component uses `_physics_process`) | Some |
| `_physics_process(delta)` | Counters, timers, regeneration, monitoring | Some |

### Communication

Guts are **signal-driven**. Two signal-connection styles appear in the code (both are real, both are valid — match the style of the neighbors you're wiring to):

1. **Bus-based (most common)**
   ```gdscript
   self.bus_connect(sig_name, _on_something)      # subscribe
   self.bus_disconnect(sig_name, _on_something)   # unsubscribe (in cleanup)
   entity.bus_emit(sig_name)                      # emit zero-arg signal
   ```

2. **Direct Godot signal (used by `KBMGuts`, `TSpinDetectorGuts`)**
   ```gdscript
   entity.ensure_signal(sig_name)                 # make sure the signal exists
   entity.connect(sig_name, _on_something)        # subscribe
   entity.disconnect(sig_name, _on_something)     # unsubscribe (in cleanup)
   ```

> ⚠️ A few components subscribe with `bus_connect` but unsubscribe with direct `entity.disconnect` (e.g. `MoveAdapterGuts`, `AnnouncerGuts`). When editing those files, follow what's already there.

**Game-bus** emission (for events the whole game should hear):
```gdscript
game.bus_emit(sig_name)              # zero-arg
game.bus_emit_from(sig_name, entity) # pass the entity as first arg
```

**Blackboard** (shared state dict on the entity, and sometimes on the game):
```gdscript
entity.blackboard[key] = value
var v = entity.blackboard.get(key, default)
entity.blackboard.erase(key)
```

### Signal data convention

Almost all emitted/listened signals are **zero-argument**. Any payload (damage amount, target, direction, status name, etc.) is passed through the **blackboard**, not as signal arguments. The component reads its configured `*_key` from the blackboard inside the handler.

### Export layout

Components consistently group exports with `@export_group`:

- `@export_group("Listen Signals")` — `Array[StringName]` of signals to react to.
- `@export_group("Emit Signals")` — `Array[StringName]` of signals to emit.
- `@export_group("Blackboard Keys")` — `StringName` keys for reading/writing shared state.

StringName literals use the `&"name"` form (e.g. `@export var x: StringName = &"health"`).

### Cleanup contract

Because entities are pooled, every component must:

1. Disconnect every signal it connected.
2. Erase any blackboard keys it owns.
3. Reset private state to initial values.
4. Call `set_physics_process(false)` if it uses `_physics_process`.

`_on_entity_deactivating()` always begins with `super._on_entity_deactivating()`.

---

## Folder Map

```
guts/
├── death/        # conditions that destroy the entity
├── detection/    # sensing the world / tracking other entities
├── game logic/   # gameplay state machines & data holders
├── input/        # translating input into entity signals
├── physics/      # collision & motion helpers
└── pools/        # regenerating/absorbing value pools
```

---

## `death/`

Components that decide *when* an entity should be deactivated.

### `DieAtZeroHealthGuts`
**File:** `die_at_zero_health_guts.gd`

Bridges a health-is-zero signal (typically from `HealthpoolGuts`) to an entity-deactivation request.

- **Listens:** `zero_health_signals` (default `["zero_health"]`).
- **Emits:** `death_signals` (default `["request_deactivate"]`).
- On each zero-health signal, emits every `death_signals` entry on the entity bus.
- Cleanup disconnects all listen signals.

### `DieOffscreenGuts`
**File:** `die_offscreen_guts.gd`

Deactivates the entity when it leaves all camera views. Uses a child `VisibleOnScreenNotifier2D`.

- **Exports:** `notifier_path` (default `"VisibleOnScreenNotifier2D"`), `activation_delay` (default `3.0`s — prevents dying the instant it spawns off-screen).
- Waits out `activation_delay` in `_physics_process`, then enables the notifier's monitoring.
- On `screen_exited`, awaits one physics frame and double-checks `is_on_screen()` before calling `entity.deactivate()` (guards against spurious events).
- Pushes an error and disables itself if the notifier node is missing.
- `_on_entity_activated()` restarts the delay cycle for pool reuse.

> Requires a `VisibleOnScreenNotifier2D` child at `notifier_path`.

### `DieOnTimerGuts`
**File:** `die_on_timer_guts.gd`

Deactivates the entity after a fixed lifespan elapses. Useful for projectiles.

- **Exports:** `lifespan` (default `3.0`s), `timer_expired_signals` (default `["timer_expired"]`), `death_signals` (default `["request_deactivate"]`).
- Counts `_time_remaining` down in `_physics_process`; on expiry emits `timer_expired_signals` then calls `entity.deactivate()`.
- Reset on both deactivation and reactivation.

### `DieOutOfBoundsGuts`
**File:** `die_out_of_bounds_guts.gd`

Deactivates the entity when it leaves `game.game_bounds` (plus a configurable margin). No child node required.

- **Exports:** `margin` (default `16.0`px beyond bounds), `activation_delay` (default `3.0`s — prevents spawn deaths).
- After the delay, checks `entity.global_position` against `game.game_bounds` each physics frame; calls `entity.deactivate()` when outside on either axis.
- No-ops while `game` or `game.game_bounds.has_area()` is unavailable.

---

## `detection/`

Sensing and tracking components.

### `LeaderTrackerGuts`
**File:** `leader_tracker_guts.gd`

Tracks a *target entity reference* stored on a blackboard and emits when that leader dies (deactivates). Used to transition a follower (e.g. a captured body) when its leader is destroyed.

- **Enum:** `BlackboardSource { ENTITY, GAME }` — which blackboard to read the target from.
- **Exports:** `blackboard_source`, `target_entity_key` (default `&"captured_by"`), `leader_destroyed_signals` (default `["leader_destroyed"]`).
- Polls the blackboard every physics frame; when the stored reference changes, disconnects the old leader and connects the new leader's `entity_deactivating` signal.
- When the leader deactivates, emits `leader_destroyed_signals` and clears the reference.

### `LockDetectorGuts`
**File:** `lock_detector_guts.gd`

Implements **SRS-style lock delay** for falling grid pieces (Tetris). Reads step direction from the blackboard.

- **Exports:** `lock_delay` (default `0.5`s), `max_resets` (default `15`), `down_direction` (default `Vector2.DOWN`).
- **Blackboard:** `direction_key` (default `&"step_direction"`).
- **Listens:** `step_blocked_signals` (`["step_blocked"]`), `move_signals` (`["moved"]`), `rotate_signals` (`["rotated"]`).
- **Emits:** `piece_locked_signals` (`["piece_locked"]`).
- Logic:
  - Starts the lock timer only when a *downward* step is blocked (`direction == down_direction`).
  - Moves/rotations reset the timer up to `max_resets` times.
  - When the timer elapses, emits `piece_locked_signals`.

### `VisionConeGuts`
**File:** `vision_cone_guts.gd`

Builds a forward-facing detection cone as a dynamic `Area2D` + `CollisionPolygon2D` and reports the first body that enters/exits.

- **Exports:** `cone_angle` (deg, default `30.0`), `cone_length` (px, default `200.0`).
- **Blackboard (read):** `aim_key` (`&"aim_direction"` → `Vector2`), `length_key` (`&"vision_range"` → `float`), `angle_key` (`&"vision_angle"` → `float`).
- **Blackboard (write):** `target_key` (`&"detected_body"` → the `Node2D`).
- **Listens:** `aim_signals`, `change_length_signals`, `change_angle_signals`.
- **Emits:** `body_entered_signals` (`["start_shooting"]`), `body_exited_signals` (`["stop_shooting"]`).
- The polygon is an 8-segment fan from `Vector2.ZERO`; aim rotates the Area2D, length/angle changes rebuild the polygon. The detected body is written to the blackboard on enter and exit.

---

## `game logic/`

Gameplay state machines and lightweight data holders.

### `AnnouncerGuts`
**File:** `announcer_guts.gd`

Bridges **entity-bus** signals to **game-bus** signals (entity-level event → game-level reaction).

- **Exports:** `include_self` (default `true` — passes the entity as the first argument to each game-bus emit), `listen_signals` (`["path_finished"]`), `rebroadcast_signals` (`["dive_complete"]`).
- All listen signals route to one handler; any signal arguments are ignored.
- Cleanup disconnects via direct `entity.disconnect`.

### `PointsGuts`
**File:** `points_guts.gd`

Pure data holder — the entity's score value.

- **Exports:** `points` (default `100`), `value_key` (`&"points"`), `delta_key` (`&"points_delta"`).
- On init, writes `points` (and `0` delta) to the blackboard. Erases both keys on deactivation.
- Emits nothing and listens to nothing.

### `StunGuts`
**File:** `stun_guts.gd`

Temporarily disables the entity's `INTENT` and `STEERING` category components while a matching status is active.

- **Exports:** `target_status` (`&"stun"`), `status_key` (`&"status_name"`), `duration_key` (`&"status_duration"`).
- **Listens:** `status_signals` (`["apply_status"]`).
- **Emits:** `status_began_signals` (`["status_began"]`), `status_ended_signals` (`["status_ended"]`).
- On a status signal, reads `status_key`; if it equals `target_status`, reads `duration_key` and stuns. Re-stunning while already stunned just refreshes the timer.
- While stunned, iterates `entity.get_children()`, finds `CDEntityComponent`s whose category is `INTENT` or `STEERING`, and `set_physics_process(false)` on each (caching them to re-enable later).
- `_physics_process` ticks the timer down and re-enables components on expiry.

### `TimerGuts`
**File:** `timer_guts.gd`

A count-down or count-up timer.

- **Enum:** `TimerMode { COUNT_DOWN, COUNT_UP }`.
- **Exports:** `mode`, `starting_time` (default `60.0`), `tick_interval` (default `1.0`s), `auto_start` (default `true`), `value_key` (`&"timer_time"`).
- **Listens:** `pause_signals`, `resume_signals`, `reset_signals`.
- **Emits:** `tick_signals` (every `tick_interval`), `expired_signals` (when a count-down hits 0).
- Writes `current_time` to the blackboard every frame; on count-down expiry clamps to 0 and emits `expired_signals`.

### `TSpinDetectorGuts`
**File:** `t_spin_detector_guts.gd`

Detects **T-spins** (and mini T-spins) via the SRS 3-corner rule when a T-shaped piece locks. Emits on the **game bus**.

- **Exports:** `corner_cast_distance` (default `10.0`).
- **Listens:** `lock_signals` (`["piece_locked"]` — triggers detection), `rotate_signals` (`["rotated"]` — must occur before lock for any T-spin).
- **Emits (game bus):** `t_spin_signals` (`["t_spin_detected"]`).
- **Blackboard (game):** `is_t_spin_key` (`&"is_t_spin"`), `is_mini_key` (`&"is_mini"`).
- Logic:
  - Tracks a `_last_rotated` flag and a `_rotation_state` (0–3, from `global_rotation`).
  - On lock, if not recently rotated → announces `(false, false)`.
  - Otherwise casts 4 diagonal points (`intersect_point`) against `entity.collision_mask`, excluding the entity itself.
  - ≥3 occupied corners ⇒ T-spin. Determines "back" corners per rotation state: both back corners occupied ⇒ full T-spin, else mini.
  - Writes results to the game blackboard and emits on the game bus.
- Uses direct `entity.connect`/`entity.disconnect` (with `entity.ensure_signal` for lock signals).

---

## `input/`

Translating raw input into entity signals.

### `KBMGuts`
**File:** `kbm_guts.gd`

Merges **keyboard** direction and **mouse** target position into a single `steer` signal each physics frame. Keyboard takes priority.

- **Listens:** `move_signals` (`["move"]` → `Vector2`), `move_to_signals` (`["move_to"]` → `Vector2`).
- **Emits:** `steer_signals` (`["steer"]`), and writes `steer_direction_key` (`&"steer_direction"`) to the blackboard.
- Each frame: if a keyboard direction is held, emits it; otherwise, if the mouse is inside the viewport, aims toward the last `_mouse_target` and emits that direction.
- Uses direct `entity.connect`/`entity.disconnect` (with `entity.ensure_signal`).

### `MoveAdapterGuts`
**File:** `move_adapter_guts.gd`

Pure translator: a `move_to` *target position* becomes a `move` *direction vector*. Bridges Brains-that-emit-targets to Legs-that-expect-directions.

- **Listens:** `target_signals` (`["move_to"]` → `Vector2`).
- **Emits:** `direction_signals` (`["move"]`), and writes `move_direction_key` (`&"move_direction"`).
- Computes `entity.global_position.direction_to(target)` per event.
- Subscribes with `bus_connect`, unsubscribes with direct `entity.disconnect`.

---

## `physics/`

Collision and motion helpers. These reach into `CDEntity`'s physics API.

### `DeflectorBounceGuts`
**File:** `deflector_bounce_guts.gd`

A collision handler that bounces off colliders with angled deflection physics. **Owns its own config — no separate "arm" component needed.**

- **Exports:** `target_groups` (empty = handle all, trusting the collision matrix), `deflection_bias` (`Vector2(1,1)` neutral; higher = stronger deflection on that axis), `restitution` (default `1.0` = no energy loss).
- Registers itself via `entity.register_collision_handler(target_groups, _handle_collision)`; unregisters on deactivation.
- On collision: computes a deflection direction from the relative position to the collider, applies per-axis bias, re-normalizes, scales by current speed × restitution, and writes the result back to `entity.velocity`. Returns the slid remainder.

### `ImpulseReceiverGuts`
**File:** `impulse_receiver_guts.gd`

Applies an external impulse vector (read from the blackboard) to the entity's velocity.

- **Blackboard:** `impulse_key` (`&"external_impulse"` → `Vector2`).
- **Listens:** `impulse_signals` (`["external_impulse"]`).
- On signal: reads the impulse and, if non-zero, calls `entity.request_velocity_add(impulse)`.
- Emits nothing.

### `ShapeColliderGuts`
**File:** `shape_collider_guts.gd`

Dynamically updates the entity's collision polygon. Supports either a `CDShape` resource applied at init, or polygon points pulled from the blackboard on signal.

- **Exports:** `shape_resource: CDShape`, `shape_key` (`&"shape_points"` → `PackedVector2Array`).
- **Listens:** `shape_signals` (`["shape_changed"]`).
- On init, if `shape_resource` has points, calls `entity.set_collision_polygon(points)`.
- On `shape_changed`, reads `shape_key` and applies it via `entity.set_collision_polygon`.

---

## `pools/`

Regenerating / absorbing value pools. All three write a *value* and a *delta* to the blackboard and emit zero-arg event signals.

### `HealthpoolGuts`
**File:** `healthpool_guts.gd`

The single source of truth for an entity's **integer** health.

- **Exports:** `max_health` (default `3`), `starting_health` (default `-1` ⇒ use `max_health`), `invincible` (default `false`), `value_key` (`&"health"`), `delta_key` (`&"health_delta"`).
- **Listens:** `damage_signals` (`["take_damage"]`), `heal_signals` (`["heal"]`), `invincibility_signals` (`["set_invincible"]`).
- **Emits:** `health_changed_signals` (`["health_changed"]`), `zero_health_signals` (`["zero_health"]`).
- Damage/heal amounts are read from `delta_key` (the writer's responsibility to set before emitting). Healing is clamped to `max_health`. `invincibility_signals` toggles the `invincible` flag.

### `ResourcepoolGuts`
**File:** `resourcepool_guts.gd`

A generic **float** pool (fuel, energy, ammo…) with spend + passive regen.

- **Exports:** `max_resource` (default `100.0`), `starting_resource` (default `-1.0` ⇒ use max), `regen_rate` (per second, default `5.0`), `value_key` (`&"resource"`), `delta_key` (`&"resource_delta"`).
- **Listens:** `spend_signals` (`["spend_resource"]`).
- **Emits:** `resource_changed_signals` (`["resource_changed"]`), `resource_depleted_signals` (`["resource_depleted"]`), `spend_failed_signals` (`["resource_spend_failed"]`).
- Spend reads amount from `delta_key`; if insufficient, emits `spend_failed_signals`. Otherwise subtracts, clamps to 0, and emits depleted when empty. `_physics_process` passively regenerates up to `max_resource`.

### `ShieldpoolGuts`
**File:** `shieldpool_guts.gd`

A rechargeable damage buffer that absorbs what it can and **overflows** the rest to health damage signals ("catch and release").

- **Exports:** `max_shield` (default `50.0`), `recharge_delay` (default `3.0`s after damage), `recharge_rate` (per second, default `10.0`), `value_key` (`&"shield"`), `delta_key` (`&"shield_delta"`), `damage_key` (`&"damage_amount"` — shared with the damage source / healthpool).
- **Listens:** `damage_signals` (`["take_damage"]`).
- **Emits:** `shield_hit_signals` (`["shield_hit"]`), `shield_broken_signals` (`["shield_broken"]`), `shield_recharged_signals` (`["shield_recharged"]`), `overflow_signals` (`["take_health_damage"]`).
- On damage: if shield empty, forwards all damage as overflow. Otherwise absorbs up to the current shield, writes the new shield value, emits `shield_hit`, emits `shield_broken` when depleted, and forwards any remaining damage (writing the remainder back to `damage_key`) via `overflow_signals`.
- `_physics_process` recharges after `recharge_delay`; emits `shield_recharged` when going from empty to full.

---

## Creating a New Guts Component

A new Guts component should match the conventions above. Minimal skeleton (signal-driven, bus-based, with cleanup):

```gdscript
## MyNewGuts
## One-line description of what this component does.
## Second line with any extra context.

class_name MyNewGuts extends CDEntityComponent

## --- exports ---

@export var some_config: float = 1.0

@export_group("Blackboard Keys")
@export var value_key: StringName = &"my_value"

@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"do_thing"]

@export_group("Emit Signals")
@export var done_signals: Array[StringName] = [&"thing_done"]

## --- state ---

var _internal: float = 0.0

## --- lifecycle ---

## ready
func _ready() -> void:
    component_category = CDEnums.ComponentCategory.STATE
    super._ready()

## on initialize: defaults + subscriptions
func _on_initialize() -> void:
    _internal = some_config
    entity.blackboard[value_key] = _internal
    for sig in trigger_signals:
        self.bus_connect(sig, _on_trigger)

## --- signal handlers ---

## react to trigger; read payload from blackboard, emit results on bus
func _on_trigger() -> void:
    _internal = entity.blackboard.get(value_key, _internal)
    for sig in done_signals:
        entity.bus_emit(sig)

## --- processing (only if you need per-frame work) ---

#func _physics_process(delta: float) -> void:
#   ...

## --- cleanup ---

## disconnect, erase keys, reset state for pool reuse
func _on_entity_deactivating() -> void:
    super._on_entity_deactivating()
    for sig in trigger_signals:
        self.bus_disconnect(sig, _on_trigger)
    entity.blackboard.erase(value_key)
    _internal = some_config
    set_physics_process(false)

## re-enable processing on reactivation (only if you use _physics_process)
#func _on_entity_activated() -> void:
#   super._on_entity_activated()
#   _internal = some_config
#   entity.blackboard[value_key] = _internal
#   set_physics_process(true)
```

### Checklist for a new Guts component

1. **Class header comment** — `## NameGuts`, then a one/two-line description (mirror the existing style).
2. **`class_name …Guts extends CDEntityComponent`** — suffix `Guts`.
3. **`_ready()`** sets `component_category = CDEnums.ComponentCategory.STATE` *before* `super._ready()`.
4. **Exports** grouped with `@export_group("Listen Signals")`, `@export_group("Emit Signals")`, `@export_group("Blackboard Keys")` as needed. Use `Array[StringName]` for signal lists and `&"name"` for key defaults.
5. **Payloads via blackboard**, not signal arguments. Read amounts/targets/directions from configured keys inside the handler.
6. **`_on_initialize()`** connects every listen signal and writes any default blackboard values.
7. **`_on_entity_deactivating()`** (always starts with `super`): disconnect every signal, `erase` every blackboard key you own, reset private state, `set_physics_process(false)` if applicable.
8. **`_on_entity_activated()`** (only if you use `_physics_process`): re-init defaults and `set_physics_process(true)` so the component survives pool reuse.
9. **Pick one signal style per component** and stay consistent — either bus-based (`bus_connect`/`bus_disconnect`/`bus_emit`) or direct Godot signals (`ensure_signal`/`connect`/`disconnect`). (Existing code occasionally mixes them; when editing such a file, preserve its existing style.)
10. **Private state** is `_`-prefixed and declared under a `## --- state ---` block.