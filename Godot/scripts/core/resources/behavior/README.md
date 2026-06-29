# Behavior Resources

Data-only `Resource` scripts that describe **rules, transitions, scaling curves, and shape/kick tables** consumed by the game's directors and managers. Nothing here is a `Node` or runs on its own — each file is a `Resource` subclass that other systems read at runtime.

## Files

| Class | Kind | Purpose |
|-------|------|---------|
| `CDScaler` | Scaler base | Base for float-scaling resources; provides `base`/`minimum`/`maximum` + `initialize(game)` / `evaluate()` / `reset()` |
| `CDGroupCountScaler` | Scaler | Scales a value by current group count (full→`minimum`, empty→`maximum`) |
| `CDWaveScaler` | Scaler | Scales a value by wave number read from the blackboard |
| `CDDirectorRule` | Pure data | One entity swap rule for `StageDirector` |
| `CDScoringRule` | Pure data | Score/multiplier change attached to a `CDTrigger`, for `ScoreManager` |
| `CDSequenceStep` | Pure data | A single timed step in a `SignalManager` sequence |
| `CDShape` | Pure data | A polygon shape used by `Faces` to set collision polygons |
| `CDStageRule` | Data + lifecycle | Sleeps/wakes `CDStage`s when a `CDTrigger` fires, for `StageManager` |
| `CDTransition` | Data + lifecycle | Moves selected entities between groups when a `CDTrigger` fires, for `StateManager` |
| `CDWallKick` | Specialized query | Tetris-style wall-kick offset table |

---

## Patterns

### 1. Four resource kinds
1. **Pure data** — no methods, just exports (`CDDirectorRule`, `CDScoringRule`, `CDSequenceStep`, `CDShape`).
2. **Data + lifecycle/validation** — own `initialize(game)`, `reset()`, `is_valid()` (`CDStageRule`, `CDTransition`).
3. **Scalers** — an inheritance family with an `evaluate()` contract (`CDScaler` → `CDGroupCountScaler`, `CDWaveScaler`).
4. **Specialized query table** — `CDWallKick`.

### 2. File / class naming
- Filename: `cd_<snake_case_name>.gd`
- Class: `class_name CD<PascalCaseName> extends Resource` (or `extends CDScaler` for scalers).

### 3. Header docstring
Each file begins with a `##` block: class name, a one-line summary, and optional context (who consumes it).

### 4. Exports
Designer-facing fields are `@export`-ed, each preceded by a `##` comment, grouped under a `## --- Exports ---` banner. Use `StringName` (default `&""`) / `Array[StringName]` for bus-signal/group identifiers, typed resource fields (`CDTrigger`, `CDSelector`, `CDWaveScaler`) for collaborators.

### 5. Internal state
Private vars are `_`-prefixed, grouped under `## --- Internal State ---`. Any runtime state must be cleared by `reset()`.

### 6. Lifecycle methods (only where the resource owns logic)
| Method | Purpose |
|--------|---------|
| `initialize(game: CDGame)` | Cache `_game`, forward to child resources (triggers, selectors, scalers). |
| `reset()` | Clear state for game restart; forward to child resources. |
| `evaluate() -> float` | Scalers only — return the current scaled value (clamped into `[minimum, maximum]`). |
| `is_valid() -> bool` | Rules/transitions — `true` if configured with at least one effect. |

### 7. Scaler contract
Subclass `CDScaler`, override `evaluate()` (and `reset()` if stateful). Honor the full-value/empty-value endpoints landing at `minimum`/`maximum` as appropriate.

### 8. Rule/transition contract
Rule/transition resources own a `trigger: CDTrigger`, optionally a `selector: CDSelector`, and implement `initialize(game)` / `reset()` / `is_valid()`. Forward lifecycle calls to child resources (mirror `CDTransition` / `CDStageRule`).

### 9. Read live game state via `_game`
Use the cached `_game` ref (from `CDScaler` or your own field) to read `group_registry`, `blackboard`, and the game bus — never store copies.

---

## How to create a new behavior resource

**Pure data:**
```gdscript
## CDExampleRule
## One-line description of what this resource represents
## Optional: who consumes it

class_name CDExampleRule extends Resource

## --- Exports ---

## what activates this rule
@export var trigger: CDTrigger

## game bus signals to emit
@export var game_signals: Array[StringName] = []
```

**Scaler subclass:**
```gdscript
## CDExampleScaler
## Scales a float based on <some game state>

class_name CDExampleScaler extends CDScaler

## --- exports ---

## configuration field
@export var some_key: StringName = &""

## --- evaluation ---

func evaluate() -> float:
    if _game == null:
        return base
    return clampf(computed_value, minimum, maximum)

func reset() -> void:
    pass
```

### Checklist

- [ ] Filename `cd_<snake_case>.gd`; `class_name CD<PascalCase>`.
- [ ] Pick the right base: `Resource` for data, `CDScaler` for curves, `Resource` + `trigger: CDTrigger` for rules/transitions.
- [ ] `##` header: class name + one-line purpose (+ optional consumer).
- [ ] Every `@export` has a preceding `##` comment; group under `## --- Exports ---`.
- [ ] Use `StringName`/`Array[StringName]` for identifiers; typed fields for collaborators.
- [ ] If stateful: `_`-prefix private vars, group under `## --- Internal State ---`, clear them in `reset()`.
- [ ] Forward `initialize(game)` / `reset()` to child resources.
- [ ] Scalers: clamp `evaluate()` into `[minimum, maximum]`.
- [ ] Rules/transitions: implement `is_valid()`.