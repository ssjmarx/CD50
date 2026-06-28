# `trapdoors/`

Stage-level spawners. Each script in this folder is a concrete subclass of `CDStageTrapdoor` (defined in `Godot/scripts/core/base classes/cd_stage_trapdoor.gd`) that decides **what** to spawn, **where** to spawn it, and **how many** to spawn. The base class owns the rest of the lifecycle (trigger signals, staggered queue, pool vs. fresh instantiate, telefrag, safe-zone gating).

## Base class behavior (inherited by everything here)

All trapdoors in this folder inherit the following from `CDStageTrapdoor`. Concrete scripts only override the three virtual methods listed further down.

### Lifecycle

1. **Trigger** — A game-bus signal listed in `trigger_signals` (default `&"wave_start"`) fires. If `trigger_delay > 0`, the trapdoor waits that many seconds (`_on_delayed_trigger` → `_on_trigger`); otherwise `_on_trigger()` runs immediately.
2. **Queue** — `_on_trigger()` reads the current wave number from the game blackboard (`wave_key`, default `&"wave_number"`) and fills `_spawn_queue` with `0 .. total-1`, where `total` comes from `_get_spawn_count(wave_number)`.
3. **Stagger** — `_physics_process(delta)` drains the queue one index at a time, waiting `stagger_delay` seconds between spawns. Draining pauses while `_zone_is_safe` is false (see Safe zones below).
4. **Spawn** — For each popped index, `_spawn_one(index)`:
   - Picks a scene: if the base class's `spawn_scenes` array is non-empty it cycles by `index % spawn_scenes.size()`; otherwise it calls `_get_spawn_scene(index, total)`.
   - Picks a position via `_get_spawn_position(index, total)`.
   - Acquires the entity from `pool` (a `CDObjectPool`) if set, else instantiates `scene.instantiate()` fresh.
   - Optionally telefrags overlapping bodies at the spawn point (`telefrag` + `telefrag_targets`).
   - Applies `spawn_context` (a `CDSpawnContext` resource) for velocity/rotation.
   - Activates: `entity.activate()` for pooled, or `game.add_child(entity)` for fresh.
5. **Complete** — When the queue empties, the trapdoor writes `spawned_wave` to the blackboard and emits every signal in `on_spawning_complete` (default `&"spawning_complete"`).

> ⚠️ Triggering is suppressed while `game.current_state == CDEnums.GameState.GAME_OVER`.

### Base-class exports (available on every trapdoor here)

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `stagger_delay` | `float` | `0.1` | Seconds between consecutive spawns within a wave. |
| `pool` | `CDObjectPool` | `null` | Pool to acquire from. `null` = fresh `instantiate()` each time. |
| `spawn_context` | `CDSpawnContext` | `null` | Velocity/rotation applied before the entity enters the tree. |
| `spawn_scenes` | `Array[PackedScene]` | `[]` | If non-empty, overrides `_get_spawn_scene()` (cycled by index). |
| `trigger_delay` | `float` | `0.0` | Delay between the trigger signal and the first spawn. |
| `wave_key` | `StringName` | `&"wave_number"` | Blackboard key read for the current wave number. |
| `telefrag` | `bool` | `false` | Kill overlapping bodies at the spawn point before spawning. |
| `telefrag_targets` | `Array[StringName]` | `[&"enemies"]` | Groups whose members may be telefragged. |
| `trigger_signals` | `Array[StringName]` | `[&"wave_start"]` | Bus signals that start a spawn wave. |
| `safe_signals` | `Array[StringName]` | `[&"zone_safe"]` | Bus signals that mark the spawn zone clear. |
| `unsafe_signals` | `Array[StringName]` | `[&"zone_unsafe"]` | Bus signals that mark the spawn zone occupied. |
| `on_spawning_complete` | `Array[StringName]` | `[&"spawning_complete"]` | Bus signals emitted when the wave finishes spawning. |

### Safe zones

`_zone_is_safe` starts `true`. Listening to `safe_signals`/`unsafe_signals` flips it. While unsafe, the stagger loop holds the queue without spawning; it does **not** discard the queue.

### Virtual methods (the only thing concrete trapdoors override)

```gdscript
func _get_spawn_count(_wave_number: int) -> int          # how many to spawn
func _get_spawn_position(_index: int, _total: int) -> Vector2  # where to spawn each
func _get_spawn_scene(_index: int, _total: int) -> PackedScene # what scene to spawn
```

