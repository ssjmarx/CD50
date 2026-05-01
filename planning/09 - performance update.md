# Performance Update

**Status:** ✅ Complete  
**Started:** 2026-04-20  
**Completed:** 2026-04-30  
**Depends On:** None (can be done at any time)  
**Unblocks:** Space Invaders & Tetris game composition (Plan 07) — recommended before composing large-entity-count games

---

## Background

A full performance audit of the GD50 codebase identified one critical pattern and five medium-priority issues. The critical issue — `get_nodes_in_group()` called every frame by up to 15 scripts simultaneously — will cause GC stutter and frame time spikes once Space Invaders (55+ entities) is composed. The medium issues are hygiene fixes that improve code quality alongside performance.

The project's rendering configuration (640×360, GL Compatibility, pixel snapping, physics interpolation) is well-chosen and needs no changes. The signal-driven architecture (Brain → Body → Leg/Arm routing) is correct and should NOT be optimized — signal overhead is negligible at current and projected entity counts.

---

## Phase 1: GroupCache Autoload (Highest Impact)

### Problem

`get_tree().get_nodes_in_group()` allocates a new Array on every call. Fifteen call sites across the codebase call it every frame. In a game with multiple AI brains (Dogfight, Space Invaders), this creates 20+ array allocations per frame, each requiring the engine to walk its internal group structure.

### Solution

A lazy dirty-flag cache autoload. One `Dictionary[String, Array]` that stores the cached group arrays. A `Dictionary[String, bool]` tracks which groups are dirty. On lookup, dirty groups are refreshed from `get_nodes_in_group()` and cached; clean groups return the cached array directly.

### Implementation

#### 1.1 Create `Scripts/Core/group_cache.gd` — Autoload

```gdscript
# Lazy dirty-flag cache for group node lookups. Avoids repeated get_nodes_in_group() allocations.
# Mark groups dirty when nodes enter/exit the tree or add_to_group() is called.
extends Node

var _cache: Dictionary = {}     # {group_name: Array[Node]}
var _dirty: Dictionary = {}     # {group_name: bool}

func mark_dirty(group_name: String) -> void:
    _dirty[group_name] = true

func get_group(group_name: String) -> Array:
    if _dirty.get(group_name, true):
        _cache[group_name] = get_tree().get_nodes_in_group(group_name)
        _dirty[group_name] = false
    return _cache[group_name]

func get_count(group_name: String) -> int:
    return get_group(group_name).size()
```

Register as autoload in `project.godot`.

#### 1.2 Mark Dirty in `UniversalBody`

Add to `_enter_tree()` and `_exit_tree()` — mark all `collision_groups` dirty on enter/exit.

#### 1.3 Mark Dirty in `wave_spawner.gd`

After each `enemy.add_to_group(group)` call in `_spawn_one()`, call `GroupCache.mark_dirty(group)`.

#### 1.4 Add Helper Methods to Base Components

In `UniversalComponent` and `UniversalComponent2D`:

```gdscript
func get_group_nodes(group_name: String) -> Array:
    return GroupCache.get_group(group_name)

func get_group_count(group_name: String) -> int:
    return GroupCache.get_count(group_name)
```

#### 1.5 Update All Call Sites

| Script | Change |
|--------|--------|
| `group_monitor.gd` | Replace `get_tree().get_nodes_in_group()` with `get_group_count()` |
| `group_count_multiplier.gd` | Replace with `get_group_count()` |
| `interceptor_ai.gd` | Replace with `get_group_nodes()` |
| `aim_ai.gd` | Replace with `get_group_nodes()` |
| `shoot_ai.gd` | Replace with `get_group_nodes()` |
| `shoot_ai_swarm.gd` | Replace with `get_group_nodes()` |
| `music_ramping.gd` | Replace with `get_group_count()` (init) and `get_group_nodes().size()` (process) |
| `swarm_controller.gd` | Replace all 4 call sites with `get_group_nodes()` / `get_group_count()` |
| `wave_spawner.gd` (safe zone) | Replace with `get_group_nodes()` |
| `variable_tuner_global.gd` | Replace with `get_group_nodes()` |
| `grid_movement.gd` | Replace with `get_group_nodes()` |

**Note:** The returned Array is read-only. Callers must NOT modify it. If mutation is needed, use `.duplicate()`.

---

## Phase 2: Easy Wins (Low Risk, Immediate Benefit)

### 2.1 `split_on_death.gd` — Preload via PackedScene Export

**Problem:** `load()` called at death time. In Asteroids, a chain of splits causes 5 rapid `load()` calls.

