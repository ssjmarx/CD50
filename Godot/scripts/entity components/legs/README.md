# Legs — Entity Movement Components

15 leg components organized into 5 subfolders. Legs execute **movement and rotation** for an entity. All extend `CDEntityComponent` with `component_category = STEERING`.

Legs are categorized along two axes:
1. **Input type** — directional (Vector2 direction) vs positional (Vector2 world target)
2. **Velocity method** — `request_velocity_set` (hard override) vs `request_velocity_add` (incremental)

---

## Blackboard Polling Pattern

Most legs read their input from the entity blackboard every frame using a configurable key with a sensible default:

```gdscript
@export var direction_key: StringName = &"move_intent"

func _physics_process(_delta):
    var direction: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)
    entity.request_velocity_set(direction.normalized() * speed)
```

No signal connection, no `_received_input` tracking, no handler, no cleanup. The default value handles the "no input" case automatically — `Vector2.ZERO` means no movement, `0.0` means no rotation.

### Lifecycle

```
_ready()                   → set component_category = STEERING
_on_initialize()           → connect any signal listeners (only for signal-based legs)
_physics_process(delta)    → poll blackboard keys, apply velocity/rotation via entity API
_on_entity_deactivating()  → disconnect signals (if any), reset state
```

### Must-Includes When Creating Legs

1. Extend `CDEntityComponent`
2. Set `component_category = CDEnums.ComponentCategory.STEERING` in `_ready()`
3. Use `@export_group("Blackboard Keys")` for configurable blackboard key names
4. Read from `entity.blackboard.get(key, default)` — the default produces "do nothing" behavior
5. Apply movement via the entity request API (never set `velocity` directly)
6. Reset all runtime state in `_on_entity_deactivating()` (for object pool reuse)

### Entity Request API

| Method | Behavior |
|--------|----------|
| `request_velocity_set(vel)` | Override velocity entirely |
| `request_velocity_add(vel)` | Add to current velocity |
| `request_angular_set(rad/s)` | Override angular velocity |
| `request_rotation_set(rad)` | Set rotation directly |
| `request_rotation_add(rad)` | Add to current rotation |
| `request_position_set(pos)` | Teleport to position |
| `request_position_add(offset)` | Shift position by offset |

---

## Subfolders

### directional setters/ — Immediate Direction (4 scripts)

Set velocity/rotation directly from a direction vector. No momentum carries over between frames.

| Leg | Sets | Blackboard Key (default) | Entity API |
|-----|------|--------------------------|------------|
| `DirectMovementLeg` | Velocity | `direction_key` (`"move_intent"`) | `request_velocity_set()` |
| `DirectRotationLeg` | Angular velocity | `direction_key` (`"move_intent"`) | `request_angular_set()` |
| `GridMovementLeg` | Position (snapped) | `direction_key` (`"move_intent"`) | `request_position_add()` |
| `GridRotationLeg` | Rotation + wall kicks | `rotation_key` (`"rotation_intent"`) | `request_rotation_add()` / `request_position_add()` |

**Setter pattern:** When the blackboard key is absent or `Vector2.ZERO`, the leg zeros its output (velocity → ZERO, angular → 0.0). This gives responsive, snappy movement with no drift.

### directional adders/ — Accumulated Direction (2 scripts)

Add velocity each frame based on direction. Momentum builds up and persists.

| Leg | Adds | Blackboard Key (default) | Entity API |
|-----|------|--------------------------|------------|
| `AccelerationMovementLeg` | Directional force | `direction_key` (`"move_intent"`) | `request_velocity_add()` |
| `EngineLeg` | Forward thrust | Signal-based (`action` signals) | `request_velocity_add()` |

**Adder pattern:** Pair with friction legs (`LinearFrictionLeg`, `StaticFrictionLeg`) to cap speed and provide deceleration. Without friction, entities accelerate forever.

### positional setters/ — Immediate Target (2 scripts)

Set velocity/rotation directly toward a world-space target position.

| Leg | Sets | Blackboard Key (default) | Entity API |
|-----|------|--------------------------|------------|
| `DirectTargetLeg` | Velocity toward target | `target_key` (`"target_position"`) | `request_velocity_set()` |
| `TargetRotationLeg` | Rotation toward direction | `aim_key` (`"aim_direction"`) | `request_rotation_set()` |

**Positional setter pattern:** Both snap to the target within configurable thresholds (`arrival_distance`, instant-snap on overshoot). `TargetRotationLeg` supports instant snap (speed ≤ 0) or smooth rotation.

### positional adders/ — Accumulated Target (1 script)

Add velocity each frame toward a target, with distance-based deceleration.

| Leg | Adds | Blackboard Key (default) | Entity API |
|-----|------|--------------------------|------------|
| `AccelerationTargetLeg` | Force toward target | `target_key` (`"target_position"`) | `request_velocity_add()` |

**Positional adder pattern:** Tapers acceleration within `slow_distance` and stops adding at `stop_distance`. Good for homing/pursuit behavior.

### other/ — Utility & Modifiers (6 scripts)

Movement modifiers, grid utilities, and environment interactions.

| Leg | Purpose | Entity API |
|-----|---------|------------|
| `BoomerangLeg` | Constant return force toward spawn | `request_velocity_add()` |
| `GridAlignmentLeg` | Snap position to grid at intervals | `request_position_set()` |
| `GridDropLeg` | Drop N grid cells (line clear settling) | `request_position_add()` |
| `LinearFrictionLeg` | Speed-proportional deceleration | `request_velocity_add()` |
| `ScreenWrapLeg` | Wrap position around game bounds | `request_position_set()` |
| `StaticFrictionLeg` | Constant deceleration to zero | `request_velocity_add()` |

**Friction pattern:** Both friction legs use `request_velocity_add()` with negative velocity to decelerate. `LinearFrictionLeg` scales with current speed; `StaticFrictionLeg` applies constant braking. Both snap to zero when brake force exceeds remaining speed.