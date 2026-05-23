# Plan 23: V2 Spawners

## Overview

Build the V2 spawning system: a stage spawner base class with concrete variants, supporting resources, a signal-driven safe zone, and entity-level spawn Arms. This plan replaces the V1 `wave_spawner.gd` monolith (259 lines, 4 patterns, runtime property overrides, polling safe zones) and `tetromino_spawner.gd` monolith (525 lines, runtime component stripping, freeze/unfreeze hacks) with clean, single-purpose components.

**V1 Problems Solved:**
- One script handled 4 spawn patterns via `match` — now each pattern is its own component
- Runtime property overrides (`enemy.get_node("Health").max_health = grid_health_values[row]`) — replaced by explicit scene files and CDGridLayout data
- Polling safe zone (`while true: await get_tree().process_frame`) — replaced by signal-driven CDSafeZone
- Runtime component injection (`spawn_components: Array[PackedScene]`) — eliminated; V2 entities own their components
- Group injection at spawn time — eliminated; conflicts with "many specific scenes" principle

No gameplay is built. The goal is a complete, tested spawning catalog.

**Depends on:** Plan 19 (Core Infrastructure), Plan 19.5 (Object Pools), Plan 20 (Stage), Plan 21 (Brains + Legs), Plan 22 (Arms + Guts)

---

## Architecture: Two Worlds

Stage spawners and entity arms both spawn entities, but they share almost no lifecycle logic:

| Concern | Stage Spawners | Entity Arms |
|---------|---------------|-------------|
| Trigger source | Game bus (WaveCard relay) | Entity bus (`"shoot"`, `"zero_health"`) |
| Queue / stagger | Yes | No (immediate) |
| Wave number | Yes (equation) | No |
| Safe zone | Yes | No |
| Position calculation | Different per spawner | Different per arm |
| Pool integration | Yes | Yes |
| CDSpawnContext | Yes | Yes |

Pool + context application is the only shared code (~15 lines). Not worth a base class across both worlds. Instead:

- **CDStageSpawner** — base class for Point/Edge/Grid spawners (STAGE, Priority 70)
- **GunArm, SpawnOnDeathArm, PieceSplitterArm** — extend CDComponent2D directly (ARM, Priority 40)

---

## The WaveCard Relay Pattern

Spawners don't track waves themselves. They subscribe to game bus signals via a configurable `trigger_signal`. The WaveCard acts as a relay:

**With WaveCard (wave tracking):**
```
CDGame emits "game_play" on game bus
  → WaveCard hears "game_play"
  → WaveCard increments counter, emits "wave_start(wave_number: 1)" on game bus
    → CDStageSpawner hears "wave_start(1)" via its trigger_signal
    → Evaluates equation with wave_number=1
    → Stagger-spawns entities
    → Emits "spawning_complete" on game bus

... entities die ...

GroupCountGoal detects enemies = 0
  → Emits "wave_cleared" on game bus
  → WaveCard hears "wave_cleared"
  → WaveCard increments counter, emits "wave_start(wave_number: 2)" on game bus
    → Spawners fire again with wave_number=2
```

**Without WaveCard (one-shot, no wave tracking):**
```
CDGame emits "game_play" on game bus
  → CDStageSpawner hears "game_play" directly via its trigger_signal
  → wave_number defaults to 0
  → Spawns once, done
```

**Independent wave cycles:** Use different signal names. WaveCard_A emits `"asteroid_wave"`, WaveCard_B emits `"ufo_wave"`. Each spawner subscribes to whichever it needs via `trigger_signal`.

**The GDScript that makes this work:**
```gdscript
# CDStageSpawner trigger handler
# Works with both "game_play" (no args) and "wave_start(wave_number)" (1 arg)
func _on_trigger(wave_number: int = 0) -> void:
    _evaluate_and_spawn(wave_number)
```

GDScript lets you connect a signal that sends 0 args to a function expecting 1 arg with a default. The spawner doesn't care whether it's connected to `"game_play"` or `"wave_start"` — it handles whatever comes in.

