# Managers

Data-driven game components that evaluate resource-based rules each frame and drive
the game's runtime state (score, signals, stages, entity groups). Each manager is a
`CDGameComponent` subclass tagged as `CDEnums.ComponentCategory.MANAGER` and is
configured almost entirely through exported resource arrays — the script logic itself
is generic; the behavior comes from the data resources plugged into it.

## Files

| File | Class | Resource type | Purpose |
| --- | --- | --- | --- |
| `score_manager.gd` | `ScoreManager` | `CDScoringRule` | Applies score/multiplier deltas via the blackboard and bus signals. |
| `signal_manager.gd` | `SignalManager` | `CDSequenceStep` | Runs a timed sequence of bus signals triggered by one event. |
| `stage_manager.gd` | `StageManager` | `CDStageRule` | Sleeps/wakes sibling `CDStage` nodes in response to triggers. |
| `state_manager.gd` | `StateManager` | `CDTransition` | Moves entities between groups (group-as-state), deferred via `CDUpdater`. |

## Shared structure

Every manager in this folder follows the same lifecycle, which is the defining shape
of a "manager" component in this codebase:

1. **`_ready()`** — sets `component_category = CDEnums.ComponentCategory.MANAGER` and
   calls `super._ready()`. `SignalManager` additionally calls
   `set_physics_process(false)` because it only ticks while a sequence is running.
2. **`_on_initialize()`** — calls `super._on_initialize()` (where present), then
   initializes each configured data resource with the `game` reference (e.g.
   `rule.trigger.initialize(game)`). `StageManager` also builds its `_stage_map`
   here; `StateManager` caches `game.update` here.
3. **`_physics_process(delta)`** — the work loop. Each frame it evaluates the
   triggers on its configured resources and acts on the ones that fire. Details
   differ per manager (see below).
4. **`reset()`** (present on all four managers) — clears runtime state and calls
   `reset()` on each data resource so the manager can be reused on game restart.
   `ScoreManager`'s `reset()` only calls `reset()` on each rule's trigger (it
   holds no accumulated score itself).

Managers interact with the rest of the game through the shared `game` handle,
specifically: `game.blackboard`, `game.bus_emit()` / `game.bus_disconnect()`,
`game.find_children()`, `game.group_registry`, and `game.update` (a `CDUpdater`).

> Note: The data resources these managers consume (`CDScoringRule`, `CDSequenceStep`,
> `CDStageRule`, `CDTransition`, `CDTrigger`, `CDSelector`) and the node types they
> reference (`CDStage`, `CDUpdater`, `CDEntity`) are defined elsewhere. This folder
> contains only the manager scripts themselves.

---

## `ScoreManager` (`score_manager.gd`)

Evaluates an array of `CDScoringRule` resources each frame and, for each rule whose
trigger fires, writes a pending delta to the game blackboard and emits the matching
apply signal on the game bus. This allows complex scoring setups driven entirely by
data.

### Exports

| Export | Type | Default | Notes |
| --- | --- | --- | --- |
| `scoring_rules` | `Array[CDScoringRule]` | `[]` | Rules evaluated every frame. |
| `pending_score_add_key` | `StringName` | `&"pending_score_add"` | Blackboard key for a pending *add* delta (int, consumed on trigger). |
| `pending_score_set_key` | `StringName` | `&"pending_score_set"` | Blackboard key for a pending *set* value (int, consumed on trigger). |
| `pending_mult_add_key` | `StringName` | `&"pending_mult_add"` | Blackboard key for a pending multiplier *add* delta (float, consumed on trigger). |
| `pending_mult_set_key` | `StringName` | `&"pending_mult_set"` | Blackboard key for a pending multiplier *set* value (float, consumed on trigger). |

### How it works

- `_on_initialize()` initializes each rule's `trigger` with `game`.
- `_physics_process()` iterates `scoring_rules`; for any rule with a non-null
  `trigger` that `evaluate(_delta)` returns true for, it calls `_apply_rule(rule)`.
- `_apply_rule()` matches on `rule.emit_signal` (a `StringName`) against four
  literals and does two things each time:
  1. Writes `rule.score_delta` or `rule.multiplier_delta` to the corresponding
     pending blackboard key.
  2. Emits the corresponding game bus signal via `game.bus_emit(...)`.

  The four handled signal names are:
  - `&"add_score"` → writes `pending_score_add_key`, emits `add_score`
  - `&"set_score"` → writes `pending_score_set_key`, emits `set_score`
  - `&"add_multiplier"` → writes `pending_mult_add_key`, emits `add_multiplier`
  - `&"set_multiplier"` → writes `pending_mult_set_key`, emits `set_multiplier`

