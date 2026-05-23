# Plan 19: V2 Core Infrastructure

## Overview

Foundation update for the V2 Composable Architecture. No gameplay components are built. The goal is a running Godot project where entities can be placed, physics resolves deterministically, the signal bus and collision matrix work, and input routes through the router.

---

## V1 Migration

The entire V1 architecture moves to `Godot/v1/` for reference. This includes all V1 scripts, scenes, and resources. V2 lives at the `Godot/` root level. Both coexist until full migration completes. The `project.godot` points to V2 autoloads and V2 main scene.

| V1 | V2 | Notes |
|----|-----|-------|
| `UniversalBody` | `CDEntity` | Adds velocity accumulator, entity bus, state machine |
| `UniversalGameScript` | `CDGame` | Adds game bus, editor-placed children |
| `UniversalComponent` / `UniversalComponent2D` | `CDComponent2D` | Adds priority auto-assignment |
| `GroupCache` (autoload) | `CDGroupRegistry` (editor node) | Same dirty-flag pattern, typed returns, spatial queries |
| `CollisionMatrix` | `CDCollisionMatrix` (editor node) | Data-driven via CDCollisionGroup resources |
| (none) | `CDCollisionBuffer` | New — deferred collision flush |
| (none) | `CDInputRouter` (autoload) | New — decoupled input routing |
| `CommonEnums` | `CDEnums` | Expanded with ComponentCategory, EntityState, GameState |

---

## V2 Error Handling Policy

**Engine components fail fast. Game/entity components push an error and continue.**

- **Engine components** (CDEntity, CDGame, CDComponent2D, CDCollisionMatrix, CDCollisionBuffer, CDGroupRegistry, CDInputRouter, CDEnums): These are the foundation. If they're misconfigured, the game cannot function correctly. Crash with a descriptive error immediately so the developer fixes it before anything else.
- **Game/entity components** (Brains, Legs, Arms, Guts, Faces, Stage): These are gameplay building blocks. A missing signal or bad config should `push_error()` and skip, allowing the developer to see the error in the output while continuing to test the rest of the game.

Rationale: Engine crashes prevent broken builds from shipping. Component-level graceful degradation maximizes development velocity — you can test five systems while the sixth has a config error.

---

## V2 Convention: Array Exports for All Multi-Value Config

All multi-value exports use `Array[Type]` by default, even when most instances will only have one entry. This includes signal connections, target groups, and any other configurable list.

```gdscript
# Standard V2 pattern for signal connections:
@export var move_signals: Array[StringName] = [&"move"]

func _ready():
    for sig_name in move_signals:
        if entity.has_signal(sig_name):
            entity.connect(sig_name, _on_move)
        else:
            push_error("%s: entity has no signal '%s'" % [name, sig_name])
```

The editor UX is a single field with a `[+]` button. No overhead for the common case (1 entry), full flexibility when needed.

---

## V2 Signal Architecture: Hybrid Bus System

**Two bus implementations, each optimized for its use case.**

### Entity Bus — Native `add_user_signal()`
- Fixed, small set of signals per entity: `"collision"`, `"collided_by"`, `"entity_deactivating"`, `"entity_activated"`, etc.
- High frequency (per-entity per-frame). Native C++ signal dispatch matters here.
- Typed signatures via `add_user_signal()`.
- Components connect to entity signals via `@export var` StringName arrays in `_on_initialize()`.

### Game Bus — Dictionary-based
- Configurable signal names. No registration or boilerplate needed.
- Low frequency (a few dozen events per frame total across all components). Dictionary overhead is negligible.
- `bus_emit()` with nothing connected = Dictionary miss = no-op.
- `bus_connect()` before anyone emits = works fine (auto-creates entry).
- Supports the configurable signal emission pattern from Plan 20 — components emit whatever StringName their exports specify.

### Cross-Bus Communication (4 Patterns)
1. **Priority Entity → Entity (physics):** Entity native bus → Entity native bus. No Dictionary involved.
2. **Entity → Game (Announcers):** Entity native listener → Game Dictionary emit. Announcer bridges.
3. **Game → Entity (Controllers):** Game Dictionary listener → Entity native emit. Controller bridges.
4. **Entity → Entity (non-physics):** Entity → Announcer → Dictionary → Controller → Entity. Two bridges.

---

## What Gets Built

### 1. CDEnums
**Type:** GDScript (class_name only, no base class)
**Purpose:** Shared enumerations for the entire V2 system.

