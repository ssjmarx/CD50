# Base Classes

Foundational abstract bases that V2 gameplay scripts derive from. Each file defines one base; concrete scripts fill in the virtual methods. These bases share a common pattern: walk the tree to cache an ancestor (`entity` / `game`), run a two-phase lifecycle, track bus connections, and expose lifecycle virtuals.

## Files

| File | Class | Extends | Role |
|------|-------|---------|------|
| `cd_cue_card.gd` | `CDCueCard` | `CDGameControl` | Base for V2 UI display components |
| `cd_entity_component.gd` | `CDEntityComponent` | `Node2D` | Base for components attached to an entity |
| `cd_game_component.gd` | `CDGameComponent` | `Node2D` | Base for components attached to the game |
| `cd_stage_trapdoor.gd` | `CDStageTrapdoor` | `CDGameComponent` | Abstract base for stage-level spawners |

---

## Shared patterns

### 1. Cached ancestor ref
Every base resolves its ancestor in `_ready()` via `…find_ancestor(self)` (`CDEntity.find_ancestor` or `CDGame.find_ancestor`), `push_error`s and early-returns if missing. The cached ref (`entity` / `game`) is the single handle for all bus/blackboard access.

### 2. `component_category` → physics priority
`component_category: CDEnums.ComponentCategory` is used to compute `process_physics_priority` via `CDEnums.category_to_priority(...)` (so `ARMS` components tick before `GUTS`, etc.).

### 3. Two-phase lifecycle
1. **`_ready()`** — editor hint guard; resolve ancestor(s); defer `_initialize()` (deferred so the subclass's own `_ready()` has run first).
2. **`_initialize()`** — set physics priority; call `_on_initialize()`.

Concrete scripts override **`_on_initialize()`**, never `_ready()` / `_initialize()`.

### 4. Tracked bus connections
Connect through the helpers (not `…connect(...)`) so sleep/wake + exit-tree tracking works:
```gdscript
bus_connect(signal_name, callable)          # tracked
bus_disconnect(signal_name, callable)       # untrack
connect_all(signals: Array[StringName], callable)   # batch
disconnect_all(signals, callable)
```
`_exit_tree()` auto-disconnects every tracked connection. Subclasses that override `_exit_tree` must call `super._exit_tree()`.

### 5. Sleep / wake virtuals
Game-level components are sleepable by `CDStage`; entity-level components by `CDBody`. Override `_on_sleep()` / `_on_wake()` (defaults flip `set_physics_process`). Entity components also have `_on_entity_deactivating()` / `_on_entity_activated()` for pool recycle.

---

## CDCueCard

`CDCueCard` is the `Control`-rooted twin of `CDGameComponent`. It adds:
- `is_interface: bool` — when true, `_ready()` auto-creates a bare `Label` child.
- `_update_label(text)` — set the auto-label's text.
- `_publish_tracked(key, value)` / `_consume_pending(key, default)` — blackboard write/read-and-erase.

It does not cache `game` itself — the `game` ref comes from its `CDGameControl` base.

**How to create a cue card:** `class_name CDMyCueCard extends CDCueCard`, set `is_interface = true`, call `_update_label(...)` and `_publish_tracked(...)` / `_consume_pending(...)`.

---

## CDEntityComponent

Base for components attached to an entity. Caches `entity` + `game`, tracks entity-bus connections.

**Virtuals:** `_on_initialize()`, `_on_entity_deactivating()`, `_on_entity_activated()`, `_on_sleep()`, `_on_wake()`.

**How to create an entity component:**
```gdscript
class_name CDMyComponent extends CDEntityComponent

func _ready() -> void:
    component_category = CDEnums.ComponentCategory.GUTS   # set before super
    super._ready()

func _on_initialize() -> void:
    connect_all(listen_signals, _on_signal)   # tracked

func _on_entity_deactivating() -> void:
    # reset internal state before pool return / deletion
    pass
```
- Place under a `CDEntity` under a `CDGame`.
- Set `component_category` in `_ready()` before `super._ready()`.
- Wire signals with `bus_connect(...)` (not `entity.connect(...)`) so sleep/wake tracking works.

---

## CDGameComponent

Base for components attached to the game. Caches `game`, tracks game-bus connections. This is the base `directors`, `goals`, `managers`, `speakers`, `projectors`, and `cards` build on.

**Virtuals:** `_on_initialize()`, `_on_sleep()`, `_on_wake()`. No entity lifecycle virtuals.

**How to create a game component:** same as entity component, but `extends CDGameComponent` and only `_on_initialize()` / `_on_sleep()` / `_on_wake()`. Place under a `CDGame`.

---

## CDStageTrapdoor

Abstract base for stage-level spawners. Extends `CDGameComponent` and owns the **Trigger → (optional delay) → Queue → Stagger → Spawn** lifecycle plus telefrag and safe-zone gating. `_get_spawn_scene()` is abstract (`push_error`s) — every concrete trapdoor must implement it.

**Exports (inherited by every trapdoor):** `stagger_delay`, `pool`, `spawn_context`, `spawn_scenes`, `trigger_delay`, `wave_key`, `telefrag`, `telefrag_targets`, `trigger_signals`, `safe_signals`, `unsafe_signals`, `on_spawning_complete`.

**Virtuals (the only override surface):**
```gdscript
func _get_spawn_count(_wave_number: int) -> int                # default 0
func _get_spawn_position(_index: int, _total: int) -> Vector2  # default global_position
func _get_spawn_scene(_index: int, _total: int) -> PackedScene # abstract — must implement
func _populate_spawn_queue(_wave_number: int) -> void          # default fills 0..count-1
```

**How to create a trapdoor:** `class_name CDMyTrapdoor extends CDStageTrapdoor`; implement `_get_spawn_scene()`; override `_get_spawn_count()` / `_get_spawn_position()` to define count + position; override `_populate_spawn_queue()` (not `_on_trigger()`) for non-range queue logic. Configure timing/pool/telefrag/signals via inherited exports. See `game components/trapdoors/README.md` for the full lifecycle.

---

## How to create a new base class

Most gameplay should extend one of the four bases above, not introduce a new base. If you genuinely need a new base:

- [ ] Pick the root node type (`Node2D` for world, `Control` for UI) and extend that.
- [ ] Resolve the ancestor (`entity` / `game`) in `_ready()` via `…find_ancestor(self)`; `push_error` + early-return if missing; cache it.
- [ ] Run a two-phase lifecycle: `_ready()` resolves refs and defers `_initialize()`; `_initialize()` sets physics priority and calls `_on_initialize()`.
- [ ] Provide `component_category` + compute `process_physics_priority` via `CDEnums.category_to_priority(...)`.
- [ ] Implement tracked bus helpers (`bus_connect` / `bus_disconnect` / `connect_all` / `disconnect_all`) and auto-disconnect in `_exit_tree()`.
- [ ] Expose `_on_initialize()` as the override point, plus sleep/wake virtuals if the base is sleepable.
- [ ] Document every export and virtual with `##` comments.