`reset()` iterates `scoring_rules` and calls `reset()` on any rule that has the
method, clearing per-rule trigger state (cooldowns/timers) for a fresh game.
`ScoreManager` itself holds no accumulated score — the running total lives in the
consumer of its signals (e.g. a `ScoreCard`), which resets itself.

---

## `SignalManager` (`signal_manager.gd`)

A data-driven signal macro: a single `trigger` starts an ordered sequence of
`CDSequenceStep`s. Each step fires a list of game bus signals, optionally waits a
`delay_after`, and optionally waits until a sync signal has fired `wait_count`
times before advancing. When the whole sequence finishes it emits the
`on_sequence_complete` signals.

### Exports

| Export | Type | Default | Notes |
| --- | --- | --- | --- |
| `steps` | `Array[CDSequenceStep]` | `[]` | Ordered steps to execute when the sequence triggers. |
| `trigger` | `CDTrigger` | `null` | What activates the sequence (signal, timer, etc.). |
| `on_sequence_complete` | `Array[StringName]` | `[&"sequence_complete"]` | Game bus signals emitted when the entire sequence finishes. |

### Internal state

- `_current_step` (int, `-1` when not running)
- `_delay_remaining` (float countdown for the current step's `delay_after`)
- `_waiting_for_signal` (bool — true while waiting on a step's sync signal)
- `_signal_fire_count` (int — how many times the sync signal has fired this step)
- `_running` (bool — whether the sequence is actively executing)

### How it works

- `_ready()` calls `set_physics_process(false)` so nothing ticks until a sequence
  starts.
- `_on_initialize()` initializes `trigger` with `game`.
- `_physics_process(delta)`:
  - When not running, polls `trigger.evaluate(delta)`; if it fires, calls
    `_start_sequence()`.
  - When running and **not** waiting for a sync signal, counts `_delay_remaining`
    down by `delta`; when it hits `0`, calls `_advance()`.
- `_execute_step()` (called for the current step):
  1. Fires every signal in `step.signals` (skipping `&""`) via `game.bus_emit(...)`.
  2. Sets `_delay_remaining = step.delay_after`.
  3. If `step.wait_for_signal != &""` and `step.wait_count > 0`, records the count,
     sets `_waiting_for_signal = true`, and connects `_on_sync_signal` to that bus
     signal via `bus_connect(...)`.
  4. If there is no delay and no wait, advances immediately; otherwise enables
     `set_physics_process(true)`.
- `_on_sync_signal()` increments `_signal_fire_count`; when it reaches the current
  step's `wait_count`, it disconnects the listener, clears the wait flag, and — if
  the delay has also expired — calls `_next_step()`.
- `_advance()` is a guard that no-ops while waiting for a sync signal, otherwise
  calls `_next_step()`.
- `_next_step()` increments `_current_step`; if it runs past the end it calls
  `_complete()`, otherwise calls `_execute_step()`.
- `_complete()` stops running, resets `_current_step` to `-1`, disables physics
  processing, and emits every signal in `on_sequence_complete`.

`reset()` defensively disconnects any lingering sync listener, clears all
sequence state, and calls `trigger.reset()` so the manager is ready for a game
restart. `_complete()` likewise calls the same `_disconnect_sync_listener()`
first, so a still-pending sync wait is torn down even if the sequence ends
mid-step.

---

## `StageManager` (`stage_manager.gd`)

Evaluates `CDStageRule` triggers each frame and, when one fires, sleeps/wakes named
sibling `CDStage` nodes and emits the rule's game signals. This replaces
sleep_on/wake_on arrays that used to be embedded directly in `CDStage`.

### Exports

| Export | Type | Default | Notes |
| --- | --- | --- | --- |
| `rules` | `Array[CDStageRule]` | `[]` | Rules defining when to sleep/wake stages and what signals to emit. |

### Internal state

- `_stage_map: Dictionary` — maps a `CDStage` node's `name` to its reference, built
  by scanning the game's children for `CDStage` nodes.

### How it works

- `_on_initialize()`:
  1. Calls `_build_stage_map()`, which does `game.find_children("*", "CDStage")` and
     records each result as `_stage_map[node.name] = node`.
  2. For each rule, if `rule.is_valid()` it calls `rule.initialize(game)`;
     otherwise it pushes a warning naming this node.
- `_physics_process(delta)` iterates `rules`; for any valid rule whose `trigger`
  evaluates true, it calls `_execute_rule(rule)`.
- `_execute_rule(rule)`:
  1. For each name in `rule.sleep_stages`, looks up the `CDStage` in `_stage_map`
     and calls `stage.sleep()`.
  2. For each name in `rule.wake_stages`, looks up the `CDStage` and calls
     `stage.wake()`.
  3. Emits every signal in `rule.game_signals` (skipping `&""`) via
     `game.bus_emit(...)`.

`reset()` calls `reset()` on every rule for game restart.

---

## `StateManager` (`state_manager.gd`)

Transitions entities between groups (treating group membership as entity state)
using `CDTransition` resources. Matching transitions are **not** applied directly;
they are queued on the game's `CDUpdater` (`game.update`) to avoid mutating groups
while the game is iterating over them.

### Exports

| Export | Type | Default | Notes |
| --- | --- | --- | --- |
| `transitions` | `Array[CDTransition]` | `[]` | Rules defining from/to groups, triggers, selectors, and cooldowns. |

### Internal state

- `_transitioned: Dictionary` — per-frame guard ensuring each entity transitions at
  most once per frame.
- `_update: CDUpdater` — cached reference to `game.update`, used to queue deferred
  transitions.

### How it works

- `_on_initialize()` caches `_update = game.update` and calls `initialize()`.
- `initialize()` iterates `transitions`; for any `t.is_valid()` it calls
  `t.initialize(game)`, otherwise pushes a warning that the transition has empty
  group names.
- `_physics_process(delta)`:
  1. Clears the per-frame `_transitioned` guard.
  2. Advances cooldowns on every transition via `t.advance_cooldown(delta)`.
  3. For each valid, non-cooldown transition whose `trigger` evaluates true, calls
     `_process_trigger(t)`.
- `_process_trigger(t)`:
  1. **Gather candidates** via `_gather_from_groups(t)`:
     - If `t.target_groups` is empty, returns `game.group_registry.get_group(...)` of
       `t.remove_groups[0]` (or `[]` if `remove_groups` is also empty).
     - Otherwise unions every entity across all `t.target_groups`, deduplicated.
  2. **Filter** candidates, keeping only entities that are: instance-valid, in
     `CDEnums.EntityState.ACTIVE`, not already in `_transitioned` this frame, and a
     member of all groups in `t.target_groups` (via `_is_in_all_groups`).
  3. **Select**: if `t.selector` is set, calls
     `t.selector.select(filtered, global_position)` (the manager's position is
     passed in for distance-based selectors); otherwise uses the filtered list as-is.
  4. **Queue** each selected entity: marks it in `_transitioned`, then calls
     `_update.queue_transition(entity, t.remove_groups, t.add_groups,
     t.entity_signals, t.game_signals)` and starts the transition's cooldown via
     `t.start_cooldown()`.
- `_is_in_all_groups(entity, groups)` returns `true` for an empty group list, else
  requires membership in every listed group.

`reset()` clears `_transitioned` and calls `reset()` on every transition.

---

## Creating a new manager script

A manager in this folder is a `CDGameComponent` that owns a list of data resources
and reacts to their triggers. To add a new one, follow the shape the existing files
actually use:

1. **Declare the class and category** exactly as the others do:
   ```gdscript
   class_name YourManager extends CDGameComponent

   func _ready() -> void:
       component_category = CDEnums.ComponentCategory.MANAGER
       super._ready()
   ```
2. **Expose its data as exported resource arrays** (e.g.
   `@export var rules: Array[YourRule] = []`). Behavior lives in the resources, not
   in the script — keep the script a generic engine over those resources.
3. **Initialize resources in `_on_initialize()`**, passing `game` to each resource's
   trigger so it can resolve signal/timer references. Cache any other game
   references you need here (e.g. `StateManager` caches `game.update`).
4. **Do per-frame work in `_physics_process(delta)`**: evaluate each resource's
   trigger and, when it fires, take the action. Guard with validity/cooldown checks
   where relevant (see `StateManager` and `StageManager`).
5. **Act on the game through the shared `game` handle** — write to
   `game.blackboard`, call `game.bus_emit(...)`, query `game.group_registry`, find
   sibling nodes with `game.find_children(...)`, or queue deferred work via
   `game.update`.
6. **Add a `reset()` method** that clears runtime state and calls `reset()` on each
   data resource for game restart. Every manager here has one — even ones like
   `ScoreManager` that hold no own accumulator (it still resets per-rule trigger
   state like cooldowns/timers).
7. **Disable processing when idle** if the manager only runs in bursts (see
   `SignalManager` toggling `set_physics_process`), to avoid unnecessary per-frame
   work.