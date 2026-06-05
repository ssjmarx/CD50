# Selector Resources

7 resource classes that choose which entities participate in a transition or rule. Used by `CDTransition` and `CDDirectorRule`.

---

## Architecture

`CDSelector` (abstract base) stores a `_game` reference and defines the `select()` interface. 6 concrete selectors extend it with different selection strategies.

### Base Class Methods

| Method | Purpose |
|--------|---------|
| `initialize(game)` | Store the CDGame reference (for group registry access) |
| `select(candidates, source_position)` | **Override** — return a subset of candidates |
| `reset()` | Clear the game reference |

### Must-Includes When Creating Selectors

1. Extend `CDSelector`
2. Override `select(candidates, source_position) → Array[CDEntity]`
3. Add shape-specific `@export` vars (count, target_group, etc.)
4. Handle empty candidate arrays gracefully

---

## Selector Types

### CDSelectAll — Pass-Through

No filtering — returns all candidates unchanged. Use when every entity in a group should participate.

No exports.

### CDSelectN — First N

Selects the first N candidates in iteration order. Simple and deterministic.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `count` | `int` | 1 | Maximum entities to select |

### CDSelectNearestN — Nearest to Source Position

Sorts candidates by distance to the `source_position` parameter, then takes the nearest N.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `count` | `int` | 1 | Maximum entities to select |

### CDSelectNearestNToGroup — Nearest to Target Group

Sorts candidates by distance to the closest entity in a target group, then takes the nearest N. Falls back to CDSelectN behavior if no reference entity is found.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `count` | `int` | 1 | Maximum entities to select |
| `target_group` | `StringName` | &"players" | Group to find the reference point from |

### CDSelectRandomN — Random N

Selects N random candidates without replacement. Each evaluation picks independently.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `count` | `int` | 1 | Maximum entities to select |

### CDSelectSignalEmitter — Signal Emitter Filter

Filters candidates to only those that emitted a specific signal this frame. Cross-references the `_signal_emitters` registry on the game bus (populated by `bus_emit_from`, cleared by `CDUpdater`).

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `signal_name` | `StringName` | &"" | Signal name to check in the emitter registry |
| `use_game_bus` | `bool` | true | true = check game bus registry, false = check each entity's own registry |

Use this selector when a `CDSignalTrigger` fires and you need to narrow down candidates to only the entity that caused the signal.