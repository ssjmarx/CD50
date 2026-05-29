# Spawner Resources

4 resource classes that configure entity spawning: two grid strategies (math-driven and data-driven), a grid row container, and a spawn context for initial entity state.

---

## CDSpawnContext — Entity Initial State

Configures velocity, rotation, and group membership for entities when they enter the tree. Applied by `CDUtilities.apply_spawn_context()` before the entity is added.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `velocity` | `Vector2` | ZERO | Initial velocity |
| `use_random_angle` | `bool` | false | Randomize velocity direction within angle range |
| `random_angle_min` | `float` | 0.0 | Min angle for random direction |
| `random_angle_max` | `float` | TAU | Max angle for random direction |
| `random_flip_h` | `bool` | false | Randomly flip horizontal velocity |
| `random_flip_v` | `bool` | false | Randomly flip vertical velocity |
| `rotation` | `float` | 0.0 | Initial rotation in radians |
| `additional_groups` | `Array[StringName]` | [] | Extra groups to add the entity to |

### Must-Includes

- Set `velocity` for moving entities (direction + speed)
- Use `random_flip_h`/`random_flip_v` for symmetrical spread patterns (asteroids, debris)
- Use `additional_groups` to tag spawned entities for game logic

---

## CDGridEquation — Math-Driven Grid

Defines a grid by dimensions with random skip chance. Useful for uniform grids with optional holes (Breakout, Space Invaders).

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `columns` | `int` | 10 | Grid width |
| `rows` | `int` | 8 | Grid height |
| `skip_chance` | `float` | 0.0 | Probability a cell is empty (0.0–1.0) |
| `min_skips_per_row` | `int` | 0 | Guaranteed minimum skips per row |

### Must-Includes

- Set `columns` and `rows` for the grid dimensions
- Use `skip_chance` for patterns with gaps (0 = solid grid)

---

## CDGridLayout — Data-Driven Grid

Defines a grid explicitly by an array of `CDGridRow` resources. Each cell can be a different `PackedScene` or null (empty). Used for hand-crafted formations.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `columns` | `int` | 5 | Grid width (for index math) |
| `rows` | `Array[CDGridRow]` | [] | Row data, each containing cell PackedScenes |

### Methods

| Method | Purpose |
|--------|---------|
| `get_spawn_count()` | Count non-null cells across all rows |
| `get_cell(index)` | Get PackedScene at flat index (row-major order) |

### Must-Includes

- Set `columns` to match the widest row
- Fill `rows` with `CDGridRow` resources, each containing the cell scenes
- Use null cells for gaps in the formation

---

## CDGridRow — Grid Row Container

One row of a `CDGridLayout`. Simple array of `PackedScene` entries (null = empty cell).

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `cells` | `Array[PackedScene]` | [] | Cell entries (null = skip) |