---

## The CDStageSpawner Lifecycle

All stage spawners share this lifecycle:

1. **Trigger** — Game bus signal fires (via `trigger_signal` export). Handler receives optional `wave_number`.
2. **Calculate** — Determine spawn count (equation on concrete, or layout-derived via `_get_spawn_count()`).
3. **Queue** — Populate spawn queue. Pre-filter null entries (GridSpawner Mode A).
4. **Safe Zone Check** — If linked CDSafeZone is currently unsafe, pause the queue.
5. **Stagger** — Pop queue at `stagger_delay` intervals.
6. **Telefrag** — For each spawn: physics-query the spawn position. If any body in `telefrag_targets` overlaps, kill it via the health pipeline.
7. **Pool** — Acquire from `CDObjectPool` if set, otherwise instantiate fresh.
8. **Context** — Apply `CDSpawnContext` (velocity, rotation) before entity enters tree.
9. **Activate** — Add to game tree (or activate from pool).
10. **Complete** — Emit `"spawning_complete"` on game bus when queue empties.

---

## CDStageSpawner Base Class (1)

### CDStageSpawner (Abstract)
**Role:** Provides the complete stage spawn lifecycle. Concrete spawners override `_get_spawn_position()`, `_get_spawn_scene()`, and optionally `_get_spawn_count()`.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDComponent2D`, Category: `STAGE`, Priority 70 |
| **Consumes** | Game bus: configurable `trigger_signal`. CDSafeZone: `"zone_safe"`, `"zone_unsafe"` |
| **Generates** | Game bus: `"spawning_complete"` (configurable, with `wave_number: int`) |
| **Exports** | `trigger_signal: StringName = &"wave_start"` <br> `stagger_delay: float = 0.1` <br> `pool: CDObjectPool = null` <br> `spawn_context: CDSpawnContext = null` <br> `telefrag: bool = false` <br> `telefrag_targets: Array[StringName] = [&"enemies"]` <br> `safe_zone: CDSafeZone = null` <br> `on_spawning_complete: Array[StringName] = [&"spawning_complete"]` |
| **Virtual Methods** | `_get_spawn_position(index: int, total: int) -> Vector2` <br> `_get_spawn_scene(index: int, total: int) -> PackedScene` <br> `_get_spawn_count(wave_number: int) -> int` |
| **Process** | Connects to `trigger_signal` on game bus in `_on_initialize()`. On trigger: calls `_get_spawn_count(wave_number)`, populates queue, checks safe zone, starts stagger timer. Each tick pops an index, calls virtuals for position and scene. If scene is null, skips (for pre-filtered grids). Otherwise: performs telefrag check, acquires from pool or instantiates, applies spawn context, adds to game tree. On last spawn, emits `on_spawning_complete` signals with `(wave_number)`. |
| **Telefrag** | Before adding entity to tree, performs `PhysicsPointQueryParameters2D` at spawn position. For each overlapping body in `telefrag_targets`, emits `"request_deactivate"` on that body's entity bus. This triggers the standard death pipeline — death effects, score, spawn-on-death all fire. |
| **Guard** | `push_error("CDStageSpawner is abstract — use PointSpawner, EdgeSpawner, or GridSpawner")` if `_get_spawn_scene` is not overridden. |

**What the base does NOT export:** `spawn_count_equation`, `spawn_scene`, or any position-related config. Those live on the concrete spawners.

---

## Concrete Stage Spawners (3)

### PointSpawner
**Role:** Spawns entities at its own global position with optional random offset.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDStageSpawner` |
| **Exports** | `spawn_scene: PackedScene` <br> `spawn_count_equation: String = "3 + wave_number"` <br> `offset_range: Vector2 = Vector2(10, 10)` (random spread around center) |
| **Virtual Impl** | `_get_spawn_count(wave_number)`: Evaluates `spawn_count_equation` with wave_number. <br> `_get_spawn_position()`: Returns `global_position + Vector2(randf_range(-offset_range.x, offset_range.x), randf_range(-offset_range.y, offset_range.y))` <br> `_get_spawn_scene()`: Returns `spawn_scene` |
| **Use Case** | UFO spawning, asteroid field center, power-up drops, boss spawns |
| **V1 Predecessor** | `wave_spawner.gd` with `SpawnPattern.POSITION` |

