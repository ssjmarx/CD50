# Directors

Directors are `CDGameComponent` nodes (category `CDEnums.ComponentCategory.RULES`) that orchestrate behavior across **groups of entities** rather than acting on a single entity. They read from the game's `group_registry`, evaluate data-driven resource rules, and push results onto entity `blackboard`s, game-bus `signals`, or queued state transitions.

This folder contains eight director scripts. They share a common shape but each solves a different orchestration problem.

---

## Shared conventions (observed across these files)

These patterns appear in the actual code in this folder. They are not imposed by a base class — each script re-implements them.

### Base class & category
Every script extends `CDGameComponent` and sets its category in `_ready()`:

```gdscript
func _ready() -> void:
    component_category = CDEnums.ComponentCategory.RULES
    super._ready()
```

### `@tool` status
| Script | `@tool` | Editor preview (`_draw`) | Editor animation (`_process`) |
| --- | --- | --- | --- |
| `aiming_director.gd` | yes | no | no |
| `formation_director.gd` | yes | yes | yes (marching) |
| `marching_order_director.gd` | yes | no | no |
| `shooting_director.gd` | yes | no | no |
| `signal_sequence_director.gd` | yes | no | no |
| `stage_director.gd` | **no** | no | no |
| `state_director.gd` | **no** | no | no |
| `swoop_director.gd` | yes | yes | no |

Every `@tool` script guards its runtime logic with `if Engine.is_editor_hint(): return` inside `_physics_process` (and `_process`/`_draw` where they only draw in the editor).

### Entity gathering
Directors gather entities from named groups via `game.group_registry.get_group(group_name)` and deduplicate them into an `Array[CDEntity]`. Most filter to valid, `ACTIVE` entities:

```gdscript
if is_instance_valid(entity) and entity.state == CDEnums.EntityState.ACTIVE:
```

Several support a `require_all` toggle: `true` = entity must be in ALL listed groups, `false` = entity must be in ANY group.

### Output channels
Directors do **not** move entities directly. They push intent through these channels:

1. **Entity blackboard** — write `Vector2` directions / `float` distances under configurable `StringName` keys (default keys: `move_direction`, `move_distance`, `aim_direction`).
2. **Game bus signals** — emit / connect `StringName` signals via `game.bus_emit(...)`, `game.bus_emit_from(sig, entity)`, `bus_connect(...)`, or `game.bus_connect(...)`.
3. **Entity bus signals** — emit a signal on a single entity via `entity.bus_emit(shoot_signal)`.
4. **Queued transitions** — `StateDirector` defers group changes through `game.update.queue_transition(...)` (a `CDUpdater`).

### Lifecycle hooks used
- `_ready()` — set category, call `super._ready()`.
- `_on_initialize()` — connect listen-signals, initialize child resources (`trigger.initialize(game)`, `selector.initialize(game)`, `speed_scaler.initialize(game)`, `curve...`), build lookup maps.
- `_physics_process(delta)` — runtime per-frame logic (guarded against editor when `@tool`).
- `reset()` — clears state for game restart. Present on: `AimingDirector`, `FormationDirector`, `ShootingDirector`, `SignalSequenceDirector`, `StateDirector`, `SwoopDirector`. **Not** present on `MarchingOrderDirector` or `StageDirector`.

### Common dependency types
These resource/object types are referenced by the directors (defined elsewhere in the project):
- `CDEntity` — the entities being orchestrated.
- `CDGameComponent` — base class.
- `game.group_registry` — group lookups.
- `game.update` (`CDUpdater`) — deferred transition queue.
- Resources: `CDFormation`, `CDMarchingOrder`, `CDScaler`, `CDTrigger`, `CDSelector`, `CDSequenceStep`, `CDDirectorRule`, `CDTransition`, `CDCurve`.

---

## Per-script reference

### `aiming_director.gd` — `AimingDirector`
**Purpose:** Per-entity nearest-target aiming. Each shooter independently finds its closest target across `target_groups` and writes a normalized direction to its blackboard.

- `@tool`: yes
- **Inputs (exports):**
  - `shooter_groups: Array[StringName]` (default `&"enemies"`) — groups that should aim.
  - `target_groups: Array[StringName]` (default `&"players"`) — groups searched for targets.
  - Timing: `update_interval: float` (0 = every frame; >0 throttles recalculation and writes cached directions between updates).
  - Precision: `targeting_noise: float` — random offset added to the target position.
  - Blackboard key: `aim_key` (default `&"aim_direction"`), a normalized `Vector2`.
  - Angle limits: `use_angle_limit`, `min_angle_offset`, `max_angle_offset` (degrees, 0 = East, clamped in absolute world space).
