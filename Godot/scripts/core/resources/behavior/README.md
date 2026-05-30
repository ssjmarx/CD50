# Behavior Resources

4 resource classes that configure entity behavior rules. Some are data-only (exports), some include lightweight logic methods.

---

## CDDirectorRule — Entity Swap Rule

Defines one entity swap rule for StageDirector. When a trigger signal fires, selected entities from a group are swapped to a new scene.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `trigger_signals` | `Array[StringName]` | [] | Game bus signals that activate this rule |
| `target_group` | `StringName` | &"" | Which group to select entities from |
| `selector` | `CDSelector` | null | How to pick entities from the group |
| `swap_scene` | `PackedScene` | null | Scene to replace selected entities with |
| `deactivate_original` | `bool` | true | Whether to kill the original entity |

### Must-Includes

1. Set `trigger_signals` — which game bus events activate this rule
2. Set `target_group` — the group to scan for candidates
3. Assign a `CDSelector` — determines which entities get swapped
4. Set `swap_scene` — the replacement entity scene

---

## CDShape — Polygon Definition

Defines a polygon shape from 2D points. Used by Faces to set entity collision polygons.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `points` | `PackedVector2Array` | [] | Vertices of the polygon |
| `closed` | `bool` | true | Whether the shape auto-closes |

### Must-Includes

- Set `points` to define the polygon outline (clockwise, local-space coordinates)

---

## CDTransition — Group Transition Rule

Defines when and how entities move between groups. Used by Directors to orchestrate entity state changes.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `from_group` | `StringName` | &"" | Source group |
| `to_group` | `StringName` | &"" | Destination group |
| `trigger` | `CDTrigger` | null | What activates this transition |
| `selector` | `CDSelector` | null | How to pick entities from source group |
| `cooldown` | `float` | 0.0 | Seconds between activations |
| `emit_signal_name` | `StringName` | &"" | Signal emitted on entering target group |
| `exit_signal_name` | `StringName` | &"" | Signal emitted on leaving source group |
| `signal_args` | `Dictionary` | {} | Args passed with the signals |

### Methods

| Method | Purpose |
|--------|---------|
| `initialize(game)` | Reset timer, initialize trigger and selector |
| `advance_cooldown(delta)` | Tick down the cooldown timer |
| `is_on_cooldown()` | Check if transition is currently locked |
| `start_cooldown()` | Begin cooldown after activation |
| `reset()` | Full reset for game restart |
| `is_valid()` | Both groups must be non-empty |

### Must-Includes

1. Set `from_group` and `to_group` — the group swap
2. Assign a `CDTrigger` — what fires the transition
3. Assign a `CDSelector` — which entities transition
4. Optionally set `cooldown` to prevent rapid re-firing

---

## CDWallKick — Tetris Wall Kick Table

Defines offset tables for Tetris-style rotation kicks. When a piece can't rotate normally, each kick offset is tried in order.

### Kick Table Layout

8 rotation transitions indexed as:

| Index | Transition | Description |
|-------|-----------|-------------|
| 0 | 0→R | Spawn to Right |
| 1 | R→0 | Right to Spawn |
| 2 | R→2 | Right to 180° |
| 3 | 2→R | 180° to Right |
| 4 | 2→L | 180° to Left |
| 5 | L→2 | Left to 180° |
| 6 | L→0 | Left to Spawn |
| 7 | 0→L | Spawn to Left |

Rotation states: 0=spawn, 1=right, 2=180°, 3=left.

### Methods

| Method | Purpose |
|--------|---------|
| `get_kicks(from, to)` | Get kick offsets for a rotation transition |
| `_kick_index(from, to)` | Map rotation pair to table index |

### Must-Includes

- Fill the `kicks` array with `Vector2i` offsets for each of the 8 transitions
- Each inner array is tried in order — first successful position wins