| Enum | Values | Used By |
|------|--------|---------|
| `ComponentCategory` | `BRAIN`, `LEGS`, `ENTITY`, `ARMS`, `GUTS`, `FACE`, `STAGE` | CDComponent2D |
| `EntityState` | `ACTIVE`, `DEACTIVATING`, `INACTIVE` | CDEntity |
| `GameState` | `ATTRACT`, `PLAYING`, `PAUSED`, `GAME_OVER` | CDGame |
| `GameResult` | `VICTORY`, `DEFEAT`, `DRAW` | CDGame, Goals |
| `CountComparison` | `LESS_THAN`, `EQUAL_TO`, `GREATER_THAN`, `LESS_OR_EQUAL`, `GREATER_OR_EQUAL` | GroupCountGoal (Plan 20) |
| `Edge` | `TOP`, `BOTTOM`, `LEFT`, `RIGHT` | Spawners, screen utilities |
| `InputAction` | `MOVE`, `AIM`, `ACTION_PRESSED`, `ACTION_RELEASED` | CDInputRouter |

### 2. CDCollisionGroup
**Type:** Custom Resource (extends Resource)
**Purpose:** Defines a named collision group and its relationships.

| Property | Type | Description |
|----------|------|-------------|
| `group_name` | `StringName` | Identity (e.g., `&"player"`, `&"enemies"`) |
| `collides_with` | `Array[StringName]` | Groups this can hit. Empty = ghost (no collisions). |

### 3. CDComponent2D
**Type:** Extends Node2D
**Purpose:** Base class for ALL V2 components. Auto-assigns process priority based on category. Provides two-phase lifecycle to resolve signal timing.

**Cached references (V1 pattern — no runtime tree-walking):**
```gdscript
@onready var entity: CDEntity = CDEntity.find_ancestor(self)
@onready var game: CDGame = CDGame.find_ancestor(self)
```

**Priority mapping (set in `_ready()` based on `component_category`):**
| Category | Priority |
|----------|----------|
| `BRAIN` | 10 |
| `LEGS` | 20 |
| `ENTITY` | 30 (handled by CDEntity directly) |
| `ARMS` | 40 |
| `GUTS` | 50 |
| `FACE` | 60 |
| `STAGE` | 70 |

Component category is an export variable set for every CDComponent2D.

**Two-Phase Lifecycle:**

All CDComponent2D subclasses follow a deterministic two-phase initialization:

| Phase | Method | Timing | Purpose |
|-------|--------|--------|---------|
| 1 | `_ready()` | Immediate | Resolve references (`entity`, `game`), set process priority, register signals on the bus via `add_user_signal()` / `bus_connect()` |
| 2 | `_on_initialize()` | Deferred (end of frame) | Connect to signals that other components registered in Phase 1. Perform setup that depends on siblings being ready. |

```gdscript
func _ready():
    process_physics_priority = _category_to_priority(component_category)
    entity = CDEntity.find_ancestor(self)
    game = CDGame.find_ancestor(self)
    call_deferred("_initialize")

func _initialize():
    _on_initialize()

func _on_initialize():
    pass  # Override in subclass — connect to bus signals here
```

**Rationale:** Phase 1 guarantees all signals exist before Phase 2 connects to them. `call_deferred()` runs after all `_ready()` calls in the tree have completed, eliminating ordering issues between sibling components.

### 4. CDEntity
**Type:** Extends CharacterBody2D (Priority 30)
**Purpose:** Universal base for all physical entities.

**State Machine:** `ACTIVE` → `DEACTIVATING` → `INACTIVE`

**Default Node Structure:**
```
CDEntity (CharacterBody2D)
├── CollisionShape2D          # Default physics collision (circle, from @export collision_radius)
└── [CDComponent2D children]
```
- The default `CollisionShape2D` is a `CircleShape2D` created in `_ready()` from `@export var collision_radius: float = 8.0`.
- For simple entities (bullet, ball, paddle, asteroid, ship), this single shape IS the physics boundary. Group membership + Arms determine what happens on collision.
- For complex entities (brawler, boss), Area2D children can be added in the scene for separate HitBox/HurtBox zones. These are scene-level additions, not API-level.
- Components modify the collision shape through the Collision Shape API below — never by directly manipulating child nodes.

**Velocity Accumulator API:**
| Method | Description |
|--------|-------------|
| `request_velocity_set(vel: Vector2)` | Hard override. Last call wins. Discouraged — use only when a specific behavior requires it (e.g., EightWayWalk hard-stop). |
| `request_velocity_add(vel: Vector2)` | Soft add. Accumulates. Preferred for most Legs. |