### EdgeSpawner
**Role:** Spawns entities evenly distributed along the edges of the game bounds.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDStageSpawner` |
| **Exports** | `spawn_scene: PackedScene` <br> `spawn_count_equation: String = "3 + wave_number"` <br> `edges: Array[int] = [0]` (0=TOP, 1=BOTTOM, 2=LEFT, 3=RIGHT — matches CDEnums.Edge) |
| **Virtual Impl** | `_get_spawn_count(wave_number)`: Evaluates `spawn_count_equation` with wave_number. <br> `_get_spawn_position(index, total)`: Distributes `total` entities evenly across selected edges. Uses `get_game().game_bounds` for edge coordinates. <br> `_get_spawn_scene()`: Returns `spawn_scene` |
| **Use Case** | Space Invaders (enemies from top), Asteroids (rocks from all edges), Robotron wave spawns |
| **V1 Predecessor** | `wave_spawner.gd` with `SpawnPattern.SCREEN_EDGES` |

### GridSpawner
**Role:** Spawns entities in a 2D grid. Supports two mutually exclusive modes: data-driven (CDGridLayout) or math-driven (CDGridEquation).

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDStageSpawner` |
| **Exports** | **Mode A (Data):** `layout: CDGridLayout = null` <br> **Mode B (Math):** `scene: PackedScene = null` + `equation: CDGridEquation = null` <br> **Shared:** `cell_size: Vector2 = Vector2(16, 16)` <br> `cell_spacing: Vector2 = Vector2(2, 2)` |
| **Virtual Impl** | `_get_spawn_count()`: Mode A = count of non-null cells in layout (pre-computed). Mode B = `columns × rows` (then pre-filter skips). <br> `_get_spawn_scene(index)`: Mode A = the PackedScene at that cell. Mode B = `scene` (null if index is in skip set). <br> `_get_spawn_position(index)`: Calculates grid position from row/col, centered on spawner's `global_position`. |
| **Mode A — Data-Driven:** | Each cell in CDGridLayout is either a specific `PackedScene` or `null` (skip). The scene IS the config — `HardBrick.tscn` already has HP=7, no overrides needed. For random junk layouts, provide multiple CDGridLayout resources and pick random. |
| **Mode B — Math-Driven:** | Uniform grid of the same scene with randomized skips via CDGridEquation. Useful for "50 identical asteroids in a grid with some holes." |
| **Queue pre-filtering:** | GridSpawner overrides the trigger handler to pre-filter the queue — null cells are removed before the base class sees them. The base class only ever processes valid spawn requests. |
| **Validation** | `push_error()` if both layout and scene+equation are configured. Mode A takes priority if both are set. |
| **V1 Predecessor** | `wave_spawner.gd` with `SpawnPattern.GRID` |

---

## Supporting Stage (1)

### CDSafeZone
**Role:** Replaces V1's polling `_wait_for_safe_zone()` with a signal-driven Area2D. Monitors overlapping bodies and emits safe/unsafe transitions.

