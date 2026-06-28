# Core Infrastructure

The foundational runtime classes for V2. This folder holds the base entity type, the game root, and the singleton-style nodes that own collision, groups, input, pooling, audio, effects, and end-of-frame updates. Everything else in `scripts/` builds on top of these.

> Scope note: this README documents **only** the `.gd` files in this folder. It records what each class actually does in code. Classes referenced by these files but defined elsewhere (`CDEntityComponent`, `CDGameComponent`, `CDEnums`, `CDUtilities`, `CDCollisionGroup`, `CDSoundDef`, `CDNote`) are mentioned by their observed API surface only.

---

## Contents

| File | Class | Extends | One-line role |
|------|-------|---------|---------------|
| `cd_game.gd` | `CDGame` | `Node2D` | Root node of every game scene; state machine, game bus, owns infrastructure refs |
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

## Cross-cutting patterns (observed in this code)

These are recurring mechanics visible across the files, not invented conventions.

### 1. Two signal buses
- **Entity bus** lives on each `CDEntity` (`bus_connect` / `bus_disconnect` / `bus_emit`). Emitters are tracked in `CDEntity._signal_emitters`.
- **Game bus** lives on `CDGame` (`bus_connect` / `bus_disconnect` / `bus_emit` / `bus_emit_from`). `bus_emit_from` tracks the emitting entity in `CDGame._signal_emitters`.

Both `bus_connect` variants are idempotent (create the user signal if missing, guard against double-connect). `bus_emit` emits zero-argument signals.

`CDUpdater` clears `game._signal_emitters` at the end of every frame (after `_flush()`).

### 2. Physics-priority ordering
`_physics_process` order is driven by `process_physics_priority`. Hard-coded values seen here:

| Node | Priority | Why |
|------|----------|-----|
| `CDGroupRegistry` | `5` | Refresh dirty groups before anyone reads them |
| `CDEntity` | `30` | Resolve movement + collisions after components set velocity |
| `CDCollisionBuffer` | `35` | Flush collision signals after all entity physics |
| `CDUpdater` | `CDEnums.category_to_priority(CDEnums.ComponentCategory.UPDATE)` | Flush transitions after gameplay components finish |

### 3. Sleep / wake containers
`CDBody` and `CDStage` are structurally parallel:

| | `CDBody` | `CDStage` |
|---|----------|-----------|
| Extends | `CDEntityComponent` | `CDGameComponent` |
| Children collected | `CDEntityComponent` | `CDGameComponent` |
| Bus used | entity bus (`self.entity`) | game bus (`self.game`) |
| `sleep()` / `wake()` | queue via `game.update.queue_sleep/wake` | same |

Both:
- Run their component category as UPDATE / RULES respectively (set in `_ready`).
- Collect children recursively with `find_children("*", "<ClassName>")`.
- Support `start_asleep`; if set, they disable children immediately and defer bus disconnection until after children populate their `_bus_connections`.
- Implement `_flush_sleep()` / `_flush_wake()`, called by `CDUpdater` at end of frame. Sleep is flushed before wake so a same-frame `sleep→wake` resolves to awake.
- `_disconnect_child` / `_reconnect_child` walk each child's `_bus_connections` list (`{signal_name, callable}` entries) and disconnect/reconnect against the relevant bus.

`CDBody` additionally toggles collisions via `CDEntity.set_subtree_collisions(child, bool)` and calls `child._on_sleep()` / `child._on_wake()`. `CDStage` calls `child._on_sleep()` / `child._on_wake()` and, after wake, emits `on_wake_signal` on the game bus if set.

### 4. Deferred, frame-consistent mutations
Anything that could break group/collision consistency mid-frame is queued and flushed once at end of frame by `CDUpdater`:
- Group transitions (`queue_transition`) — removes/adds groups, marks them dirty in the registry, reconfigures collision layers, then emits entity and game exit/enter signals.
- Sleep/wake (`queue_sleep` / `queue_wake`) — deduped by membership check.

### 5. Robust game initialization
`CDGame._ensure_infrastructure()` resolves each required component by, in order: exact-name child lookup → script-type match anywhere under the game → auto-create with defaults (and `push_warning`). This means infrastructure nodes may be nested (e.g., inside a `CDStage`) and will still be found.

