# `resources/behavior/`

Data-only `Resource` scripts that describe **rules, transitions, scaling curves, and shape/kick tables** consumed by the game's directors and managers. Nothing in this folder is a `Node` or runs on its own — each file is a `Resource` subclass (filename `cd_*.gd`, `class_name CD*`) that other systems read at runtime.

This README documents **only what the `.gd` files in this folder actually contain**. References to external systems (e.g. `StageDirector`, `StageManager`, `ScoreManager`, `SignalSequenceDirector`, `Faces`, `WaveCard`) are quoted from each script's own docstring and are defined elsewhere.

---

## Shared conventions

Every script in this folder follows the same shape. New files should match it.

### File / class naming
- Filename: `cd_<snake_case_name>.gd`
- Class: `class_name CD<PascalCaseName> extends Resource` (or `extends CDScaler` for scalers — see below).

### Header docstring
Each file begins with a multi-line `##` comment block:
```gdscript
## CDClassName
## One-line summary of what the resource represents
## Optional further context (who consumes it, etc.)
```

### Exports
- Designer-facing fields are `@export`-ed.
- Each export has a `##` comment on the line directly above it.
- Group related exports under a `## --- Exports ---` (or `## --- exports ---`) section banner.

### Internal state
- Private vars are `_`-prefixed (e.g. `_game`, `_peak_count`, `_cooldown_timer`).
- Grouped under a `## --- Internal State ---` / `## --- state ---` banner.

### Lifecycle methods (only where the resource owns logic)
Not every resource has these — pure-data resources omit them entirely.

| Method | Purpose |
| --- | --- |
| `initialize(game: CDGame) -> void` | Cache the `CDGame` reference and forward it to any child resources (triggers, selectors, scalers). Override to also connect signals. |
| `reset() -> void` | Clear internal state for a game restart. Forward to child resources where present. |
| `evaluate() -> float` | Scalers only — return the current scaled value. |
| `is_valid() -> bool` | Rules/transitions — return `true` if the resource is configured with at least one effect. |

### Common typed dependencies
Several resources reference sibling resource types via typed `@export` fields. These types live in other folders and are **not** documented here:
- `CDTrigger` — what activates a rule/transition (signal, timer, group count, …).
- `CDSelector` — how to pick entities from a group (e.g. `CDSelectAll`, `CDSelectN`).
- `CDWaveScaler` — a scaler whose output overrides a cooldown.
- `CDGame` — the game root passed into `initialize()`; exposes `group_registry`, `blackboard`, and the game bus.

---

## Resource inventory

The folder contains four kinds of resources:

1. **Pure data** — no methods, just exports (`CDDirectorRule`, `CDScoringRule`, `CDSequenceStep`, `CDShape`).
2. **Data + lifecycle/validation logic** (`CDStageRule`, `CDTransition`).
3. **Scalers** — an inheritance family with an `evaluate()` contract (`CDScaler` base; `CDGroupCountScaler`, `CDWaveScaler` subclasses).
4. **Specialized query table** — `CDWallKick`.

---

### `CDScaler` — `cd_scaler.gd`

> Abstract base class for float value scaling resources. Provides base value, clamping, and a game-aware lifecycle.

**Exports**
- `base: float = 1.0` — baseline value before scaling.
- `minimum: float = 0.0` — clamped lower bound.
- `maximum: float = 10.0` — clamped upper bound.

**State**
- `_game: CDGame` — cached game reference for group registry / bus access.

**Methods**
- `initialize(game: CDGame) -> void` — stores `_game`. Subclasses override and call `super.initialize(game)`.
- `evaluate() -> float` — returns `base` by default. Subclasses override to compute a scaled value.
- `reset() -> void` — no-op base; subclasses override to clear state.

This is the contract every scaler follows: subclass it, override `evaluate()` (and `reset()` if you keep state), read `_game` for live game state.

---

### `CDGroupCountScaler` — `cd_group_count_scaler.gd`

> Scales a float value based on the current count of entities in a group. Returns `minimum` when the group is at peak capacity, `maximum` when the group is empty. The peak capacity dynamically adjusts upward if the group size ever exceeds it.

`extends CDScaler`.

**Enum**
```gdscript
enum EasingType {
    LINEAR,
    EASE_IN,    # Slow start, fast end (compounding)
    EASE_OUT    # Fast start, slow end (diminishing returns)
}
```

**Exports**
- `group_name: StringName = &""` — group to count entities from.
- `easing: EasingType = LINEAR` — interpolation curve.

**State**
- `_peak_count: int` — peak group size tracked across the wave.
- `_was_empty: bool = true` — used to detect wave transitions (empty → populated).

