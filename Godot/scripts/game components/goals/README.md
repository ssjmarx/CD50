# Goals

Win/lose logic for a game. A **goal** is a `CDGameComponent` that watches one
specific kind of game state (entity group counts, a blackboard score value, or
arbitrary game-bus signals) and, when its condition is met, writes a result to
the game blackboard and fires game-bus signals that other systems (e.g. an
orchestrator) can react to.

This folder contains three goal implementations:

| Script | Watches | Fires when |
| --- | --- | --- |
| `group_count_goal.gd` | `game.group_registry` entity counts | one/all monitored groups satisfy a count comparison |
| `score_threshold_goal.gd` | an `int` on `game.blackboard` | the score crosses a threshold |
| `signal_goal.gd` | game-bus signals | any of its `trigger_signals` fires |

## The goal contract

All three goals follow the same shape. When their condition is met they:

1. Early-out if `game.current_state == CDEnums.GameState.GAME_OVER`.
2. Write their configured `game_result` (`CDEnums.GameResult`) to
   `game.blackboard` under their `result_key` (default `&"game_result"`).
3. Call `game.bus_emit(sig)` for every signal name in their
   `on_condition_met` array (informational signals).
4. Call `game.bus_emit(sig)` for every signal name in their
   `end_game_signals` array (terminator signals, e.g. `&"game_over"`).

So a goal is configured by four shared exports:

- `game_result: CDEnums.GameResult` — result written on success (e.g.
  `VICTORY`, `DEFEAT`).
- `result_key: StringName` — blackboard key the result is written under.
- `on_condition_met: Array[StringName]` — **informational** game-bus signals
  emitted on success (default `[&"goal_reached"]`). These tell other systems a
  goal fired but do not by themselves terminate the game.
- `end_game_signals: Array[StringName]` — **terminator** game-bus signals
  emitted on success (e.g. `&"game_over"`, which the orchestrator listens for
  to end the session). Kept separate from `on_condition_met` so informational
  vs terminator intent is explicit per goal.

  > Why two arrays instead of one? Before the split, goals mixed the two
  > semantics in a single `on_condition_met`, which caused `SignalGoal` to
  > default to `[&"game_over"]` (terminator) while its siblings defaulted to
  > `[&"goal_reached"]` (informational) — the same field meant different
  > things per goal. The split makes both intents first-class.

  > **Defaults shape — pick the one that matches your intent.** The three
  > goals ship with **two** default "shapes", and this is intentional but
  > asymmetric, so be aware which you are copying:
  >
  > | Shape | `game_result` | `end_game_signals` | Used by | Intent |
  > | --- | --- | --- | --- | --- |
  > | **Victory / opt-in terminator** | `VICTORY` | `[]` | `GroupCountGoal`, `ScoreThresholdGoal` | "the player achieved something" — does *not* end the game unless a designer adds `&"game_over"` |
  > | **Defeat / always-terminator** | `DEFEAT` | `[&"game_over"]` | `SignalGoal` | "a trigger means the player lost and the game ends now" |
  >
  > When adding a new goal, choose the shape that matches the *default* intent.
  > Rule of thumb: failure triggers (player died, enemies reached the bottom)
  > → the `DEFEAT` / `[&"game_over"]` shape; success triggers (score reached,
  > area cleared) → the `VICTORY` / `[]` shape and let the scene opt into
  > termination. Both are only defaults — every field is overridable in the
  > inspector.

All three override `_on_initialize()` (a base-class lifecycle hook) to wire up
their inputs: connecting to a registry, the game bus, or a blackboard signal.
All three also override `_ready()` to set
`component_category = CDEnums.ComponentCategory.RULES` before `super._ready()`.

## Shared infrastructure these scripts reference

None of the following are defined in this folder — they come from the base
class (`CDGameComponent`) and the wider project. They are mentioned here only
because the goal scripts depend on them:

- `game` — the game node the component belongs to.
- `game.blackboard` — `Dictionary` of shared game state that goals read/write.
- `game.current_state` — current `CDEnums.GameState` (goals check for
  `GAME_OVER`).
- `game.group_registry` — tracks entity counts per `StringName` group; exposes
  `group_count_changed(group_name, count)` signal and `get_count(group)`.
- `game.bus_connect(name, callable)` / `game.bus_emit(name)` — the game's
  string-keyed signal bus.
- `CDEnums.GameResult`, `CDEnums.GameState`, `CDEnums.CountComparison`,
  `CDEnums.ComponentCategory`, and `CDEnums.compare(observed, target, op)`.
- `_on_initialize()` — base-class lifecycle hook used instead of `_ready()` for
  setup that needs `game`/the bus to be available.

### `CDEnums.compare(observed, target, op)`

