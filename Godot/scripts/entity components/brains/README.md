# Brains — Entity Intent Components

17 brain components that define what an entity **wants to do**. All extend `CDEntityComponent` with `component_category = INTENT`. Brains never act directly — they produce intent that legs, arms, and other components consume.

Organized into 3 subcategories:
- **player/** — 5 scripts driven by player input via `game.input_router`
- **ai action/** — 3 scripts for AI firing/aiming/attack behaviors
- **ai movement/** — 9 scripts for AI navigation and positioning

---

## Two Communication Modes

Brains use one of two patterns depending on whether their output is continuous or intermittent:

| Mode | Pattern | When to Use |
|------|---------|-------------|
| **Blackboard writer** | Write intent to `entity.blackboard[key]` every frame | Continuous data (movement, aiming) |
| **Signal + blackboard** | Write data to blackboard, emit zero-arg signal | Intermittent events (shoot, action) |

### Continuous Data Flow (most brains)

Brains write to configurable blackboard keys every `_physics_process`. No signal emission, no connection, no cleanup. Legs and other consumers poll the blackboard with sensible defaults.

```
# Brain writes
entity.blackboard["move_intent"] = direction

# Leg reads (default = Vector2.ZERO = no movement)
var intent = entity.blackboard.get("move_intent", Vector2.ZERO)
```

### Intermittent Events (action brains)

Action brains write event data to the blackboard and emit a zero-arg signal to wake listeners:

```
# Brain writes data, then signals
entity.blackboard["action_name"] = action
entity.bus_emit("fire")  # zero-arg notification
```

---

## Common Brain Lifecycle

```
_ready()         → set component_category = INTENT, call super._ready()
_on_initialize() → connect input/AI sources, connect entity bus listeners
_physics_process() → write intent to entity.blackboard (continuous brains)
                   OR emit zero-arg signal (intermittent brains)
_on_entity_deactivating() → disconnect all signals, reset state
```

### Blackboard Key Pattern

Most brains export a configurable key with a sensible default:

```gdscript
@export var move_key: StringName = &"move_intent"

func _physics_process(_delta):
    entity.blackboard[move_key] = _get_direction()
```

This makes brains composable — any brain can write to any key, and any consumer can read from it.

### Target Acquisition (AI Brains)

AI brains find targets via `game.group_registry.get_nearest(group, position)`. This searches registered entity groups for the closest match.

Many AI brains support:
- **`update_interval`** — throttle how often targeting recalculates (0 = every frame)
- **`targeting_noise`** — add random offset to target position for imprecision
- **`target_groups`** — which entity groups to target

### Patrol Modes (Waypoint Brains)

Waypoint-following brains support `CDEnums.PatrolMode`:
- `LOOP` — restart from beginning when path ends
- `RETRACE` — reverse direction when path ends
- `ONCE` — emit complete signal and stop

### Must-Includes When Creating Brains

1. Extend `CDEntityComponent`
2. Set `component_category = CDEnums.ComponentCategory.INTENT` in `_ready()`
3. Export configurable blackboard keys with sensible defaults
4. Write intent to `entity.blackboard[key]` in `_physics_process` (continuous) or before signal emit (intermittent)
5. Disconnect all connections in `_on_entity_deactivating()` with `is_connected()` guards
6. Reset internal state in `_on_entity_deactivating()`

---

## Player Brains

Driven by `game.input_router` — convert player input into entity intent.

| Brain | Input Source | Blackboard Key / Signal | Purpose |
|-------|-------------|------------------------|---------|
| `PlayerMoveBrain` | `input_move` | `move_key` (default `"move_intent"`) | Directional movement from stick/keys |
| `PlayerMoveToBrain` | Mouse position | `target_key` (default `"target_position"`) | Move toward mouse cursor |
| `PlayerAimBrain` | `input_aim` | `aim_key` (default `"aim_direction"`) | Aim direction from stick |
| `PlayerActionBrain` | `input_action_pressed/released` | `"action_name"` + zero-arg named signals | Button presses (fire, etc.) |
| `PlayerKBMMoveBrain` | Keyboard + mouse hybrid | `move_key` + `target_key` | WASD movement + mouse aiming |

### PlayerActionBrain Dual-Signal Pattern

On action press, emits **both**:
1. Named signal (e.g., `fire`) — for specific arms like `GunArm`
2. Zero-arg `action` signal — for catch-all listeners

Also writes `action_name` to entity blackboard before signaling.

### Player ID Filtering

All player brains filter by `player_id` — only respond to input matching their assigned player number.

---

## AI Action Brains

AI-driven firing/aiming behaviors. These use the intermittent pattern (signal + blackboard).

| Brain | Output | Purpose |
|-------|--------|---------|
| `AIAimAtNearestBrain` | Writes `aim_key` to blackboard | Aim toward nearest target in group |
| `AIRepeatActionBrain` | Named signal + `action` signal | Fire repeatedly on interval while active |
| `AITractorBeamBrain` | `fire_tractor_beam` signal | Trigger tractor beam at trigger_height during dive |

### AIRepeatActionBrain Start/Stop Pattern

This brain listens for `start_shooting` / `stop_shooting` signals to toggle its firing loop. While active, it fires on `fire_interval`. Uses the same dual-signal pattern as `PlayerActionBrain`.

### AITractorBeamBrain Dive Interrupt

Waits for entity to reach `trigger_height` during a dive (checked via `qualifying_groups`), then halts movement and fires the tractor beam arm. Listens for `tractor_beam_complete` to resume.

---

## AI Movement Brains

AI-driven navigation behaviors. Most are pure blackboard writers (continuous data flow).

### Target-Tracking (Direction-Based)

These write a **direction vector** to a configurable blackboard key.

| Brain | Target | Behavior |
|-------|--------|----------|
| `AIChaseBrain` | Nearest in group | Move toward, stop at `stop_distance` |
| `AIFleeBrain` | Nearest threat | Move away, stop beyond `flee_distance` |

### Target-Tracking (Position-Based)

These write a **target position** and/or direction to configurable blackboard keys.

| Brain | Target | Behavior |
|-------|--------|----------|
| `AIFormationBrain` | Leader entity | Maintain offset from leader, auto-acquire from group |
| `AIOrbitBrain` | Leader entity | Circle leader at `orbit_radius` with `orbit_speed` |

### Path-Based

These follow generated or predefined paths.

| Brain | Path Source | Behavior |
|-------|------------|----------|
| `AIPathMoveBrain` | `Curve2D` resource | Follow baked path, supports patrol modes |
| `AISwoopBrain` | `CDCurve` resource | Checkpoint-based swoop; start/stop via entity bus signals, movement data via blackboard |

### AISwoopBrain — Hybrid Pattern

`AISwoopBrain` is a hybrid: start/stop are controlled by entity bus signals (`begin_swoop` / `return_to_formation`), but the actual movement data is written to the entity blackboard (`move_key`, `distance_key`) for legs to poll. This combines intermittent event handling with continuous data flow.

### Waypoint-Based

| Brain | Path Source | Behavior |
|-------|------------|----------|
| `AIRandomSweepBrain` | Random waypoints | Random center points + exit edge, supports patrol modes |

### Timer-Based

| Brain | Behavior |
|-------|----------|
| `AITimedStepBrain` | Write direction to blackboard at `step_interval`; listens for speed/direction changes and resets |
| `AIIdleWanderBrain` | Pick random points near spawn, idle between moves, stuck timeout |