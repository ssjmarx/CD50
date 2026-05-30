# Legs — Entity Movement Components

15 leg components organized into 5 subfolders. Legs execute **movement and rotation** for an entity. All extend `CDEntityComponent` with `component_category = STEERING`.

Legs are categorized along two axes:
1. **Input type** — directional (Vector2 direction) vs positional (Vector2 world target)
2. **Velocity method** — `request_velocity_set` (hard override) vs `request_velocity_add` (incremental)

---

## Common Leg Pattern

```
_ready()                   → set component_category = STEERING
_on_initialize()           → ensure signals, connect listeners
_on_<signal>(args)         → store input state (direction, target, action flags)
_physics_process(delta)    → apply velocity/rotation/position changes via entity API
_on_entity_deactivating()  → disconnect signals, reset state
```

### Must-Includes When Creating Legs

1. Extend `CDEntityComponent`
2. Set `component_category = CDEnums.ComponentCategory.STEERING` in `_ready()`
3. Use `@export_group("Listen Signals")` for input signal arrays
4. Call `entity.ensure_signal()` before connecting in `_on_initialize()`
5. Disconnect all connections with validity guards in `_on_entity_deactivating()`
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

| Leg | Sets | Listen Signal | Entity API |
|-----|------|---------------|------------|
| `DirectMovementLeg` | Velocity | `move` (Vector2) | `request_velocity_set()` |
| `DirectRotationLeg` | Angular velocity | `move` (Vector2) + `action` (StringName) | `request_angular_set()` |
| `GridMovementLeg` | Position (snapped) | `move` (Vector2) | `request_position_add()` |
| `GridRotationLeg` | Rotation + wall kicks | `rotate` (float) | `request_rotation_add()` / `request_position_add()` |

**Setter pattern:** If no input is received this frame, the leg zeros its output (velocity → ZERO, angular → 0.0). This gives responsive, snappy movement with no drift.

### directional adders/ — Accumulated Direction (2 scripts)

Add velocity each frame based on direction. Momentum builds up and persists.

| Leg | Adds | Listen Signal | Entity API |
|-----|------|---------------|------------|
| `AccelerationMovementLeg` | Directional force | `move` (Vector2) | `request_velocity_add()` |
| `EngineLeg` | Forward thrust | `action` (StringName) | `request_velocity_add()` |

**Adder pattern:** Pair with friction legs (`LinearFrictionLeg`, `StaticFrictionLeg`) to cap speed and provide deceleration. Without friction, entities accelerate forever.

### positional setters/ — Immediate Target (2 scripts)

Set velocity/rotation directly toward a world-space target position.

| Leg | Sets | Listen Signal | Entity API |
|-----|------|---------------|------------|
| `DirectTargetLeg` | Velocity toward target | `move_to` (Vector2) | `request_velocity_set()` |
| `TargetRotationLeg` | Rotation toward direction | `aim` (Vector2) | `request_rotation_set()` |

**Positional setter pattern:** Both snap to the target within configurable thresholds (`arrival_distance`, instant-snap on overshoot). `TargetRotationLeg` supports instant snap (speed ≤ 0) or smooth rotation.

### positional adders/ — Accumulated Target (1 script)

Add velocity each frame toward a target, with distance-based deceleration.

| Leg | Adds | Listen Signal | Entity API |
|-----|------|---------------|------------|
| `AccelerationTargetLeg` | Force toward target | `move_to` (Vector2) | `request_velocity_add()` |

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