**Collision Shape API:**
| Method | Description |
|--------|-------------|
| `set_collision_circle(radius: float)` | Replaces the default CollisionShape2D with a CircleShape2D of the given radius |
| `set_collision_polygon(points: PackedVector2Array)` | Replaces the default CollisionShape2D with a CollisionPolygon2D using the given points |
| `set_collision_rect(width: float, height: float)` | Replaces the default CollisionShape2D with a RectangleShape2D of given dimensions |

These methods manage the internal node tree so components don't couple to CDEntity's layout. The old shape node is freed, the new one is added as a child. Only the primary physics collision shape is affected — not Area2D HitBox/HurtBox children (those are managed by their own components).

**Position API:**
| Method | Description |
|--------|-------------|
| `request_position_set(pos: Vector2)` | Teleport to exact position. Applied after move_and_collide in Priority 30 step. Discouraged — use only when a specific behavior requires it (eg., snapping to a grid when initializing). |
| `request_position_add(offset: Vector2)` | Teleport by offset. Applied after move_and_collide. Used by grid step. |

**Physics Process (Priority 30):**
1. Apply `_accumulated_velocity` via `move_and_collide(delta)`.
2. Apply pending position set/add if present.
3. Clear velocity accumulator and position request.
4. Enforce axis locks and screen clamping.
5. If collision occurred, buffer it — do NOT emit signals.
6. Register with `CDCollisionBuffer`.

**`flush_collisions()`:**
1. For each buffered collision:
   - Emit `"collision(collider, normal)"` on own bus.
   - Emit `"collided_by(self, -normal)"` on collider's bus (if valid).
2. Clear buffer.

**`activate()` (pool lifecycle only):**
1. Set state to `ACTIVE`.
2. Enable all `CollisionShape2D` children.
3. Set `visible = true`, resume physics processing.
4. Emit `"entity_activated"` — components re-initialize (reset counters, reconnect game bus).

**Editor-placed entities** are born active. `activate()` is only called on pooled entities being pulled from a pool (see Plan 19.5).

**`deactivate()`:**
1. Set state to `DEACTIVATING`.
2. Disable all `CollisionShape2D` children via `set_deferred("disabled", true)`.
3. Emit `"entity_deactivating"` — components respond (reset state, disconnect from game bus).
4. **If `pool != null`:** Call `pool.release(self)`. Entity sleeps in pool (processing off, invisible, not freed).
5. **If `pool == null`:** `call_deferred("queue_free")`. Entity is destroyed.

The entity routes itself. Callers (Arms, Goals, Marks) always call `deactivate()` and don't need to know whether the entity is pooled.

**Entity Bus Signals:**
| Signal | Params | Description |
|--------|--------|-------------|
| `"collision"` | `(collider, normal)` | Buffered, fired at Priority 35 |
| `"collided_by"` | `(source, -normal)` | Inverse of collision, fired on collider |
| `"entity_deactivating"` | `()` | Entity is shutting down — components reset |
| `"entity_activated"` | `()` | Pooled entity is waking up — components re-initialize |

**Key Exports:**
| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `groups` | `Array[StringName]` | `[]` | Groups this entity belongs to. Applied on `_ready`. |
| `collision_radius` | `float` | `8.0` | Radius for the default CircleShape2D created in `_ready` |
| `lock_x` | `bool` | `false` | Lock X axis to spawn position |
| `lock_y` | `bool` | `false` | Lock Y axis to spawn position |

**Internal property (not exported — set by pool):**
| Property | Type | Description |
|----------|------|-------------|
| `pool` | `CDObjectPool` | Set by pool after instantiation. Null = not pooled (default). |

### 5. CDCollisionBuffer
**Type:** Node (editor-placed child of CDGame, `process_physics_priority = 35`)
**Purpose:** Defers collision signal emission until all entities have moved.

| Method | Description |
|--------|-------------|
| `register_entity(entity: CDEntity)` | Adds entity to this frame's flush queue |

**Process (Priority 35):**
1. Iterate `_entities_to_flush`.
2. For each valid entity, call `entity.flush_collisions()`.
3. Clear the list.

### 6. CDGroupRegistry
**Type:** Node (editor-placed child of CDGame, `process_physics_priority = 5`)
**Purpose:** Frame-cached, typed access to entity groups. Successor to V1's `GroupCache` autoload.

**V1 → V2 changes from GroupCache:**
- Typed returns: `Array[CDEntity]` instead of `Array`
- New spatial queries: `get_nearest()`, `get_nearest_to_entity()`
- Editor-placed node instead of autoload
- Same dirty-flag caching strategy

