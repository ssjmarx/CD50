# Brains — Entity Intent Components

Brains are entity components that decide what an entity **wants to do**. Every script here extends `CDEntityComponent` and sets `component_category = CDEnums.ComponentCategory.INTENT` in `_ready()`. Brains never move or fire anything directly — they write intent into the entity's blackboard and/or emit bus signals, which legs, arms, and other components consume.

This folder contains **19 brain scripts** in three subfolders:

| Subfolder | Count | Driven by |
|-----------|-------|-----------|
| `player/` | 5 | Player input (via `game.input_router` or direct mouse polling) |
| `ai action/` | 4 | AI firing / aiming / capture behaviors |
| `ai movement/` | 10 | AI navigation and positioning |

---

## Communication Patterns

Brains communicate their intent using one or both of these mechanisms, as observed in the actual code:

### 1. Blackboard writers (continuous)

Most brains write values to `entity.blackboard[key]` every `_physics_process()`. Consumers (e.g. legs) read these keys with defaults:

```gdscript
# Brain writes direction + distance
entity.blackboard[move_key] = direction      # default key: "move_direction"
entity.blackboard[distance_key] = distance   # default key: "move_distance"
```

A few brains also read runtime overrides from the blackboard (e.g. `AITimedStepBrain` reads `step_interval` / `step_direction` from the blackboard, falling back to exported defaults).

### 2. Bus signals (events)

Event-driven brains connect to and emit signals over the entity/game bus:

```gdscript
# Listen (in _on_initialize)
self.bus_connect(start_signal, _on_start)

# Emit on the entity bus
entity.bus_emit(fire_action)

# Emit on the game bus (global events)
game.bus_emit(capture_started_signal)
```

Connections are always paired with guarded disconnects in `_on_entity_deactivating()`.

> Note: `AITractorBeamBrain` additionally calls `entity.request_velocity_set(Vector2.ZERO)` directly to halt the entity during a capture — the one place a brain issues a direct request rather than purely writing intent.

---

## Common Lifecycle

All brains follow the same skeleton (not every brain overrides every hook):

```gdscript
func _ready():
    component_category = CDEnums.ComponentCategory.INTENT
    super._ready()

func _on_initialize():
    # connect input sources / entity-bus listeners
    # generate waypoints / pick initial targets

func _physics_process(delta):
    # write intent to entity.blackboard[...]   (continuous brains)
    # and/or advance timers / waypoints

func _on_entity_deactivating():
    super._on_entity_deactivating()
    # disconnect all signals (with is_connected guards)
    # reset internal state
```

`PlayerActionBrain` also overrides `_on_sleep()` / `_on_wake()` to disconnect/reconnect input signals.

### Target acquisition

AI brains find targets via `game.group_registry`:

- `get_nearest(group, position)` — nearest entity in a group (used by chase, flee, aim, formation, orbit)
- `get_group(group)` — all entities in a group (used by escort's nearest-from-group fallback)

Several AI brains share these targeting options:

- **`update_interval`** — seconds between target recalculation; cached value is written between updates (0 = every frame). Used by `AIAimAtNearestBrain`, `AIChaseBrain`, `AIFleeBrain`, `AIOrbitBrain`.
- **`targeting_noise`** — random offset added to the target/leader position for imprecision. Used by the same four brains.
- **`target_groups` / `threat_groups`** — which entity groups to search.

### Patrol modes

Waypoint-following brains use `CDEnums.PatrolMode`:

- `LOOP` — restart from the first waypoint when the path ends
- `RETRACE` — reverse traversal direction when the path ends
- `ONCE` — stop (and optionally emit a complete signal) when the path ends

Used by `AIPathMoveBrain` and `AIRandomSweepBrain`.

---

## How to create a new brain

1. Create a `.gd` file in the appropriate subfolder (`player/`, `ai action/`, or `ai movement/`).
2. `extends CDEntityComponent` and declare a `class_name`.
3. In `_ready()`, set `component_category = CDEnums.ComponentCategory.INTENT` before calling `super._ready()`.
4. Export configurable blackboard keys with the standard defaults (`move_direction`, `move_distance`, `aim_direction`, etc.).
5. Decide your output style:
   - **Continuous** → write to `entity.blackboard[key]` in `_physics_process()`.
   - **Event** → connect in `_on_initialize()` with `self.bus_connect(...)`, emit with `entity.bus_emit(...)` or `game.bus_emit(...)`.
6. In `_on_entity_deactivating()`, call `super._on_entity_deactivating()` first, then disconnect every signal (guard with `is_connected`) and reset all internal state.
7. Use `game.group_registry` for any target lookups; use `game.input_router` for player input (where applicable).

---

# `player/` — Player Input Brains

Convert player input into entity intent. Multiplayer-capable brains export `player_id` and ignore input from other players.

| Script | class_name | Input source | Output |
|--------|------------|--------------|--------|
| `player_move_brain.gd` | `PlayerMoveBrain` | `game.input_router.input_move` | Writes `move_key` (default `move_direction`) |
| `player_move_to_brain.gd` | `PlayerMoveToBrain` | `entity.get_global_mouse_position()` | Writes `move_direction_key` + `move_distance_key` |
| `player_kbm_move_brain.gd` | `PlayerKBMMoveBrain` | `input_router.input_move` + mouse | Writes `move_key` + `distance_key` via KBM state machine |
| `player_aim_brain.gd` | `PlayerAimBrain` | `get_viewport().get_mouse_position()` | Writes `aim_key` (default `aim_direction`) |
| `player_action_brain.gd` | `PlayerActionBrain` | `input_router.input_action_pressed/released` | Emits named action signals on the entity bus |

### `PlayerMoveBrain`
- Exports: `player_id = 1`, `move_key = "move_direction"`.
- Connects `game.input_router.input_move` in `_on_initialize()`. On each move event matching `player_id`, writes the direction vector to `entity.blackboard[move_key]`.

### `PlayerMoveToBrain`
- Exports: `dead_zone = 4.0`, `move_direction_key = "move_direction"`, `move_distance_key = "move_distance"`.
- Each `_physics_process()`, reads the global mouse position, computes direction + distance to it, and writes both keys. If within `dead_zone`, writes zero. No `player_id`, no input_router connection.
- Per its header comment, uses a direction + distance paradigm to avoid conversion.

### `PlayerKBMMoveBrain`
- Exports: `player_id = 1`, `dead_zone = 4.0`, `move_key = "move_direction"`, `distance_key = "move_distance"`.
- Implements a three-state input mode machine (private enum `_InputMode { NONE, KEYBOARD, MOUSE }`):
  - `KEYBOARD` — entered when `input_move` delivers a non-zero vector; writes the keyboard direction with `distance = 0`. When the vector returns to zero, falls back to `NONE`.
  - `NONE` — writes zero intent; if the mouse moves, switches to `MOUSE`.
  - `MOUSE` — writes direction + distance toward the mouse cursor, respecting `dead_zone`.
- Filters `input_move` by `player_id`.

### `PlayerAimBrain`
- Exports: `player_id = 1`, `aim_key = "aim_direction"`.
- Each `_physics_process()`, reads `get_viewport().get_mouse_position()`, computes the normalized direction from the entity to the mouse, and writes it to `entity.blackboard[aim_key]`. Skips the frame if the mouse position is `Vector2.ZERO`.
- Note: `player_id` is exported but not currently used in the processing logic; the comment states it is intended for multiplayer filtering.

### `PlayerActionBrain`
- Exports: `player_id = 1`, `action_mappings = ["fire"]`.
- Connects `game.input_router.input_action_pressed` and `input_action_released` in `_on_initialize()`.
- On press (when `pid == player_id` and the action is in `action_mappings`): emits `entity.bus_emit(action)` (the raw action name, e.g. `"fire"`).
- On release: emits `entity.bus_emit(StringName(action + "_end"))` (e.g. `"fire_end"`).
- Overrides `_on_sleep()` / `_on_wake()` to disconnect / reconnect the input signals.

---

# `ai action/` — AI Action Brains

AI-driven firing, aiming, and capture behaviors. These are event/signal-oriented rather than pure blackboard writers.

| Script | class_name | Output | Purpose |
|--------|------------|--------|---------|
| `ai_aim_brain.gd` | `AIAimAtNearestBrain` | Writes `aim_key` to blackboard | Aim toward nearest target |
| `ai_repeat_action_brain.gd` | `AIRepeatActionBrain` | Emits `fire_action` signal on interval | Repeat an action while active |
| `ai_tractor_beam_brain.gd` | `AITractorBeamBrain` | Emits capture/arm signals on entity + game bus | Capture attempt triggered by a mark signal |
| `lasso_brain.gd` | `LassoBrain` | Emits lasso start/end + arm fire signals on entity bus | Timed lasso firing sequence |

### `AIAimAtNearestBrain`
- Exports: `target_groups = ["enemies"]`, `update_interval = 0.0`, `targeting_noise = 0.0`, `aim_key = "aim_direction"`.
- On each recalculation, finds the nearest entity in the first `target_group` that yields a hit (via `game.group_registry.get_nearest`), applies optional noise, and writes the direction to it into `entity.blackboard[aim_key]`. Between recalculation frames (when `update_interval > 0`) the cached direction is re-written.

### `AIRepeatActionBrain`
- Exports: `fire_interval = 0.3`, `wave_scaler: CDWaveScaler`, `start_signals = ["start_shooting"]`, `stop_signals = ["stop_shooting"]`, `fire_action = "shoot"`.
- `_on_initialize()` initializes `wave_scaler` (if set) and connects the start/stop signals via `self.bus_connect`.
- On a start signal: becomes active and primes the timer to `fire_interval` so the first shot fires immediately.
- While active in `_physics_process()`: accumulates the timer; when it reaches the effective interval (scaled by `wave_scaler.evaluate()` if present), resets the timer and emits `entity.bus_emit(fire_action)`.
- On a stop signal: becomes inactive and emits `entity.bus_emit(fire_action + "_end")`.

### `AITractorBeamBrain`
- Exports: `max_captures = 1`, `qualifying_groups = ["diving"]`, `capture_limit_key = "active_capture_count"`, plus listen/emit signal arrays and `capturing_entity_key = "capturing_entity"`.
- Listen signals: `trigger_signals = ["fire_tractor_beam"]`, `arm_complete_signals = ["tractor_beam_complete"]`.
- Emit signals: `arm_fire_signals = ["fire_tractor_beam"]` (entity bus), `capture_started_signals = ["capture_phase_started"]` and `capture_ended_signals = ["capture_phase_ended"]` (game bus).
- On a trigger signal: proceeds only if not already capturing, the entity is in one of `qualifying_groups`, and the global capture count (read from `game.blackboard[capture_limit_key]`) is below `max_captures` (skipped if the key is empty).
- `_begin_capture()`: sets capturing, calls `entity.request_velocity_set(Vector2.ZERO)`, stores `entity` in `game.blackboard[capturing_entity_key]`, emits the capture-started signals on the game bus, then emits the arm-fire signals on the entity bus.
- On `arm_complete`: clears capturing and emits the capture-ended signals on the game bus.

### `LassoBrain`
- Exports: `max_captures = 1`, `qualifying_groups = ["diving"]`, `capture_duration = 1.0`, `capture_limit_key = "active_capture_count"`, plus listen/emit signal arrays.
- Creates a one-shot `Timer` (wait time = `capture_duration`) in `_ready()`.
- On a trigger signal (default `"fire_tractor_beam"`): qualifies the same way as `AITractorBeamBrain` (group membership + global capture limit), then `_begin_capture()` emits `lasso_start_signals` on the entity bus, emits `arm_fire_signals` on the entity bus, and starts the timer.
- When the timer times out: emits `lasso_end_signals` on the entity bus. Per the header, this lets a spider halt, shoot, and return to formation.

---

# `ai movement/` — AI Movement Brains

AI navigation and positioning. Most are pure blackboard writers that emit a move direction (and usually a distance) each frame.

## Direction + distance writers (write both `move_key` and `distance_key`)

| Script | class_name | Target | Behavior |
|--------|------------|--------|----------|
| `ai_chase_brain.gd` | `AIChaseBrain` | Nearest in `target_groups` | Move toward; stop emitting when within `stop_distance` |
| `ai_escort_brain.gd` | `AIEscortBrain` | Blackboard-referenced entity or nearest in `target_groups` | Move to target + `offset`; optional stop-when-close |
| `ai_formation_brain.gd` | `AIFormationBrain` | Leader via NodePath or nearest in `target_groups` | Maintain `offset` rotated by leader's facing |
| `ai_orbit_brain.gd` | `AIOrbitBrain` | Leader via NodePath or nearest in `target_groups` | Orbit at `orbit_radius` with `orbit_speed` |
| `ai_idle_wander_brain.gd` | `AIIdleWanderBrain` | Random points near spawn | Wander + idle pauses + stuck timeout |
| `ai_path_move_brain.gd` | `AIPathMoveBrain` | Baked `Curve2D` waypoints | Follow path with patrol modes |
| `ai_swoop_brain.gd` | `AISwoopBrain` | `CDCurve` checkpoints | Signal-triggered swoop; start/stop/reset |
| `ai_random_sweep_brain.gd` | `AIRandomSweepBrain` | Random center waypoints + exit edge | Sweep across the play area |

## Direction-only writers (write `move_key` only)

| Script | class_name | Behavior |
|--------|------------|----------|
| `ai_flee_brain.gd` | `AIFleeBrain` | Move away from nearest threat; stop beyond `flee_distance` |
| `ai_timed_step_brain.gd` | `AITimedStepBrain` | Write a direction on a timer; interval/direction overridable via blackboard |

### `AIChaseBrain`
- Exports: `target_groups = ["enemies"]`, `stop_distance = 10.0`, `update_interval = 0.0`, `targeting_noise = 0.0`, `move_key = "move_direction"`, `distance_key = "move_distance"`.
- Finds the nearest target across all groups; if within `stop_distance` writes zero direction + zero distance, otherwise writes the normalized direction and the distance. Throttled recalculation writes cached values between updates.

### `AIEscortBrain`
- Exports: `blackboard_source` (enum `BlackboardSource { ENTITY, GAME }`, default `ENTITY`), `target_entity_key = "captured_by"`, `target_groups = []`, `offset = Vector2.ZERO`, `stop_when_close = true`, `close_distance = 5.0`, `move_direction_key = "move_direction"`, `move_distance_key = "move_distance"`, `arrived_signals = ["escort_achieved"]`.
- Resolves its target each frame: if `target_groups` is non-empty it finds the nearest entity across those groups; otherwise it reads a `CDEntity` from the entity or game blackboard under `target_entity_key` (and erases the key if the reference is invalid).
- Computes the target position + `offset`; if `stop_when_close` and within `close_distance`, erases the move keys and emits `arrived_signals`. Otherwise writes the normalized direction + distance.

### `AIFleeBrain`
- Exports: `threat_groups = ["player"]`, `flee_distance = 150.0`, `update_interval = 0.0`, `targeting_noise = 0.0`, `move_key = "move_direction"`.
- Finds the nearest threat; if farther than `flee_distance` writes zero, otherwise writes the direction **away** from the threat (only the direction key — no distance key).

### `AIFormationBrain`
- Exports: `target_entity_path: NodePath = ""`, `target_groups = ["leader"]`, `offset = Vector2(20, 0)`, `move_key = "move_direction"`, `distance_key = "move_distance"`.
- Resolves a leader from `target_entity_path` in `_on_initialize()` (if set and a `CDEntity`), otherwise auto-acquires the nearest entity from `target_groups` each frame.
- Writes direction + distance toward `leader.global_position + offset.rotated(leader.global_rotation)`.

### `AIIdleWanderBrain`
- Exports: `wander_radius = 100.0`, `idle_time = 2.0`, `arrival_distance = 5.0`, `stuck_timeout = 3.0`, `move_key = "move_direction"`, `distance_key = "move_distance"`.
- Centers the wander area on `entity._spawn_position` (captured in `_on_initialize()`). Picks a random point within `wander_radius`, moves toward it, idles for `idle_time` on arrival, then picks a new target. If `stuck_timeout` elapses without arrival, picks a new target.

### `AIOrbitBrain`
- Exports: `orbit_radius = 50.0`, `orbit_speed = 2.0`, `update_interval = 0.0`, `targeting_noise = 0.0`, `move_key = "move_direction"`, `distance_key = "move_distance"`, `target_entity_path = ""`, `target_groups = ["leader"]`.
- Resolves a leader the same way as `AIFormationBrain`. Computes a circular offset (`cos`/`sin` of accumulated time × `orbit_speed` × `orbit_radius`) around the (optionally noisy) leader position and writes direction + distance toward that point. Throttled updates reuse the last computed target.

### `AIPathMoveBrain`
- Exports: `path_curve: Curve2D`, `waypoint_spacing = 20.0`, `arrival_distance = 5.0`, `patrol_mode = CDEnums.PatrolMode.LOOP`, `use_global_coords = false`, `move_key`, `distance_key`, `complete_signals = ["patrol_complete"]`.
- In `_on_initialize()`, bakes waypoints from the curve at `waypoint_spacing` intervals; unless `use_global_coords` is on, each point is offset by `entity._spawn_position`.
- Each frame writes direction + distance toward the current waypoint; on arrival advances. End-of-path behavior depends on `patrol_mode` (`LOOP` wraps, `RETRACE` reverses, `ONCE` emits `complete_signals` and disables physics processing).

### `AIRandomSweepBrain`
- Exports: `waypoint_count = 1`, `waypoint_radius = 100.0`, `valid_exit_edges` (array of `CDEnums.Edge`, default all four), `exit_overshoot = 50.0`, `arrival_distance = 5.0`, `patrol_mode = CDEnums.PatrolMode.ONCE`, `move_key = "move_direction"`.
- In `_on_initialize()`, generates `waypoint_count` random points near `game.game_bounds`'s center (clamped to bounds), then appends one exit point on a random valid edge offset by `exit_overshoot`.
- Writes only the move **direction** (no distance key) toward the current waypoint; advances on arrival. End-of-path handled per `patrol_mode` (`ONCE` disables physics processing; this brain does not emit a complete signal).

### `AISwoopBrain` (`@tool`)
- Exports: `curve: CDCurve` (with change-redraw wiring), `target_direction = Vector2.DOWN`, `target_distance = 400.0`, `move_key`, `distance_key`, `checkpoint_spacing = 30.0`, `arrival_threshold = 8.0`, `loop = false`, plus listen signals (`start_signals = ["begin_swoop"]`, `stop_signals = []`, `reset_signals = []`), `complete_signals = ["swoop_complete"]`, and editor preview properties (`preview_color`, `preview_width`).
- Marked `@tool`; draws a preview polyline of the generated curve in the editor via `_draw()` (only when `Engine.is_editor_hint()` is true).
- On a start signal: generates a `Curve2D` from the entity's position to `position + target_direction.normalized() * target_distance` using `curve.generate_curve(...)`, bakes evenly-spaced checkpoints, and begins advancing.
- Each frame writes direction + distance toward the current checkpoint; advances on arrival. At the end, if `loop` is on (and the entity is `ACTIVE`) it regenerates the curve from the current position; otherwise it cleans up and emits `complete_signals`.
- Stop signals abort early; reset signals clean up and immediately restart from the current position. Cleanup clears the move/distance keys so legs stop the entity. Disables physics processing on activation (waits for the start signal).

### `AITimedStepBrain`
- Exports: `step_interval = 1.0`, `step_direction = Vector2.DOWN`, `step_interval_key = "step_interval"`, `step_direction_key = "step_direction"`, `move_key = "move_direction"`, `reset_signals = ["reset_step"]`.
- Each `_physics_process()` accumulates a timer; when it reaches the current interval it writes `step_direction` to `move_key`. The interval and direction are read from the entity blackboard each step, falling back to the exported defaults — so any other component can modulate stepping by writing those keys.
- On a reset signal: clears the timer and erases the blackboard overrides so the defaults take effect again.
- Writes only the move direction (no distance key).