A single static helper on `CDEnums` that evaluates an `observed` value against
a `target` using a `CountComparison` operator (`LESS_THAN`, `EQUAL_TO`,
`GREATER_THAN`, `LESS_OR_EQUAL`, `GREATER_OR_EQUAL`). Both numeric goals keep a
thin private `_compare(observed)` wrapper that binds the goal's own
`target_count`/`threshold` and `comparison`, then delegates to
`CDEnums.compare`. **Do not re-implement the match block** — call
`CDEnums.compare` so the operator vocabulary stays in one place.

---

## `group_count_goal.gd` — `GroupCountGoal`

Monitors one or more entity groups via `game.group_registry` and fires when
their counts match a comparison. Supports AND/OR logic across groups.

### Exports

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `target_groups` | `Array[StringName]` | `[&"enemies"]` | groups whose counts are watched |
| `comparison` | `CDEnums.CountComparison` | `EQUAL_TO` | operator applied to each group's count |
| `target_count` | `int` | `0` | value each count is compared against |
| `require_all_groups` | `bool` | `true` | `true` = ALL groups must match, `false` = ANY |
| `count_key_suffix` | `StringName` | `&"_count"` | appended to a group name to form the blackboard count key |
| `game_result` | `CDEnums.GameResult` | `VICTORY` | result written on success |
| `result_key` | `StringName` | `&"game_result"` | blackboard key for the result |
| `on_condition_met` | `Array[StringName]` | `[&"goal_reached"]` | informational signals emitted on success |
| `on_count_changed` | `Array[StringName]` | `[&"enemies_count_changed"]` | signals emitted whenever a watched count changes |

### Behavior

- `_ready()` sets `component_category = CDEnums.ComponentCategory.RULES` then
  calls `super._ready()`.
- `_on_initialize()` connects directly to
  `game.group_registry.group_count_changed`.
- On every count change for a watched group, the handler:
  1. Ignores the event if the group isn't in `target_groups` or the game is over.
  2. Writes the new count to `game.blackboard` under
     `StringName(group_name + count_key_suffix)` (e.g. `enemies_count`).
  3. Emits every signal in `on_count_changed`.
  4. Calls `_check_condition()`; if it passes, runs the standard goal contract
     (write `game_result`, emit `on_condition_met`, emit `end_game_signals`).
- `_check_condition()` loops `target_groups` and ANDs (`require_all_groups =
  true`) or ORs (`false`) the result of `_compare(get_count(g))`.
- `_compare(observed)` is a thin wrapper that returns
  `CDEnums.compare(observed, target_count, comparison)`.

### Notes

- Example use case from the header comment: "kill all enemies" — set
  `target_groups = [&"enemies"]`, `comparison = EQUAL_TO`, `target_count = 0`,
  and add `&"game_over"` to `end_game_signals`.

---

## `score_threshold_goal.gd` — `ScoreThresholdGoal`

Monitors an `int` score value on `game.blackboard` and fires when it crosses a
threshold.

### Exports

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `threshold` | `int` | `10000` | value the score is compared against |
| `comparison` | `CDEnums.CountComparison` | `GREATER_OR_EQUAL` | operator applied to the score |
| `score_key` | `StringName` | `&"current_score"` | blackboard key to read the score from |
| `game_result` | `CDEnums.GameResult` | `VICTORY` | result written on success |
| `result_key` | `StringName` | `&"game_result"` | blackboard key for the result |
| `on_score_changed` | `Array[StringName]` | `[&"score_changed"]` | bus signals that mean "score updated" |
| `on_condition_met` | `Array[StringName]` | `[&"goal_reached"]` | informational signals emitted on success |

### Behavior

- `_ready()` sets `component_category = CDEnums.ComponentCategory.RULES` then
  calls `super._ready()`.
- `_on_initialize()` connects every signal in `on_score_changed` (via
  `bus_connect`) to `_on_score_updated`.
- `_on_score_updated()` is zero-argument: it reads `game.blackboard.get(score_key, 0)`,
  compares it with `_compare()`, and on success runs the standard goal contract.
- `_compare(observed)` is a thin wrapper that returns
  `CDEnums.compare(observed, threshold, comparison)`.

### Notes

- The score source is decoupled: this goal never computes a score, it only
  reads whatever the blackboard has under `score_key` when a
  `score_changed`-style signal fires. Whatever system updates the score is
  responsible for also emitting one of the signals listed in `on_score_changed`.

---

## `signal_goal.gd` — `SignalGoal`

The simplest goal: listens for game-bus signals and fires immediately, with no
numeric condition. Use it as a direct signal → result bridge.

### Exports

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `trigger_signals` | `Array[StringName]` | `[]` | bus signals that fire the goal |
| `game_result` | `CDEnums.GameResult` | `DEFEAT` | result written on success |
| `result_key` | `StringName` | `&"game_result"` | blackboard key for the result |
| `on_condition_met` | `Array[StringName]` | `[&"goal_reached"]` | informational signals emitted on success |
| `end_game_signals` | `Array[StringName]` | `[&"game_over"]` | terminator signals emitted on success |