> **Optional refs** — `sound_bank` is the one exception to the auto-create rule: it is resolved by `find_child("CDSoundBank", ...)` only and is **never auto-created**. A game that needs procedural audio adds a `CDSoundBank` node (often nested in a `CDStage`); a game that doesn't simply omits it, and `sound_bank` stays `null`.

### 6. Pools + activation lifecycle
`CDEntity` carries a `pool` reference (null = not pooled). `CDObjectPool` pre-warms instances invisible and physics-disabled, then `CDEntity.activate()` / `deactivate()` (two-phase: mark → deferred `_complete_deactivation`) move entities in and out of the pool while re-registering groups and toggling collisions.

### 7. Collision layer indirection
Components never touch Godot layer numbers directly. `CDCollisionMatrix` assigns each `CDCollisionGroup` a unique bit (`1 << index`, max 32 groups), builds a combined mask from each group's `collides_with`, and applies both to `CollisionObject2D.collision_layer` / `collision_mask` via `configure()`. `CDEntity.register_collision_handler` resolves group names to layer bits through `get_layer_for_group`.

---

## File-by-file reference

### `CDGame` — game root
`class_name CDGame extends Node2D`

Root of every game scene. Owns the game bus, shared `blackboard`, the state machine, and references to the five infrastructure nodes.

**Exports**
| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `game_bounds` | `Rect2` | — | Play area used by entities for clamping/spawning |

**Infrastructure refs** (resolved in `_ready`): `collision_buffer`, `group_registry`, `collision_matrix`, `input_router`, `update` (all via `_ensure_infrastructure` — find-or-create) plus the optional `sound_bank: CDSoundBank` (find-only via `find_child`, never auto-created; stays `null` if absent).

**State machine** — `current_state` (`CDEnums.GameState`): `ATTRACT` → `PLAYING` → `GAME_OVER`, plus `PAUSED`. Setter emits `game_state_changed` on the bus. Observed transitions:
- `start_game()` — `ATTRACT`→`PLAYING`, unpauses tree, clears blackboard, emits `game_play`.
- `end_game(result)` — →`GAME_OVER`, pauses tree, stores `blackboard["game_result"]`, emits `game_over`.
- `_end_game_from_bus()` — reads `blackboard["game_result"]` (default `DEFEAT`) and calls `end_game`.
- `pause_game()` / `unpause_game()` — toggle `PAUSED`↔`PLAYING`.
- `reset_game()` — clears blackboard, `reload_current_scene()`.
- `_quit_game()` — `get_tree().quit()`.

**Setup behavior** (`_ready`): skips in editor hint; ensures infrastructure; sets `process_mode = ALWAYS` on itself, `PAUSABLE` on children, `ALWAYS` on `input_router`; pauses the tree; builds collision maps and configures all `CollisionObject2D`s; wires input router's `start_pressed`/`restart_pressed`/`quit_pressed` to `start_game`/`reset_game`/`_quit_game`; connects `game_over` → `_end_game_from_bus`; spawns a centered "PRESS ENTER TO START" `Label`.

**Bus API** — `bus_connect`, `bus_disconnect`, `bus_emit` (no emitter tracking), `bus_emit_from` (tracks emitter, warns if signal unregistered).

**Static** — `find_ancestor(node) -> CDGame`: walks parents to the nearest `CDGame`.

---

### `CDEntity` — base entity
`class_name CDEntity extends CharacterBody2D`

Accumulates per-frame movement requests from components, resolves them with `move_and_collide`, detects collisions, and emits collision signals. Priority `30`.

**Exports**
| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `groups` | `Array[StringName]` | `[]` | Groups this entity belongs to (registered on `_ready`) |
| `collision_radius` | `float` | `8.0` | Radius of the default `CircleShape2D` |
| `collision_response` | `CDEnums.CollisionResponse` | `SLIDE` | Default response: `SLIDE` / `BOUNCE` / `STOP` |
| `lock_x` / `lock_y` | `bool` | `false` | Zero velocity on that axis each frame |
| `clamp_to_bounds` | `bool` | `false` | Clamp position to `game.game_bounds` |
| `bounds_margin` | `float` | `0.0` | Inset inside bounds |
| `unlock_y_on` / `lock_y_on` | `Array[StringName]` | `[]` | Entity-bus signals toggling Y lock |
| `unclamp_bounds_on` / `clamp_bounds_on` | `Array[StringName]` | `[]` | Entity-bus signals toggling bounds clamping |

