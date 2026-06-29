# Goals — Win/Lose Condition Components

`Goals` are `CDGameComponent` nodes (category `RULES`) that watch one specific kind of game state (entity group counts, a blackboard score value, or game-bus signals) and, when their condition is met, write a result to the game blackboard and fire game-bus signals.

## Files

| File | Class | Watches |
|------|-------|---------|
| `group_count_goal.gd` | `GroupCountGoal` | `game.group_registry` entity counts |
| `score_threshold_goal.gd` | `ScoreThresholdGoal` | an `int` on `game.blackboard` |
| `signal_goal.gd` | `SignalGoal` | game-bus signals (no numeric condition) |

---

## Patterns

### 1. Rules category
Every goal sets `component_category = CDEnums.ComponentCategory.RULES` in `_ready()` before `super._ready()`.

### 2. The standard fire contract
When a goal's condition is met, every goal runs the same four steps:
1. Early-out if `game.current_state == CDEnums.GameState.GAME_OVER`.
2. Write `game_result` (`CDEnums.GameResult`) to `game.blackboard` under `result_key` (default `&"game_result"`).
3. `game.bus_emit(sig)` every signal in `on_condition_met` (**informational**).
4. `game.bus_emit(sig)` every signal in `end_game_signals` (**terminator**, e.g. `&"game_over"`).

```gdscript
if game.current_state == CDEnums.GameState.GAME_OVER:
    return
# ...evaluate condition...
if condition_met:
    game.blackboard[result_key] = game_result
    for sig in on_condition_met:
        game.bus_emit(sig)
    for sig in end_game_signals:
        game.bus_emit(sig)
```

### 3. Four shared exports
- `game_result: CDEnums.GameResult` — result written on success.
- `result_key: StringName` — blackboard key (default `&"game_result"`).
- `on_condition_met: Array[StringName]` — informational signals (default `[&"goal_reached"]`).
- `end_game_signals: Array[StringName]` — terminator signals (kept separate from `on_condition_met` so informational vs terminator intent is explicit).

### 4. Two default shapes
| Shape | `game_result` | `end_game_signals` | Intent |
|-------|---------------|--------------------|--------|
| **Victory** | `VICTORY` | `[]` | Success trigger — does *not* end the game unless a designer opts in (used by `GroupCountGoal`, `ScoreThresholdGoal`) |
| **Defeat** | `DEFEAT` | `[&"game_over"]` | Failure trigger — ends the game now (used by `SignalGoal`) |

Pick the shape that matches the goal's default intent. Everything is overridable in the inspector.

### 5. Wire inputs in `_on_initialize()`
- Game-bus signals → `connect_all(signals, handler)` (inherited; tracked + auto-disconnected).
- Registry/typed signals → connect directly (e.g. `game.group_registry.group_count_changed`).

### 6. Numeric comparison
Numeric goals delegate to a single shared helper — never re-implement the operator `match`:
```gdscript
func _compare(observed: int) -> bool:
    return CDEnums.compare(observed, threshold, comparison)
```
`comparison` is a `CDEnums.CountComparison` (`LESS_THAN`, `EQUAL_TO`, `GREATER_THAN`, `LESS_OR_EQUAL`, `GREATER_OR_EQUAL`).

---

## How to create a new goal

```gdscript
## MyNewGoal
## <one-line description>

class_name MyNewGoal extends CDGameComponent

@export var my_threshold: int = 10

@export_group("Game Result")
@export var game_result: CDEnums.GameResult = CDEnums.GameResult.VICTORY
@export var result_key: StringName = &"game_result"

@export_group("Emit Signals")
@export var on_condition_met: Array[StringName] = [&"goal_reached"]
@export var end_game_signals: Array[StringName] = []

func _ready() -> void:
    component_category = CDEnums.ComponentCategory.RULES
    super._ready()

func _on_initialize() -> void:
    connect_all(trigger_signals, _on_trigger)   # or whatever your source is

func _on_trigger() -> void:
    if game.current_state == CDEnums.GameState.GAME_OVER:
        return
    if _condition_met():
        game.blackboard[result_key] = game_result
        for sig in on_condition_met:
            game.bus_emit(sig)
        for sig in end_game_signals:
            game.bus_emit(sig)

func _condition_met() -> bool:
    return false  # your logic here; use CDEnums.compare for numeric goals
```

### Checklist

- [ ] `class_name …Goal extends CDGameComponent`; set `component_category = RULES` in `_ready()`.
- [ ] Add the four standard exports (`game_result`, `result_key`, `on_condition_met`, `end_game_signals`).
- [ ] Pick the default shape (Victory `[]` / Defeat `[&"game_over"]`) matching the goal's intent.
- [ ] Early-out on `GAME_OVER` in every handler.
- [ ] Wire inputs in `_on_initialize()`; prefer `connect_all` for bus signals.
- [ ] For numeric conditions, call `CDEnums.compare(observed, target, op)` — don't copy a `match` block.
- [ ] Bus signals are zero-argument; only typed registry signals carry args.
- [ ] Add `&"game_over"` to `end_game_signals`, never to `on_condition_met`.