### Behavior

- `_ready()` sets `component_category = CDEnums.ComponentCategory.RULES` then
  calls `super._ready()`.
- `_on_initialize()` connects every signal in `trigger_signals` via the
  inherited `connect_all(trigger_signals, _on_signal_received)` (tracked for
  auto-disconnect on `_exit_tree`).
- `_on_signal_received()` early-outs on `GAME_OVER`, then runs the standard
  goal contract (write `game_result`, emit `on_condition_met`, emit
  `end_game_signals`). There is **no** `_compare` / threshold logic.

### Notes

- Default `game_result` is `DEFEAT` and default `end_game_signals` already
  contains `&"game_over"`, so the out-of-the-box intent is "a trigger signal
  means the player lost and the game should end." (Sibling goals leave
  `end_game_signals` empty by default, so they don't end the game unless you
  opt in.)
- Header comment example: invaders reach the bottom → a Mark emits
  `"end_game"` → this goal writes `DEFEAT` and emits `"game_over"`.

---

## How to create a new goal script

These are the patterns the existing three goals actually use. Mirror them so
the new goal integrates with the bus/blackboard the same way.

1. **Create `Godot/scripts/game components/goals/<name>_goal.gd`.**
2. **Declare a class and base:**
   ```gdscript
   class_name MyGoal extends CDGameComponent
   ```
3. **Set the component category in `_ready()` before `super._ready()`:**
   ```gdscript
   func _ready() -> void:
       component_category = CDEnums.ComponentCategory.RULES
       super._ready()
   ```
   All goals advertise `RULES` so the processing order is deterministic.
4. **Add the standard "fire the goal" exports** (copy from any existing goal):
   ```gdscript
   @export_group("Game Result")
   @export var game_result: CDEnums.GameResult = CDEnums.GameResult.VICTORY
   @export var result_key: StringName = &"game_result"

   @export_group("Emit Signals")
   ## informational signals — emitted on success but do not end the game
   @export var on_condition_met: Array[StringName] = [&"goal_reached"]
   ## terminator signals — emitted on success to end the game (e.g. game_over)
   @export var end_game_signals: Array[StringName] = []
   ```
   Leave `end_game_signals` empty unless this goal should terminate the session
   out-of-the-box; designers add `&"game_over"` when they want that.
5. **Add the exports your goal specifically needs** to describe its trigger
   condition (a threshold, a set of signals, a list of groups, etc.).
6. **Override `_on_initialize()`** to connect whatever your trigger source is:
   - For an array of game-bus signals, prefer the inherited
     `connect_all(signals, handler)` (tracked for auto-disconnect) — see
     `SignalGoal`. For a single signal or non-array source, `bus_connect(...)` /
     `game.bus_connect(...)` still work.
   - For registry/typed signals, connect directly
     (see `GroupCountGoal` → `game.group_registry.group_count_changed`).
7. **In your handler, run the standard contract:**
   ```gdscript
   if game.current_state == CDEnums.GameState.GAME_OVER:
       return
   # ...evaluate your condition...
   if condition_met:
       game.blackboard[result_key] = game_result
       for sig in on_condition_met:
           game.bus_emit(sig)
       for sig in end_game_signals:
           game.bus_emit(sig)
   ```
8. **If the goal uses a numeric comparison**, delegate to the shared helper —
   do **not** copy a `match` block:
   ```gdscript
   func _compare(observed: int) -> bool:
       return CDEnums.compare(observed, threshold, comparison)
   ```
   This keeps the `CDEnums.CountComparison` operator vocabulary in one place.

### Conventions observed in this folder

- **Naming:** files and classes end in `_goal`.
- **Component category:** every goal sets
  `component_category = ComponentCategory.RULES` in `_ready()`.
- **Game-over guard:** every signal handler early-returns on
  `GameState.GAME_OVER` so a goal can't re-fire after the game has ended.
- **Bus signals are zero-argument:** handlers connected via `bus_connect` /
  `game.bus_connect` take no args (`_on_score_updated`, `_on_signal_received`).
  `GroupCountGoal` is the exception only because it connects to a typed
  registry signal (`group_count_changed(group_name, count)`) rather than the
  string bus.
- **Informational vs terminator:** `on_condition_met` carries informational
  signals (e.g. `goal_reached`); `end_game_signals` carries terminator signals
  (e.g. `game_over`). The bus signal `game_over` is the convention for
  terminating the current game — add it to `end_game_signals`, not
  `on_condition_met`.
- **Shared comparison:** numeric goals call `CDEnums.compare(...)` rather than
  re-implementing the operator `match`.