**Methods**
- `initialize(game: CDGame)` — calls `super.initialize(game)`; no signal connections.
- `evaluate() -> float` — reads `_game.group_registry.get_group(group_name).size()`, tracks the peak, detects wave resets, computes `ratio = 1 - count/peak`, applies easing (`ease(ratio, 4.0)` for `EASE_IN`, `ease(ratio, 0.25)` for `EASE_OUT`), and returns `lerpf(minimum, maximum, eased_ratio)`. Returns `minimum` when unconfigured (`_game == null` or `group_name == &""`).
- `reset()` — zeroes `_peak_count`, sets `_was_empty = true`.

Note the semantics: the scaler maps **full group → `minimum`** and **empty group → `maximum`**.

---

### `CDWaveScaler` — `cd_wave_scaler.gd`

> Converts wave number into a scaled float value via linear interpolation with clamping. Reads wave number from the game blackboard (set by `WaveCard`, per its docstring).

`extends CDScaler`.

**Exports**
- `per_wave: float = -0.3` — amount added per wave after wave 1 (negative = decreases over time).
- `wave_key: StringName = &"wave_number"` — blackboard key to read the current wave number from.

**Methods**
- `evaluate() -> float` — reads `_game.blackboard[wave_key]` (defaults to `1` if absent), returns `clampf(base + per_wave * (wave_number - 1), minimum, maximum)`.
- `reset()` — no-op; the blackboard is the source of truth.

There is a commented-out `_previous_wave` debug block in the file — left intentionally inactive.

---

### `CDDirectorRule` — `cd_director_rule.gd`

> One entity swap rule for `StageDirector`. When trigger signals fire, selected entities are swapped to a new scene.

**Exports**
- `trigger_signals: Array[StringName] = []` — game bus signals that activate this rule.
- `target_group: StringName = &""` — which group to select entities from.
- `selector: CDSelector = null` — how to pick entities from the group (e.g. `CDSelectAll`, `CDSelectN`).
- `swap_scene: PackedScene = null` — scene to replace selected entities with.
- `deactivate_original: bool = true` — whether to deactivate the original entity after swapping.

Pure data — no methods.

---

### `CDScoringRule` — `cd_scoring_rule.gd`

> Defines a score or multiplier change attached to a `CDTrigger`. Used by `ScoreManager` to evaluate state changes and apply scoring deltas.

**Exports**
- `trigger: CDTrigger` — the trigger that determines when this rule fires.
- `score_delta: int = 0` — flat amount to add to (or subtract from) the score.
- `multiplier_delta: float = 0.0` — amount to add to (or subtract from) the multiplier.
- `emit_signal: StringName = &"add_score"` — which game bus signal to emit. Expected values per the comment: `"add_score"`, `"set_score"`, `"add_multiplier"`, `"set_multiplier"`.

Pure data — no methods.

---

### `CDSequenceStep` — `cd_sequence_step.gd`

> A single step in a `SignalSequenceDirector`'s timed signal sequence. Fires one or more game bus signals simultaneously, then waits before advancing.

**Exports**
- `signals: Array[StringName] = []` — game bus signals fired simultaneously when the step activates.
- `delay_after: float = 0.0` — seconds to wait after firing before advancing to the next step.
- `wait_for_signal: StringName = &""` — if set, pause after `delay_after` until this signal fires on the game bus (useful for synchronizing with spawning/swoop completion).
- `wait_count: int = 1` — how many times `wait_for_signal` must fire before advancing.

Pure data — no methods.

---

### `CDShape` — `cd_shape.gd`

> A polygon shape defined by 2D points. Used by `Faces` to set entity collision polygons at init time.

**Exports**
- `points: PackedVector2Array = PackedVector2Array()` — vertices of the polygon in local-space coordinates.
- `closed: bool = true` — whether the polygon auto-closes (last point connects to first).

Pure data — no methods.

---

### `CDStageRule` — `cd_stage_rule.gd`

> Defines a single stage control rule for `StageManager`. When the trigger fires, named `CDStage`s are slept/woken and optional game signals emitted.

**Exports**
- `trigger: CDTrigger` — what activates this rule (signal, timer, etc.).
- `sleep_stages: Array[StringName] = []` — stage node names to put to sleep.
- `wake_stages: Array[StringName] = []` — stage node names to wake up.
- `game_signals: Array[StringName] = []` — game bus signals to emit after execution.

**Methods**
- `initialize(game: CDGame)` — forwards to `trigger.initialize(game)` if a trigger is assigned.
- `reset()` — forwards to `trigger.reset()` if assigned.
- `is_valid() -> bool` — `true` if at least one of `sleep_stages`, `wake_stages`, or `game_signals` is non-empty.

