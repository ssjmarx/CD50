# Selector Resources

5 resource classes that choose which entities participate in a transition or rule. Used by `CDTransition` and `CDDirectorRule`.

---

## Architecture

`CDSelector` (abstract base) stores a `_game` reference and defines the `select()` interface. 4 concrete selectors extend it with different selection strategies.

### Base Class Methods

| Method | Purpose |
|--------|---------|
| `initialize(game)` | Store the CDGame reference (for group registry access) |
| `select(candidates)` | **Override** — return a subset of candidates |
| `reset()` | Clear the game reference |

### Must-Includes When Creating Selectors

1. Extend `CDSelector`
2. Override `select(candidates) → Array[CDEntity]`
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

### CDSelectNearestN — Nearest to Target Group

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
