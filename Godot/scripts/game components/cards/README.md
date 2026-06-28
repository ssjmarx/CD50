# Cards

This folder contains **Card** scripts. A Card is a `CDCueCard` subclass that owns one piece of tracked game state (a score, a life count, a timer, a wave number, a capture tally, etc.) and is responsible for:

1. Holding that state in instance variables.
2. Publishing the current value to the **Game Blackboard** under a configurable key.
3. Listening to the **Game Bus** for the signals that should mutate that state.
4. Emitting **Game Bus** signals when the value changes.
5. Mirroring the value onto a label (the inherited `_update_label()` from `CDCueCard`).

Cards do **not** decide *why* their state changes — they react to signals and write results back out. Other systems (arms, guts, spawners, stage controllers) are the ones that fire the listen signals.

Every script here declares `class_name`, so it is exposed to the editor and can be attached to a node directly.

---

## Shared patterns (observed across the files)

The five cards in this folder are not identical, but they share a consistent skeleton. When reading or extending them, keep the following in mind.

### Base class

All cards extend `CDCueCard`:

```gdscript
class_name XxxCard extends CDCueCard
```

`CDCueCard` is not in this folder; it provides at least:
- `_update_label(text: String)` — writes the supplied text onto the card's internal label.
- `_publish_tracked(key: StringName, value)` — writes a value into the Game Blackboard.
- `_consume_pending(key: StringName, default)` — reads *and clears* a pending value from the blackboard, returning `default` if absent (used by `ScoreCard`).
- A `game` reference exposing `game.blackboard`, `game.bus_connect()`, `game.bus_emit()`, and `game._signal_emitters`.

### `@export` groups

Most cards organize their exports into the following groups, which appear in the inspector:

- **Blackboard Keys** — `StringName` keys the card publishes to or reads from.
- **Listen Signals** — `Array[StringName]` of Game Bus signals the card subscribes to.
- **Emit Signals** — `Array[StringName]` of Game Bus signals the card fires when its state changes.

`StringName` literals are written with the `&"..."` syntax.

### Lifecycle

The cards follow this `_ready()` shape:

```gdscript
func _ready() -> void:
    super._ready()
    current_value = starting_value
    _update_label(...)           # immediate first paint
    call_deferred("_on_initialize")
```

Initialization that touches the Game Bus / Blackboard is deferred to `_on_initialize()` so the game structure is ready by the time it runs. A typical `_on_initialize()`:

```gdscript
func _on_initialize() -> void:
    _publish_tracked(value_key, current_value)
    for sig in listen_signals:
        game.bus_connect(sig, _handler)
```

### Reacting to signals

Signal handlers in these cards always do the same three things, in order:

1. Mutate the internal state.
2. `_update_label(...)` so the UI reflects the new value.
3. `_publish_tracked(key, value)` so the blackboard reflects the new value.
4. Loop over the relevant `on_*_changed` arrays and `game.bus_emit(sig)` each one.

Listening and emitting are both done over the **Game Bus**, not Godot's direct `connect`/`emit` between nodes. The only exception is `CaptureCard`, which additionally connects directly to a `CDEntity`'s `entity_deactivating` signal for cleanup (see below).

---

## Files

### `capture_card.gd` — `CaptureCard`

Tracks how many entities are currently captured at the game level and keeps that count in the blackboard. Unlike the other cards, it does **not** follow the export-grouped `Array[StringName]` listen/emit pattern — it uses single `StringName` exports instead.

**Exports**

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `listen_signal` | `StringName` | `&"player_captured"` | Game Bus signal fired when an entity is captured (requires an `AnnouncerGuts` on the captured entity). |
| `rescue_signal` | `StringName` | `&"player_rescued"` | Game Bus signal fired when an entity is rescued. Left empty to disable rescue handling. |
| `count_key` | `StringName` | `&"active_capture_count"` | Blackboard key holding the current number of active captures. |
| `blackboard_source_key` | `StringName` | `&"captured_entity"` | Blackboard key the capturing arm writes the captured entity reference to. Must match the `target_blackboard_key` in `CaptureOnHitArm`. |

**State**

- `_captured_entities: Array[CDEntity]` — the list of currently tracked captured entities.

**Behavior**

- On initialize, sets `blackboard[count_key] = 0`, connects `listen_signal` to `_on_capture_event`, and (if non-empty) connects `rescue_signal` to `_on_rescue_event`.
- On a capture event, reads the captured `CDEntity` from `game.blackboard.get(blackboard_source_key)`, validates it, guards against duplicates, appends it to `_captured_entities`, and **connects directly** to that entity's `entity_deactivating` signal (using a string-based `connect()` with `.bind(captured_entity)`) so the count is decremented if the entity dies.
- On a rescue event, reads the rescued entity from `game._signal_emitters[rescue_signal]`, erases it from the list, and disconnects the death handler.
- On `entity_deactivating` of a tracked entity, erases it from the list.
- After any of the above, `_update_count()` recomputes `count = _captured_entities.size()`, writes it to `blackboard[count_key]`, and calls `_update_label("CAPTURE: %d" % count)`.