**Fix:** Replace `@export var fragment_path: String` with `@export var fragment_scene: PackedScene`. Resources loaded via `@export` are loaded at scene import time (zero runtime cost) and shared across all instances (Godot's resource cache). Remove the runtime `load()` call.

```gdscript
# Before:
@export var fragment_path: String = ""
# In _on_parent_died:
var fragment_scene: PackedScene = load(fragment_path)

# After:
@export var fragment_scene: PackedScene
# In _on_parent_died:
if fragment_scene == null: return
var fragment = fragment_scene.instantiate()
```

This is also a design improvement — type-safe, editor-validated, no string paths.

**Note:** All scene files that reference `fragment_path` will need updating to use `fragment_scene` in the editor.

### 2.2 `group_count_multiplier.gd` — Change-Only Update

**Problem:** Sets `game.current_multiplier` every frame even when unchanged. The setter has a guard (`if _value != _current`), but the group lookup still happens.

**Fix:** Add a local cache of the last-set value. Only update when count changes.

```gdscript
var _last_count: int = -1

func _physics_process(_delta):
    var count = get_group_count(target_group)
    if count != _last_count:
        _last_count = count
        game.current_multiplier = count
```

Combined with the GroupCache from Phase 1, this is essentially free when nothing changes.

### 2.3 `health.gd` — Single-Pass Die()

**Problem:** `get_children()` called twice in `die()` — once for collision shapes, once for process disabling.

**Fix:** Merge into one loop:

```gdscript
func die() -> void:
    parent.hide()
    if "velocity" in parent:
        parent.velocity = Vector2.ZERO
    for child: Node in parent.get_children():
        if child != self:
            child.process_mode = Node.PROCESS_MODE_DISABLED
        if child is CollisionShape2D or child is CollisionPolygon2D:
            child.set_deferred("disabled", true)
        elif child is Area2D:
            for shape: Node in child.get_children():
                if shape is CollisionShape2D or shape is CollisionPolygon2D:
                    shape.set_deferred("disabled", true)
    parent.queue_free()
```

---

## Phase 3: WaveSpawner Batch Spawning (Medium Refactor)

### Problem

For GRID spawns (32×6 = 192 entities), the current code creates 192 SceneTree timers and 192 lambda closures. Each timer is tracked by the engine until it fires.

### Solution

Replace timer-per-entity with a process-driven queue. A single `_process` function counts down and spawns one entity per stagger interval.

### Implementation

New member variables:

```gdscript
var _spawn_queue: Array[int] = []
var _spawn_timer: float = 0.0
var _spawn_wave_num: int = 0
```

Replace the spawning loop in `_on_spawning_wave()`:

```gdscript
# Before:
for i in spawn_count:
    var delay = i * stagger_delay
    get_tree().create_timer(delay).timeout.connect(func(): _spawn_one(wave_number, i, spawn_count))

# After:
_spawn_queue.clear()
for i in spawn_count:
    _spawn_queue.append(i)
_spawn_wave_num = wave_number
_spawn_timer = 0.0
set_process(true)
```

New `_process` function:

```gdscript
func _process(delta: float) -> void:
    if _spawn_queue.is_empty():
        set_process(false)
        return
    _spawn_timer -= delta
    while _spawn_timer <= 0.0 and not _spawn_queue.is_empty():
        var index: int = _spawn_queue.pop_front()
        _spawn_one(_spawn_wave_num, index, spawn_count - _spawn_queue.size())
        _spawn_timer += stagger_delay
```

**Note:** `_spawn_one` needs the total count for the "last spawn" check (`index == total - 1`). Adjust to detect queue empty instead, or pass the total at queue creation time.

**Note:** Spawning is now frame-based, not physics-tied. For visual staggering this is correct. If any game needs physics-tied spawning, use `_physics_process` instead.

**Games to test after this change:**
- Pong (ball spawn at game start, stagger_delay)
- Breakout (brick grid, no stagger)
- Asteroids (wave spawning with stagger)
- Dogfight (enemy wave spawning)
- Breaksteroids (asteroid grid)
- Pongout (brick grid + ball)

---

## Phase 4: SoundSynth Performance (Arcade Audio Optimization)

### Problem

When composing Space Invaders (55 UFO entities, each with a CONTINUOUS SoundSynth component), three performance issues were identified:

1. **Voice explosion:** 55 identical synths all generating audio simultaneously — only the engine's AudioStreamPlayer limit prevented all 55 from playing. At 55 simultaneous `_get_sample()` loops, frame time spiked massively.
2. **Buffer-fill burst:** When 6 voices all started playing at once, the first `_process()` frame saw ~1000+ available frames per voice. With 6 voices: ~6553 `_get_sample()` calls in a single frame — causing a noticeable stutter at spawn.
3. **Identical sound layering:** 6 identical CONTINUOUS synths playing the same waveform caused audio artifacts (intermittent hitching from phase interference).

### Solution: Three-Tier Audio Optimization

Modeled after real arcade hardware, which had 1-3 sound channels total. Sounds were shared across all instances of the same entity type.

#### 4.1 Voice Limiting (`MAX_VOICES = 6`)

A static voice counter caps the total number of simultaneously active synths:

```gdscript
const MAX_VOICES: int = 6
static var _active_voices: int = 0
var _voice_active: bool = false
```

- CONTINUOUS: Only starts if under the voice cap; otherwise stays silent with `_process` disabled
- ON_SIGNAL: `play_one_shot()` returns early (drops the sound) if voice cap is reached
- Voices freed when one-shot finishes or entity exits tree (`_exit_tree`)

#### 4.2 Fill Rate Cap (`MAX_FILL_PER_FRAME = 256`)

Prevents the initial buffer-fill burst by capping samples generated per frame:

```gdscript
const MAX_FILL_PER_FRAME: int = 256  # ~11.6ms at 22050Hz
var to_fill = mini(_playback.get_frames_available(), MAX_FILL_PER_FRAME)
```

- Applied in all three fill locations (CONTINUOUS process, ON_SIGNAL process, play_one_shot initial fill)
- Burst dropped from ~6553 to 6 × 256 = 1536 max
- Buffer catches up smoothly over subsequent frames — completely inaudible

#### 4.3 CONTINUOUS Deduplication Registry

Only one synth per unique sound profile plays at a time. Identical CONTINUOUS synths register in a static dictionary:

```gdscript
static var _continuous_registry: Dictionary = {}  # signature -> WeakRef to self
var _signature: String = ""  # "{wave_shape}_{effect}_{note}"
```

- **`_try_claim_continuous()`**: Checks if an identical synth is already registered. If yes, stays silent but keeps `_process` running to detect slot openings
- **Slot takeover**: Blocked synths check the registry each frame via `WeakRef.get_ref()`. If the registered synth dies, the first blocked synth claims the slot
- **`_exit_tree()`**: Releases voice and removes registry entry

**Result:** 55 UFOs with identical `SQUARE/WARBLE/C4` config → exactly **1** plays. Combined with voice limiting and fill rate cap, the synth system scales to any number of entities.

### Impact

| Metric | Before | After |
|--------|--------|-------|
| Active synths at 55 UFOs | 55 | 1 (dedup) + max 6 (voice cap) |
| `_get_sample()` calls at spawn | ~60,000 | ~256 (fill cap) |
| Spawn stutter | Severe | None |
| Sustained audio hitching | Yes (layering) | No (dedup) |
| Stress test limit (smooth) | ~55 entities | ~150 entities (2000+ = engine ceiling) |

---

## Phase 5: Verify (No Code Changes)

- [x] Run each game with Godot's built-in profiler
- [x] Confirm `get_nodes_in_group()` allocations are eliminated (GroupCache autoload)
- [x] Test Space Invaders with 55+ entities — smooth after SoundSynth optimization
- [x] Stress test: 150 UFOs seamless, 2000+ = engine physics ceiling (not a code issue)

---

## What We're NOT Doing (And Why)

| Considered | Decision | Reason |
|------------|----------|--------|
| Signal chain optimization | ❌ Skip | Signal overhead is ~5ms/sec at 55 entities. Negligible. The routing layer provides axis locks, 1:many fan-out, and brain/leg decoupling. Not worth losing. |
| Object pooling for bullets/entities | ❌ Skip | Entity counts are too low (max ~4 bullets per gun, ~200 bricks at peak). Pooling adds complexity for zero measurable gain. |
| Custom physics | ❌ Skip | `move_and_collide()` is ideal for arcade games. No benefit to bypassing it. |
| Spatial partitioning for AI targeting | ❌ Skip | Entity counts per group are <60. Linear scan is faster than maintaining a spatial index at this scale. May revisit if games exceed 200+ entities per group. |

---

## Expected Impact

| Phase | GC Allocations Eliminated | Frame Time Savings | Risk |
|-------|--------------------------|-------------------|------|
| Phase 1 (GroupCache) | ~20 arrays/frame in Dogfight, ~60+ in Space Invaders | 2-5ms/frame at 55 entities | Low — drop-in replacement |
| Phase 2 (Easy wins) | ~5 allocations per asteroid death chain | <1ms | Very low — single-file changes |
| Phase 3 (WaveSpawner) | ~200 timer objects per grid spawn | <1ms (but cleaner memory profile) | Medium — needs testing across all games |
| Phase 4 (SoundSynth) | ~60,000 _get_sample() calls at spawn | Eliminated spawn stutter, audio hitching | Low — arcade-hardware-inspired caps |
| Phase 5 (Verify) | N/A | N/A | None |
+++++++ REPLACE