| Aspect | Detail |
|--------|--------|
| **Extends** | `Area2D` (not CDComponent2D — it's a physics object) |
| **Consumes** | Godot physics overlap detection |
| **Generates** | `"zone_safe()"`, `"zone_unsafe()"` (custom signals) |
| **Exports** | `unsafe_groups: Array[StringName] = [&"enemies", &"space_rocks"]` <br> `monitoring: bool = true` |
| **Process** | Tracks count of overlapping bodies in `unsafe_groups`. When count transitions from 0→1, emits `"zone_unsafe"`. When count transitions from 1→0, emits `"zone_safe"`. |
| **Integration** | CDStageSpawner connects to these signals. When unsafe, the spawn queue pauses. When safe resumes, the queue unpauses. No polling, no `await` loops. |
| **V1 Predecessor** | `wave_spawner.gd` `_wait_for_safe_zone()` — a polling `while true: await` loop |

---

## Resources (3)

### CDSpawnContext
**Role:** A lightweight resource that describes how a newly spawned entity should be configured before entering the tree. Replaces V1's `initial_velocity`, `use_random_angle`, `random_flip_h/v` exports.

| Property | Type | Description |
|----------|------|-------------|
| `velocity` | `Vector2` | Initial velocity (default `Vector2.ZERO`) |
| `use_random_angle` | `bool` | If true, rotate velocity vector to a random angle |
| `random_angle_min` | `float` | Min angle for random rotation (default `0.0`) |
| `random_angle_max` | `float` | Max angle for random rotation (default `TAU`) |
| `random_flip_h` | `bool` | Randomly negate X velocity (default `false`) |
| `random_flip_v` | `bool` | Randomly negate Y velocity (default `false`) |
| `rotation` | `float` | Initial entity rotation (default `0.0`) |

**Application:** CDStageSpawner and entity arms apply this to the entity BEFORE `add_child()`, so `_ready()` sees the correct velocity and rotation.

**Shared logic:** Since both CDStageSpawner and entity arms apply CDSpawnContext, the application logic is extracted to a static helper:

```gdscript
# In CDGame or a utility class
static func apply_spawn_context(entity: CDEntity, context: CDSpawnContext) -> void:
    if not context: return
    entity.velocity = context.velocity
    if context.use_random_angle:
        var speed = entity.velocity.length()
        var angle = Vector2.from_angle(randf_range(context.random_angle_min, context.random_angle_max))
        entity.velocity = angle * speed
    if context.random_flip_h:
        entity.velocity.x *= [-1, 1].pick_random()
    if context.random_flip_v:
        entity.velocity.y *= [-1, 1].pick_random()
    entity.rotation = context.rotation
```

### CDGridLayout
**Role:** A custom Resource defining a 2D grid of explicit entity scenes. The data IS the logic — no property overrides needed.

| Property | Type | Description |
|----------|------|-------------|
| `columns` | `int` | Width of the grid |
| `rows` | `Array[CDGridRow]` | Array where index 0 = top row, N = bottom row |

**CDGridRow (Inner Resource):**

| Property | Type | Description |
|----------|------|-------------|
| `cells` | `Array[PackedScene]` | Length must match `columns`. `null` = skip (empty cell). Non-null = that scene is spawned. |

**Why this replaces V1 grid overrides:**
- V1: `grid_health_values: [7, 5, 3, 1, 1]` → spawner reaches into `enemy.get_node("Health").max_health`
- V2: Row 0 cells are `HardBrick.tscn` (HP=7), Row 1 cells are `MediumBrick.tscn` (HP=5), etc.
- For random junk patterns: create 5 different CDGridLayout resources with different `null` holes, pick one at random

### CDGridEquation
**Role:** A math-driven grid definition. For cases where you want a uniform grid of the same entity with some randomized gaps.

| Property | Type | Description |
|----------|------|-------------|
| `columns` | `int` | Grid width |
| `rows` | `int` | Grid height |
| `skip_chance` | `float` | Probability each cell is skipped (0.0 = spawn all, 0.3 = skip ~30%) |
| `min_skips_per_row` | `int` | Guarantee ≥N gaps per row (default `0`) |

**When to use:** When every cell spawns the same scene (e.g., 50 identical asteroids) and you just need some random holes. For mixed entity types, use CDGridLayout instead.

---

## Entity Arms (3)

These extend CDComponent2D directly (ARM category, Priority 40). They respond to entity bus signals and spawn immediately — no queue, no stagger, no wave tracking.

### GunArm
**Role:** Spawns a projectile entity on `"shoot"` signal. Uses object pool if available, falls back to fresh instantiation.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDComponent2D`, Category: `ARM`, Priority 40 |
| **Consumes** | Entity bus: `"shoot"` (configurable via `fire_signal`) |
| **Generates** | New entity added to game tree |
| **Exports** | `bullet_scene: PackedScene` <br> `pool: CDObjectPool = null` <br> `cooldown: float = 0.3` <br> `fire_signal: StringName = &"shoot"` <br> `spawn_context: CDSpawnContext = null` <br> `inherit_rotation: bool = true` (bullet faces entity's forward direction) |
| **Process** | On `fire_signal`, checks cooldown. If ready: acquires entity from pool (or instantiates), sets position to entity's muzzle point, applies spawn context + entity's rotation, adds to game tree (or activates from pool). |
| **V1 Predecessor** | `gun_simple.gd` |

### SpawnOnDeathArm
**Role:** Spawns an entity when the parent entity dies. Replaces V1's runtime component injection and death effects.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDComponent2D`, Category: `ARM`, Priority 40 |
| **Consumes** | Entity bus: `"zero_health"` or `"request_deactivate"` (configurable via `death_signal`) |
| **Generates** | New entity added to game tree |
| **Exports** | `spawn_scene: PackedScene` <br> `pool: CDObjectPool = null` <br> `death_signal: StringName = &"zero_health"` <br> `spawn_context: CDSpawnContext = null` <br> `inherit_position: bool = true` <br> `inherit_velocity: bool = false` |
| **Process** | On `death_signal`, instantiates (or acquires from pool) `spawn_scene`. Sets position to entity's position if `inherit_position`. Applies spawn context. Adds to game tree. |
| **Use Cases** | Death explosion VFX, asteroid splitting into smaller asteroids, Missile Command chain reactions, enemy dropping a power-up |
| **V1 Predecessor** | `death_effect.gd`, `death_effect_brick.gd` |

### PieceSplitterArm
**Role:** Tetris-specific arm. On `piece_locked`, spawns individual SettledCell entities at each of the piece's block offsets, then deactivates the parent.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDComponent2D`, Category: `ARM`, Priority 40 |
| **Consumes** | Entity bus: `"piece_locked(cell_positions: Array[Vector2])"` |
| **Generates** | Multiple SettledCell entities added to game tree. Game bus: `"piece_settled"` (announcer pattern). Own entity bus: `"request_deactivate"`. |
| **Exports** | `settled_cell_scene: PackedScene` <br> `pool: CDObjectPool = null` <br> `settled_group: StringName = &"settled"` <br> `on_piece_settled: Array[StringName] = [&"piece_settled"]` |
| **Process** | On `"piece_locked"`, iterates `cell_positions`. For each position: instantiates `settled_cell_scene`, sets `global_position`, adds to `settled_group`, adds to game tree. After all cells spawned, emits `on_piece_settled` signals on game bus (announcer pattern), then `"request_deactivate"` on own entity bus. |
| **V1 Predecessor** | Part of `tetromino_spawner.gd` `_on_piece_locked()` |

---

## V1 → V2 Migration Map

| V1 Script | V2 Component(s) | Key Changes |
|-----------|-----------------|-------------|
| `wave_spawner.gd` (POSITION) | PointSpawner | Pattern extracted into dedicated component |
| `wave_spawner.gd` (SCREEN_EDGES) | EdgeSpawner | Pattern extracted, uses game_bounds |
| `wave_spawner.gd` (GRID) | GridSpawner + CDGridLayout / CDGridEquation | Grid math → data resource or equation resource |
| `wave_spawner.gd` (_wait_for_safe_zone) | CDSafeZone | Polling loop → signal-driven Area2D |
| `wave_spawner.gd` (property_overrides) | Eliminated | Explicit scenes replace runtime overrides |
| `wave_spawner.gd` (spawn_components) | Eliminated | V2 entities own their components |
| `wave_spawner.gd` (spawn_groups) | Eliminated | V2 entities declare groups in scene files |
| `wave_spawner.gd` (initial_velocity) | CDSpawnContext | Extracted into reusable resource |
| `wave_spawner.gd` (telefrag) | CDStageSpawner base class | Built into lifecycle, respects health pipeline |
| `wave_spawner.gd` (director routing) | Trigger signals | Direct signal subscription, no middleware |
| `tetromino_spawner.gd` (lock/split) | PieceSplitterArm | Entity handles its own lock+split |
| `tetromino_spawner.gd` (bag/preview/hold) | Deferred | BlockDropManager deferred to post-Galaga plan |
| `gun_simple.gd` | GunArm | Pool-backed, configurable fire signal |
| `death_effect.gd` / `death_effect_brick.gd` | SpawnOnDeathArm | Unified, pool-backed, configurable death signal |
| `property_override.gd` | CDSpawnContext | Narrowed to velocity/rotation only |

---

## Implementation Order

### Phase 1: Resources + Base
1. CDSpawnContext → prove resource application (velocity, rotation) before `add_child`
2. `apply_spawn_context()` static helper → prove shared utility
3. CDStageSpawner (base) → prove trigger → queue → stagger → spawn lifecycle (with test scene that overrides virtuals inline)

### Phase 2: Simplest Concrete
4. PointSpawner → prove equation evaluation + position offset

### Phase 3: Grid System
5. CDGridLayout → prove data-driven grid (explicit scenes per cell)
6. CDGridEquation → prove math-driven grid (uniform scene + skips)
7. GridSpawner → prove both modes + queue pre-filtering

### Phase 4: Edge Spawning
8. EdgeSpawner → prove game_bounds edge distribution

### Phase 5: Safety
9. CDSafeZone → prove signal-driven safe/unsafe transitions
10. Wire CDSafeZone into CDStageSpawner → prove queue pause/resume

### Phase 6: Entity Arms
11. GunArm → prove pool-backed projectile spawning + cooldown
12. SpawnOnDeathArm → prove death-triggered spawning + pool fallback
13. PieceSplitterArm → prove multi-spawn + announcer pattern

---

## Proof / Testing

### Test 1: PointSpawner + WaveCard Lifecycle
- WaveCard listens to `"game_play"`, emits `"wave_start(1)"`
- PointSpawner with `trigger_signal = &"wave_start"`, `spawn_count_equation = "5"`, `stagger_delay = 0.1`, scene = `Asteroid.tscn`
- Game starts → WaveCard emits `"wave_start(1)"` → PointSpawner fires → queue of 5 → stagger-spawns 5 asteroids
- Last spawn → `"spawning_complete"` emitted on game bus

### Test 2: EdgeSpawner Without WaveCard
- EdgeSpawner with `trigger_signal = &"game_play"`, `spawn_count_equation = "10"`, `edges = [TOP]`, scene = `Invader.tscn`
- Game starts → EdgeSpawner hears `"game_play"` directly → wave_number defaults to 0 → 10 invaders evenly spaced across top edge

### Test 3: GridSpawner Data-Driven Mode
- CDGridLayout: 3 rows × 5 columns. Row 0 = `HardBrick.tscn`, Rows 1-2 = `WeakBrick.tscn`, some cells `null`
- GridSpawner with layout → spawns exactly the non-null cells at correct grid positions
- Count = non-null cells (not rows × columns)

### Test 4: GridSpawner Math-Driven Mode
- CDGridEquation: 8 rows × 14 columns, `skip_chance = 0.2`, `min_skips_per_row = 2`
- GridSpawner with scene + equation → spawns uniform grid with randomized gaps
- Verify each row has ≥ 2 skips

### Test 5: CDSafeZone Queue Pause
- CDSafeZone monitors `unsafe_groups = [&"enemies"]`
- PointSpawner linked to CDSafeZone
- Enemy enters CDSafeZone → `"zone_unsafe"` → spawner pauses queue
- Enemy leaves CDSafeZone → `"zone_safe"` → spawner resumes queue
- Verify no entities spawn while zone is unsafe

### Test 6: Telefrag
- PointSpawner with `telefrag = true`, `telefrag_targets = [&"asteroids"]`
- Asteroid sitting at spawn position
- Spawner triggers → telefrag check → kills asteroid (via `"request_deactivate"` on asteroid's entity bus) → spawns new entity at same position

### Test 7: GunArm Pool Cycle
- Entity with GunArm, pool = `BulletPool`, cooldown = 0.3
- Fire signal → acquires from pool → sets position/rotation → activates
- Bullet hits wall → `"request_deactivate"` → returns to pool
- Fire again → reacquires same bullet from pool
- Verify no memory leaks after 100 fire cycles

### Test 8: SpawnOnDeathArm Chain Reaction
- Asteroid: HealthPoolGuts(1) + DieAtZeroHealthGuts + SpawnOnDeathArm(spawns SmallAsteroid)
- Bullet: DamageOnHitArm
- Bullet hits asteroid → asteroid dies → SpawnOnDeathArm spawns 2 SmallAsteroids
- SmallAsteroids are now in the game, each with their own health

### Test 9: PieceSplitterArm
- ActivePiece: LockDetectorGuts + PieceSplitterArm
- Piece locks → LockDetector emits `"piece_locked(cell_positions)`
- PieceSplitter spawns 4 SettledCell entities at those positions
- Emits `"piece_settled"` on game bus (announcer pattern)
- ActivePiece receives `"request_deactivate"` and deactivates

---

## File Structure

```
Godot/Scripts/
├── Spawners/
│   ├── cd_stage_spawner.gd         # Abstract base class
│   ├── point_spawner.gd
│   ├── edge_spawner.gd
│   ├── grid_spawner.gd
│   └── cd_safe_zone.gd
├── Arms/
│   ├── gun_arm.gd
│   ├── spawn_on_death_arm.gd
│   └── piece_splitter_arm.gd
├── Resources/
│   ├── cd_spawn_context.gd         # CDSpawnContext resource
│   ├── cd_grid_layout.gd           # CDGridLayout + CDGridRow resources
│   └── cd_grid_equation.gd         # CDGridEquation resource
```

---

## Risks & Open Questions

1. **CDStageSpawner base class scope creep:** The base manages trigger, queue, stagger, safe zone, telefrag, pool, and context. If future spawners need exotic lifecycle hooks, the base could bloat. **Mitigation:** Keep virtuals minimal (`_get_spawn_position`, `_get_spawn_scene`, `_get_spawn_count`). If a spawner needs fundamentally different lifecycle behavior, it should extend CDComponent2D directly.

2. **Telefrag death cascade:** Telefrag kills overlapping entities via `"request_deactivate"`, which triggers their death pipeline. If a telefragged entity's SpawnOnDeathArm spawns something at the same position, the new entity might overlap the spawner's entity. **Mitigation:** Telefrag runs before `add_child`, so death spawns resolve first. Document this ordering.

3. **CDGridEquation skip determinism:** Math-driven skips use `randf()` per cell. Same equation produces different results each wave. For deterministic layouts, use CDGridLayout. **Mitigation:** Document that CDGridEquation is for randomized patterns only.

4. **Pool exhaustion fallback:** GunArm and SpawnOnDeathArm fall back to fresh instantiation when the pool returns null. This is correct behavior but means pool sizing affects performance, not correctness. **Mitigation:** Document that pools are a performance optimization, not a correctness requirement.

5. **PieceSplitterArm and LineClearMonitor timing:** PieceSplitterArm runs at Priority 40 (ARM), spawns cells, then emits `"piece_settled"` on game bus. LineClearMonitor (Stage, Priority 70) hears `"piece_settled"` with a 1-frame delay to ensure all cells are in the tree. **Mitigation:** Document the timing dependency. Same pattern as TSpinDetectorGuts in Plan 22.

6. **BlockDropManager deferral:** This plan does NOT include BlockDropManager (bag system, hold, preview, level gravity). That component is deferred until after the Group-as-State pattern is proven with Galaga. PieceSplitterArm and LockDetectorGuts (Plan 22) prepare the entity side; BlockDropManager will handle the stage side later.