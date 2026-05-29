# Core Base Classes

Four base classes that every V2 component extends. These are not game components — they define the lifecycle, reference resolution, and processing priority that all components inherit.

| Base Class | Extends | Attached To | Has Entity Ref | Has Game Ref |
|------------|---------|-------------|----------------|--------------|
| `CDEntityComponent` | Node2D | CDEntity | Yes | Yes |
| `CDGameComponent` | Node2D | CDGame | No | Yes |
| `CDCueCard` | Control | CDGame | No | Yes |
| `CDStageTrapdoor` | CDGameComponent | CDGame | No | Yes |

---

## CDEntityComponent — Entity Components

**Use when:** Your component lives as a child of a CDEntity (Brains, Legs, Arms, Guts, Faces, Voices).

### Two-Phase Lifecycle

**Phase 1 (`_ready`):** Resolves `entity` and `game` references, sets `process_physics_priority` from `component_category`. Does NOT connect signals — siblings may not exist yet.

**Phase 2 (`_on_initialize`):** Called deferred after all siblings' `_ready()` complete. This is where you connect entity bus signals, read sibling state, and start processing.

```
_ready()           → resolve refs, set priority, defer _initialize
_initialize()      → connect lifecycle signals, call _on_initialize()
_on_initialize()   → YOUR CODE HERE: connect signals, read siblings
```

### Virtual Methods

| Method | When It Fires | Override For |
|--------|--------------|--------------|
| `_on_initialize()` | After all `_ready()` calls complete | Connect signals, read sibling components |
| `_on_entity_deactivating()` | Entity is dying (pool return or free) | Reset state, disconnect from game bus |
| `_on_entity_activated()` | Entity recycled from pool | Re-enable processing, reconnect signals |

### Must-Includes for Every Subclass

1. Set `component_category` export in the editor scene
2. Override `_on_initialize()` for signal connections — never connect in `_ready()`
3. Override `_on_entity_deactivating()` to reset internal state (pooled entities retain stale values)
4. Override `_on_entity_activated()` if you disabled processing in deactivating

### Available References

- `entity: CDEntity` — parent entity (velocity API, bus signals, lifecycle)
- `game: CDGame` — ancestor game (game bus, group registry, collision matrix)

---

## CDGameComponent — Game Components

**Use when:** Your component lives as a child of CDGame (Directors, Goals, Speakers, Projectors).

Same two-phase lifecycle as CDEntityComponent but simpler:
- No `entity` reference (game components aren't attached to entities)
- No pool lifecycle hooks (game components persist for the game's lifetime)
- `_on_initialize()` is your one override point

### Must-Includes

1. Set `component_category` export in the editor scene
2. Override `_on_initialize()` to connect to game bus signals

---

## CDCueCard — UI Display Components

**Use when:** Your component displays game state as text (ScoreCard, LivesCard, TimerCard, WaveCard).

Extends **Control**, not Node2D — cue cards live in the UI layer, not the physics world. Fixed priority 70 (RULES).

### The Interface Pattern

Set `is_interface = true` to auto-create a child Label. Call `_update_label(text)` whenever state changes. The label is created programmatically — no scene setup needed.

### Must-Includes

1. Set `is_interface` if the card displays text
2. Connect to game bus signals in `_ready()` (cue cards can skip two-phase — game bus is Dictionary-based, no ordering issues)
3. Call `_update_label()` when state changes

---

## CDStageTrapdoor — Stage Spawners

**Use when:** You need to spawn entities into the game world (PointTrapdoor, EdgeTrapdoor, GridTrapdoor).

Extends CDGameComponent with a complete Trigger → Queue → Stagger → Spawn lifecycle. Start with this, override three virtuals.

### The Spawn Lifecycle

```
Game bus signal (e.g. "wave_start")
  → _on_trigger() queues N spawn indices
  → _physics_process() drains queue with stagger delay
  → _spawn_one() per index: acquire from pool or instantiate
  → "spawning_complete" emitted when queue empty
```

### Virtual Methods to Override

| Method | Returns | Purpose |
|--------|---------|---------|
| `_get_spawn_count(wave_number)` | `int` | How many entities to spawn this wave |
| `_get_spawn_position(index, total)` | `Vector2` | Where to place entity #index |
| `_get_spawn_scene(index, total)` | `PackedScene` | Which scene to spawn for index (null = skip) |

### Key Exports

| Export | Default | Purpose |
|--------|---------|---------|
| `pool` | null | Set to CDObjectPool for pooled spawning, null for fresh instantiate |
| `spawn_context` | null | CDSpawnContext resource for velocity/rotation on spawn |
| `telefrag` | false | Kill overlapping entities at spawn point before spawning |
| `stagger_delay` | 0.1 | Seconds between each entity spawn |

### Safe Zone Pattern

Trapdoors listen for `"zone_safe"` / `"zone_unsafe"` signals from SafeZoneMark components. When unsafe, spawning pauses (queue holds) until the zone clears. Prevents entities spawning on top of each other.

### Must-Includes

1. Set `component_category` to RULES (or let the base class do it in `_ready`)
2. Override `_get_spawn_scene()` — this is the one required virtual
3. Override `_get_spawn_count()` and `_get_spawn_position()` for anything beyond single-point spawning
4. Set `pool` export if spawning pooled entities (bullets, asteroids, invaders)