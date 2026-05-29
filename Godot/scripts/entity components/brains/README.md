# Brains — Entity Intent Components

16 brain components that define what an entity **wants to do**. All extend `CDEntityComponent` with `component_category = INTENT`. Brains never act directly — they emit signals that legs, arms, and other components listen to.

Organized into 3 subcategories:
- **player/** — 4 scripts driven by player input via `game.input_router`
- **ai action/** — 3 scripts for AI firing/aiming/attack behaviors
- **ai movement/** — 9 scripts for AI navigation and positioning

---

## Common Brain Pattern

Every brain follows the same lifecycle:

```
_ready()         → set component_category = INTENT, call super._ready()
_on_initialize() → ensure emit signals exist, connect input/AI sources
_physics_process() → emit intent signals every frame (move, aim, action)
_on_entity_deactivating() → disconnect all signals, reset state
```

### Signal Types

Brains emit two kinds of signals:

| Signal Type | Example | Consumer |
|-------------|---------|----------|
| Directional | `move(Vector2)` | Legs (direction-based movement) |
| Positional | `move_to(Vector2)` | Legs (target-position movement) |
| Action | `shoot`, `action(StringName)` | Arms (trigger weapons) |
| Aim | `aim(Vector2)` | Legs/Faces (rotation/facing) |

### Entity Signal Bus

Brains emit signals **on the entity**, not directly on components. This means any component on the entity can listen. The brain doesn't know or care who's receiving.

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
3. Call `entity.ensure_signal()` for all emit signals in `_on_initialize()`
4. Emit intent signals on the **entity** (not `self`)
5. Disconnect all connections in `_on_entity_deactivating()` with `is_connected()` guards
6. Reset internal state in `_on_entity_deactivating()`

---

## Player Brains

Driven by `game.input_router` — convert player input into entity intent signals.

| Brain | Input Source | Emit Signal | Purpose |
|-------|-------------|-------------|---------|
| `PlayerMoveBrain` | `input_move` | `move(Vector2)` | Directional movement from stick/keys |
| `PlayerMoveToBrain` | Mouse position | `move_to(Vector2)` | Move toward mouse cursor |
| `PlayerAimBrain` | `input_aim` | `aim(Vector2)` | Aim direction from stick |
| `PlayerActionBrain` | `input_action_pressed/released` | `action + named signals` | Button presses (fire, etc.) |

### PlayerActionBrain Dual-Signal Pattern

On action press, emits **both**:
1. Named signal (e.g., `fire`) — for specific arms like `GunArm`
2. Generic signal `action(action_name)` — for catch-all listeners

On action release, emits both:
1. Named end signal (e.g., `fire_end`)
2. Generic signal `action_end(action_name)`

### Player ID Filtering

All player brains filter by `player_id` — only respond to input matching their assigned player number.

---

## AI Action Brains

AI-driven firing/aiming behaviors that run on `_physics_process`.

| Brain | Emit Signal | Purpose |
|-------|-------------|---------|
| `AIAimAtNearestBrain` | `aim(Vector2)` | Aim toward nearest target in group |
| `AIRepeatActionBrain` | Named action + `action(StringName)` | Fire repeatedly on interval while active |
| `AITractorBeamBrain` | `fire_tractor_beam` | Trigger tractor beam at trigger_height during dive |

### AIRepeatActionBrain Start/Stop Pattern

This brain listens for `start_shooting` / `stop_shooting` signals to toggle its firing loop. While active, it fires on `fire_interval`. Uses the same dual-signal pattern as `PlayerActionBrain`.

### AITractorBeamBrain Dive Interrupt

Waits for entity to reach `trigger_height` during a dive (checked via `qualifying_groups`), then halts movement and fires the tractor beam arm. Listens for `tractor_beam_complete` to resume.

---

## AI Movement Brains

AI-driven navigation behaviors. Most emit directional or positional signals every frame.

### Target-Tracking (Direction-Based)

These emit `move(Vector2)` — a **direction vector** for legs to interpret.

| Brain | Target | Behavior |
|-------|--------|----------|
| `AIChaseBrain` | Nearest in group | Move toward, stop at `stop_distance` |
| `AIFleeBrain` | Nearest threat | Move away, stop beyond `flee_distance` |

### Target-Tracking (Position-Based)

These emit `move_to(Vector2)` — a **target position** for legs to navigate to.

| Brain | Target | Behavior |
|-------|--------|----------|
| `AIFormationBrain` | Leader entity | Maintain offset from leader, auto-acquire from group |
| `AIOrbitBrain` | Leader entity | Circle leader at `orbit_radius` with `orbit_speed` |

### Waypoint-Based

These generate and follow waypoint paths.

| Brain | Path Source | Behavior |
|-------|------------|----------|
| `AIPathMoveBrain` | `Curve2D` resource | Follow baked path, supports patrol modes |
| `AIDiveBombBrain` | Generated sine wave | Sine-wave dive toward target with overshoot |
| `AIRandomSweepBrain` | Random waypoints | Random center points + exit edge, supports patrol modes |

### Timer-Based

| Brain | Behavior |
|-------|----------|
| `AITimedStepBrain` | Emit directional signal at `step_interval`; listens for speed/direction changes and resets |
| `AIIdleWanderBrain` | Pick random points near spawn, idle between moves, stuck timeout |