`_get_spawn_scene()` is abstract in the base class (it `push_error`s and returns `null`). Every script below implements it. `_get_spawn_count()` and `_get_spawn_position()` fall back to `0` and `global_position` respectively.

---

## Files in this folder

### `edge_trapdoor.gd` — `EdgeTrapdoor`

Spawns entities evenly distributed along one or more edges of the game bounds, with optional jitter.

**Exports**

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `spawn_scene` | `PackedScene` | — | Scene instantiated for every entity. |
| `spawn_count_equation` | `String` | `"3 + wave_number"` | Equation evaluated via `CDUtilities.evaluate_int()` to determine count. |
| `edges` | `Array[CDEnums.Edge]` | `[CDEnums.Edge.TOP]` | Which edges of `game.game_bounds` to spawn along. |
| `jitter` | `float` | `0.0` | Blend between even spacing (`0.0`) and fully random along the perimeter (`1.0`). |

**How it works**

- `_on_initialize()` calls `super()` then `_build_perimeter()`, which converts each selected edge into a `{start, end, length}` segment and sums their lengths into `_total_perimeter`.
- `_get_spawn_count(wave_number)` evaluates `spawn_count_equation` against the variable `wave_number`.
- `_get_spawn_position(index, total)` computes an even fraction `(index + 0.5) / total` of the perimeter, a random fraction `randf() * total_perimeter`, then `lerpf`s them by `jitter`. The result is wrapped with `fposmod` and walked segment-by-segment to recover a world position.
- `_get_spawn_scene()` always returns the single `spawn_scene`.

**Usage notes**

- Position depends on `game.game_bounds`; the trapdoor's own `global_position` is **not** used.
- Multiple edges are traversed in the order listed. Each edge is converted to a clockwise segment (TOP → RIGHT → BOTTOM → LEFT), so mixing edges yields a continuous perimeter only if they are listed in clockwise order.

---

### `grid_trapdoor.gd` — `GridTrapdoor`

Spawns entities in a centered 2D grid. Runs as `@tool` and draws an editor preview. Supports two mutually exclusive modes:

- **Mode A (data-driven):** assign a `CDGridLayout` resource (`layout`). Each non-empty cell maps to a scene.
- **Mode B (math-driven):** assign a single `spawn_scene` plus a `CDGridEquation` resource (`equation`) that supplies columns, rows, and skip logic.

**Exports**

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `layout` | `CDGridLayout` | `null` | Mode A layout resource. Takes priority if set. |
| `spawn_scene` | `PackedScene` | `null` | Mode B scene used for every non-skipped cell. |
| `equation` | `CDGridEquation` | `null` | Mode B math resource (columns/rows/skip). |
| `cell_size` | `Vector2` | `Vector2(16, 16)` | Size of each grid cell. |
| `cell_spacing` | `Vector2` | `Vector2(2, 2)` | Gap between cells. |
| `preview_color` (`Preview` group) | `Color` | `Color.CYAN` | Editor-only draw color. |
| `preview_radius` (`Preview` group) | `float` | `4.0` | Editor-only circle radius. |

The `layout`, `equation`, `cell_size`, `cell_spacing`, `preview_color`, and `preview_radius` setters all call `queue_redraw()` once the node is ready, so changing them in the inspector updates the preview live.

**How it works**

- `_on_trigger()` is **overridden entirely** (it does not call `super()`). After the GAME_OVER guard it reads `wave_number` from the blackboard, clears `_spawn_queue`, and dispatches:
  - If `layout != null` → `_populate_queue_mode_a()`. If Mode B is also configured, a warning is pushed. Mode A appends every flat index whose `layout.get_cell(i)` is non-null and records `_grid_columns` / `_grid_rows` from the layout.
  - Else if `spawn_scene != null and equation != null` → `_populate_queue_mode_b()`. Builds a `_skip_set`: each cell is skipped with probability `equation.skip_chance`, then a second pass enforces `equation.min_skips_per_row` by randomly adding skips per row until the minimum is met. Non-skipped indices are appended to the queue.
  - Else → `push_error` and return.
  - Finally resets `_spawn_timer` and enables physics processing so the base stagger loop can take over.
