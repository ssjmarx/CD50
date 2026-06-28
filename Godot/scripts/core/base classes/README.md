# Base Classes

This folder holds the foundational `class_name` base scripts that V2 gameplay scripts derive from. Each file defines one abstract base; concrete scripts in other folders extend these and fill in the virtual methods.

> These scripts reference a handful of classes defined elsewhere in the codebase. They are not defined here and are listed only so the relationships are clear:
> - `CDGame` — ancestor game node (provides `blackboard`, `current_state`, `bus_emit()`, and `find_ancestor()`).
> - `CDEntity` — ancestor entity node (provides `entity_activated` / `entity_deactivating` signals, `activate()`, and `find_ancestor()`).
> - `CDEnums` — provides `ComponentCategory`, `GameState`, and `category_to_priority()`.
> - `CDObjectPool` — pool used by the trapdoor (provides `acquire()`).
> - `CDSpawnContext` — resource describing velocity/rotation applied at spawn.
> - `CDUtilities` — provides `apply_spawn_context()`.

## Files

| File | Class | Extends | Role |
|------|-------|---------|------|
| `cd_cue_card.gd` | `CDCueCard` | `Control` | Base for V2 UI display components |
| `cd_entity_component.gd` | `CDEntityComponent` | `Node2D` | Base for components attached to an entity |
| `cd_game_component.gd` | `CDGameComponent` | `Node2D` | Base for components attached to the game |
| `cd_stage_trapdoor.gd` | `CDStageTrapdoor` | `CDGameComponent` | Abstract base for stage-level spawners |

---

## CDCueCard (`cd_cue_card.gd`)

Base class for UI display components. Unlike the other bases here it extends `Control` (lives in the UI layer, not the physics world). It resolves a cached `game` reference and gives subclasses two helpers for reading/writing the game blackboard.

### Exports
- `is_interface: bool = false` — when `true`, `_ready()` auto-creates a bare `Label` child for text output.

### Cached refs
- `game: CDGame` — resolved at `_ready()` via `CDGame.find_ancestor(self)`.

### Internal state
- `_label: Label` — only created when `is_interface` is `true`.

### Lifecycle
- `_ready()` sets `process_physics_priority = 70` (fixed; cue cards process after gameplay) and, if `is_interface`, calls `_create_label()`.

### Label helpers
- `_create_label()` — creates a bare `Label` and adds it as a child.
- `_update_label(text: String)` — sets `_label.text` if the label exists. Call from subclasses when displayed state changes.

### Blackboard helpers
- `_consume_pending(key: StringName, default: Variant = null) -> Variant` — reads `key` from `game.blackboard`, erases it, and returns it; returns `default` if the game ref is missing, the key is absent, or its value is `null`.
- `_publish_tracked(key: StringName, value: Variant) -> void` — writes `value` to `game.blackboard[key]`. No-ops if `game` is missing.

### How to create a new cue card
1. Create a script: `class_name CDMyCueCard extends CDCueCard`.
2. Add it to a `Control` node placed somewhere under a `CDGame` in the scene tree.
3. If it should show text without you managing a `Label`, set `is_interface = true` and call `_update_label(...)` from your logic.
4. Read/write shared state through `_consume_pending(...)` and `_publish_tracked(...)`.

---

## CDEntityComponent (`cd_entity_component.gd`)

Base class for components attached to an entity. It walks the tree to cache both its parent `CDEntity` and ancestor `CDGame`, runs a two-phase lifecycle, tracks entity-bus connections (so `CDBody` can sleep/wake them), and exposes virtuals for initialize / deactivate / activate / sleep / wake.

### Exports
- `component_category: CDEnums.ComponentCategory` — used to compute `process_physics_priority` via `CDEnums.category_to_priority(...)`.

### Cached refs
- `entity: CDEntity` — resolved in `_ready()` via `CDEntity.find_ancestor(self)`. `push_error` and early-return if missing.
- `game: CDGame` — resolved in `_ready()` via `CDGame.find_ancestor(self)`. `push_error` and early-return if missing.

### Internal state
- `_bus_connections: Array[Dictionary]` — tracked `{"signal_name": StringName, "callable": Callable}` entries for sleep/wake support.

### Two-phase lifecycle
1. `_ready()` — editor hint guard; sets `process_physics_priority` from `component_category`; resolves `entity` and `game`; defers `_initialize()`.
2. `_initialize()` — connects `entity_deactivating` and `entity_activated` on the entity; calls `_on_initialize()`.

### Virtual methods (override these)
- `_on_initialize()` — connect entity/game bus signals and read sibling state. Default: no-op.
- `_on_entity_deactivating()` — reset internal state before pool return or deletion. Default: `set_physics_process(false)`.
- `_on_entity_activated()` — re-enable processing when recycled from pool. Default: `set_physics_process(true)`.
- `_on_sleep()` — customize sleep behavior (clear timers, reset state). Default: `set_physics_process(false)`. Called by `CDBody`.
- `_on_wake()` — customize wake behavior (restart timers, re-query state). Default: `set_physics_process(true)`. Called by `CDBody`.

