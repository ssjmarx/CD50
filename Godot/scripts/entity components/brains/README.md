# Brains — Entity Intent Components

`Brains` are `CDEntityComponent` scripts (category `INTENT`) that decide what an entity **wants to do**. Brains never move or fire anything directly — they write intent into the entity's blackboard and/or emit bus signals, which legs, arms, and other components consume.

## Subfolders

| Subfolder | Driven by |
|-----------|-----------|
| `player/` | Player input (via `game.input_router` or direct mouse polling) |
| `ai action/` | AI firing / aiming / capture behaviors |
| `ai movement/` | AI navigation and positioning |

Player brains convert input into intent. AI brains are split between **action** (event/signal-oriented: aim, repeat-fire, capture, lasso) and **movement** (blackboard writers that emit a move direction and usually a distance each frame).

---

## Patterns

### 1. Intent category
Every brain sets `component_category = CDEnums.ComponentCategory.INTENT` in `_ready()` before `super._ready()`.

### 2. Two communication styles
- **Blackboard writers (continuous)** — most brains write values to `entity.blackboard[key]` every `_physics_process()`. Consumers read with defaults:
  ```gdscript
  entity.blackboard[move_key] = direction      # default key: &"move_direction"
  entity.blackboard[distance_key] = distance   # default key: &"move_distance"
  ```
- **Bus signals (events)** — event-driven brains connect and emit over the entity/game bus:
  ```gdscript
  self.bus_connect(start_signal, _on_start)    # listen in _on_initialize()
  entity.bus_emit(fire_action)                  # emit on the entity bus
  game.bus_emit(capture_started_signal)         # emit on the game bus
  ```

A few brains read runtime overrides from the blackboard (e.g. `AITimedStepBrain` reads `step_interval` / `step_direction`).

### 3. Common lifecycle
```gdscript
func _ready():
    component_category = CDEnums.ComponentCategory.INTENT
    super._ready()

func _on_initialize():
    # connect input sources / entity-bus listeners
    # generate waypoints / pick initial targets

func _physics_process(delta):
    # write intent to entity.blackboard[...] (continuous brains)
    # and/or advance timers / waypoints

func _on_entity_deactivating():
    super._on_entity_deactivating()
    # disconnect all signals (with is_connected guards)
    # reset internal state
```

`PlayerActionBrain` also overrides `_on_sleep()` / `_on_wake()` to disconnect/reconnect input signals.

### 4. Target acquisition (AI brains)
AI brains find targets via `game.group_registry`:
- `get_nearest(group, position)` — nearest entity in a group.
- `get_group(group)` — all entities in a group.

Several AI brains share these targeting options:
- **`update_interval`** — seconds between target recalculation; cached value is written between updates (`0` = every frame).
- **`targeting_noise`** — random offset added to the target/leader position for imprecision.
- **`target_groups` / `threat_groups`** — which entity groups to search.

### 5. Patrol modes
Waypoint-following brains use `CDEnums.PatrolMode`:
- `LOOP` — restart from the first waypoint when the path ends.
- `RETRACE` — reverse traversal direction when the path ends.
- `ONCE` — stop (and optionally emit a complete signal) when the path ends.

### 6. Cleanup
Always `super._on_entity_deactivating()` first, then disconnect every signal (guard with `is_connected`) and reset all internal state. Brains are pooled.

---

## How to create a new brain

```gdscript
## MyNewBrain
## <one-line description>

class_name MyNewBrain extends CDEntityComponent

@export var target_groups: Array[StringName] = [&"enemies"]
@export var update_interval: float = 0.0
@export var targeting_noise: float = 0.0

@export_group("Blackboard Keys")
@export var move_key: StringName = &"move_direction"
@export var distance_key: StringName = &"move_distance"

@export_group("Listen Signals")
@export var start_signals: Array[StringName] = [&"game_play"]

var _recalc_timer: float = 0.0
var _cached_dir: Vector2 = Vector2.ZERO
var _cached_dist: float = 0.0

func _ready() -> void:
    component_category = CDEnums.ComponentCategory.INTENT
    super._ready()

func _on_initialize() -> void:
    for sig in start_signals:
        self.bus_connect(sig, _on_start)

func _on_start() -> void:
    set_physics_process(true)

func _physics_process(delta: float) -> void:
    _recalc_timer += delta
    if update_interval <= 0.0 or _recalc_timer >= update_interval:
        _recalc_timer = 0.0
        _recompute()
    entity.blackboard[move_key] = _cached_dir
    entity.blackboard[distance_key] = _cached_dist

func _recompute() -> void:
    var target := game.group_registry.get_nearest(target_groups[0], entity.global_position)
    if target == null:
        _cached_dir = Vector2.ZERO
        _cached_dist = 0.0
        return
    var to := target.global_position - entity.global_position
    _cached_dist = to.length()
    _cached_dir = to.normalized() if _cached_dist > 0.0 else Vector2.ZERO

func _on_entity_deactivating() -> void:
    super._on_entity_deactivating()
    for sig in start_signals:
        self.bus_disconnect(sig, _on_start)
    _recalc_timer = 0.0
    _cached_dir = Vector2.ZERO
    _cached_dist = 0.0
```

### Checklist

- [ ] Create the file in the matching subfolder (`player/`, `ai action/`, or `ai movement/`).
- [ ] `extends CDEntityComponent`, declare a `class_name`, set `component_category = INTENT` in `_ready()`.
- [ ] Export configurable blackboard keys with the standard defaults (`move_direction`, `move_distance`, `aim_direction`).
- [ ] Decide output style: continuous → write `entity.blackboard[key]` in `_physics_process()`; event → `self.bus_connect(...)` in `_on_initialize()`, emit with `entity.bus_emit(...)` / `game.bus_emit(...)`.
- [ ] Use `game.group_registry` for target lookups; `game.input_router` for player input.
- [ ] In `_on_entity_deactivating()`, call `super` first, then disconnect signals (guard with `is_connected`) and reset all internal state.