- `_get_spawn_position(index, _total)` converts the flat index to `(col, row)`, computes `step = cell_size + cell_spacing`, centers the grid on `global_position`, and returns the world cell center. The centering math matches the editor preview and the comment notes it mirrors `FormationDirector`.
- `_get_spawn_scene(index, _total)` returns `layout.get_cell(index)` in Mode A, otherwise `spawn_scene`.
- `_draw()` is editor-only (`Engine.is_editor_hint()`). It recomputes grid dimensions from whichever resource is set and draws a `preview_color` circle of `preview_radius` at each cell center, using the same centering math as runtime.

**Usage notes**

- Mode A ignores `spawn_scene`/`equation`; Mode B ignores `layout`. Configure only the mode you intend to use.
- `spawn_scenes` on the base class still overrides `_get_spawn_scene()` if populated — leave it empty to let this script's mode logic pick scenes.
- Skip logic is randomized per trigger, so Mode B produces a different subset each wave.
- The trapdoor's `global_position` is the center of the grid.

---

### `point_trapdoor.gd` — `PointTrapdoor`

The simplest trapdoor. Spawns all entities at its own `global_position` with an optional random offset. Uses an equation for count and a single scene.

**Exports**

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `spawn_scene` | `PackedScene` | — | Scene instantiated for every entity. |
| `spawn_count_equation` | `String` | `"3 + wave_number"` | Equation evaluated via `CDUtilities.evaluate_int()`. |
| `offset_range` | `Vector2` | `Vector2(10, 10)` | Maximum random offset per axis; actual offset is `randf_range(-v, v)`. |

**How it works**

- `_get_spawn_count(wave_number)` evaluates `spawn_count_equation` against `wave_number`.
- `_get_spawn_position(_index, _total)` returns `global_position` plus a random offset in `[-offset_range.x, offset_range.x] × [-offset_range.y, offset_range.y]`.
- `_get_spawn_scene()` always returns `spawn_scene`.

**Usage notes**

- Unlike `EdgeTrapdoor`, the trapdoor's node position is authoritative — place the node where you want spawns to appear.
- Set `offset_range` to `Vector2.ZERO` for exact pinpoint spawning.

---

## Creating a new trapdoor

1. Create `Godot/scripts/game components/trapdoors/<your_trapdoor>.gd`.
2. Declare it as a subclass and, if you want editor preview, mark it `@tool`:

   ```gdscript
   @tool
   class_name YourTrapdoor extends CDStageTrapdoor
   ```
3. Add `@export` variables for whatever inputs your spawn strategy needs (scenes, equations, ranges, resources).
4. Override **at least** these three virtual methods:

   ```gdscript
   func _get_spawn_count(wave_number: int) -> int:
       # Evaluate an equation, read a resource, or return a constant.
       return CDUtilities.evaluate_int(spawn_count_equation, ["wave_number"], [wave_number], "YourTrapdoor '%s'" % name)

   func _get_spawn_position(index: int, total: int) -> Vector2:
       # Compute the world position for this entity.
       return global_position

   func _get_spawn_scene(index: int, total: int) -> PackedScene:
       # Return the scene for this slot, or null to skip.
       return spawn_scene
   ```
5. If your trapdoor needs custom queue logic (like `GridTrapdoor`'s two modes), override `_on_trigger()` **entirely** — but replicate the essentials: guard against `CDEnums.GameState.GAME_OVER`, read the wave number from the blackboard, populate `_spawn_queue` with indices, reset `_spawn_timer`, and call `set_physics_process(true)` so the base stagger loop runs. Do not forget to emit `on_spawning_complete` is handled by the base `_physics_process`, so leave it intact.
6. For editor previews, override `_draw()` and gate it on `Engine.is_editor_hint()`, and call `queue_redraw()` from your `@export` setters when `is_node_ready()` is true (see `grid_trapdoor.gd`).
7. Configure base-class behavior (triggers, stagger, pool, telefrag, safe zones) via the inherited exports — do not reimplement them.

### Equation evaluation

All equation-based counts in this folder go through:

```gdscript
CDUtilities.evaluate_int(expr: String, var_names: Array, var_values: Array, context_label: String) -> int
```

Pass the variable names you support (here just `["wave_number"]`) and their values; `context_label` is used in error messages, typically `"ClassName '%s'" % name`.