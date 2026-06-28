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
   `on_condition_met` array.

So a goal is configured by three shared exports:

- `game_result: CDEnums.GameResult` — result written on success (e.g.
  `VICTORY`, `DEFEAT`).
- `result_key: StringName` — blackboard key the result is written under.
- `on_condition_met: Array[StringName]` — game-bus signals emitted on success.
  **Add `&"game_over"` here to make the goal actually end the game** (the
  comments in each script call this out explicitly).

All three override `_on_initialize()` (a base-class lifecycle hook) to wire up
their inputs: connecting to a registry, the game bus, or a blackboard signal.

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
  `CDEnums.ComponentCategory`.
- `_on_initialize()` — base-class lifecycle hook used instead of `_ready()` for
  setup that needs `game`/the bus to be available.

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
| `on_condition_met` | `Array[StringName]` | `[&"goal_reached"]` | signals emitted on success |
| `on_count_changed` | `Array[StringName]` | `[&"enemies_count_changed"]` | signals emitted whenever a watched count changes |

### Behavior

- `_on_initialize()` connects directly to
  `game.group_registry.group_count_changed`.
- On every count change for a watched group, the handler:
  1. Ignores the event if the group isn't in `target_groups` or the game is over.
  2. Writes the new count to `game.blackboard` under
     `StringName(group_name + count_key_suffix)` (e.g. `enemies_count`).
  3. Emits every signal in `on_count_changed`.
  4. Calls `_check_condition()`; if it passes, runs the standard goal contract
     (write `game_result`, emit `on_condition_met`).
- `_check_condition()` loops `target_groups` and ANDs (`require_all_groups =
  true`) or ORs (`false`) the result of `_compare(get_count(g))`.
- `_compare(observed)` is a `match` over `CDEnums.CountComparison`
  (`LESS_THAN`, `EQUAL_TO`, `GREATER_THAN`, `LESS_OR_EQUAL`,
  `GREATER_OR_EQUAL`).

### Notes

- Does **not** override `_ready()` and does not set `component_category`.
- Example use case from the header comment: "kill all enemies" — set
  `target_groups = [&"enemies"]`, `comparison = EQUAL_TO`, `target_count = 0`,
  and add `&"game_over"` to `on_condition_met`.

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
| `on_condition_met` | `Array[StringName]` | `[&"goal_reached"]` | signals emitted on success |

### Behavior

- `_ready()` sets `component_category = CDEnums.ComponentCategory.RULES` and
  calls `super._ready()` — **this is the only goal in this folder that sets a
  component category.**
- `_on_initialize()` connects every signal in `on_score_changed` (via
  `bus_connect`) to `_on_score_updated`.
- `_on_score_updated()` is zero-argument: it reads `game.blackboard.get(score_key, 0)`,
  compares it with `_compare()`, and on success runs the standard goal contract.
- `_compare(observed)` is the same `CDEnums.CountComparison` `match` block used
  by `GroupCountGoal` (but against `threshold` instead of `target_count`).

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
| `on_condition_met` | `Array[StringName]` | `[&"game_over"]` | signals emitted on success |

### Behavior

- `_on_initialize()` connects every signal in `trigger_signals` (via
  `game.bus_connect`) to `_on_signal_received`.
- `_on_signal_received()` early-outs on `GAME_OVER`, then runs the standard
  goal contract (write `game_result`, emit `on_condition_met`). There is **no**
  `_compare` / threshold logic.

### Notes

- Default `game_result` is `DEFEAT` and default `on_condition_met` already
  contains `&"game_over"`, so the out-of-the-box intent is "a trigger signal
  means the player lost and the game should end."
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
3. **Add the standard "fire the goal" exports** (copy from any existing goal):
   ```gdscript
   @export_group("Game Result")
   @export var game_result: CDEnums.GameResult = CDEnums.GameResult.VICTORY
   @export var result_key: StringName = &"game_result"

   @export_group("Emit Signals")
   @export var on_condition_met: Array[StringName] = [&"goal_reached"]
   ```
4. **Add the exports your goal specifically needs** to describe its trigger
   condition (a threshold, a set of signals, a list of groups, etc.).
5. **Override `_on_initialize()`** to connect whatever your trigger source is:
   - For game-bus signals, use `bus_connect(sig, handler)` /
     `game.bus_connect(sig, handler)` (see `ScoreThresholdGoal`,
     `SignalGoal`).
   - For registry/typed signals, connect directly
     (see `GroupCountGoal` → `game.group_registry.group_count_changed`).
6. **In your handler, run the standard contract:**
   ```gdscript
   if game.current_state == CDEnums.GameState.GAME_OVER:
       return
   # ...evaluate your condition...
   if condition_met:
       game.blackboard[result_key] = game_result
       for sig in on_condition_met:
           game.bus_emit(sig)
   ```
7. **If the goal uses a numeric comparison**, copy the `_compare(observed)` +
   `CDEnums.CountComparison` `match` pattern from
   `group_count_goal.gd` / `score_threshold_goal.gd` verbatim — it keeps the
   operator vocabulary consistent across goals.
8. **(Optional) Set a component category** in `_ready()` before
   `super._ready()` if your goal should advertise one — `ScoreThresholdGoal`
   does this with `ComponentCategory.RULES`. The other two goals currently
   leave `component_category` unset, so this is not required.

### Conventions observed in this folder

- **Naming:** files and classes end in `_goal`.
- **Game-over guard:** every signal handler early-returns on
  `GameState.GAME_OVER` so a goal can't re-fire after the game has ended.
- **Bus signals are zero-argument:** handlers connected via `bus_connect` /
  `game.bus_connect` take no args (`_on_score_updated`, `_on_signal_received`).
  `GroupCountGoal` is the exception only because it connects to a typed
  registry signal (`group_count_changed(group_name, count)`) rather than the
  string bus.
- **"Add `&"game_over"` to actually end the game"** — documented in the header
  comments of `group_count_goal.gd` and `score_threshold_goal.gd`. The bus
  signal `game_over` is the convention for terminating the current game.