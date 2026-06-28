# `triggers/` — State Machine Transition Triggers

This folder contains `CDTrigger` resources used (per the base class's own header comment) as state machine transition triggers. Each trigger is a `Resource` subclass with a `class_name` beginning in `CD`, intended to be configured in the inspector and evaluated each frame.

## Files

| File | Class | Flavors |
|------|-------|---------|
| `cd_trigger.gd` | `CDTrigger` | Abstract base class |
| `cd_signal_trigger.gd` | `CDSignalTrigger` | Event |
| `cd_timer_trigger.gd` | `CDTimerTrigger` | Event |
| `cd_group_count_trigger.gd` | `CDGroupCountTrigger` | Evaluative |
| `cd_composite_trigger.gd` | `CDCompositeTrigger` | Composite |

## The Two Flavors

Every trigger carries an `is_evaluative: bool` flag (default `false`) declared in `CDTrigger`. The header comment describes two flavors:

- **Evaluative** (`is_evaluative = true`): a *continuous condition* checked via `is_condition_met()`. The composite trigger treats these as "cheap" and never consumes them.
- **Event** (`is_evaluative = false`): a *moment-based* occurrence checked via `evaluate(delta)`. Evaluation can *consume* the event (e.g. `CDSignalTrigger` clears its fired flag after returning `true`).

`CDGroupCountTrigger` is the only subclass here that sets `is_evaluative = true` (in its `_init()`).

## Shared Lifecycle Contract

All triggers implement the same three methods, inherited from `CDTrigger`:

1. **`initialize(game: CDGame)`** — stores the `_game` reference. Subclasses call `super.initialize(game)` and then do their own setup (connect signals, seed timers, initialize child triggers/scalers).
2. **`evaluate(delta: float) -> bool`** — called per frame. Returns `true` when the trigger fires *this frame*. The base implementation always returns `false`.
3. **`reset()`** — clears internal state and nulls out `_game`. Subclasses clear their own state then call `super.reset()`.

There is also `is_condition_met() -> bool` (default `false`), used by evaluative triggers to report their current condition without edge/one-shot semantics.

All triggers store a `_game: CDGame` reference, populated by `initialize()`. Through it they access:
- `_game.bus_connect(sig, callable)` / `_game.bus_disconnect(sig, callable)` — used by `CDSignalTrigger`.
- `_game.group_registry.get_count(group_name)` — used by `CDGroupCountTrigger`.

---

## `CDTrigger` (`cd_trigger.gd`)

Abstract base class. `extends Resource`.

| Member | Type | Notes |
|--------|------|-------|
| `is_evaluative` | `bool` | `true` = continuous condition, `false` = moment-based event. Default `false`. |
| `_game` | `CDGame` | Game reference; set by `initialize()`, cleared by `reset()`. |

Methods:

- `initialize(game: CDGame)` — stores `_game`.
- `evaluate(_delta: float) -> bool` — override in subclasses; base returns `false`.
- `is_condition_met() -> bool` — override in evaluative subclasses; base returns `false`.
- `reset()` — sets `_game = null`.

---

## `CDSignalTrigger` (`cd_signal_trigger.gd`)

Event trigger. Header: *"Evaluates true when a signal on its list fires."* Fires when one or more named signals are emitted on the game bus.

| Export | Type | Default | Meaning |
|--------|------|---------|---------|
| `signal_names` | `Array[StringName]` | `[]` | Signals to listen for via `bus_connect`. Empty `&""` entries are skipped. |
| `require_all` | `bool` | `false` | When `true`, every name in `signal_names` must have fired before the trigger fires. |
| `require_count` | `int` | `1` | Minimum number of signal receptions before firing. |

Internal state: `_has_fired`, `_received` (`Dictionary` of `{StringName: bool}`), `_fire_count`.

Behavior:

- `initialize()` connects `_on_signal_received.bind(sig)` to each non-empty signal name. If `signal_names` is empty it pushes a warning that the trigger will never fire.
- On each received signal, `_fire_count` is incremented and the name is recorded in `_received`. The trigger sets `_has_fired = true` when **both** `_fire_count >= require_count` **and** (`not require_all` OR `_received.size() >= signal_names.size()`). It then clears `_received` and resets `_fire_count`.
- `evaluate()` is a one-shot consumer: if `_has_fired` is true it clears the flag and returns `true` once, then returns `false` until the next fire.
- `reset()` disconnects all bound callbacks (if `_game` is non-null), clears `_received`, zeroes `_fire_count`, then calls `super.reset()`.

---

## `CDTimerTrigger` (`cd_timer_trigger.gd`)

Event trigger. Header: *"fires on a configurable timer interval."*

| Export | Type | Default | Meaning |
|--------|------|---------|---------|
| `interval` | `float` | `5.0` | Base time between fires, in seconds. |
| `scaler` | `CDScaler` | `null` | Optional scaler resource. When assigned, its `evaluate()` result **overrides** `interval`. |
| `random_variance` | `float` | `0.0` | ±jitter added to the interval each cycle. |

Internal state: `_time_until_fire`.

Behavior:

- `initialize()` calls `super.initialize()`, initializes the `scaler` if present, and runs `_reset_timer()`.
- `evaluate(delta)` subtracts `delta` from `_time_until_fire`; when it reaches `<= 0.0` it calls `_reset_timer()` and returns `true`.
- `_reset_timer()` uses the scaler's value if present, otherwise `interval`, then adds `randf_range(-random_variance, random_variance)` when `random_variance > 0.0`.
- `reset()` zeroes `_time_until_fire` and resets the `scaler` if present.
- A commented-out debug print exists in `_reset_timer()` (left as-is in source).

---

## `CDGroupCountTrigger` (`cd_group_count_trigger.gd`)

Evaluative trigger. Header: *"compares group entity counts against a threshold."* Fires on the **rising edge** only (false→true transition).

| Export | Type | Default | Meaning |
|--------|------|---------|---------|
| `group_names` | `Array[StringName]` | `[]` | Groups to read via `_game.group_registry.get_count()`. |
| `comparison` | `CDEnums.CountComparison` | `LESS_OR_EQUAL` | Operator used to compare each count against `threshold`. |
| `threshold` | `int` | `0` | Value each group count is compared to. |
| `require_all` | `bool` | `true` | `true` = ALL groups must satisfy; `false` = ANY group satisfies. |

Internal state: `_was_met` (previous condition state, for edge detection).

Behavior:

- `_init()` sets `is_evaluative = true`.
- `evaluate()` calls `_check_condition()`; it returns `true` **only** when the condition is met now and was not met previously (`currently_met and not _was_met`). Sustained-true does not re-fire.
- `is_condition_met()` returns the current (non-edge) condition state, used by composite triggers.
- `_check_condition()` returns `false` early if `_game` is null or `group_names` is empty. In `require_all` mode any empty `&""` group name forces `false`; in ANY mode empty names are skipped.
- `_compare(count)` matches on `CDEnums.CountComparison` (`LESS_THAN`, `EQUAL_TO`, `GREATER_THAN`, `LESS_OR_EQUAL`, `GREATER_OR_EQUAL`) and falls through to `false`.
- `reset()` sets `_was_met = false` then calls `super.reset()`.

The `CDEnums.CountComparison` enum is referenced but **not defined** in this folder — it lives elsewhere in the codebase.

---

## `CDCompositeTrigger` (`cd_composite_trigger.gd`)

Composite trigger. Header: *"Combines multiple sub-triggers with AND/OR logic."* It "correctly separates evaluative (condition) and event (moment) sub-triggers."

| Export | Type | Default | Meaning |
|--------|------|---------|---------|
| `triggers` | `Array[CDTrigger]` | `[]` | Child triggers evaluated together. |
| `require_all` | `bool` | `true` | `true` = AND (all), `false` = OR (any). |

Behavior:

- `initialize()` calls `super.initialize()` then `initialize()` on every child trigger.
- `evaluate(delta)` returns `false` if `triggers` is empty; otherwise dispatches to `_evaluate_and()` or `_evaluate_or()` based on `require_all`.
- `is_condition_met()` iterates every child (both `is_evaluative` and non-evaluative branches call `trigger.is_condition_met()` and short-circuit on `false`) and returns `true` only if all children report their condition met.
- **AND (`_evaluate_and`)**: first checks all evaluative children via `is_condition_met()` (returns `false` if any fails), then checks all event children via `evaluate(delta)` (returns `false` if any fails). Returns `true` only if all pass.
- **OR (`_evaluate_or`)**: first checks evaluative children via `is_condition_met()` (returns `true` on the first that passes), then checks event children via `evaluate(delta)` (returns `true` on the first that fires). Returns `false` if none pass.
- `reset()` calls `reset()` on every child, then `super.reset()`.

The evaluative-first ordering is intentional: evaluative conditions are checked before event triggers are evaluated, because event evaluation can *consume* the event.

---

## Creating a New Trigger

To add a new trigger type, follow the pattern these five files actually use:

1. **Create `cd_<name>_trigger.gd`** in this folder with `class_name CD<Name>Trigger extends CDTrigger`. Use the `CD` prefix and tab indentation to match the existing files.
2. **Decide the flavor.** If the trigger is a continuous condition, set `is_evaluative = true` (typically in `_init()`, as `CDGroupCountTrigger` does) and implement `is_condition_met()`. If it is moment-based, leave `is_evaluative` at its default and rely on `evaluate(delta)`.
3. **Use `@export` for inspector-configurable fields.** Follow the existing convention: typed collections (`Array[StringName]`, `Array[CDTrigger]`), enums from `CDEnums`, and optional sub-resources (e.g. `CDScaler`) exposed as exported variables.
4. **Implement the lifecycle methods:**
   - `initialize(game: CDGame)` — call `super.initialize(game)` first, then set up state (connect signals, seed timers, initialize child resources/triggers).
   - `evaluate(delta: float) -> bool` — return `true` only on the frame the trigger should fire. Be deliberate about whether evaluation *consumes* an event (see `CDSignalTrigger`) or uses *edge detection* (see `CDGroupCountTrigger`).
   - `is_condition_met() -> bool` — implement for evaluative triggers so composites can read the raw condition.
   - `reset()` — clear internal state first, then call `super.reset()` so `_game` is nulled.
5. **Access game systems only through `_game`** (e.g. `bus_connect`/`bus_disconnect`, `group_registry`). Do not introduce other global lookups; the only dependency injected into these resources is the `CDGame` reference from `initialize()`.
6. **Keep header doc-comments.** Each existing file starts with a `## CD...` title line followed by a one-line description; mirror that style for new files.