- **Behavior:** In `_physics_process`, gathers shooters, optionally throttles, then for each shooter calls `_calculate_aim` which uses `game.group_registry.get_nearest(group, pos)` per target group, applies optional noise, and optional absolute-angle clamping.
- **Blackboard writes:** `entity.blackboard[aim_key] = direction`.
- **`reset()`:** clears update timer and cached directions.

### `formation_director.gd` — `FormationDirector`
**Purpose:** Manages tiered sub-formation grids (`CDFormation`) and animates them with data-driven marching orders. Auto-assigns group members to slots and writes per-entity move data.

- `@tool`: yes (editor preview + marching animation).
- **Inputs (exports):**
  - `formation_groups`, `require_all` — which entities may occupy slots.
  - `formations: Array[CDFormation]` — sub-formation definitions (each has its own grid, `preferred_group`, and offset). Setter re-inits slots and redraws.
  - Marching: `marching_orders: Array[CDMarchingOrder]` — ordered Step/Pause/Breathe commands.
  - `speed_scaler: CDScaler` — multiplies marching speed (effective duration is divided by the evaluated multiplier).
  - Blackboard keys: `direction_key` (`move_direction`), `distance_key` (`move_distance`).
  - Preview: `preview_color`, `preview_radius` (drawn as circles at slot positions).
- **Behavior:**
  - `_process` (editor only) advances marching for preview; `_draw` (editor only) renders slot positions including the current marching offset and breathing scales.
  - `_physics_process` advances marching, auto-assigns untracked group members to slots (preferred group first, then un-preferred formations, then as last resort), cleans stale/invalid/out-of-group slots, and writes move data.
  - Marching state tracks a raw timer and a scaled timer; looping resets `_accumulated_offset` to snap back to the start (a comment notes you can comment out that line to allow endless drifting).
  - Breathing values (`spacing_scale`, `offset_scale`) come from the current marching order via `get_breathing_values`.
- **Blackboard writes:** `move_direction` (direction to slot target) and `move_distance` (distance to slot target; 0 if already there).
- **`reset()`:** resets scaler, re-inits slots, clears assignment map and marching state.

### `marching_order_director.gd` — `MarchingOrderDirector`
**Purpose:** A "blind conductor" that translates `CDMarchingOrder` resources into a **continuous** movement intent. Unlike `FormationDirector` it does not manage slots — it evaluates the path delta each frame and writes direction + magnitude to all target entities, leaving discrete stepping to the entities' Legs.

- `@tool`: yes.
- **Inputs (exports):**
  - `target_groups`, `require_all`.
  - Marching: `marching_orders: Array[CDMarchingOrder]`.
  - `speed_scaler: CDScaler`.
  - Blackboard keys: `direction_key` (`move_direction`), `distance_key` (`move_distance`).
  - Listen signal: `reset_signal` (default `&"reset_orders"`) — resets the sequence to the start.
- **Behavior:** `_physics_process` computes the previous frame's offset, advances marching, takes the delta, and writes the **normalized delta** as direction and the **delta length** as distance (snapped to zero below 0.001). Marching logic mirrors `FormationDirector` but accumulates scaled time per-frame (`scaled_delta = delta * multiplier`) and carries excess scaled time across step boundaries to prevent micro-stutters.
- **Signal:** connects `reset_signal` via `game.bus_connect`.
- **Blackboard writes:** `move_direction`, `move_distance`.
- **Note:** No public `reset()` method (only internal `_reset_marching_state`).

### `shooting_director.gd` — `ShootingDirector`
**Purpose:** Data-driven shooting. A `CDTrigger` decides **when** to fire and a `CDSelector` decides **who** fires. Emits a shoot signal on each selected entity.

- `@tool`: yes.
- **Inputs (exports):**
  - `target_groups: Array[StringName]` (default `&"enemies"`).
  - `trigger: CDTrigger` — evaluated each frame; when true, a fire cycle occurs.
  - `selector: CDSelector` — narrows candidates (if absent, all candidates fire).
  - Signal: `shoot_signal` (default `&"shoot"`).
- **Behavior:** `_physics_process` calls `trigger.evaluate(delta)`; on success it gathers candidates (valid + active, deduplicated), runs them through the selector, and calls `entity.bus_emit(shoot_signal)` on each.
- **`reset()`:** resets the trigger.

### `signal_sequence_director.gd` — `SignalSequenceDirector`
**Purpose:** A signal macro — turns one or more trigger signals into a timed sequence of game-bus signals. Each step fires its signals, waits a delay, and optionally waits for a sync signal a number of times before advancing.

- `@tool`: yes.
- **Inputs (exports):**
  - `steps: Array[CDSequenceStep]`.
  - `trigger_signals: Array[StringName]` (default `&"game_play"`) — start the sequence.
  - `on_sequence_complete: Array[StringName]` (default `&"sequence_complete"`).
