# Directors — Group Orchestration Components

`Directors` are `CDGameComponent` nodes (category `RULES`) that orchestrate behavior across **groups of entities** rather than acting on a single entity. They read from `game.group_registry`, evaluate data-driven resource rules, and push results onto entity blackboards, game-bus signals, or queued state transitions.

> **Removed:** `signal_sequence_director.gd` and `state_director.gd` were deleted as near-duplicates of `managers/signal_manager.gd` and `managers/state_manager.gd`. Those managers are the canonical implementations.

## Files

| File | Class | Output |
|------|-------|--------|
| `aiming_director.gd` | `AimingDirector` | Blackboard `aim_direction` (per-entity nearest-target aiming) |
| `formation_director.gd` | `FormationDirector` | Blackboard `move_direction` / `move_distance` (slot grid + marching) |
| `marching_order_director.gd` | `MarchingOrderDirector` | Blackboard `move_direction` / `move_distance` (continuous path delta) |
| `shooting_director.gd` | `ShootingDirector` | Entity-bus shoot signal (trigger + selector driven) |
| `stage_director.gd` | `StageDirector` | Entity swap (deactivate + spawn replacement) on game-bus signal |
| `swoop_director.gd` | `SwoopDirector` | Blackboard `move_direction` / `move_distance` along a curve; emits `swoop_complete` |

---

## Patterns

### 1. Rules category
Every director extends `CDGameComponent` and sets `component_category = CDEnums.ComponentCategory.RULES` in `_ready()` before `super._ready()`.

### 2. `@tool` status
Five of six are `@tool` (preview geometry, or harmless to evaluate in the editor). `StageDirector` is **not** `@tool` (it does runtime entity swaps). Every `@tool` script guards runtime loops with:
```gdscript
if Engine.is_editor_hint(): return
```

### 3. Entity gathering
Gather entities via the shared registry helper — do **not** re-implement the dedup loop:

```gdscript
return game.group_registry.get_groups_union(target_groups, true)  # dedup + active filter
```

- `active_only := true` — common case (valid + `ACTIVE` in one call).
- `active_only := false` — only when you filter later (e.g. during slot assignment).
- `require_all` (intersection mode) is implemented inline; the ANY branch delegates to `get_groups_union`.

### 4. Output channels (never move entities directly)
1. **Entity blackboard** — write `Vector2` directions / `float` distances under configurable keys (defaults: `move_direction`, `move_distance`, `aim_direction`).
2. **Game-bus signals** — `game.bus_emit(sig)` / `game.bus_emit_from(sig, entity)`.
3. **Entity-bus signals** — `entity.bus_emit(shoot_signal)`.
4. **Queued transitions** — `game.update.queue_transition(...)` (used by managers, not by any remaining director).

### 5. Data-driven resources
Directors are configured by attachable resources: `CDFormation`, `CDMarchingOrder`, `CDTrigger`, `CDSelector`, `CDDirectorRule`, `CDCurve`, `CDScaler`. Initialize child resources in `_on_initialize()` (e.g. `trigger.initialize(game)`).

### 6. Listen signals via `connect_all`
```gdscript
connect_all(trigger_signals, _on_trigger)  # inherited; tracked + auto-disconnected on _exit_tree
```
If you override `_exit_tree`, call `super._exit_tree()` so tracked connections are torn down.

### 7. `reset()` for game restart
Every stateful director has a public `reset()` that clears timers/caches and re-inits child resources. Omit it only for truly stateless directors (`StageDirector`).

---

## How to create a new director

```gdscript
@tool
## MyNewDirector
## <one-line purpose; which channel(s) it outputs to>

class_name MyNewDirector extends CDGameComponent

@export var target_groups: Array[StringName] = [&"enemies"]
@export var require_all: bool = false

@export_group("Blackboard Keys")
@export var direction_key: StringName = &"move_direction"
@export var distance_key: StringName = &"move_distance"

@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"game_play"]

func _ready() -> void:
    component_category = CDEnums.ComponentCategory.RULES
    super._ready()

func _on_initialize() -> void:
    connect_all(trigger_signals, _on_trigger)   # tracked + auto-disconnected
    # initialize any child resources here

func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return
    var entities := _gather_target_entities()
    # compute intent, write blackboard keys / emit signals

func _gather_target_entities() -> Array[CDEntity]:
    return game.group_registry.get_groups_union(target_groups, true)

func reset() -> void:
    pass   # clear timers/caches, re-init child resources
```

### Checklist

- [ ] Extend `CDGameComponent`; set `component_category = RULES` in `_ready()`.
- [ ] Decide `@tool` status. If `@tool`, guard runtime loops with `if Engine.is_editor_hint(): return` and gate `_draw`/`_process` to editor-only where appropriate.
- [ ] Declare `target_groups` + `require_all` if you gather entities.
- [ ] Gather via `game.group_registry.get_groups_union(groups, active_only)` — never re-implement the dedup loop.
- [ ] Pick output channel(s) (blackboard / game-bus / entity-bus / queued transitions); never move entities directly.
- [ ] Initialize child resources in `_on_initialize()`.
- [ ] Connect listen-signals via `connect_all(...)`; if you override `_exit_tree`, call `super._exit_tree()`.
- [ ] Add a `reset()` (omit only if truly stateless).
- [ ] If editor previews are useful, implement `_draw()` and have export setters call `queue_redraw()` when `is_node_ready()`.