**Movement request API** (additive accumulates; set beats add; last setter wins)
| Method | Effect |
|--------|--------|
| `request_velocity_set(vel)` / `request_velocity_add(vel)` | Override / accumulate linear velocity |
| `request_angular_set(ang)` / `request_angular_add(ang)` | Override / accumulate angular velocity |
| `request_rotation_set(rot)` / `request_rotation_add(d)` | Snap / offset rotation (skips angular vel) |
| `request_position_set(pos)` / `request_position_add(off)` | Teleport / offset position (skips physics, resets interpolation) |

**Physics step** (`_physics_process`, only when `state == ACTIVE`): clears `_signal_emitters`; applies velocity add then set; applies axis locks; iterates `move_and_collide` up to `MAX_COLLISION_ITERATIONS` (4), each iteration checking for a registered collision handler (specific layers first, then catch-all `layers == 0`) and falling back to `_default_collision_response`; applies angular velocity, then rotation/position overrides; clamps to bounds; writes `position`/`rotation`/`velocity` to `blackboard`; registers self with the collision buffer if it has pending collisions; clears all accumulators/pending overrides.

**Lifecycle** — `state` is `CDEnums.EntityState` (`ACTIVE` / `DEACTIVATING` / `INACTIVE`).
- `deactivate()` — mark `DEACTIVATING`, disable physics, clear blackboard, defer `_complete_deactivation`.
- `_complete_deactivation()` — disable subtree collisions, emit `entity_deactivating`, remove from groups + mark dirty, then return to `pool.release(self)` (invisible, `INACTIVE`) or `queue_free()`.
- `activate()` — `INACTIVE`→`ACTIVE`, clear blackboard, enable subtree collisions, visible, physics on, re-add groups + mark dirty, emit `entity_activated`.

**Collision shapes** — `_create_default_collision_shape()` adds a `CircleShape2D` from `collision_radius`. Helpers `set_collision_circle(radius)`, `set_collision_polygon(points)`, `set_collision_rect(w,h)` clear existing shapes first.

**Collision handler registry**
- `register_collision_handler(target_groups: Array[StringName], handler: Callable)` — empty `target_groups` = catch-all. Resolves group names to layer bits via `game.collision_matrix.get_layer_for_group`.
- `unregister_collision_handler(handler)`.
- `_find_collision_handler(collider)` — specific-layer handlers first, then catch-all.

**Bus API** — `bus_connect`, `bus_disconnect`, `bus_emit` (tracks self in `_signal_emitters`).

**Entity bus signals** (defined in `_ready`): `collision(collider, normal)`, `collided_by(source, normal)`, `request_deactivate()`, `entity_deactivating()`, `entity_activated()`.

**Collision flushing** — `flush_collisions()` emits `collision` and the counterpart `collided_by` (with negated normal) for each pending collision; called by `CDCollisionBuffer` at priority `35`.

**Static helpers** — `set_subtree_collisions(node, enabled)` toggles deferred `disabled` on direct `CollisionShape2D`/`CollisionPolygon2D` children; `find_ancestor(node) -> CDEntity`.

---

### `CDBody` — entity-level sleep/wake container
`class_name CDBody extends CDEntityComponent`

Swaps entity behavior sets by sleeping/waking a group of child `CDEntityComponent`s without pooling/unpooling the entity. Component category is forced to `UPDATE` in `_ready` so it processes after children.

**Exports (`Control Signals` group)**
| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `start_asleep` | `bool` | `false` | Disable children before their first frame |
| `sleep_on` | `Array[StringName]` | `[]` | Entity-bus signals that trigger `sleep()` |
| `wake_on` | `Array[StringName]` | `[]` | Entity-bus signals that trigger `wake()` |

**API** — `sleep()` / `wake()` (idempotent, queue through `game.update`); `_flush_sleep()` / `_flush_wake()` (executed by `CDUpdater`). On flush, sleep disconnects each child's bus connections, disables subtree collisions, calls `child._on_sleep()`; wake reverses it.

---

### `CDStage` — game-level sleep/wake container
`class_name CDStage extends CDGameComponent`

Game-side analogue of `CDBody`: sleeps/wakes a group of child `CDGameComponent`s (e.g., for multi-level / remix content). Component category forced to `RULES` in `_ready`.

**Exports (`Control` group)**
| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `start_asleep` | `bool` | `false` | Disable children before their first frame |
| `on_wake_signal` | `StringName` | `&""` | Game-bus signal emitted after wake completes |