### `lives_card.gd` — `LivesCard`

Tracks player lives and emits zero-arg changed/depleted signals.

**Exports**

| Group | Export | Type | Default |
| --- | --- | --- | --- |
| — | `starting_lives` | `int` | `3` |
| Blackboard Keys | `lives_key` | `StringName` | `&"current_lives"` |
| Listen Signals | `on_life_lost` | `Array[StringName]` | `[&"life_lost"]` |
| Listen Signals | `on_life_gained` | `Array[StringName]` | `[&"life_gained"]` |
| Emit Signals | `on_lives_changed` | `Array[StringName]` | `[&"lives_changed"]` |
| Emit Signals | `on_lives_depleted` | `Array[StringName]` | `[&"lives_depleted"]` |

**State**

- `current_lives: int`

**Behavior**

- On `_on_initialize`, publishes `current_lives` to `lives_key`, and connects every signal in `on_life_lost` / `on_life_gained` to its handler.
- `_on_life_lost` decrements `current_lives`, updates the label and blackboard, emits every `on_lives_changed` signal, and — if the count has reached `0` or below — also emits every `on_lives_depleted` signal.
- `_on_life_gained` increments `current_lives`, updates the label and blackboard, and emits `on_lives_changed`. It does **not** check for depletion.

### `score_card.gd` — `ScoreCard`

Tracks score with an optional multiplier. The multiplier is applied on **add**, not on **set**. Producers do not call the card directly — they write a pending delta/value to the blackboard, then fire a trigger signal that the card consumes.

**Exports**

| Group | Export | Type | Default |
| --- | --- | --- | --- |
| — | `starting_score` | `int` | `0` |
| — | `starting_multiplier` | `float` | `1.0` |
| Blackboard Keys | `pending_add_key` | `StringName` | `&"pending_score_add"` |
| Blackboard Keys | `pending_set_key` | `StringName` | `&"pending_score_set"` |
| Blackboard Keys | `score_key` | `StringName` | `&"current_score"` |
| Blackboard Keys | `pending_mult_add_key` | `StringName` | `&"pending_mult_add"` |
| Blackboard Keys | `pending_mult_set_key` | `StringName` | `&"pending_mult_set"` |
| Blackboard Keys | `multiplier_key` | `StringName` | `&"current_multiplier"` |
| Listen Signals | `on_add_score` | `Array[StringName]` | `[&"add_score"]` |
| Listen Signals | `on_set_score` | `Array[StringName]` | `[&"set_score"]` |
| Listen Signals | `on_add_multiplier` | `Array[StringName]` | `[]` |
| Listen Signals | `on_set_multiplier` | `Array[StringName]` | `[]` |
| Emit Signals | `on_score_changed` | `Array[StringName]` | `[&"score_changed"]` |
| Emit Signals | `on_multiplier_changed` | `Array[StringName]` | `[&"multiplier_changed"]` |

**State**

- `current_score: int`
- `current_multiplier: float` (initialized to `1.0` as a typed default, then overwritten with `starting_multiplier` in `_ready()`)

**Behavior**

- On `_on_initialize`, publishes both `score_key` and `multiplier_key`, and connects each of the four listen arrays to its handler (empty arrays are no-ops).
- `_on_add_score` reads `int(_consume_pending(pending_add_key, 0))`. If the delta is `0` it returns early. Otherwise it adds `int(delta * current_multiplier)` to the score, updates label/blackboard, and emits `on_score_changed`.
- `_on_set_score` reads `_consume_pending(pending_set_key, current_score)` and assigns it directly (the multiplier is **not** applied on set).
- `_on_add_multiplier` and `_on_set_multiplier` mirror the score handlers for `current_multiplier`, but they do **not** update the label — only the blackboard and `on_multiplier_changed`.

### `timer_card.gd` — `TimerCard`

A countdown or count-up timer that updates its label and emits tick signals on a fixed interval.

**Exports**

| Group | Export | Type | Default |
| --- | --- | --- | --- |
| — | `mode` | `TimerMode` enum (`COUNT_UP`, `COUNT_DOWN`) | `COUNT_DOWN` |
| — | `starting_time` | `float` | `60.0` |
| — | `tick_interval` | `float` | `1.0` |
| Blackboard Keys | `time_key` | `StringName` | `&"current_time"` |
| Listen Signals | `on_timer_pause` | `Array[StringName]` | `[&"timer_pause"]` |
| Listen Signals | `on_timer_resume` | `Array[StringName]` | `[&"timer_resume"]` |
| Listen Signals | `on_timer_reset` | `Array[StringName]` | `[&"timer_reset"]` |
| Emit Signals | `on_timer_tick` | `Array[StringName]` | `[&"timer_tick"]` |
| Emit Signals | `on_timer_expired` | `Array[StringName]` | `[&"timer_expired"]` |

