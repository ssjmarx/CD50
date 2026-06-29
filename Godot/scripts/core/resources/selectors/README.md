# Selectors

`CDSelector` resources take a list of candidate `CDEntity` objects and return a subset. They are `Resource`s — configured in the inspector, shared, and reusable.

## Files

| Class | Uses `_game` | Uses `source_position` | Behavior |
|-------|--------------|------------------------|----------|
| `CDSelector` | Yes (cached) | Optional | Abstract base |
| `CDSelectAll` | No | No | Pass-through — returns all candidates |
| `CDSelectByKey` | Yes (blackboard) | No | Returns the entity at a blackboard key, if valid and present |
| `CDSelectN` | No | No | First N candidates in order |
| `CDSelectNearestN` | No | Yes | N nearest to `source_position` |
| `CDSelectNearestNToGroup` | Yes (group registry) | No | N nearest to the nearest entity in `target_group` |
| `CDSelectRandomN` | No | No | N random candidates without replacement |
| `CDSelectSignalEmitter` | Yes (signal registry) | No | Only candidates that emitted the signal this frame |

---

## Patterns

### 1. Base class contract
`CDSelector` is abstract (`class_name CDSelector extends Resource`).
```gdscript
func initialize(game: CDGame) -> void          # caches _game; some subclasses need blackboard/group/signal registry
func select(candidates: Array[CDEntity], source_position: Vector2 = Vector2.ZERO) -> Array[CDEntity]
func reset() -> void                            # clears _game
```
`select()` returns `candidates` unchanged in the base; subclasses override it. `source_position` is the caller's `global_position` (e.g. the director's) and is consumed by distance-based selectors.

### 2. One file per selector, one override
Each selector is its own `cd_select_<name>.gd`, `class_name CDSelect<Name> extends CDSelector`, exposing `@export` config and overriding only `select()`.

### 3. Two dependency flavors
- **Game-aware** selectors cache `_game` (set by `initialize`) and read `blackboard`, `group_registry`, or `_signal_emitters` from it.
- **Standalone** selectors ignore `_game` entirely.

### 4. Defensive inputs
Every selector guards against empty `candidates` and null/invalid references before indexing. Returning `candidates` unchanged is a valid pass-through.

---

## How to create a new selector

```gdscript
## CDSelect<Name>
## <one-line description>

class_name CDSelect<Name> extends CDSelector

@export var count: int = 1

func select(candidates: Array[CDEntity], source_position: Vector2 = Vector2.ZERO) -> Array[CDEntity]:
    if candidates.is_empty():
        return []
    # ...filter/sort candidates, using _game and/or source_position as needed...
    return result
```

### Checklist

- [ ] Filename `cd_select_<name>.gd`; `class_name CDSelect<Name> extends CDSelector`.
- [ ] `##` header docstring.
- [ ] `@export` config fields, each with a `##` comment.
- [ ] Override `select(candidates, source_position) -> Array[CDEntity]`.
- [ ] Use `_game` (set by `initialize`) for blackboard/group/signal registry access; use `source_position` for distance logic.
- [ ] Guard against empty `candidates` and null/invalid references before indexing.
- [ ] Override `reset()` if you add state beyond `_game`.