| Method | Return | Description |
|--------|--------|-------------|
| `mark_dirty(group_name: StringName)` | void | Invalidate cache for a group |
| `get_group(group_name: StringName) -> Array[CDEntity]` | Cached array | Frame-lazy, re-queries on dirty |
| `get_count(group_name: StringName) -> int` | Count | Uses cached group |
| `get_nearest(group_name: StringName, to_pos: Vector2) -> CDEntity` | Closest or null | Linear scan of cached group |
| `get_nearest_to_entity(group_name: StringName, entity: CDEntity) -> CDEntity` | Closest excluding self | Filters out querying entity |

**Signal Emissions:**
| Signal | Params | Description |
|--------|--------|-------------|
| `group_count_changed` | `(group_name: StringName, count: int)` | Emitted when a dirty group's count changes from previous frame |

**Process (Priority 5):**
1. For each dirty group, re-query and compare count to previous frame's count.
2. If count changed, emit `group_count_changed`.
3. Clear dirty flags.
4. Empty process loop when no groups are dirty — zero cost.

**Rationale for Priority 5:** CDGroupRegistry must emit count changes before any Brain (Priority 10) or Stage (Priority 70) components process. Priority 5 ensures group state is settled before any gameplay logic runs.

### 7. CDCollisionMatrix
**Type:** Node (editor-placed child of CDGame)
**Purpose:** Auto-configures physics layers from CDCollisionGroup resources. Engine component — fails fast on misconfiguration.

**Key Export:**
| Export | Type | Description |
|--------|------|-------------|
| `collision_groups` | `Array[CDCollisionGroup]` | All group definitions for this game |

**Startup Logic:**
1. Iterate `collision_groups`.
2. **If more than 32 groups:** `push_error("CDCollisionMatrix: 33 groups defined, but Godot supports a maximum of 32 physics layers. Remove a CDCollisionGroup or merge two groups that share collision behavior.")` and halt. This is an engine-level constraint — fail fast.
3. Assign each group a unique bit (layer 1–32).
4. For each group, build collision mask by OR-ing bits of all groups in `collides_with`.
5. Store mapping in `Dictionary[StringName, int]`.

**`configure(entity: CDEntity)`:** Called when entity enters tree. Reads entity's groups, sets `collision_layer` and `collision_mask`.

### 8. CDGame
**Type:** Extends Node2D
**Purpose:** Root node for every game scene. Manages state, game bus, provides access to shared systems.

**Editor-placed children (NOT auto-created — placed in editor for visibility and configuration):**
- `CDCollisionBuffer`
- `CDGroupRegistry`
- `CDCollisionMatrix`
- Zero or more `CDObjectPool` nodes (see Plan 19.5)

**Cached references:**
```gdscript
@onready var collision_buffer: CDCollisionBuffer = $CDCollisionBuffer
@onready var group_registry: CDGroupRegistry = $CDGroupRegistry
@onready var collision_matrix: CDCollisionMatrix = $CDCollisionMatrix
```

**Game State Machine:** `ATTRACT` → `PLAYING` → `GAME_OVER` (with `PAUSED` as overlay)

**Game Bus API (Dictionary-based — see V2 Signal Architecture section):**
```gdscript
var _bus: Dictionary = {}

func bus_connect(signal_name: StringName, callable: Callable):
    if not _bus.has(signal_name):
        _bus[signal_name] = []
    _bus[signal_name].append(callable)

func bus_disconnect(signal_name: StringName, callable: Callable):
    if _bus.has(signal_name):
        _bus[signal_name].erase(callable)

func bus_emit(signal_name: StringName, args: Array = []):
    if _bus.has(signal_name):
        for callable in _bus[signal_name]:
            callable.callv(args)
```

No registration needed. `bus_emit` with no connections = no-op. Configurable signal names work trivially. See V2 Signal Architecture section for cross-bus communication patterns.

**Key Methods:**
| Method | Description |
|--------|-------------|
| `start_game()` | ATTRACT → PLAYING, emits `"game_play"` on game bus |
| `end_game(result: GameResult)` | PLAYING → GAME_OVER, emits `"game_over"` with `[result]` on game bus |
| `reset_game()` | → ATTRACT, emits `"game_reset"` on game bus, reloads state |

**Key Exports:**
| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `game_bounds` | `Rect2` | Project viewport | Play area for clamping/wrapping |
| `collision_groups` | `Array[CDCollisionGroup]` | `[]` | Group definitions (forwarded to CDCollisionMatrix) |

### 9. CDInputRouter
**Type:** Autoload (extends Node)
**Purpose:** Decouples raw input from entity logic. Routes to player-specific signals.