**API** — `sleep()` / `wake()` (idempotent, queue through `game.update`); `_flush_sleep()` / `_flush_wake()`. Flush disconnects/reconnects each child's `_bus_connections` against the **game** bus and calls `child._on_sleep()` / `child._on_wake()`. After wake, emits `on_wake_signal` on the game bus if set.

> Difference from `CDBody`: `CDStage` does **not** toggle collisions (it operates on game components, not entities) and targets the game bus rather than the entity bus.

---

### `CDUpdater` — end-of-frame flusher
`class_name CDUpdater extends Node`

Runs at `UPDATE` priority. Owns three queues flushed every `_physics_process`: pending group transitions, pending sleep, pending wake. After flushing it clears `game._signal_emitters`.

**API**
| Method | Effect |
|--------|--------|
| `queue_transition(entity, remove_groups, add_groups, entity_signals=[], game_signals=[])` | Remove/add groups, mark dirty in registry, reconfigure collision layers, then emit entity then game exit/enter signals |
| `queue_sleep(container)` | Queue a `CDBody`/`CDStage` to sleep (deduped) |
| `queue_wake(container)` | Queue a `CDBody`/`CDStage` to wake (deduped) |

Flush order per frame: transitions (FIFO) → sleep → wake (so same-frame sleep→wake ends awake).

---

### `CDCollisionBuffer` — collision signal flusher
`class_name CDCollisionBuffer extends Node`

Priority `35` (right after entity physics at `30`). Entities that detected collisions register themselves during their physics step; this node then calls `entity.flush_collisions()` on each and clears the list.

**API** — `register_entity(entity: CDEntity)` (called by `CDEntity._physics_process`).

---

### `CDCollisionMatrix` — layer/mask configurator
`class_name CDCollisionMatrix extends Node`

Maps `CDCollisionGroup` resources to physics bitmasks so code never touches raw layer numbers. Max 32 groups (one bit each via `1 << index`).

**Exports**
| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `collision_groups` | `Array[CDCollisionGroup]` | `[]` | One per collision type |
| `configure_signals` | `Array[StringName]` | `[]` | Game-bus signals that trigger `configure_static_bodies()` |

**API**
| Method | Effect |
|--------|--------|
| `build_maps()` / `_build_maps()` | Build `_layer_map` (group→bit) and `_mask_map` (group→combined mask) |
| `get_layer_for_group(name) -> int` | Resolve a group name to its layer bit |
| `configure(node: CollisionObject2D)` | Set `collision_layer`/`collision_mask` from the node's groups |
| `configure_static_bodies()` | Scan tree, configure all non-`CDEntity` `CollisionObject2D`s in known groups |

On `_ready`: builds maps, connects `configure_signals` on the `cd_game` group node, and configures static bodies once.

---

### `CDGroupRegistry` — frame-cached group access
`class_name CDGroupRegistry extends Node`

Priority `5` — refreshes dirty groups before any component reads them. Emits `group_count_changed(group_name, count)` only when a count actually changes.

**API**
| Method | Effect |
|--------|--------|
| `mark_dirty(group_name)` | Invalidate cache for a group (called when entities join/leave) |
| `get_group(name) -> Array[CDEntity]` | Typed membership (auto-refreshes if dirty) |
| `get_count(name) -> int` | Membership count |
| `get_nearest(name, to_pos) -> CDEntity` | Closest entity in group to a world position |
| `get_nearest_to_entity(name, entity) -> CDEntity` | Closest entity in group to another entity (excludes self) |

---

### `CDInputRouter` — input → signals
`class_name CDInputRouter extends Node`

Pure signal emitter. `process_mode = ALWAYS` so system buttons work while paused. Polls system buttons every physics frame; gameplay input is skipped when `get_tree().paused`.

**Signals**
| Signal | When |
|--------|------|
| `input_move(player_id, direction)` | Movement vector each frame |
| `input_aim(player_id, direction)` | Aim vector (only when non-zero) |
| `input_action_pressed/released(player_id, action)` | Tracked action edge |
| `start_pressed` / `restart_pressed` / `quit_pressed` / `pause_pressed` | System buttons (always) |

**Exports**
| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `player_count` | `int` | `1` | `1` = no prefix; `2+` = `p1_`/`p2_` action prefixes |
| `tracked_actions` | `Array[StringName]` | `[&"fire"]` | Gameplay actions to track for press/release |