- **Behavior:** Physics processing is disabled by default and enabled only while running. On trigger, it executes step 0. Each step fires its signals, sets a `delay_after` countdown, and optionally waits for `wait_for_signal` to fire `wait_count` times. Advancing requires BOTH the delay to expire AND the sync count to be met (whichever finishes second gates the advance). Loops/advances through steps; on completion emits `on_sequence_complete` and disables physics processing.
- **Signal usage:** `connect_all(trigger_signals, _on_trigger)` (inherited helper) for triggers, `game.bus_emit` for step signals, `game.bus_disconnect` for sync listeners. The sync listener is connected with `bus_connect(...)` (tracked) in `_execute_step()` and disconnected in `_on_sync_signal()` when the count is met.
- **Defensive cleanup:** `_complete()` and `reset()` both call `_disconnect_sync_listener()` first, so a still-pending sync wait is torn down even if the sequence is interrupted mid-step.
- **`reset()`:** defensively disconnects any lingering sync listener, then clears running state, timers, and wait counters; disables physics processing.

### `stage_director.gd` — `StageDirector`
**Purpose:** Listens for game-bus signals and performs entity **swaps** based on `CDDirectorRule` resources — deactivating the original and spawning a replacement at the same position.

- `@tool`: **no**.
- **Inputs (exports):**
  - `rules: Array[CDDirectorRule]` — each defines trigger signals, `target_group`, `swap_scene`, optional `selector`, and `deactivate_original`.
- **Behavior:** `_on_initialize` builds a reverse map (`_signal_to_rules`: signal → rules) and connects each trigger signal via `bus_connect(sig, _on_trigger.bind(sig))`. On trigger, it processes each matching rule: gathers the target group, narrows via `rule.selector.select(candidates)` (or all if no selector), optionally calls `entity.request_deactivate()`, instantiates `rule.swap_scene`, adds it to `game`, positions it at the original's global position, and activates it.
- **Validation:** rules missing `swap_scene` or `target_group` are skipped with a `push_warning`.
- **Note:** No `reset()` method.

### `state_director.gd` — `StateDirector`
**Purpose:** Transitions entities between groups (treating groups as states) using `CDTransition` resources. Transitions are queued through `CDUpdater` to avoid mutating groups during iteration.

- `@tool`: **no**.
- **Inputs (exports):**
  - `transitions: Array[CDTransition]` — each defines target/from groups, a `CDTrigger`, a `CDSelector`, cooldown, and group add/remove lists plus entity/game signals.
- **Behavior:** `_on_initialize` caches `game.update` (the `CDUpdater`) and initializes valid transitions (warnings for empty group names). `_physics_process` clears a per-frame guard map, advances all cooldowns, then evaluates each transition's trigger; when a trigger fires it gathers candidates, filters (valid, active, not already transitioned this frame, in all target groups), selects (passing the director's `global_position` for distance-based selectors), and queues each via `_update.queue_transition(entity, remove_groups, add_groups, entity_signals, game_signals)`.
- **Per-frame guard:** `_transitioned` ensures each entity transitions at most once per frame.
- **`reset()`:** clears the guard map and resets all transitions.

### `swoop_director.gd` — `SwoopDirector`
**Purpose:** Moves entities along a generated `Curve2D` using virtual "ghost" target points for deterministic spacing, with optional multi-lane formation. Emits `swoop_complete` per entity when it finishes.

- `@tool`: yes (editor curve preview via `_draw`).
- **Inputs (exports):**
  - `swooping_groups`, `require_all`.
  - `target: Vector2` — curve end point.
  - `curve: CDCurve` — generates the `Curve2D` from director position to target.
  - Movement: `swoop_speed`, `formation_offset` (spacing between successive entities).
  - Lanes: `lane_count` (1 = single file, 2 = pairs, …), `lane_spacing`.
  - Blackboard keys: `direction_key`, `distance_key`, `completed_entity_key` (default `&"swoop_completed_entity"`).
  - Listen signals: `trigger_signals` (default `&"spawning_complete"`).
  - Emit signals: `on_swoop_complete` (default `&"swoop_complete"`).
  - Preview: `show_preview`, `preview_color`, `preview_width`.