**Signals:**
| Signal | Params |
|--------|--------|
| `input_move` | `(player_id: int, direction: Vector2)` |
| `input_aim` | `(player_id: int, direction: Vector2)` |
| `input_action_pressed` | `(player_id: int, action: StringName)` |
| `input_action_released` | `(player_id: int, action: StringName)` |

**Process:** Reads `Input` every frame, emits with `player_id` for multi-player filtering.

---

## Implementation Order

1. **CDEnums** — Pure data, no dependencies
2. **CDCollisionGroup** — Resource, no dependencies
3. **CDComponent2D** — Depends on CDEnums
4. **CDEntity** — Depends on CDComponent2D, CDEnums
5. **CDCollisionBuffer** — Depends on CDEntity
6. **CDGroupRegistry** — Depends on CDEntity. Successor to V1 GroupCache.
7. **CDCollisionMatrix** — Depends on CDCollisionGroup, CDEntity
8. **CDGame** — Depends on all above
9. **CDInputRouter** — Standalone autoload, can parallel with 4–8

---

## Proof / Testing

After all systems are built, create a test scene that proves:

1. **Entity Creation:** Two CDEntity nodes under CDGame. Both register with CDGroupRegistry.
2. **Collision Matrix:** `"player"` and `"enemies"` groups defined. Matrix configures layers. Entities collide correctly.
3. **Velocity Accumulator:** Debug Leg adds velocity via `request_velocity_add()`. Entity moves and stops.
4. **Position Set:** Debug grid Leg calls `request_position_add()`. Entity teleports by step. Happens at Priority 30, visible to Priority 35 collision flush.
5. **Collision Buffer:** Two entities collide. Signals fire at Priority 35, after both have moved.
6. **Entity Bus:** Debug Arm listens for `"collision"`. Receives it via native signal.
7. **Deactivation:** Arm calls `deactivate()` on target. Collision shapes disable. Entity freed at frame end.
8. **Pooled Deactivation/Activation:** CDObjectPool acquires entity, configures position, calls `activate()`. Arm calls `deactivate()` — entity returns to pool instead of being freed. Pool re-acquires same entity — `activate()` fires, `"entity_activated"` received by components. (Full pool proof test in Plan 19.5.)
9. **Input Router:** Key press → `input_move` emitted with correct direction and player_id.
10. **Collision Shape API:** Entity with default collision_radius of 8. Call `set_collision_polygon(polygon_points)` → default circle replaced with CollisionPolygon2D. Call `set_collision_rect(20, 10)` → replaced with RectangleShape2D. Collision matrix still works after shape swap.

---

## File Structure

```
Godot/
├── v1/                              # Entire V1 architecture preserved here
│   ├── Scripts/
│   ├── Scenes/
│   ├── Resources/
│   └── ...
├── Scripts/                          # V2 scripts
│   ├── Core/
│   │   ├── cdenums.gd               # CDEnums — shared enumerations
│   │   ├── cdentity.gd              # CDEntity — base entity
│   │   ├── cdgame.gd                # CDGame — game root
│   │   ├── cdcomponent2d.gd         # CDComponent2D — base component
│   │   ├── cdcollisionbuffer.gd     # CDCollisionBuffer — deferred collision flush
│   │   ├── cdgroupregistry.gd       # CDGroupRegistry — cached group queries
│   │   ├── cdcollisionmatrix.gd     # CDCollisionMatrix — auto layer config
│   │   ├── cdcollisiongroup.gd      # CDCollisionGroup — resource
│   │   └── cdinputrouter.gd         # CDInputRouter — autoload
│   ├── Brains/
│   ├── Legs/
│   ├── Arms/
│   ├── Guts/
│   ├── Faces/
│   └── Stage/
├── Scenes/                           # V2 scenes
├── Resources/                        # V2 resources
└── project.godot                     # Points to V2 autoloads, V2 main scene
```

---

## Risks & Open Questions

1. **32 Layer Limit:** Handled. CDCollisionMatrix fails fast with descriptive error if exceeded. Hard engine constraint, no graceful fallback possible.

2. **Velocity set vs add:** `request_velocity_set` is last-write-wins. Discouraged in favor of `add`. Documented in component specs as "use only when a specific behavior requires hard override."

3. **Position set during physics:** `request_position_set` / `request_position_add` are applied after `move_and_collide` in the Priority 30 step. This ensures grid entities teleport to their final position before the Priority 35 collision flush sees them. Grid collision checking (can I move to this cell?) is the responsibility of the grid Leg, which calls `test_move()` or physics query before submitting the position request.