---

### `CDTransition` — `cd_transition.gd`

> Defines when and how entities move between groups. Used by `Directors` to orchestrate entity state changes via trigger → selector → group swap.

**Exports**
- `remove_groups: Array[StringName] = []` — groups to remove entities from.
- `add_groups: Array[StringName] = []` — groups to add entities to.
- `target_groups: Array[StringName] = []` — groups used for filtering candidates (entity must be in **all** of these).
- `trigger: CDTrigger` — what activates this transition (timer, signal, group count, etc.).
- `selector: CDSelector` — how to pick entities from the source group.
- `cooldown: float = 0.0` — seconds between activations (`0` = no cooldown).
- `wave_scaler: CDWaveScaler` — optional; overrides `cooldown` when assigned.
- `entity_signals: Array[StringName] = []` — signals on transition (entity-level).
- `game_signals: Array[StringName] = []` — signals on transition (game bus).

**State**
- `_cooldown_timer: float` — tracks cooldown progress.

**Methods**
- `initialize(game: CDGame)` — zeroes `_cooldown_timer`, then forwards `initialize(game)` to `wave_scaler`, `trigger`, and `selector` (in that order). Pushes a warning if no `selector` is assigned.
- `reset()` — zeroes `_cooldown_timer`, forwards `reset()` to `wave_scaler`, `trigger`, `selector`.
- `advance_cooldown(delta: float)` — ticks `_cooldown_timer` down toward `0`.
- `is_on_cooldown() -> bool` — `true` while `_cooldown_timer > 0`.
- `start_cooldown()` — after a successful activation, sets `_cooldown_timer` to the effective cooldown. If a `wave_scaler` is assigned, its `evaluate()` result is used instead of `cooldown`. No timer is started if the effective value is `<= 0`.
- `is_valid() -> bool` — `true` if at least one of `remove_groups` or `add_groups` is non-empty.

---

### `CDWallKick` — `cd_wall_kick.gd`

> Tetris-style wall kick offset table. Defines kick positions to try when a rotation is blocked by collision.

**Exports**
- `kicks: Array[Array]` — 8 kick arrays indexed by rotation transition. Each inner array is `Array[Vector2i]` of offsets tried in order. Default is eight empty arrays.

**Methods**
- `get_kicks(from: int, to: int) -> Array[Vector2i]` — returns the kick offsets for the rotation transition `(from, to)`, or `[]` if the index is out of range.
- `_kick_index(from: int, to: int) -> int` (private) — maps a rotation state pair to a table index. Rotation states are `0=spawn, 1=right, 2=180°, 3=left`. Mapping:

  | Transition | Index |
  | --- | --- |
  | `0 → 1` (0→R) | 0 |
  | `1 → 0` (R→0) | 1 |
  | `1 → 2` (R→2) | 2 |
  | `2 → 1` (2→R) | 3 |
  | `2 → 3` (2→L) | 4 |
  | `3 → 2` (L→2) | 5 |
  | `3 → 0` (L→0) | 6 |
  | `0 → 3` (0→L) | 7 |

  Any other pair returns `-1`.

---

## How to add a new resource to this folder

1. **Create `cd_<name>.gd`** with the standard header and class declaration.
2. **Pick the right base:**
   - A pure data container → `extends Resource`.
   - A float scaling curve → `extends CDScaler` and override `evaluate()` (and `reset()` if you keep state). Honor the contract: full-value and empty-value endpoints should land at `minimum`/`maximum` as appropriate.
   - A rule/transition with activation semantics → `extends Resource`, give it a `trigger: CDTrigger` export, and implement `initialize(game)`, `reset()`, and `is_valid()`.
3. **Export designer-facing fields with `## ` comments**, grouped under a `## --- Exports ---` banner. Use `StringName` (default `&""`) and `Array[StringName]` for bus-signal/group identifiers, and typed resource fields (`CDTrigger`, `CDSelector`, `CDWaveScaler`) for collaborators.
4. **If you keep runtime state**, prefix it with `_`, group under `## --- Internal State ---`, and make sure `reset()` clears it.
5. **Forward lifecycle calls** to any child resources you reference (mirroring `CDTransition`/`CDStageRule`): `initialize(game)` → each child's `initialize(game)`; `reset()` → each child's `reset()`.
6. **Use `_game`** (from `CDScaler` or your own cached field) to read live state — `group_registry`, `blackboard`, and the game bus — rather than storing copies.

### Minimal template (pure data)
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

### Minimal template (scaler subclass)
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
    # ...compute and clamp into [minimum, maximum]...
    return clampf(computed_value, minimum, maximum)

func reset() -> void:
    pass