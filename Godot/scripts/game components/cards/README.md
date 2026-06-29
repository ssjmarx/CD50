# Cards — Tracked State Cards

`Cards` are `CDCueCard` subclasses that own one piece of tracked game state (score, lives, timer, wave number, capture tally, etc.). Each card holds the state, publishes it to the **Game Blackboard**, listens to the **Game Bus** for mutations, emits **Game Bus** signals on change, and mirrors the value onto a label.

Cards do **not** decide *why* their state changes — they react to signals and write results back out. Other systems (arms, guts, spawners, stage controllers) fire the listen signals.

## Files

| File | Class | Tracks |
|------|-------|--------|
| `capture_card.gd` | `CaptureCard` | Active capture count (+ tracks captured entities for cleanup) |
| `lives_card.gd` | `LivesCard` | Player lives, emits depleted signal |
| `score_card.gd` | `ScoreCard` | Score + multiplier (multiplier applied on add, not set) |
| `timer_card.gd` | `TimerCard` | Countdown/count-up timer with tick + expired signals |
| `wave_card.gd` | `WaveCard` | Current wave number (emits current wave, then increments) |

---

## Patterns

### 1. Base class `CDCueCard`
All cards extend `CDCueCard`, which provides:
- `_update_label(text)` — writes text onto the card's internal label.
- `_publish_tracked(key, value)` — writes a value into the Game Blackboard.
- `_consume_pending(key, default)` — reads *and clears* a pending blackboard value (used by `ScoreCard`).
- A `game` reference exposing `game.blackboard`, `game.bus_connect()`, `game.bus_emit()`.

### 2. Export groups
```gdscript
@export_group("Blackboard Keys")    # StringName keys to publish to / read from
@export_group("Listen Signals")     # Array[StringName] of Game Bus signals to subscribe to
@export_group("Emit Signals")       # Array[StringName] of Game Bus signals to fire on change
```
`StringName` literals use `&"..."`. An empty emit/listen array disables that direction.

### 3. Two-phase lifecycle
`CDCueCard` extends `CDGameControl`, whose `_ready()` defers `_on_initialize()`. Cards do **not** call `call_deferred` themselves:

```gdscript
func _ready() -> void:
    super._ready()
    current_value = starting_value
    _update_label(...)                      # immediate first paint

func _on_initialize() -> void:
    super._on_initialize()                  # resolves game
    _publish_tracked(value_key, current_value)
    connect_all(listen_signals, _handler)   # inherited; tracked + auto-disconnected on _exit_tree
```

### 4. Handler contract
Every signal handler does the same four things, in order:
1. Mutate internal state.
2. `_update_label(...)` (UI reflects the new value).
3. `_publish_tracked(key, value)` (blackboard reflects the new value).
4. Loop over the relevant `on_*_changed` array and `game.bus_emit(sig)` each one.

Listening and emitting are both over the **Game Bus**. The only exception is `CaptureCard`, which additionally connects directly to a captured `CDEntity`'s `entity_deactivating` for cleanup.

### 5. Pending-delta pattern (`ScoreCard`)
When producers don't call the card directly, they write a pending delta/set value to the blackboard, then fire a trigger signal. The handler reads it with `_consume_pending(key, default)`.

### 6. Physics-driven cards (`TimerCard`)
Cards that tick use `_physics_process(delta)` gated by an `_is_running` flag.

---

## How to create a new card

```gdscript
## MyNewCard
## <one-line description>

class_name MyNewCard extends CDCueCard

@export var starting_value: int = 0

@export_group("Blackboard Keys")
@export var value_key: StringName = &"my_value"

@export_group("Listen Signals")
@export var on_change_signals: Array[StringName] = [&"my_input"]

@export_group("Emit Signals")
@export var on_changed_signals: Array[StringName] = [&"my_changed"]

var current_value: int = 0

func _ready() -> void:
    super._ready()
    current_value = starting_value
    _update_label("MY: %d" % current_value)

func _on_initialize() -> void:
    super._on_initialize()
    _publish_tracked(value_key, current_value)
    connect_all(on_change_signals, _on_change)

func _on_change() -> void:
    current_value += 1
    _update_label("MY: %d" % current_value)
    _publish_tracked(value_key, current_value)
    for sig in on_changed_signals:
        game.bus_emit(sig)
```

### Checklist

- [ ] `class_name …Card extends CDCueCard`.
- [ ] Add a starting-value `@export` and a `current_*` state var.
- [ ] Add `Blackboard Keys` / `Listen Signals` / `Emit Signals` groups (use `&"..."`; empty array = disabled).
- [ ] In `_ready()`: `super._ready()`, seed `current_*`, paint the label once. Do **not** defer `_on_initialize` yourself.
- [ ] In `_on_initialize()`: `super._on_initialize()`, `_publish_tracked(key, value)`, `connect_all(listen_signals, handler)`.
- [ ] Each handler: mutate → `_update_label` → `_publish_tracked` → loop `game.bus_emit`.
- [ ] For delta-driven state, follow `ScoreCard`'s pending-key + `_consume_pending` pattern.
- [ ] For ticking state, use `_physics_process` gated by an `_is_running` flag (see `TimerCard`).
- [ ] Stay on the Game Bus; only drop to direct `connect()`/`disconnect()` when you must track a specific node (see `CaptureCard`).