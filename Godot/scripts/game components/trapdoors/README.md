# Trapdoors — Stage-Level Entity Spawners

3 concrete trapdoor components that spawn entities into the game world. All extend `CDStageTrapdoor` which provides the Trigger → Queue → Stagger → Spawn lifecycle with telefrag and safe zone support.

---

## CDStageTrapdoor Lifecycle

```
trigger_signal (e.g. "wave_start")
  → _on_trigger(wave_number)
	  → _get_spawn_count(wave_number)      # how many to spawn
	  → build _spawn_queue of indices
	  → set_physics_process(true)

_physics_process(delta)
  → hold if _zone_is_safe == false
  → pop index from queue
  → _spawn_one(index)
	  → _get_spawn_scene(index, total)     # which scene to spawn (null = skip)
	  → _get_spawn_position(index, total)  # where to place it
	  → telefrag check (optional)
	  → apply spawn_context (velocity/rotation)
	  → activate entity (pool or fresh instantiate)
  → emit "spawning_complete" when queue empty
```

### Virtual Methods — Override These

| Method | Returns | Purpose |
|--------|---------|---------|
| `_get_spawn_count(wave_number)` | `int` | How many entities to queue for this wave |
| `_get_spawn_position(index, total)` | `Vector2` | World position for entity at this index |
| `_get_spawn_scene(index, total)` | `PackedScene` | Scene to instantiate (null = skip slot) |

### Must-Includes When Creating Trapdoors

1. Extend `CDStageTrapdoor`
2. Override at minimum `_get_spawn_scene()` (required) and `_get_spawn_position()`
3. Override `_get_spawn_count()` if using equation-based counts
4. Call `super._on_initialize()` if overriding initialization
5. Use `CDUtilities.evaluate_int()` for equation-based spawn counts
6. Set `trigger_signals` to connect wave start signals

### Base Class Features

| Feature | Details |
|---------|---------|
| **Stagger** | `stagger_delay` spaces out entity creation across frames |
| **Pooling** | Optional `pool` (CDObjectPool) for reused entities |
| **Spawn context** | Optional `CDSpawnContext` for initial velocity/rotation |
| **Telefrag** | `telefrag` kills overlapping entities at spawn point via physics query |
| **Safe zone** | Pauses spawning while `zone_unsafe` signal is active |
| **Mixed spawning** | `spawn_scenes: Array[PackedScene]` cycles through scene types per slot |
| **Completion** | Emits `spawning_complete` with wave number when queue drains |

### Mixed Spawning (`spawn_scenes`)

The base class supports two spawn modes:

| Export | Behavior |
|--------|----------|
| `spawn_scene: PackedScene` | All entities are the same type (original behavior) |
| `spawn_scenes: Array[PackedScene]` | Each slot cycles through the array (modulo length) |

When `spawn_scenes` is populated, `_get_spawn_scene(index, total)` returns `spawn_scenes[index % spawn_scenes.size()]`. Any remaining slots fall back to `spawn_scene`. This enables mixed-type spawning (e.g., bug/wasp/spider patterns) from a single trapdoor without subclassing.

**Example:** `spawn_scenes = [bug, wasp, wasp]` with count 12 produces: bug, wasp, wasp, bug, wasp, wasp, bug, wasp, wasp, bug, wasp, wasp (4 bug + 8 wasp).

---

## Components

### EdgeTrapdoor — Perimeter Spawn Points

Spawns entities evenly distributed along selected edges of the game bounds. Supports jitter for randomization.

| Feature | Details |
|---------|---------|
| **Edges** | Configurable array of `CDEnums.Edge` (TOP, RIGHT, BOTTOM, LEFT) |
| **Distribution** | Even spacing along continuous perimeter with optional `jitter` lerp |
| **Count** | Equation string evaluated via `CDUtilities.evaluate_int()` |
| **Scene** | Single `spawn_scene` for all entities |

### GridTrapdoor — 2D Grid Layout

Spawns entities in a centered grid. Two modes: **Mode A** (data-driven via `CDGridLayout` resource) or **Mode B** (math-driven via `CDGridEquation` resource).

| Feature | Details |
|---------|---------|
| **Mode A** | `CDGridLayout` resource maps cells to scenes (null = skip) |
| **Mode B** | `CDGridEquation` + `spawn_scene` with random skip chance and min skips per row |
| **Sizing** | `cell_size` + `cell_spacing` determine grid geometry |
| **Centering** | Grid is centered on the trapdoor's `global_position` |
| **Override** | Replaces `_on_trigger()` for two-mode dispatch |

### PointTrapdoor — Single Point Spawn

Spawns entities at its own position with optional random offset range. Simplest trapdoor.

| Feature | Details |
|---------|---------|
| **Position** | `global_position` ± random offset within `offset_range` |
| **Count** | Equation string evaluated via `CDUtilities.evaluate_int()` |
| **Scene** | Single `spawn_scene` for all entities |
