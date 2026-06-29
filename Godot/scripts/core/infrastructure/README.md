# Core Infrastructure

The foundational runtime classes for V2. This folder holds the base entity type, the game root, and the singleton-style nodes that own collision, groups, input, pooling, audio, effects, and end-of-frame updates. Everything else in `scripts/` builds on top of these.

## Files

| File | Class | Extends | Role |
|------|-------|---------|------|
| `cd_game.gd` | `CDGame` | `Node2D` | Root of every game scene; state machine, game bus, owns infrastructure refs |
| `cd_entity.gd` | `CDEntity` | `CharacterBody2D` | Base physical entity; accumulates movement, resolves physics, emits collisions |
| `cd_body.gd` | `CDBody` | `CDEntityComponent` | Sleeps/wakes a group of child `CDEntityComponent`s on an entity |
| `cd_stage.gd` | `CDStage` | `CDGameComponent` | Sleeps/wakes a group of child `CDGameComponent`s on the game |
| `cd_updater.gd` | `CDUpdater` | `Node` | End-of-frame flusher for group transitions and sleep/wake |
| `cd_collision_buffer.gd` | `CDCollisionBuffer` | `Node` | Flushes collision signals after entity physics finishes |
| `cd_collision_matrix.gd` | `CDCollisionMatrix` | `Node` | Maps `CDCollisionGroup` resources → physics layer/mask bitmasks |
| `cd_group_registry.gd` | `CDGroupRegistry` | `Node` | Frame-cached, typed access to entity groups |
| `cd_input_router.gd` | `CDInputRouter` | `Node` | Converts Godot Input actions into typed signals |
| `cd_object_pool.gd` | `CDObjectPool` | `Node` | Pre-warmed pool of one entity scene type |
| `cd_effect.gd` | `CDEffect` | `Node2D` | One-shot visual effect that auto-frees |
| `cd_sound_bank.gd` | `CDSoundBank` | `CDGameComponent` | Procedural audio engine via `AudioStreamGenerator` |

---

## Cross-cutting patterns

### 1. Two signal buses
- **Entity bus** — on each `CDEntity` (`bus_connect` / `bus_disconnect` / `bus_emit`). Emitters tracked in `CDEntity._signal_emitters`.
- **Game bus** — on `CDGame` (`bus_connect` / `bus_disconnect` / `bus_emit` / `bus_emit_from`). `bus_emit_from` tracks the emitting entity in `CDGame._signal_emitters`.

Both `bus_connect` variants are idempotent (create the user signal if missing, guard double-connects). `bus_emit` emits zero-argument signals. `CDUpdater` clears `game._signal_emitters` at end of frame.

### 2. Physics-priority ordering
`_physics_process` order is driven by `process_physics_priority`:

| Node | Priority | Why |
|------|----------|-----|
| `CDGroupRegistry` | `5` | Refresh dirty groups before anyone reads them |
| `CDEntity` | `30` | Resolve movement + collisions after components set velocity |
| `CDCollisionBuffer` | `35` | Flush collision signals after all entity physics |
| `CDUpdater` | `CDEnums.category_to_priority(UPDATE)` | Flush transitions after gameplay components finish |

### 3. Sleep / wake containers
`CDBody` and `CDStage` are structurally parallel: both collect their child component class via `find_children("*", "<ClassName>")`, support `start_asleep`, implement `_flush_sleep()` / `_flush_wake()` (called by `CDUpdater`; sleep before wake so a same-frame `sleep→wake` resolves awake), and walk each child's `_bus_connections` list to disconnect/reconnect against the relevant bus (`self.entity` vs `self.game`).

| | `CDBody` | `CDStage` |
|---|----------|-----------|
| Extends | `CDEntityComponent` | `CDGameComponent` |
| Children | `CDEntityComponent` | `CDGameComponent` |
| Bus | entity bus | game bus |
| Extra | toggles subtree collisions | emits `on_wake_signal` after wake |

### 4. Deferred, frame-consistent mutations
Anything that could break group/collision consistency mid-frame is queued and flushed once at end of frame by `CDUpdater`: group transitions (`queue_transition`), and sleep/wake (`queue_sleep` / `queue_wake`, deduped by membership).

### 5. Robust game initialization
`CDGame._ensure_infrastructure()` resolves each required component by, in order: exact-name child lookup → script-type match anywhere under the game → auto-create with defaults (and `push_warning`). Infrastructure nodes may be nested (e.g. inside a `CDStage`).

**Optional refs** are the exception: `sound_bank` is resolved by `find_child(...)` only and is **never auto-created**. Omit the node if the scene doesn't need audio; `sound_bank` stays `null`.

### 6. Pools + activation lifecycle
`CDEntity` carries a `pool` reference (`null` = not pooled). `CDObjectPool` pre-warms instances invisible + physics-disabled. `CDEntity.activate()` / `deactivate()` (two-phase: mark → deferred `_complete_deactivation`) move entities in/out of the pool while re-registering groups and toggling collisions.

### 7. Collision layer indirection
Components never touch Godot layer numbers. `CDCollisionMatrix` assigns each `CDCollisionGroup` a unique bit (`1 << index`, max 32), builds a combined mask from each group's `collides_with`, and applies both via `configure()`. `CDEntity.register_collision_handler` resolves group names to layer bits through `get_layer_for_group`.

---

## How to create a new entity

1. Scene root `extends CDEntity` (or a subclass).
2. Set `groups`, `collision_radius` / `collision_response`, axis locks, bounds clamping as needed.
3. Add `CDEntityComponent` children for behavior; group them under a `CDBody` to swap behavior sets.
4. If pooled: set the root scene on a `CDObjectPool`, acquire via `pool.acquire()` → `entity.activate()`, release via `entity.deactivate()`.

## How to create a new sleep/wake container

`CDBody` and `CDStage` are the two shapes. A new one follows the same structure:
- Extend the correct component base (`CDEntityComponent` for entity scope, `CDGameComponent` for game scope).
- In `_ready`: set `component_category` and call `super._ready()`.
- In `_on_initialize`: `_collect_children()` (recursive `find_children` for your child class) and apply `start_asleep`.
- `sleep()` / `wake()` early-out on current state and queue through `game.update.queue_sleep` / `queue_wake`.
- `_flush_sleep()` / `_flush_wake()` iterate `_children`, disconnect/reconnect each child's `_bus_connections` against the right bus, plus whatever enable/disable side-effects your child type needs.
- Provide `_disconnect_child` / `_reconnect_child` matching the `{signal_name, callable}` entry shape.

## How to add a new infrastructure singleton

- `class_name` it; `extends Node` (or `Node2D` if it needs a transform).
- Pick a `process_physics_priority` that places it correctly in the frame order above.
- Add a typed reference + a `_find_or_create(YourClass, "YourClass")` line inside `CDGame._ensure_infrastructure()` so it is auto-resolved/created.
- For **optional** nodes, resolve with `find_child(...)` instead of `_find_or_create(...)` and skip auto-create — components that depend on it must degrade gracefully when absent (the way `sound_bank` is handled).