- **Behavior:**
  - On trigger, gathers entities, generates the curve, computes `_pixels_per_frame = swoop_speed / physics_fps` and `_entry_delay_frames`, determines a fixed perpendicular `_lane_axis` from the initial tangent, then releases the first lane group.
  - Entities are released `lane_count` at a time with an `_entry_delay_frames` gap; lane offset is `(index - (count-1)/2) * lane_spacing` along `_lane_axis`.
  - Each frame advances each entity's ghost offset by `_pixels_per_frame`, writes direction/distance to the ghost position, and marks entities complete when their offset reaches `_curve_length`. On completion it sets `game.blackboard[completed_entity_key] = entity` and emits each `on_swoop_complete` signal via `game.bus_emit_from(sig, entity)`.
  - `_enter_tree`/`_exit_tree` connect/disconnect the curve resource's `changed` signal for live redraws. `_exit_tree` also calls `super._exit_tree()` so the inherited `CDGameComponent` auto-disconnects any tracked game-bus connections (the trigger signals connected via `connect_all`).
- **`reset()`:** resets the curve resource and clears all ghost/lane/slot/pending state; disables physics processing.

---

## How to use a director

1. Add the director node (e.g. `FormationDirector`) to a game scene as a child of the game node that provides `group_registry`, `update`, and the bus.
2. Configure its exported groups so it gathers the right entities (and set `require_all` if needed).
3. Attach any required resources (`CDFormation`, `CDMarchingOrder`, `CDTrigger`, `CDSelector`, `CDSequenceStep`, `CDDirectorRule`, `CDTransition`, `CDCurve`, `CDScaler`).
4. Wire the output:
   - For blackboard-writing directors, ensure target entities have a component (e.g. Legs) that reads the configured blackboard keys.
   - For signal directors, ensure the emitted/connected signal names match listeners elsewhere.
5. If the director listens for a trigger signal, make sure something emits that signal on the game bus.
6. `@tool` directors will show previews/animation in the editor when configured; runtime logic runs only outside the editor.

---

## How to create a new director

Follow the patterns already present in this folder. A minimal director that writes to entity blackboards looks like this skeleton (mirrors the actual code conventions above):

```gdscript
@tool
class_name MyNewDirector extends CDGameComponent

## MyNewDirector
## One-line purpose. Describe what it orchestrates and which channel(s) it outputs to.

## --- exports ---

## groups containing entities this director acts on
@export var target_groups: Array[StringName] = [&"enemies"]
## true = entity must be in ALL groups; false = entity must be in ANY group
@export var require_all: bool = false

@export_group("Blackboard Keys")
@export var direction_key: StringName = &"move_direction"
@export var distance_key: StringName = &"move_distance"

@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"game_play"]

## --- state ---

## per-frame caches / timers go here

## --- lifecycle ---

func _ready() -> void:
    component_category = CDEnums.ComponentCategory.RULES
    super._ready()

func _on_initialize() -> void:
    # connect trigger signals (tracked + auto-disconnected on _exit_tree), initialize child resources, build lookup maps
    connect_all(trigger_signals, _on_trigger)

## --- processing ---

func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return
    # gather, filter (valid + ACTIVE), compute intent, write outputs

## --- helpers ---

## gather entities from all target groups (deduplicated)
func _gather_target_entities() -> Array[CDEntity]:
    var seen: Dictionary = {}
    var result: Array[CDEntity] = []
    for group_name in target_groups:
        for entity in game.group_registry.get_group(group_name):
            if not seen.has(entity):
                seen[entity] = true
                result.append(entity)
    return result

## --- reset ---

func reset() -> void:
    pass
```

Checklist for a faithful new director (based on this folder's existing scripts):

- [ ] Extend `CDGameComponent` and set `component_category = CDEnums.ComponentCategory.RULES` in `_ready()`.
- [ ] Decide `@tool` status. If `@tool`, guard runtime loops with `if Engine.is_editor_hint(): return` and (if you draw) gate `_draw`/`_process` to editor-only where appropriate.
- [ ] Declare groups + `require_all` (match the existing spelling) if you gather entities.
- [ ] Deduplicate gathered entities and filter to `is_instance_valid(entity) and entity.state == CDEnums.EntityState.ACTIVE`.
- [ ] Choose your output channel(s): blackboard keys, game-bus signals, entity-bus signals, or queued transitions. Do **not** move entities directly.
- [ ] Initialize any child resources in `_on_initialize()` (e.g. `trigger.initialize(game)`).
- [ ] Connect listen-signals in `_on_initialize()` via the inherited `connect_all(signals, callable)` (tracked and auto-disconnected by the base `_exit_tree()`). If you override `_exit_tree`, call `super._exit_tree()`.
- [ ] If you connect a one-off/sync listener that must be torn down early, add a defensive `_disconnect_*` helper and call it from both `_complete()`/`reset()` and `_exit_tree()` (see `SignalSequenceDirector._disconnect_sync_listener`).
- [ ] Add a `reset()` method that clears your state (omit only if the director is truly stateless, as `StageDirector` is).
- [ ] If editor previews are useful, implement `_draw()` and have export setters call `queue_redraw()` when `is_node_ready()`.