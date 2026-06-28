# Selectors

This folder contains `CDSelector` resources. A selector takes a list of candidate `CDEntity` objects and returns a subset of them. Selectors are Resources, so they can be configured in the inspector and shared.

## Base class

### `CDSelector` (`cd_selector.gd`)

Abstract base class. `class_name CDSelector extends Resource`.

- Stores a `_game: CDGame` reference that is used by some subclasses to reach the game's blackboard, group registry, and signal-emitter registry.
- `initialize(game: CDGame) -> void` — stores the `CDGame` reference.
- `select(candidates: Array[CDEntity], _source_position: Vector2 = Vector2.ZERO) -> Array[CDEntity]` — the interface subclasses override. The base implementation returns `candidates` unchanged.
  - `source_position` is documented as the director's `global_position` and is consumed by the distance-based selectors.
- `reset() -> void` — clears `_game` back to `null`.

## Concrete selectors

All concrete selectors extend `CDSelector` and override `select()`. Exported properties are configurable in the inspector.

### `CDSelectAll` (`cd_select_all.gd`)

Pass-through selector. Returns the full candidate list unchanged. Use when every entity in a group should participate.

- No exported properties.

### `CDSelectByKey` (`cd_select_by_key.gd`)

Selects a single entity referenced by a game blackboard key. Useful for transitions that need to target a specific entity stored by a director (e.g. `SwoopDirector`).

- `@export var key: StringName = &""` — the blackboard key holding a `CDEntity` reference.
- Looks up `_game.blackboard[key]` and returns `[target]` only if the value is a valid `CDEntity` that is also present in `candidates`. Otherwise returns `[]`. If `_game` is missing or the key is absent, returns `[]`.

### `CDSelectN` (`cd_select_n.gd`)

Selects the first N candidates in iteration order. Simple and deterministic — no sorting or randomization.

- `@export var count: int = 1` — maximum number of entities to select.
- Returns `candidates.slice(0, n)` where `n = mini(count, candidates.size())`.

### `CDSelectNearestN` (`cd_select_nearest_n.gd`)

Selects N candidates nearest to the StateDirector's position. Sorts by distance to `source_position` and returns the closest N.

- `@export var count: int = 1` — maximum number of entities to select.
- Returns `[]` if `candidates` is empty. Otherwise copies the candidate list, sorts it ascending by `global_position.distance_squared_to(source_position)`, and returns the first N.

### `CDSelectNearestNToGroup` (`cd_select_nearest_n_to_group.gd`)

Selects N candidates nearest to the closest entity in a target group. Sorts candidates by distance to a reference entity; falls back to first-N if no reference entity is found.

- `@export var count: int = 1` — maximum number of entities to select.
- `@export var target_group: StringName = &"players"` — the group to find the reference point from.
- The reference point is obtained via `_game.group_registry.get_nearest_to_entity(target_group, candidates[0])` (nearest entity in `target_group` to the first candidate).
- If no reference entity is found, it returns the first N candidates (`candidates.slice(0, n)`).
- Otherwise it copies the candidate list, sorts it ascending by distance to the reference entity's `global_position`, and returns the first N.

### `CDSelectRandomN` (`cd_select_random_n.gd`)

Selects N random candidates without replacement. Each evaluation picks independently — different results each time.

- `@export var count: int = 1` — maximum number of entities to select.
- Builds a copy of the candidate pool, then repeatedly picks a random index, appends the chosen entity to the result, and removes it from the pool until N have been selected.

### `CDSelectSignalEmitter` (`cd_select_signal_emitter.gd`)

Filters candidates to only those that emitted a specific signal this frame. Cross-references the emitter registry on the game or entity bus.

- `@export var signal_name: StringName = &""` — the signal name to look up in the emitter registry.
- `@export var use_game_bus: bool = true` — `true` checks the game bus, `false` checks each candidate's own entity bus.
- If `signal_name` is empty or `_game` is null, returns `candidates` unchanged.
- With the game bus (`use_game_bus == true`): returns only candidates present in `_game._signal_emitters.get(signal_name, [])`.
- With the entity bus (`use_game_bus == false`): for each candidate, checks that candidate's own `entity._signal_emitters.get(signal_name, [])` and keeps the candidate if it appears in that list.

## How to use

1. Create a selector Resource (e.g. `CDSelectNearestN`) and configure its exported properties in the inspector.
2. At runtime, `initialize(game)` is called once to hand the selector its `CDGame` reference.
3. Call `select(candidates, source_position)` with the candidate `Array[CDEntity]` and (for distance-based selectors) the director's `global_position` as `source_position`. The returned array is the selected subset.
4. Call `reset()` to clear the stored game reference.

## How to create a new selector

1. Create a new `.gd` file in this folder named `cd_select_<name>.gd`.
2. Declare a unique class name extending the base:
   ```gdscript
   class_name CDSelect<Name> extends CDSelector
   ```
3. Add `@export` properties for any configuration (count, keys, group names, flags, etc.).
4. Override `select`:
   ```gdscript
   func select(candidates: Array[CDEntity], source_position: Vector2 = Vector2.ZERO) -> Array[CDEntity]:
   ```
   - Use `_game` (set by `initialize`) when you need the blackboard, group registry, or signal-emitter registry.
   - Use `source_position` for any distance-based logic.
   - Return an `Array[CDEntity]` containing only the entities you want selected. Returning `candidates` unchanged is a valid pass-through behavior.
5. Guard against empty inputs and null/invalid references before indexing — the existing selectors all check `candidates.is_empty()` or validity before operating.

### Selector behavior summary

| Selector | Uses `_game` | Uses `source_position` | Behavior |
| --- | --- | --- | --- |
| `CDSelectAll` | No | No | Returns all candidates |
| `CDSelectByKey` | Yes (blackboard) | No | Returns the entity at a blackboard key, if valid and present |
| `CDSelectN` | No | No | Returns the first N candidates |
| `CDSelectNearestN` | No | Yes | Returns N nearest to `source_position` |
| `CDSelectNearestNToGroup` | Yes (group registry) | No | Returns N nearest to the nearest entity in `target_group` |
| `CDSelectRandomN` | No | No | Returns N random candidates without replacement |
| `CDSelectSignalEmitter` | Yes (signal registry) | No | Returns only candidates that emitted the signal this frame |