### Bus connection tracking
- `bus_connect(signal_name: StringName, callable: Callable)` — adds the user signal on `entity` if missing, connects `callable` if not already connected, and records the pair in `_bus_connections`.
- `bus_disconnect(signal_name: StringName, callable: Callable)` — disconnects the callable on `entity` if present and removes the matching tracked entry (iterates backward).

### How to create a new entity component
1. Create a script: `class_name CDMyComponent extends CDEntityComponent`.
2. Set `component_category` in the inspector (drives physics priority).
3. Place the node under a `CDEntity` that lives under a `CDGame`.
4. Override `_on_initialize()` to read siblings and wire up signals — use `bus_connect(...)` (not `entity.connect(...)`) so sleep/wake tracking works.
5. Override `_on_entity_deactivating()` / `_on_entity_activated()` and/or `_on_sleep()` / `_on_wake()` as needed for pooled entities.

---

## CDGameComponent (`cd_game_component.gd`)

Base class for components attached to the game itself (the entity-component analog for game-level systems). It caches the ancestor `CDGame`, runs the same two-phase lifecycle pattern, and tracks game-bus connections (so `CDStage` can sleep/wake them).

### Exports
- `component_category: CDEnums.ComponentCategory` — used to compute `process_physics_priority`.

### Cached refs
- `game: CDGame` — resolved in `_ready()` via `CDGame.find_ancestor(self)`. `push_error` and early-return if missing.

### Internal state
- `_bus_connections: Array[Dictionary]` — tracked `{"signal_name": StringName, "callable": Callable}` entries for sleep/wake support.