Expected Godot Input actions: `start`, `restart`, `quit`, `pause`, and per-player `<prefix>move_left/right/up/down`, `<prefix>aim_left/right/up/down`, `<prefix><action>`.

---

### `CDObjectPool` — per-type entity pool
`class_name CDObjectPool extends Node`

Pre-warms instances of one `PackedScene` to avoid runtime allocation. Created instances are invisible with physics and collision shapes disabled.

**Exports**
| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `scene` | `PackedScene` | — | Entity scene to instantiate |
| `initial_size` | `int` | `50` | Pre-warm count |
| `grow_by` | `int` | `5` | Grow amount when empty |
| `max_size` | `int` | `0` | Hard cap (`0` = unlimited) |

**API** — `acquire() -> CDEntity` (grows up to `max_size`, returns `null` at cap); `release(entity)` (called by `CDEntity._complete_deactivation`); `get_active_count()` / `get_available_count()` / `get_total_count()`. `_exit_tree` frees every entity.

Acquired entities get `pool = self` set at creation; activation/visibility/collisions are managed by `CDEntity.activate()`/`deactivate()`.

---

### `CDEffect` — one-shot visual effect
`class_name CDEffect extends Node2D`

Attach particles/sprites as children; the node auto-frees after `lifetime`.

**Exports**
| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `lifetime` | `float` | `1.0` | Seconds before `queue_free` (`<= 0` = never auto-free) |
| `colors` | `Array[Color]` | `[]` | Palette for `get_random_color()` |

**API** — `get_random_color() -> Color` (random from `colors`, or `Color.WHITE` if empty).

---

### `CDSoundBank` — procedural audio engine
`class_name CDSoundBank extends CDGameComponent`

Generates all SFX at runtime via `AudioStreamGenerator` (no audio files). Uses an internal `Voice` class per channel, output on the `CD_Audio` bus.

**Constants**
| Constant | Value | Meaning |
|----------|-------|---------|
| `MIX_RATE` | `11025` | Generation sample rate |
| `MAX_CONTINUOUS` | `4` | Continuous voice pool size |
| `MAX_FILL_PER_FRAME` | `256` | Frames pushed per voice per `_process` |
| `MAX_INITIAL_FILL` | `128` | Initial fill to prevent gaps |
| `POSITIONAL_DISTANCE` / `GLOBAL_DISTANCE` | `2000.0` / `2000000.0` | `AudioStreamPlayer2D.max_distance` for positional vs. global sounds |

Reverb delay lines (at `MIX_RATE`): `REVERB_DELAY_1=1102` (100ms), `REVERB_DELAY_2=1654` (150ms), `REVERB_DELAY_3=2205` (200ms); `REVERB_FEEDBACK=0.3`, `REVERB_MIX=0.4`.

**Exports** — `max_channels: int = 8` (one-shot voice count; lower for arcade authenticity).

**Voice pools / registries**
- `_voices` — one-shot pool (`max_channels`).
- `_continuous_pool` — continuous/looped pool (`MAX_CONTINUOUS`).
- `_sound_registry` — active one-shots keyed by `CDSoundDef` instance id (dedup).
- `_continuous_registry` — active continuous voices keyed by signature string.
- `_has_active` gates `_process` (lazily enabled via `_ensure_process`, disabled when nothing is active).

**One-shot API** — `play_one_shot(def: CDSoundDef, sound_position, positional, exclusive, caller_id) -> bool`.
- Empty `def.notes` → `false`.
- If the same `CDSoundDef` is already playing: `exclusive` → skip (`false`); otherwise restart from the beginning (arcade-style overlap stutter).
- Otherwise allocate an idle voice (reclaiming a draining voice if all busy), register it, configure wave/effect/volume/reverb, and start jingle sequencing at note 0.
- Supports multi-note **jingles** (`_advance_jingle`) with optional **glide/portamento** between notes (continuous phase accumulation so glides stay smooth).
- After generation completes, voices enter **drain mode** to let the buffer finish playing before `_release_voice`.

**Continuous API** — looped sounds, ref-counted so multiple sources share one voice:
- `start_continuous(signature, wave_shape, effect, note, volume, source_id, sound_position, positional) -> bool` — dedup by signature; increments ref count and stores source position; switches to global distance when >1 source.
- `stop_continuous(signature, source_id)` — decrements ref count; fully stops at 0, restores positional audio back at 1.
- `pause_continuous` / `resume_continuous(signature, source_id)` — pauses the player only when all sources are paused.
- `update_continuous_position(signature, source_id, sound_position)` — updates source position; moves the player if single source.