**State**

- `current_time: float`
- `_tick_accumulator: float` — accumulates frame deltas until `tick_interval` is reached.
- `_is_running: bool` — starts `true`.

**Behavior**

- Uses `_physics_process(delta)`, not `_process`. Returns early when `not _is_running`.
- In `COUNT_DOWN`, subtracts `delta` and, on reaching `<= 0.0`, clamps to zero, sets `_is_running = false`, publishes/labels the final value, emits `on_timer_expired`, and returns (no tick that frame).
- In `COUNT_UP`, adds `delta`.
- A tick fires whenever `_tick_accumulator >= tick_interval`; the accumulator is decremented by `tick_interval`, the value is published and labeled, and `on_timer_tick` is emitted.
- `_on_timer_paused` / `_on_timer_resumed` only flip `_is_running`. `_on_timer_reset` restores `starting_time`, zeroes the accumulator, sets `_is_running = true`, publishes, and labels — but does **not** emit a tick or expiry signal.
- Time is formatted as `M:SS` via `_format_time()` using integer division/modulo.

### `wave_card.gd` — `WaveCard`

Tracks the current wave number and relays start/changed signals to spawners.

**Exports**

| Group | Export | Type | Default |
| --- | --- | --- | --- |
| — | `starting_wave` | `int` | `1` |
| Blackboard Keys | `wave_key` | `StringName` | `&"wave_number"` |
| Listen Signals | `on_advance_wave` | `Array[StringName]` | `[&"game_play", &"wave_cleared"]` |
| Listen Signals | `on_reset_wave` | `Array[StringName]` | `[&"wave_reset"]` |
| Emit Signals | `on_wave_start` | `Array[StringName]` | `[&"wave_start"]` |
| Emit Signals | `on_wave_changed` | `Array[StringName]` | `[&"wave_changed"]` |

**State**

- `current_wave: int`

**Behavior**

- `_advance_wave` is the important quirk: it **emits the current wave first, then increments**. So on the first call, listeners receive `starting_wave`; the counter is bumped afterward to set up the next call. It emits both `on_wave_start` and `on_wave_changed`.
- `_reset_wave` sets `current_wave = starting_wave`, updates the label and blackboard, and emits only `on_wave_changed` (not `on_wave_start`).
- Labels are formatted as `"Wave %d"`.

---

## How to use a Card in a scene

1. Attach the card's script to a node (typically a `Label` or a node carrying a `Label` child, since `CDCueCard` provides `_update_label`).
2. In the inspector, set the starting value (`starting_score`, `starting_lives`, `starting_time`, `starting_wave`, etc.).
3. Tweak the **Blackboard Keys** only if another system expects the value under a different name.
4. Populate the **Listen Signals** arrays with the Game Bus signals that should drive this card. Leave entries empty to disable that direction (e.g. `ScoreCard` ships with `on_add_multiplier` empty).
5. Populate the **Emit Signals** arrays with the Game Bus signals other systems should react to.
6. Have other components fire the listen signals. For `ScoreCard` specifically, those components must first write the pending delta/set value to the blackboard under the matching `pending_*_key` before emitting the trigger.

---

## How to create a new Card

Mirror the structure of the existing cards. Concretely:

1. Create `your_card.gd` in this folder.
2. Declare the class and base:
   ```gdscript
   class_name YourCard extends CDCueCard
   ```
3. Declare a starting-value export and a current-value state variable.
4. Add a **Blackboard Keys** export group with a `StringName` key for publishing.
5. Add **Listen Signals** and **Emit Signals** groups as `Array[StringName]` arrays, defaulting to the signals you want to use (use `&"..."` literals; an empty array disables that direction).
6. Implement `_ready()` to call `super._ready()`, seed `current_*` from the starting value, paint the label once, and `call_deferred("_on_initialize")`.
7. Implement `_on_initialize()` to `_publish_tracked(key, value)` and loop over each listen array calling `game.bus_connect(sig, _handler)`.
8. Implement one handler per event. Inside each handler:
   - mutate `current_*`,
   - `_update_label(...)`,
   - `_publish_tracked(key, current_*)`,
   - loop over the matching emit array and `game.bus_emit(sig)`.
9. If your state is driven by pending blackboard deltas rather than direct signals, follow `ScoreCard`'s lead: expose `pending_*_key` exports and call `_consume_pending(key, default)` inside the handler.
10. If you need a `_physics_process` loop (e.g. a timer or anything that ticks), gate it on a `_is_running` flag the way `TimerCard` does.

Stay within the Game Bus for listening and emitting; only drop down to direct Godot `connect()`/`disconnect()` when you must listen to a specific node the way `CaptureCard` listens to `entity_deactivating` on each captured `CDEntity`.