### Two-phase lifecycle
1. `_ready()` — editor hint guard; resolves `game`; defers `_initialize()`. (Priority is set in phase 2 so the subclass's own `_ready()` has already run.)
2. `_initialize()` — sets `process_physics_priority` from `component_category`; calls `_on_initialize()`.

### Virtual methods (override these)
- `_on_initialize()` — connect game bus signals and set up game-level logic. Default: no-op.
- `_on_sleep()` — customize sleep behavior (clear timers, reset state). Default: `set_physics_process(false)`. Called by `CDStage`.
- `_on_wake()` — customize wake behavior (restart timers, re-query state). Default: `set_physics_process(true)`. Called by `CDStage`.

> Note: unlike `CDEntityComponent`, this base does **not** define `_on_entity_deactivating` / `_on_entity_activated` — game components are not pooled with an entity lifecycle.

### Bus connection tracking
- `bus_connect(signal_name: StringName, callable: Callable)` — adds the user signal on `game` if missing, connects `callable` if not already connected, and records the pair in `_bus_connections`.
- `bus_disconnect(signal_name: StringName, callable: Callable)` — disconnects the callable on `game` if present and removes the matching tracked entry (iterates backward).

### How to create a new game component
1. Create a script: `class_name CDMyGameComponent extends CDGameComponent`.
2. Set `component_category` in the inspector (drives physics priority).
3. Place the node under a `CDGame`.
4. Override `_on_initialize()` and use `bus_connect(...)` (not `game.connect(...)`) to wire game bus signals so sleep/wake tracking works.
5. Override `_on_sleep()` / `_on_wake()` if the system needs to suspend/resume with the stage.

---

## CDStageTrapdoor (`cd_stage_trapdoor.gd`)

Abstract base class for stage-level spawners. Extends `CDGameComponent`. It implements the full **Trigger → (optional delay) → Queue → Stagger → Spawn** lifecycle and adds telefrag and safe-zone gating.

> This class is abstract: `_get_spawn_scene()` `push_error`s if you forget to override it. Concrete trapdoors override the three `_get_spawn_*` virtuals (the file's own error message references `PointTrapdoor`, `EdgeTrapdoor`, `GridTrapdoor` as examples).

### Exports

**Spawn timing / acquisition**
- `stagger_delay: float = 0.1` — seconds between each entity spawn in a wave.
- `pool: CDObjectPool = null` — pooled spawning when set; otherwise fresh `instantiate()`.
- `spawn_context: CDSpawnContext = null` — optional velocity/rotation applied before the entity enters the tree.
- `spawn_scenes: Array[PackedScene] = []` — scenes cycled by index; if non-empty this is used instead of `_get_spawn_scene()`.
- `trigger_delay: float = 0.0` — seconds to wait after a trigger signal before spawning begins.

**Blackboard**
- `wave_key: StringName = &"wave_number"` (under `Blackboard Keys`) — key read from `game.blackboard` to get the current wave number.

**Telefrag**
- `telefrag: bool = false` — kill overlapping bodies at the spawn point before spawning.
- `telefrag_targets: Array[StringName] = [&"enemies"]` — groups that telefrag will affect; empty means everything.

**Listen signals (game bus) — group `Listen Signals`**
- `trigger_signals: Array[StringName] = [&"wave_start"]` — start a spawn wave. Routed through `_on_delayed_trigger` when `trigger_delay > 0`, otherwise `_on_trigger`.
- `safe_signals: Array[StringName] = [&"zone_safe"]` — mark the spawn zone safe (spawning allowed).
- `unsafe_signals: Array[StringName] = [&"zone_unsafe"]` — mark the spawn zone unsafe (spawning paused).

**Emit signals (game bus) — group `Emit Signals`**
- `on_spawning_complete: Array[StringName] = [&"spawning_complete"]` — emitted once the entire wave has spawned.

### Internal state
- `_spawn_queue: Array[int]` — indices still to spawn this wave.
- `_spawn_timer: float` — countdown for `stagger_delay`.
- `_current_wave: int` — wave number captured from the trigger.
- `_zone_is_safe: bool = true` — paused while a safe-zone mark reports the area is occupied.
- `_delay_remaining: float` — countdown for `trigger_delay`.
- `_pending_wave: int` — wave number held during the delay phase.

### Lifecycle
- `_ready()` — calls `super._ready()`, forces `component_category = CDEnums.ComponentCategory.RULES`, and disables physics processing until a trigger arrives.
- `_on_initialize()` — connects every entry in `trigger_signals` (to `_on_delayed_trigger` when `trigger_delay > 0`, else `_on_trigger`), plus all `safe_signals` and `unsafe_signals`, via the inherited `bus_connect()`.
- `_physics_process(delta)`:
  1. If `_delay_remaining > 0`, count it down and fire `_on_trigger()` when it reaches zero, then return (delay gate).
  2. If the queue is empty, stop processing.
  3. If the zone is unsafe, return (do not spawn).
  4. Drain the queue, calling `_spawn_one()` per index and accumulating `stagger_delay` on `_spawn_timer`.
  5. When the queue empties, write `game.blackboard["spawned_wave"] = _current_wave` and emit every `on_spawning_complete` signal via `game.bus_emit()`.

### Spawn flow details
- `_on_trigger()` — early-returns on `GAME_OVER`; reads the wave from `blackboard[wave_key]`; asks `_get_spawn_count()`; fills `_spawn_queue` with `0..total-1`; resets `_spawn_timer`; enables processing.
- `_on_delayed_trigger()` — early-returns on `GAME_OVER`; stores the wave in `_pending_wave`; arms `_delay_remaining`; enables processing (the actual queuing happens when the delay elapses via `_on_trigger()`).
- `_spawn_one(index)`:
  - Picks the scene from `spawn_scenes[index % size]` if any, otherwise `_get_spawn_scene(index, total)`. Skips the slot if the scene is `null`.
  - Gets the position from `_get_spawn_position(index, total)`.
  - Acquires from `pool.acquire()` (and sets `global_position`) when a pool is set, otherwise `scene.instantiate()` and set `global_position`.
  - If `telefrag`, calls `_telefrag_at(spawn_position, entity)` before the entity enters the tree.
  - Applies `spawn_context` via `CDUtilities.apply_spawn_context(entity, spawn_context)`.
  - Activates: `entity.activate()` for pooled entities, or `game.add_child(entity)` for fresh ones.

### Telefrag
- `_telefrag_at(pos, _exclude)` — point-queries `get_world_2d().direct_space_state` (areas off, bodies on, excluding `_exclude.get_rid()`). For each hit, if `telefrag_targets` is empty or `_matches_telefrag_targets(body)` is true, prints `"telefrag!"` and emits `request_deactivate` on the body.
- `_matches_telefrag_targets(body)` — true if the body is in any of the `telefrag_targets` groups.

### Safe zone
- `_on_zone_safe()` / `_on_zone_unsafe()` flip `_zone_is_safe`, which the stagger loop consults each frame.

### Virtual methods (override these in concrete trapdoors)
- `_get_spawn_count(_wave_number: int) -> int` — how many entities to spawn for the wave. Default: `0`.
- `_get_spawn_position(_index: int, _total: int) -> Vector2` — world position for entity at `index`. Default: `global_position`.
- `_get_spawn_scene(_index: int, _total: int) -> PackedScene` — scene for entity at `index`; return `null` to skip the slot. **Must override** — the base `push_error`s and returns `null`.

### How to create a new trapdoor
1. Create a script: `class_name CDMyTrapdoor extends CDStageTrapdoor`.
2. Place the node under a `CDGame` and position it where spawns should originate.
3. In the inspector, optionally set `spawn_scenes` (skips `_get_spawn_scene`), `pool`, `spawn_context`, `stagger_delay`, `trigger_delay`, and the listen/emit signal arrays.
4. If `spawn_scenes` is empty, override `_get_spawn_scene(_index, _total)` (required) and return a `PackedScene` or `null`.
5. Override `_get_spawn_count(_wave_number)` to return how many to spawn, and `_get_spawn_position(_index, _total)` if the default (`global_position`) isn't right.
6. The base handles all triggering, staggering, pooling, telefrag, safe-zone gating, and completion signaling — do not reimplement those.