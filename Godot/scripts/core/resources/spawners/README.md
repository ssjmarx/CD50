# `spawners/` — Spawn Configuration Resources

This folder holds **data-only `Resource` classes** used to configure how entities are
placed into the world and what initial state they receive.

> ⚠️ **No spawning logic lives here.** Despite the folder name, these scripts contain
> no `instantiate()` calls, timers, or spawning loops. They are pure data containers
> that other systems (trapdoors, arms) read from. The actual spawning happens in:
>
> - `Godot/scripts/game components/trapdoors/grid_trapdoor.gd` — consumes `CDGridLayout` / `CDGridEquation`
> - `Godot/scripts/core/base classes/cd_stage_trapdoor.gd` — consumes `CDSpawnContext`
> - Various arms (`gun_arm.gd`, `lasso_arm.gd`, `spawn_on_death_arm.gd`, `powerup_wingman_arm.gd`) — consume `CDSpawnContext`

There are two distinct concerns represented here:

| Concern | Classes | Purpose |
| --- | --- | --- |
| Grid formation definitions | `CDGridLayout`, `CDGridRow`, `CDGridEquation` | Describe *where* things spawn in a grid |
| Spawned-entity initial state | `CDSpawnContext` | Describe *what state* a spawned entity starts with |

---

## `CDGridEquation` — Math-driven grid (`cd_grid_equation.gd`)

A compact resource that defines a grid purely by dimensions plus probabilistic skip
rules. Use this when you want a **uniform grid with optional random holes** (e.g.
Breakout walls, Space Invaders formations where some slots can be empty).

| Export | Type | Default | Description |
| --- | --- | --- | --- |
| `columns` | `int` | `10` | Number of columns in the grid. |
| `rows` | `int` | `8` | Number of rows in the grid. |
| `skip_chance` | `float` | `0.0` | Probability any given cell is empty (`0.0` = solid, `1.0` = all empty). |
| `min_skips_per_row` | `int` | `0` | Guaranteed minimum number of skips per row. |

This resource has **no methods** — it is read by `grid_trapdoor.gd` (Mode B), which
walks the `columns × rows` space and rolls against `skip_chance` (respecting
`min_skips_per_row`) to decide which cells to fill.

---

## `CDGridLayout` — Hand-crafted grid (`cd_grid_layout.gd`)

A data-driven grid where every cell is explicitly assigned a `PackedScene` (or
`null` for a gap). Use this when you want **specific, authored formations** rather
than a uniform grid.

Each row is a `CDGridRow` resource (see below). Rows are stored in row-major order.

### Exports

| Export | Type | Default | Description |
| --- | --- | --- | --- |
| `columns` | `int` | `5` | Grid width in cells. Used for flat-index → (row, col) math. |
| `rows` | `Array[CDGridRow]` | `[]` | Row data; each row holds cell `PackedScene`s (`null` = skip). |

### Methods

#### `get_spawn_count() -> int`

Iterates every cell across all rows and returns the count of non-`null` entries.
Useful for sizing object pools before spawning.

```gdscript
var needed: int = layout.get_spawn_count()
```

#### `get_cell(index: int) -> PackedScene`

Returns the `PackedScene` at the given **flat (row-major) index**, or `null` if the
index is out of range or the cell is a gap.

Internally computes:
- `row_index = index / columns`
- `col_index = index % columns`

…and guards against empty rows and out-of-range indices by returning `null`.

> Note: the `@warning_ignore("integer_division")` annotation suppresses Godot's
> warning for the intentional integer `index / columns` division.

This resource is read by `grid_trapdoor.gd` (Mode A).

---

## `CDGridRow` — One row of a `CDGridLayout` (`cd_grid_row.gd`)

A tiny container resource representing a single horizontal row of cells.

| Export | Type | Default | Description |
| --- | --- | --- | --- |
| `cells` | `Array[PackedScene]` | `[]` | Cell entries for this row. `null` means skip/empty. |

A `CDGridLayout` holds an array of these. There is no logic — it exists so rows can
be authored and edited independently in the Godot inspector.

---

## `CDSpawnContext` — Initial state for a spawned entity (`cd_spawn_context.gd`)

A bag of optional initial-state values applied to an entity **just before it enters
the `SceneTree`**. This lets a single `PackedScene` be reused with different
starting velocities, rotations, groups, etc.