**Sample generation** — `_get_sample(voice, t)` applies glide frequency interpolation, `CDUtilities.apply_freq_effect`, `CDUtilities.wave_sample`, `CDUtilities.apply_amp_effect`, and the per-voice reverb delay buffer (3-tap sum with feedback, dry/wet mix).

**`Voice` inner class** — per-voice state: `player`, `gen`, `playback`, `active`, `frame_pos`, `shot_end`, `phase`, `cached_freq`, `wave_shape`, `effect`, `volume`, `sound_id`, `source_id`, jingle state (`note_index`, `notes`, `note_frame_start`), glide state, drain state, reverb buffer, and continuous state (`continuous`, `ref_count`, `source_ids`, `paused_sources`).

---

## How to use this folder

### Minimum game scene
A `CDGame` root with a configured `game_bounds`. `CDGame` will find-or-create `CDCollisionBuffer`, `CDGroupRegistry`, `CDCollisionMatrix`, `CDInputRouter`, and `CDUpdater` automatically (emitting a warning for each auto-created node). To customize any of them, add the node as a child (optionally nested in a `CDStage`) and configure it in the editor.

`CDSoundBank` is **optional** and never auto-created — add one as a child (anywhere under the game, often nested in a `CDStage`) only if the scene needs procedural audio.

### Typical runtime flow per physics frame
1. **Priority 5** — `CDGroupRegistry` refreshes dirty groups.
2. **Components** — entity/game components read groups/input, call `request_velocity_*` etc. on entities, and emit on the entity/game buses.
3. **Priority 30** — each `CDEntity` resolves accumulated movement, runs `move_and_collide`, detects collisions, registers with `CDCollisionBuffer`.
4. **Priority 35** — `CDCollisionBuffer` flushes each entity's `collision` / `collided_by` signals.
5. **UPDATE priority** — `CDUpdater` flushes group transitions and sleep/wake, then clears `game._signal_emitters`.

### Adding a new entity
1. Create a scene whose root script `extends CDEntity` (or a subclass).
2. Set `groups`, `collision_radius` / `collision_response`, axis locks, and bounds clamping as needed.
3. Add `CDEntityComponent` children for behavior; optionally group them under a `CDBody` to swap behavior sets.
4. If pooled, set the root's scene on a `CDObjectPool` and acquire via `pool.acquire()` → `entity.activate()`; release via `entity.deactivate()`.

### Adding a new sleep/wake container
`CDBody` and `CDStage` are the two existing shapes. To add another, follow the same structure observable in those files:
- Extend the correct component base (`CDEntityComponent` for entity scope, `CDGameComponent` for game scope).
- In `_ready`, set the desired `component_category` and call `super._ready()`.
- In `_on_initialize`, `_collect_children()` (recursive `find_children` for your child class) and apply `start_asleep`.
- Provide `sleep()` / `wake()` that early-out on current state and queue through `game.update.queue_sleep` / `queue_wake`.
- Implement `_flush_sleep()` / `_flush_wake()` iterating `_children`, disconnecting/reconnecting each child's `_bus_connections` against the appropriate bus (`self.entity` vs `self.game`), plus whatever enable/disable side-effects your child type needs.
- Provide `_disconnect_child` / `_reconnect_child` matching the `{signal_name, callable}` entry shape.

### Adding a new infrastructure singleton
If you need another always-present node discovered by `CDGame`:
- `class_name` it and `extends Node` (or `Node2D` if it needs a transform).
- Pick a `process_physics_priority` that places it correctly in the frame order above.
- Add a typed reference variable + a `_find_or_create(YourClass, "YourClass")` line inside `CDGame._ensure_infrastructure()` so it is auto-resolved/created the same way as the others.

> If the node is **optional** (not every scene needs it), resolve it with `find_child(...)` instead of `_find_or_create(...)` and skip the auto-create fallback, the way `sound_bank` is handled. Components that depend on it should degrade gracefully when it's absent.

> Keep it grounded: only add fields/methods you can see analogues for in the existing files. Do not invent new bus mechanisms, pooling strategies, or collision handling beyond the patterns above.