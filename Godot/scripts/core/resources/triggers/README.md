# Trigger Resources

5 resource classes that determine when a `CDTransition` fires. Used by `CDTransition` and `CDDirectorRule`.

---

## Architecture

`CDTrigger` (abstract base) stores a `_game` reference and defines the `evaluate()` interface. Two flavors:

- **Evaluative** (`is_evaluative = true`) — continuous condition checks (e.g., group count). Use `is_condition_met()` for current state, `evaluate()` for edge detection (fires on false→true).
- **Event** (`is_evaluative = false`) — moment-based (e.g., signal received, timer elapsed). `evaluate()` returns true once per event then resets.

### Base Class Methods

| Method | Purpose |
|--------|---------|
| `initialize(game)` | Store CDGame reference |
| `evaluate(delta)` | **Override** — return true when trigger should fire |
| `is_condition_met()` | **Override** — return current condition state (evaluative triggers) |
| `reset()` | Clear state and game reference |

### Must-Includes When Creating Triggers

1. Extend `CDTrigger`
2. Set `is_evaluative = true` in `_init()` for condition-type triggers
3. Override `evaluate(delta)` — this is what `CDTransition` calls
4. Override `is_condition_met()` for evaluative triggers (used by `CDCompositeTrigger`)
5. Override `reset()` to clean up connections and state
6. Handle null `_game` gracefully

---

## Trigger Types

### CDTimerTrigger — Interval Timer (Event)

Fires on a configurable timer interval with optional random variance.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `interval` | `float` | 5.0 | Base time between fires (seconds) |
| `random_variance` | `float` | 0.0 | ±random offset added to interval |

### CDSignalTrigger — Game Bus Signal (Event)

Fires when a named signal is received on the game bus. Captures entity arguments for use by transitions.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `signal_name` | `StringName` | &"" | Bus signal to listen for |

Extra methods:
- `consume_pending()` — return captured entities and clear the list

### CDGroupCountTrigger — Group Population (Evaluative)

Compares a group's entity count against a threshold. Fires on false→true edge (rising edge detection only).

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `group_name` | `StringName` | &"" | Group to monitor |
| `comparison` | `CountComparison` | LESS_OR_EQUAL | Comparison operator |
| `threshold` | `int` | 0 | Value to compare against |

### CDCompositeTrigger — AND/OR Combination

Combines multiple sub-triggers with AND (all must fire) or OR (any can fire) logic. Correctly separates evaluative and event sub-triggers during evaluation.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `triggers` | `Array[CDTrigger]` | [] | Sub-triggers to combine |
| `require_all` | `bool` | true | true = AND, false = OR |

Extra methods:
- `consume_pending()` — collect pending entities from all signal sub-triggers
