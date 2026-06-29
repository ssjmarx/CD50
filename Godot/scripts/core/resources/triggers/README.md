# Triggers — State Machine Transition Triggers

`CDTrigger` resources used as state machine transition triggers. Each is a `Resource` subclass configured in the inspector and evaluated each frame.

## Files

| Class | Flavor | Fires when |
|-------|--------|------------|
| `CDTrigger` | Abstract base | (never) |
| `CDSignalTrigger` | Event | One or more named game-bus signals fire |
| `CDTimerTrigger` | Event | `interval` (+ optional `CDScaler` + jitter) elapses |
| `CDGroupCountTrigger` | Evaluative | A group count vs `threshold` comparison becomes true (rising edge) |
| `CDCompositeTrigger` | Composite | AND/OR of child triggers, separating evaluative vs event children |

---

## Patterns

### 1. Two flavors via `is_evaluative`
- **Event** (`is_evaluative = false`, default) — moment-based; checked via `evaluate(delta)`. Evaluation may *consume* the event (`CDSignalTrigger` clears its fired flag after returning `true`).
- **Evaluative** (`is_evaluative = true`) — continuous condition checked via `is_condition_met()`. `CDCompositeTrigger` treats these as "cheap" and never consumes them. (`CDGroupCountTrigger` sets this in `_init()`.)

### 2. Lifecycle contract (inherited from `CDTrigger`)
```gdscript
func initialize(game: CDGame) -> void       # cache _game; subclass setup (connect signals, seed timers, init children)
func evaluate(delta: float) -> bool          # True when the trigger fires THIS frame (base returns false)
func is_condition_met() -> bool              # Evaluative only: raw current condition (base returns false)
func reset() -> void                         # Clear state; clear _game (subclass clears first, then super)
```

### 3. `_game` is the only injected dependency
Through `_game`, triggers reach `bus_connect`/`bus_disconnect` and `group_registry.get_count(...)`. No other global lookups.

### 4. Edge detection vs one-shot consumption
Pick one and be deliberate:
- `CDSignalTrigger` — `evaluate()` consumes: returns `true` once, then resets.
- `CDGroupCountTrigger` — `evaluate()` uses rising-edge detection (`currently_met and not _was_met`); sustained-true does not re-fire.

### 5. Composite ordering
`CDCompositeTrigger` checks **evaluative children first** (`is_condition_met`), then event children (`evaluate`). This is intentional — event evaluation can consume the event.

---

## How to create a new trigger

```gdscript
## CD<Name>Trigger
## One-line description

class_name CD<Name>Trigger extends CDTrigger

@export var some_key: StringName = &""

func _init() -> void:
    is_evaluative = true   # only for evaluative triggers

func initialize(game: CDGame) -> void:
    super.initialize(game)
    # ...your setup (connect signals, seed timers, init child resources)...

func evaluate(delta: float) -> bool:
    # event triggers: return true on the fire frame (consume or edge-detect as appropriate)
    return false

func is_condition_met() -> bool:
    # evaluative triggers only: raw condition for composites
    return false

func reset() -> void:
    # clear your state first
    super.reset()
```

### Checklist

- [ ] Filename `cd_<name>_trigger.gd`; `class_name CD<Name>Trigger extends CDTrigger`.
- [ ] Two-line `##` header (title + one-line description).
- [ ] Decide flavor: set `is_evaluative = true` in `_init()` for continuous conditions, else leave default.
- [ ] Use typed `@export` fields (`Array[StringName]`, `CDEnums` enums, optional sub-resources like `CDScaler`).
- [ ] Implement `initialize(game)` (call `super` first), `evaluate(delta)`, and — for evaluative triggers — `is_condition_met()`.
- [ ] Be deliberate about consume-vs-edge semantics in `evaluate()`.
- [ ] `reset()` clears your state first, then `super.reset()`.
- [ ] Access game systems only through `_game`.