> Applied externally by `CDUtilities.apply_spawn_context(entity, context)`
> (in `Godot/scripts/core/resources/infrastructure/cd_utilities.gd`).
> If `context` is `null`, the function does nothing — so this field is optional
> everywhere it's exposed.

### Exports

| Export | Type | Default | Description |
| --- | --- | --- | --- |
| `velocity` | `Vector2` | `Vector2.ZERO` | Initial velocity (direction + speed). |
| `use_random_angle` | `bool` | `false` | If `true`, randomize velocity direction within an angle range (preserves speed). |
| `random_angle_min` | `float` | `0.0` | Min angle for random direction (radians). |
| `random_angle_max` | `float` | `TAU` | Max angle for random direction (radians). |
| `random_flip_h` | `bool` | `false` | Randomly flip the horizontal velocity component (50/50). |
| `random_flip_v` | `bool` | `false` | Randomly flip the vertical velocity component (50/50). |
| `rotation` | `float` | `0.0` | Initial rotation in radians. |
| `additional_groups` | `Array[StringName]` | `[]` | Extra groups to add the entity to, beyond its scene-defined groups. |

### Where it's consumed

`CDSpawnContext` is exposed as an optional `@export` on several spawners, each of
which calls `CDUtilities.apply_spawn_context(spawned, spawn_context)` on the freshly
instantiated entity:

- `Godot/scripts/core/base classes/cd_stage_trapdoor.gd`
- `Godot/scripts/entity components/arms/triggered arms/gun_arm.gd`
- `Godot/scripts/entity components/arms/triggered arms/lasso_arm.gd`
- `Godot/scripts/entity components/arms/death reactions/spawn_on_death_arm.gd`
- `Godot/scripts/entity components/arms/powerup arms/powerup_wingman_arm.gd`

---

## How to use these resources

Because every script here is a plain `Resource`, you work with them the standard
Godot way:

### 1. Create an instance

Either:
- In the **Inspector**, right-click a `@export var foo: CDGridLayout` field on a
  consuming node (e.g. `grid_trapdoor`) and choose *New CDGridLayout*, **or**
- Save a `.tres` file to disk so it can be shared/reused:

  ```
  # Godot "New Resource → CDGridLayout → save as formations/breakout_wall.tres"
  ```

### 2. Author a `CDGridLayout` formation

1. Create a `CDGridLayout` resource.
2. Add one `CDGridRow` per visual row.
3. In each row, drag `PackedScene`s into `cells`. Leave entries `null` (or omit
   them) to create gaps.
4. Set `columns` to the grid width (used for index math in `get_cell`).
5. Assign the layout to a `grid_trapdoor`'s `layout` export (Mode A).

### 3. Author a `CDGridEquation` formation

1. Create a `CDGridEquation` resource.
2. Set `columns`, `rows`, then tune `skip_chance` and `min_skips_per_row`.
3. Assign it to a `grid_trapdoor`'s `equation` export (Mode B).
4. Note: the grid trapdoor fills all non-skipped cells with a single scene —
   `CDGridEquation` does *not* map cells to scenes the way `CDGridLayout` does.

### 4. Configure a `CDSpawnContext`

1. Create a `CDSpawnContext` resource (or leave the export `null` for defaults).
2. Set the desired initial velocity / rotation / groups / randomization flags.
3. Assign it to any spawner that exposes a `spawn_context` export.

---

## How to add a new resource type to this folder

If a new spawn-related configuration concept is needed, follow the existing
conventions exactly:

1. **File name**: `cd_<snake_case_name>.gd` (matches `class_name` lowercased).
2. **Header doc-comment**: two-line `##` block — class name on line 1, one-line
   purpose on line 2.
3. **Class declaration**: `class_name CD<PascalName> extends Resource`.
4. **Exports**: each `@export var` gets its own `##` doc-comment above it, with
   units in parentheses where relevant (e.g. "radians").
5. **No spawning side effects**: this folder is data-only. If a new class needs to
   actually *do* spawning, it belongs in `game components/trapdoors/` or
   `entity components/arms/`, not here.
6. **Consumer wiring**: add an `@export var` of the new type on the consuming
   node and read it from there. Do not put Godot-node lifecycle code in these
   resources.

### Minimal template

```gdscript
## CDMyNewConfig
## One-line description of what this configures

class_name CDMyNewConfig extends Resource

## what this field controls (include units)
@export var some_value: float = 0.0