# Managers — Data-Driven Game State Components

`Managers` are `CDGameComponent` subclasses (category `MANAGER`) that evaluate resource-based rules each frame and drive the game's runtime state. Each manager is configured almost entirely through exported resource arrays — the script logic is generic; the behavior comes from the data resources plugged into it.

## Files

| File | Class | Resource type | Purpose |
|------|-------|---------------|---------|
| `score_manager.gd` | `ScoreManager` | `CDScoringRule` | Applies score/multiplier deltas via blackboard + bus signals |
| `signal_manager.gd` | `SignalManager` | `CDSequenceStep` | Runs a timed sequence of bus signals triggered by one event |
| `stage_manager.gd` | `StageManager` | `CDStageRule` | Sleeps/wakes sibling `CDStage` nodes in response to triggers |
| `state_manager.gd` | `StateManager` | `CDTransition` | Moves entities between groups (group-as-state), deferred via `CDUpdater` |

---

## Patterns

### 1. Manager category
Every manager sets `component_category = CDEnums.ComponentCategory.MANAGER` in `_ready()` before `super._ready()`.

### 2. Behavior lives in resources, not the script
Expose data as exported resource arrays (e.g. `@export var rules: Array[CDScoringRule] = []`). The script is a **generic engine** over those resources — it never hardcodes game-specific behavior.

### 3. Shared lifecycle
```gdscript
func _ready() -> void:
    component_category = CDEnums.ComponentCategory.MANAGER
    super._ready()
    # SignalManager also calls set_physics_process(false) until a sequence starts

func _on_initialize() -> void:
    super._on_initialize()              # where present
    for rule in rules:
        rule.trigger.initialize(game)   # pass game to each resource's trigger
    # cache other game references here (e.g. StateManager caches game.update)

func _physics_process(delta: float) -> void:
    # evaluate each resource's trigger; act on the ones that fire

func reset() -> void:
    # clear runtime state
    for rule in rules:
        rule.reset()                    # reset each resource for game restart
```

### 4. Act through the shared `game` handle
- `game.blackboard` — write/read shared state.
- `game.bus_emit(sig)` / `game.bus_disconnect(...)` — game bus.
- `game.find_children("*", "CDStage")` — find sibling nodes.
- `game.group_registry` — entity group queries.
- `game.update` (`CDUpdater`) — queue deferred work (used by `StateManager` to avoid mutating groups mid-iteration).

### 5. Per-resource action
Each frame, evaluate every resource's trigger and, when it fires, take the action defined by that resource (write a blackboard key + emit a signal, fire step signals, sleep/wake a stage, queue a transition). Guard with validity/cooldown checks where relevant.

### 6. `reset()` for game restart
Every manager has a `reset()` that clears runtime state and calls `reset()` on each data resource — even managers that hold no accumulator (e.g. `ScoreManager` still resets per-rule trigger cooldowns/timers).

### 7. Disable processing when idle
If the manager only runs in bursts, toggle `set_physics_process` (see `SignalManager`).

---

## How to create a new manager

```gdscript
## MyNewManager
## <one-line description>

class_name MyNewManager extends CDGameComponent

@export var rules: Array[CDMyRule] = []

func _ready() -> void:
    component_category = CDEnums.ComponentCategory.MANAGER
    super._ready()

func _on_initialize() -> void:
    super._on_initialize()
    for rule in rules:
        if rule.is_valid():
            rule.initialize(game)

func _physics_process(delta: float) -> void:
    for rule in rules:
        if rule.trigger and rule.trigger.evaluate(delta):
            _apply_rule(rule)

func _apply_rule(rule: CDMyRule) -> void:
    # write blackboard keys / emit bus signals / query registry / queue work
    pass

func reset() -> void:
    for rule in rules:
        rule.reset()
```

### Checklist

- [ ] `class_name …Manager extends CDGameComponent`; set `component_category = MANAGER` in `_ready()`.
- [ ] Expose behavior as exported resource arrays; keep the script a generic engine.
- [ ] In `_on_initialize()`: `super` first, then initialize each resource's trigger with `game`, cache other game refs.
- [ ] Do per-frame work in `_physics_process`; guard with validity/cooldown checks.
- [ ] Act only through the `game` handle (blackboard, bus, registry, `find_children`, `update`).
- [ ] Add a `reset()` that clears state and calls `reset()` on each resource.
- [ ] Disable processing when idle if the manager runs in bursts.