# Plan 26: Block Drop V2

## Overview

Block Drop (Tetris) reimplemented in the V2 Composable Architecture. This is the **second complete game built on V2 infrastructure** (after Galaga in Plan 25), and the first **pseudogrid** game — proving the architecture works for grid-based, discrete-input games where the physics world IS the grid.

Block Drop has no grid data structure. SettledCells are entities with collision shapes. Row scanning uses physics point queries. Row collapse is driven by entities listening to game bus announcements and computing their own drops. Every occupancy check is a `PhysicsPointQueryParameters2D` at the target cell position.

**Depends on:** Plan 19 (Core Infrastructure), Plan 19.5 (Object Pooling), Plan 20 (Stage), Plan 21 (Brains + Legs), Plan 22 (Arms + Guts), Plan 23 (Spawners), Plan 24 (Faces, Voices, Projections & Speakers), Plan 25 (Swarm Controllers — Group-as-State pattern, CDBusBridge)

---

## Key Architectural Decisions

### Decision 1: No Grid Data Structure

V1 used `grid_basic.gd` with a 2D occupancy array. V2 uses physics queries against SettledCell entities. This eliminates the grid component entirely. The physics world IS the grid.

- **Occupancy check:** `PhysicsPointQueryParameters2D` at target cell position
- **Row scanning:** One query per cell position per row (200 queries for 10×20, once per piece lock)
- **Row collapse:** Entities compute their own drops from game bus announcements

### Decision 2: Group-as-State for Piece Lifecycle

Pieces transition between `"active_piece"`, `"preview_piece"`, and `"held_piece"` groups. Brains and Guts check group membership before processing. This eliminates the V1 approach of stripping components and freezing processes.

- `"active_piece"` → ConditionalPlayerMoveBrain, ConditionalPlayerActionBrain, LockDetectorGuts, TimedStepBrain all process
- `"preview_piece"` → all processing frozen, entity sits at preview position
- `"held_piece"` → all processing frozen, entity sits at hold position

The Group-as-State pattern (Plan 25) handles the entire lifecycle. BlockDropManager moves entities between groups. No component stripping, no property overrides, no `set_process` calls.

### Decision 3: TetrominoGuts as Single Source of Truth

One Guts component holds all piece shape data. Multiple consumers react to `"shape_changed"`:

```
TetrominoGuts emits "shape_changed(cell_offsets, piece_color)"
  → SpriteFace / VectorFace draws the piece
  → GhostPieceFace computes and draws ghost
  → GridMovementLeg reads offsets for multi-cell validation
  → GridRotationAdvanced reads offsets for rotation computation
  → PieceSplitterArm reads offsets for cell spawn positions
  → LockDetectorGuts reads offsets for lock position computation
```

This follows the same pattern as AsteroidGuts → VectorFace + ShapeColliderGuts (Plan 24).

### Decision 4: Line Clear Brain Pattern

LineClearMonitor announces `"lines_cleared(row_indices)"` on the game bus. Each SettledCell independently computes how many rows to drop via its SettledDropBrain. The stage never directly sets entity positions. Entities determine their own fate based on broadcasted game state.

This is the "Line Clear Brain" approach identified in the Block Drop V2 brainstorm — the clear winner over raycasting (fragile, timing issues) and centralized math (violates entity-owns-state).

### Decision 5: BlockDropManager (Not CDSwarmStateMachine)

BlockDropManager uses the Group-as-State **pattern** without the CDSwarmStateMachine **machinery**. Reasons:

- CDSwarmStateMachine manages group transitions for swarms of entities. Block Drop manages 1-3 entities (active, preview, held).
- BlockDropManager still needs Tetris-specific logic: 7-bag queue, entity spawning, position management, level tracking, gravity speed table, spawn-blocked detection.
- Having both CDSwarmStateMachine AND BlockDropManager adds complexity without reducing code.
- Same relationship as FormationController — uses the pattern without the state machine.

---

## Changes to Existing Plans

### Plan 19: CDInputRouter — DAS/ARR Support

**Enhancement:** Add DAS (Delayed Auto Shift) and ARR (Auto Repeat Rate) to `CDInputRouter`.

DAS belongs at the input routing level, not the Brain level. All grid games benefit from frame-accurate auto-repeat. Brains receive the same `input_move` signal — they don't need to know about DAS.

| New Export | Type | Default | Description |
|------------|------|---------|-------------|
| `das_delay` | `float` | `0.0` | Seconds before auto-repeat starts. 0 = no DAS. |
| `arr_delay` | `float` | `0.05` | Seconds between repeated emissions during DAS. |

**Internal state (per player_id):**
```
_das_state: Dictionary  # player_id → { direction, timer, das_active, arr_timer }
```

**Behavior:**
- On first direction press: emit `input_move` immediately. Store direction + start DAS timer.
- While held: after `das_delay`, start emitting `input_move` at `arr_delay` intervals.
- On direction change: reset DAS state, emit new direction immediately.
- On release: clear DAS state.
- When `das_delay = 0` (default): no change to current behavior — no auto-repeat.

### Plan 20: New CueCard — LevelCard

**LevelCard** (extends CDCueCard)

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `starting_level` | `int` | `1` | Level at game start |
| `advance_signal` | `StringName` | `&"level_advance"` | Game bus signal that advances the level |
| `start_signal` | `StringName` | `&"game_play"` | Game bus signal that starts the game |
| `on_level_changed` | `Array[StringName]` | `[&"level_changed"]` | Signals emitted when level changes |

**Signal connections (Game Bus):**
- Listens: `start_signal`, `advance_signal`, `"level_reset"`

**Behavior:**
- On `start_signal`: set level to `starting_level`, emit `on_level_changed`.
- On `advance_signal`: increment level, emit `on_level_changed`.
- On `"level_reset"`: reset to `starting_level`.

### Plan 21: GridMovementLeg — "step_blocked" Signal

**Enhancement:** Add optional `"step_blocked"` signal emission.

| New Export | Type | Default | Description |
|------------|------|---------|-------------|
| `step_blocked_signal` | `StringName` | `&""` | Signal emitted on entity bus when movement is blocked. Empty = no emission. |

**Behavior:**
- When a move signal is received but the target cell is occupied or out of bounds: if `step_blocked_signal` is non-empty, emit it on the entity bus.
- Additive change — existing games without this export configured see no behavior change.

### Plan 22: LockDetectorGuts — step_blocked Mode

**Enhancement:** Add alternative floor detection via `"step_blocked"` signal.

| New Export | Type | Default | Description |
|------------|------|---------|-------------|
| `floor_signal` | `StringName` | `&""` | Entity bus signal to listen for floor detection. When set, uses this instead of `"collision"` for grounded detection. |

**Behavior:**
- When `floor_signal` is non-empty: listen for this signal instead of `"collision"` for grounded detection.
- On `floor_signal` received: start lock timer.
- On `"moved"` or `"rotated"`: reset lock timer (up to `max_resets`).
- When empty: use existing collision-based detection (unchanged behavior).

---

## New Components

### Entity Components (5)

---

#### TetrominoGuts

**Type:** CDComponent2D, Category: `GUTS`, Priority 50
**Purpose:** Single source of truth for piece shape data. Holds offsets, rotation states, wall kick tables, and piece color. Emits `"shape_changed"` when shape changes.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"configure_piece(piece_type: int)"` (from BlockDropManager on spawn) |
| **Generates** | Entity bus: `"shape_changed(cell_offsets: Array[Vector2i], piece_color: Color)"` |
| **Exports** | `piece_type: int = 0` (I=0, O=1, T=2, S=3, Z=4, J=5, L=6) <br> `randomize_on_init: bool = false` (for non-Block Drop use) <br> `color_table: Array[Color]` (color per piece type, 7 entries) <br> `rotations_resource: TetrominoRotations` (Resource with all rotation data + wall kicks) |

**Internal State:**
| Property | Type | Description |
|----------|------|-------------|
| `cell_offsets` | `Array[Vector2i]` | Current rotation cell positions (relative to entity) |
| `rotation_index` | `int` | Current rotation state (0-3) |
| `piece_color` | `Color` | Current display color |

**Key Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `get_cell_offsets() -> Array[Vector2i]` | Offsets | Current cell positions |
| `get_rotation_index() -> int` | Index | Current rotation state |
| `get_piece_color() -> Color` | Color | Current color |
| `get_world_cell_positions() -> Array[Vector2]` | Positions | entity.global_position + each offset × cell_size |
| `get_wall_kicks(rotation_from: int, rotation_to: int) -> Array[Vector2i]` | Kicks | SRS kick offsets for this rotation transition |
| `rotate_cw() -> bool` | Success | Advance rotation. Emit `"shape_changed"`. Returns false if no more states. |
| `rotate_ccw() -> bool` | Success | Reverse rotation. Emit `"shape_changed"`. Returns false if no more states. |
| `set_rotation(index: int)` | void | Set specific rotation. Emit `"shape_changed"`. |

**Process:**
1. On `_on_initialize()`: if `randomize_on_init`, pick random piece type. Load rotation data from `rotations_resource`. Set initial offsets from rotation 0. Emit `"shape_changed"`.
2. On `"configure_piece"`: set piece type, load rotations, set color from `color_table`, reset rotation to 0. Emit `"shape_changed"`.
3. On pool lifecycle (`_on_entity_activated()`): reset rotation to 0, reload offsets. Emit `"shape_changed"`.

**TetrominoRotations Resource:**
| Property | Type | Description |
|----------|------|-------------|
| `piece_rotations` | `Array[PieceRotationSet]` | 7 entries (one per piece type) |

**PieceRotationSet (inner Resource):**
| Property | Type | Description |
|----------|------|-------------|
| `rotations` | `Array[Array[Vector2i]]` | 4 rotation states, each with cell offsets |
| `wall_kicks` | `Array[Array[Vector2i]]` | Wall kick offsets per rotation transition (8 entries: 0→R, R→0, R→2, 2→R, 2→L, L→2, L→0, 0→L) |

---

#### ConditionalPlayerMoveBrain

**Type:** CDComponent2D, Category: `BRAIN`, Priority 10
**Purpose:** Routes directional input from CDInputRouter to entity bus, but only when entity is in a configured group. Generic — usable by any game needing group-gated movement input.

| Aspect | Detail |
|--------|--------|
| **Consumes** | `CDInputRouter.input_move(player_id, direction: Vector2)` |
| **Generates** | Entity bus: configurable name, type `(Vector2)` |
| **Exports** | `player_id: int = 0` <br> `active_group: StringName = &"active_piece"` <br> `move_signal: StringName = &"move"` |

**Process:**
- Each `_physics_process`: check if entity is in `active_group`. If not, skip.
- If in group: poll `CDInputRouter` current held direction for `player_id`. Emit `move_signal` with direction.

**Note:** DAS/ARR is handled by CDInputRouter (Plan 19 enhancement). This brain just reads the current input state.

---

#### ConditionalPlayerActionBrain

**Type:** CDComponent2D, Category: `BRAIN`, Priority 10
**Purpose:** Routes action button presses from CDInputRouter to entity bus signals, but only when entity is in a configured group. Generic — usable by any game needing group-gated action input.

| Aspect | Detail |
|--------|--------|
| **Consumes** | `CDInputRouter.input_action_pressed(player_id, action: StringName)` <br> `CDInputRouter.input_action_released(player_id, action: StringName)` |
| **Generates** | Entity bus: configurable action signals, type `(StringName)` |
| **Exports** | `player_id: int = 0` <br> `active_group: StringName = &"active_piece"` <br> `action_mappings: Array[StringName] = [&"rotate_cw", &"rotate_ccw", &"hard_drop", &"hold"]` <br> `action_signal: StringName = &"action"` |

**Process:**
- On `input_action_pressed`: check if entity is in `active_group`. If yes, check if action is in `action_mappings`. If yes, emit `action_signal` with the action StringName on entity bus.
- On `input_action_released`: same filtering, emit `action_end_signal` if configured.

**Use cases beyond Block Drop:** Any game where a player entity can be "active" or "inactive" (frozen, stunned, in a menu) and input should be gated by group membership.

---

#### SettledDropBrain

**Type:** CDComponent2D, Category: `BRAIN`, Priority 10
**Purpose:** Listens for line clears and computes how many rows this specific cell needs to drop. The "Line Clear Brain" pattern — entities determine their own fate from broadcasted game state.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Game bus: `"lines_cleared(row_indices: Array[int])"` |
| **Generates** | Entity bus: `"grid_drop(drop_count: int)"` |
| **Exports** | `playfield_origin_y: float = 0.0` <br> `cell_size_y: float = 18.0` <br> `drop_signal: StringName = &"grid_drop"` |

**Process:**
- On `"lines_cleared(row_indices)`: calculate current row from entity position:
  `current_row = int(round((entity.global_position.y - playfield_origin_y) / cell_size_y))`
- Count how many indices in `row_indices` are strictly greater than `current_row` (rows below this cell that were cleared).
- If `drop_count > 0`: emit `drop_signal` with `drop_count` on entity bus.

**Why this is the V2 Win:** The stage never reaches into an entity to change its position. It just announces "lines 19 and 20 cleared!" and the entities sort themselves out. Per-block juice (staggered drops, individual sounds) becomes trivial.

---

#### GhostPieceFace

**Type:** CDComponent2D, Category: `FACE`, Priority 60
**Purpose:** Computes and draws the ghost piece — a translucent outline at the piece's projected landing position. A Face component, not a Brain, because ghost rendering is visual output.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"shape_changed(cell_offsets, piece_color)"`. Entity `global_position`. TetrominoGuts sibling for current offsets. |
| **Generates** | Visual only — `_draw()` calls. No signals. |
| **Exports** | `cell_size: Vector2 = Vector2(18, 18)` <br> `color: Color = Color(1, 1, 1, 0.3)` (semi-transparent white) <br> `line_width: float = 1.0` <br> `active_group: StringName = &"active_piece"` |

**Process:**
1. On `"shape_changed"`: store new cell offsets.
2. Each `_physics_process` (when entity in `active_group`): project piece straight down via physics queries until blocked. Store ghost positions.
3. `_draw()`: for each ghost cell, draw a rectangle outline at the ghost position relative to entity origin.

**Ghost projection algorithm:**
```
displacement = 0
while can_drop_one_more(displacement):
    displacement += 1
ghost_positions = [entity.global_position + offset * cell_size + Vector2(0, displacement * cell_size.y) for offset in cell_offsets]
```

`can_drop_one_more()` uses `PhysicsPointQueryParameters2D` at each projected cell position, excluding the entity's own RID.

**Why a Face, not a Brain:** The ghost doesn't generate intent or affect game state. It reads shape data (from TetrominoGuts) and physics state (from queries) to produce visual output. This is the Face contract exactly — Priority 60, reads state, draws.

---

### Stage Components (2)

---

#### BlockDropManager

**Type:** CDStageComponent2D, Category: `STAGE`, Priority 70
**Purpose:** Macro-state manager for the Block Drop game. Manages the bag, spawning, hold, preview, and level progression. Does NOT move blocks, handle locking, or scan lines.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Game bus: `"game_play"`, `"piece_settled"`, `"hold_requested"`, `"level_changed"` |
| **Generates** | Game bus: `"spawn_blocked"`, `"level_advance"`. Entity bus on pieces: `"configure_piece(piece_type)"`. Manipulates entity groups. |
| **Exports** | `bag_scenes: Array[PackedScene]` (7 piece scenes, one per type) <br> `randomizer_mode: int = 0` (0 = BAG7, 1 = RANDOM) <br> `spawn_position: Vector2` <br> `preview_positions: Array[Vector2]` (next queue display positions) <br> `hold_position: Vector2` <br> `cell_pool: CDObjectPool` <br> `settled_cell_scene: PackedScene` <br> `piece_pool: CDObjectPool` <br> `gravity_table: Array[float]` (TimedStepBrain interval per level) <br> `lines_per_level: int = 10` <br> `initial_level: int = 1` |

**Internal State:**
| Property | Type | Description |
|----------|------|-------------|
| `_bag_queue` | `Array[int]` | Indices into bag_scenes for 7-bag randomizer |
| `_active_piece` | `CDEntity` | Current active piece entity |
| `_preview_pieces` | `Array[CDEntity]` | Preview piece entities |
| `_held_piece` | `CDEntity` | Held piece entity (null if none) |
| `_can_hold` | `bool` | Only one hold per drop |
| `_current_level` | `int` | Current game level |
| `_lines_at_level_start` | `int` | Lines cleared at start of current level |

**Process — On `"game_play"`:**
1. Reset bag, level, hold state.
2. Spawn preview pieces (fill preview queue).
3. Spawn first active piece: acquire from `piece_pool`, configure TetrominoGuts with piece type, position at `spawn_position`, add to `"active_piece"` group, activate.
4. Configure TimedStepBrain interval from `gravity_table[current_level]`.

**Process — On `"piece_settled"`:**
1. `_can_hold = true` (reset hold lock).
2. Check if spawn position is blocked: `PhysicsPointQueryParameters2D` at `spawn_position`. If occupied by `"settled"` group entity → emit `"spawn_blocked"` on game bus (triggers game over via Goal).
3. If clear: promote first preview piece to active (remove from `"preview_piece"`, add to `"active_piece"`, move to `spawn_position`).
4. Shift remaining previews forward in display positions.
5. Spawn new preview at last preview position from bag.
6. Configure TimedStepBrain interval on new active piece.

**Process — On `"hold_requested"`:**
1. Guard: `if !_can_hold or !_active_piece: return`
2. Set `_can_hold = false`.
3. Remove active from `"active_piece"`, add to `"held_piece"`, move to `hold_position`.
4. If `_held_piece` exists: remove from `"held_piece"`, add to `"active_piece"`, move to `spawn_position`, configure TimedStepBrain. Set `_held_piece = old_active`.
5. If no held piece: set `_held_piece = old_active`. Spawn next active from bag normally.

**Group-as-State behavior:**
- When piece moves to `"preview_piece"`: ConditionalPlayerMoveBrain, ConditionalPlayerActionBrain, TimedStepBrain, LockDetectorGuts all stop processing (they check group membership). Piece sits frozen at preview position.
- When piece moves to `"active_piece"`: all components resume processing immediately.
- No component stripping, no `set_process` calls, no property overrides.

**7-Bag Randomizer:**
- Shuffle all 7 piece type indices into `_bag_queue`.
- Draw from front of queue.
- When queue empty, reshuffle and refill.

**Level Progression:**
- Listen to `"score_gained"` or track lines cleared.
- When lines cleared ≥ `lines_at_level_start + lines_per_level`: increment level, emit `"level_advance"`.
- On level change: update TimedStepBrain interval on active piece from `gravity_table`.

---

#### LineClearMonitor

**Type:** CDStageComponent2D, Category: `STAGE`, Priority 70
**Purpose:** Scans the playfield for complete rows, kills cells in cleared rows, announces clears to game bus, drives scoring.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Game bus: `"piece_settled"`, `"t_spin_detected(is_t_spin: bool, is_mini: bool)"`. Physics space for row scanning. |
| **Generates** | Game bus: `"lines_cleared(row_indices: Array[int])"`, `"score_gained(points: int)"`, `"level_advance"`, `"line_clear_complete"`. Entity bus (targeted): `"kill_cell"` on specific SettledCell entities. |
| **Exports** | `playfield_origin: Vector2` <br> `cell_size: Vector2 = Vector2(18, 18)` <br> `rows: int = 20` <br> `columns: int = 10` <br> `target_group: StringName = &"settled"` <br> `clear_delay: float = 0.3` <br> `kill_signal: StringName = &"take_damage"` <br> **Scoring:** <br> `score_table: Array[int] = [0, 100, 300, 500, 800]` <br> `t_spin_table: Array[int] = [400, 800, 1200, 1600]` <br> `t_spin_mini_table: Array[int] = [100, 200, 400]` <br> `combo_table: Array[int] = [0, 50, 100, 150, 200, 300, 400, 500]` <br> `b2b_multiplier: float = 1.5` <br> `enable_combo: bool = true` <br> `enable_back_to_back: bool = true` <br> `enable_t_spin_scoring: bool = true` <br> `lines_per_level: int = 10` |

**Internal State:**
| Property | Type | Description |
|----------|------|-------------|
| `_combo_count` | `int` | Consecutive drops that cleared ≥1 line |
| `_is_b2b_eligible` | `bool` | Last clear was Tetris (4) or T-spin |
| `_last_t_spin` | `bool` | Last piece lock was T-spin |
| `_last_t_spin_mini` | `bool` | Last piece lock was T-spin mini |
| `_total_lines_cleared` | `int` | Running total for level progression |
| `_current_level` | `int` | Current game level |
| `_pending_settled` | `bool` | Flag: piece settled, scan pending |

**Process — On `"piece_settled"`:**
1. Set `_pending_settled = true`. Do NOT scan immediately — defer 1 frame so PieceSplitterArm finishes spawning cells.

**Process — Each `_physics_process`:**
1. If `_pending_settled`:
   - Clear flag.
   - Scan all rows via physics point queries.
   - For each row `r` from 0 to `rows-1`:
     - For each column `c` from 0 to `columns-1`:
       - Query position: `playfield_origin + Vector2(c * cell_size.x + cell_size.x/2, r * cell_size.y + cell_size.y/2)`
       - Filter results by `target_group` membership
       - If any cell position has no entity → row is not full
     - If all cells occupied → add row index to `full_rows`
   - Process clears (see below).

**Process — Clear full rows:**
1. If `full_rows` is empty:
   - If `enable_combo`: reset `_combo_count = 0`
   - Emit `"line_clear_complete"`
   - Return
2. For each row in `full_rows`:
   - Collect all SettledCell entities in that row (from scan results)
   - For each entity: emit `kill_signal` on entity's bus (triggers HealthPoolGuts → zero_health → deactivate)
3. Calculate score:
   - `line_count = full_rows.size()`
   - If T-spin full: `base = t_spin_table[line_count] × level`
   - If T-spin mini: `base = t_spin_mini_table[line_count] × level`
   - If regular: `base = score_table[line_count] × level`
   - If `enable_back_to_back` and `_is_b2b_eligible` and (Tetris or T-spin): apply `b2b_multiplier`
   - If `enable_combo` and `_combo_count > 0`: add `combo_table[min(_combo_count, combo_table.size()-1)]`
4. Emit `"score_gained(base + combo_bonus)"`
5. Emit `"lines_cleared(full_rows)"` → all SettledCells receive via SettledDropBrain
6. Update B2B eligibility: `_is_b2b_eligible = (line_count == 4 or _last_t_spin)`
7. If `enable_combo`: increment `_combo_count`
8. Update `_total_lines_cleared`, check level progression
9. After `clear_delay`: emit `"line_clear_complete"`

**Row scanning algorithm:**
```
for row in range(rows):
    var y_pos = playfield_origin.y + row * cell_size.y + cell_size.y / 2.0
    var row_full = true
    var row_entities: Array[CDEntity] = []
    for col in range(columns):
        var x_pos = playfield_origin.x + col * cell_size.x + cell_size.x / 2.0
        var query = PhysicsPointQueryParameters2D.new()
        query.position = Vector2(x_pos, y_pos)
        query.collision_mask = settled_layer_mask
        var results = space_state.intersect_point(query)
        var found = false
        for result in results:
            var body = result["collider"]
            if body.is_in_group(target_group):
                row_entities.append(body)
                found = true
                break
        if not found:
            row_full = false
            break
    if row_full:
        full_rows.append(row)
```

---

## Entity Scene Compositions

### ActivePiece.tscn

```
CDEntity (ActivePiece)
├── ConditionalPlayerMoveBrain (player_id=0, active_group="active_piece")
├── ConditionalPlayerActionBrain (player_id=0, active_group="active_piece", mappings=[rotate_cw, rotate_ccw, hard_drop, hold])
├── TimedStepBrain (step_direction=DOWN, step_signal="move")
├── GridMovementLeg (cell_size=(18,18), step_blocked_signal="step_blocked")
├── GridRotationAdvanced (rotations from TetrominoGuts)
├── TetrominoGuts (configured on spawn by BlockDropManager)
├── LockDetectorGuts (floor_signal="step_blocked", lock_delay=0.5, max_resets=15)
├── TSpinDetectorGuts (T-piece only — scene variant without this for non-T pieces)
├── PieceSplitterArm (settled_cell_scene, pool=cell_pool)
├── SpriteFace or VectorFace (draws cells from "shape_changed")
├── GhostPieceFace (draws ghost outline)
├── SoundVoice (trigger="moved" → move tick)
├── SoundVoice (trigger="rotated" → rotate click)
├── SoundVoice (trigger="piece_locked" → lock thud)
Groups: ["active_piece"]  (changed to "preview_piece" or "held_piece" by BlockDropManager)
```

**Note on TSpinDetectorGuts:** Only present on T-piece instances. BlockDropManager creates scene variants or adds the component only for T-pieces. Alternatively, TSpinDetectorGuts checks TetrominoGuts.piece_type and skips if not T.

### SettledCell.tscn

```
CDEntity (SettledCell)
├── SettledDropBrain (playfield_origin_y, cell_size_y=18)
├── GridDropLeg (cell_size_y=18, tween_duration=0.1)
├── HealthPoolGuts (max_health=1, damage_signal="take_damage")
├── SpriteFace (draws colored square, bindings for death flash)
├── SoundVoice (trigger="entity_deactivating" → optional death sound)
Groups: ["settled"]
```

---

## Block Drop Game Scene

```
CDGame (block_drop)
├── CDCollisionBuffer
├── CDGroupRegistry
├── CDCollisionMatrix
│   Groups: "active_pieces" → collides_with ["walls", "settled"]
│           "settled" → collides_with ["active_pieces", "walls"]
│           "walls" → collides_with ["active_pieces", "settled"]
│
├── PiecePool (CDObjectPool, scene=ActivePiece.tscn, initial_size=3)
├── CellPool (CDObjectPool, scene=SettledCell.tscn, initial_size=80)
│
├── BlockDropManager (Stage)
│   bag_scenes = [I.tscn, O.tscn, T.tscn, S.tscn, Z.tscn, J.tscn, L.tscn]
│   spawn_position = playfield top-center
│   preview_positions = [right side, stacked vertically]
│   hold_position = left side
│   gravity_table = [1.0, 0.9, 0.8, ...] (interval per level)
│
├── LineClearMonitor (Stage)
│   playfield_origin = top-left of playfield
│   cell_size = (18, 18)
│   rows = 20, columns = 10
│   scoring tables (from Plan 11)
│
├── ScoreCard (CueCard, is_interface=true) — listens "score_gained"
├── LevelCard (CueCard, is_interface=true) — listens "level_changed"
├── GroupCountGoal — watches "active_piece", count=0 + "spawn_blocked" → defeat
│
├── PlayfieldWalls (StaticBody2D)
│   ├── LeftWall (CollisionShape2D — tall thin rect)
│   ├── RightWall (CollisionShape2D)
│   └── BottomWall (CollisionShape2D)
│
├── SoundSpeaker — "score_gained" → line clear sound
├── SoundSpeaker — "level_changed" → level up jingle
├── CRTProjection — optional CRT effect
│
├── [Active Piece] — spawned by BlockDropManager, pooled via PiecePool
├── [Settled Cells] — spawned by PieceSplitterArm, pooled via CellPool
├── [Preview Pieces] — managed by BlockDropManager, group="preview_piece"
└── [Held Piece] — managed by BlockDropManager, group="held_piece"
```

---

## Full Signal Flow

```
START:
  CDGame emits "game_play" on game bus
    → BlockDropManager hears "game_play"
    → Fills bag, spawns previews, spawns active piece
    → Piece added to "active_piece" group
    → ConditionalPlayerBrains start processing

PLAY:
  CDInputRouter (with DAS) → emits input_move / input_action_pressed
    → ConditionalPlayerMoveBrain (in "active_piece") → emits "move(Vector2)" on entity bus
    → ConditionalPlayerActionBrain (in "active_piece") → emits "action(rotate_cw)" on entity bus
    → GridMovementLeg validates target via physics query → request_position_add()
      → If blocked: emits "step_blocked" on entity bus
    → GridRotationAdvanced rotates TetrominoGuts offsets
      → TetrominoGuts emits "shape_changed"
      → SpriteFace redraws, GhostPieceFace recomputes ghost
    → TimedStepBrain ticks → emits "move(Vector2.DOWN)"
      → GridMovementLeg validates → piece drops one row
      → If blocked: emits "step_blocked"

LOCK:
  LockDetectorGuts receives "step_blocked" → starts lock timer
  LockDetectorGuts receives "moved" or "rotated" → resets timer
  Lock timer expires → emits "piece_locked(cell_positions)"
    → TSpinDetectorGuts checks corners → announces "t_spin_detected" to game bus
    → PieceSplitterArm hears "piece_locked"
      → Spawns 4 SettledCells from CellPool at cell positions
      → Adds to "settled" group
      → Emits "piece_settled" on game bus (announcer pattern)
      → Emits "request_deactivate" on own entity bus → piece returns to PiecePool

CLEAR:
  LineClearMonitor hears "piece_settled" (1-frame delay for cell spawning)
    → Scans rows via physics point queries
    → Finds full rows
    → Emits "kill_cell" (via "take_damage") on each cell's entity bus
      → HealthPoolGuts → zero_health → entity deactivates → returns to CellPool
    → Calculates score (T-spin, combo, B2B)
    → Emits "lines_cleared(row_indices)" on game bus
    → Emits "score_gained(points)" on game bus
    → All surviving SettledCells receive "lines_cleared"
      → SettledDropBrain computes drop count → emits "grid_drop(N)"
      → GridDropLeg tweens entity down

SPAWN:
  BlockDropManager hears "piece_settled"
    → Checks spawn position (physics query)
    → If blocked: emits "spawn_blocked" → game over
    → If clear: promotes preview to active, spawns new preview

HOLD:
  Player presses hold → ConditionalPlayerActionBrain emits "action(hold)"
    → BlockDropManager hears via game bus relay
    → Removes active from "active_piece", adds to "held_piece"
    → Adds held to "active_piece" (or spawns new if no held piece)
    → Group change instantly gates all processing
```

---

## Implementation Order

### Phase 1: Shape + Board (no input, no game logic)

1. **TetrominoRotations resource** — define all rotation states + wall kicks for 7 piece types
2. **TetrominoGuts** — piece shape source of truth, emits `"shape_changed"`
3. **SettledCell.tscn** — CDEntity + HealthPoolGuts + SpriteFace
4. **Playfield walls** — StaticBody2D with left/right/bottom collision shapes
5. **Test:** place cells manually, verify collision shapes exist and physics queries detect them

### Phase 2: Piece Movement (player control)

6. **CDInputRouter DAS enhancement** — add per-player DAS/ARR state
7. **ConditionalPlayerMoveBrain** — group-gated directional input
8. **ConditionalPlayerActionBrain** — group-gated action input
9. **GridMovementLeg enhancement** — add `"step_blocked"` signal
10. **GridRotationAdvanced integration** — consume TetrominoGuts offsets, emit `"shape_changed"` via TetrominoGuts
11. **ActivePiece.tscn** — compose all components
12. **Test:** manual piece placement, move/rotate with keyboard

### Phase 3: Gravity + Lock

13. **LockDetectorGuts enhancement** — add `floor_signal` mode for `"step_blocked"`
14. **TimedStepBrain** — gravity on interval, emits `"move(DOWN)"`
15. **PieceSplitterArm integration** — spawn SettledCells on `"piece_locked"`
16. **Test:** piece falls, locks, cells appear on board

### Phase 4: Spawning + Game Flow

17. **BlockDropManager** — bag, spawn, preview, hold via Group-as-State
18. **LevelCard** — generic CueCard for level tracking
19. **Game scene composition** — wire everything together
20. **Test:** full spawn-lock-spawn cycle, hold, preview display, game over detection

### Phase 5: Line Clear + Scoring

21. **SettledDropBrain** — compute drop from `"lines_cleared"`
22. **GridDropLeg** — tweened cell drops
23. **LineClearMonitor** — row scanning, cell killing, scoring
24. **ScoreCard + LevelCard integration**
25. **Test:** clear lines, verify scoring, cells drop correctly

### Phase 6: Modern Features

26. **GhostPieceFace** — ghost projection and rendering
27. **TSpinDetectorGuts integration** — T-piece corner checking
28. **Lock delay with move resets** — verify max_resets behavior
29. **Level speed curve** — gravity_table, TimedStepBrain reconfiguration
30. **Test:** ghost, T-spin detection, level progression

### Phase 7: Juice + Polish

31. **SoundVoice instances** — move tick, rotate click, lock thud on ActivePiece
32. **SoundSpeaker instances** — line clear, level up, game over on CDGame
33. **SpriteFace bindings** — death flash on cells, lock squish
34. **Game flow** — attract → play → game over
35. **Test:** full polished gameplay loop

---

## Proof / Testing

### Test 1: TetrominoGuts Shape Changes
- ActivePiece with TetrominoGuts configured as T-piece
- VectorFace or SpriteFace connected to `"shape_changed"`
- Call `rotate_cw()` → offsets update → Face redraws → `"shape_changed"` emitted
- Verify all 4 rotation states correct

### Test 2: ConditionalPlayerBrains + Group-as-State
- ActivePiece with ConditionalPlayerMoveBrain (active_group="active_piece")
- Entity in "active_piece" group → press arrow → "move" emitted on entity bus
- Move entity to "preview_piece" group → press arrow → no signal emitted
- Move back to "active_piece" → press arrow → signal emitted again

### Test 3: Grid Movement + Step Blocked
- ActivePiece with GridMovementLeg (step_blocked_signal="step_blocked")
- SettledCells placed on board below piece
- Emit "move(DOWN)" → blocked → "step_blocked" fires on entity bus
- Emit "move(LEFT)" → unblocked → entity moves, no "step_blocked"

### Test 4: Full Lock Cycle
- ActivePiece falls via TimedStepBrain
- LockDetectorGuts receives "step_blocked" → starts lock timer
- Timer expires → "piece_locked" emitted
- PieceSplitterArm spawns 4 SettledCells → "piece_settled" on game bus
- ActivePiece deactivates (returns to pool)

### Test 5: Line Clear + Drop
- Fill a row with 10 SettledCells
- LineClearMonitor scans → finds full row
- Emits "take_damage" on each cell → cells deactivate
- Emits "lines_cleared([row_index])" on game bus
- SettledCells above: SettledDropBrain computes drop_count → GridDropLeg tweens down

### Test 6: Hold via Group-as-State
- ActivePiece in "active_piece" group, being controlled
- Hold requested → BlockDropManager moves to "held_piece" group
- ConditionalPlayerBrains stop processing immediately
- Previous held piece moved to "active_piece" group
- ConditionalPlayerBrains start processing immediately

### Test 7: GhostPieceFace
- ActivePiece with GhostPieceFace + TetrominoGuts
- SettledCells on lower rows
- Ghost drawn at projected landing position
- Rotate piece → ghost updates
- Move piece → ghost updates

### Test 8: Pool Lifecycle
- CellPool with initial_size=80
- Piece locks → PieceSplitterArm acquires 4 cells from pool
- Line clears → cells deactivated → return to pool
- Verify no memory leaks after 50 piece locks

---

## File Structure

```
Godot/Scripts/
├── Core/
│   └── cdinputrouter.gd          # Enhanced: DAS/ARR support
├── Brains/
│   ├── conditional_player_move_brain.gd    # Group-gated movement input
│   ├── conditional_player_action_brain.gd  # Group-gated action input
│   └── settled_drop_brain.gd               # Line clear drop computation
├── Guts/
│   └── tetromino_guts.gd         # Piece shape source of truth
├── Faces/
│   └── ghost_piece_face.gd       # Ghost piece projection + rendering
├── Stage/
│   ├── block_drop_manager.gd     # Bag, spawn, hold, level
│   ├── line_clear_monitor.gd     # Row scanning, scoring
│   └── level_card.gd             # Generic level CueCard
├── Resources/
│   └── tetromino_rotations.gd    # Rotation + wall kick data resource
├── Scenes/
│   ├── Games/
│   │   └── block_drop.tscn       # Block Drop game scene
│   ├── Entities/
│   │   ├── active_piece.tscn     # ActivePiece entity scene
│   │   └── settled_cell.tscn     # SettledCell entity scene
│   └── Resources/
│       ├── tetromino_i.tres      # I-piece rotation data
│       ├── tetromino_o.tres      # O-piece rotation data
│       ├── tetromino_t.tres      # T-piece rotation data
│       ├── tetromino_s.tres      # S-piece rotation data
│       ├── tetromino_z.tres      # Z-piece rotation data
│       ├── tetromino_j.tres      # J-piece rotation data
│       └── tetromino_l.tres      # L-piece rotation data
```

---

## Risks & Open Questions

1. **Physics query performance:** Row scanning does `rows × columns` physics point queries per piece lock (e.g., 200 for 10×20). This happens once per piece lock (not per frame), so it should be negligible. **Mitigation:** Profile during implementation. If it becomes an issue, cache a sparse representation of occupied cells alongside the entity-based approach.

2. **TetrominoGuts as shared dependency:** Multiple components (Face, Leg, Arm, Guts) all read from TetrominoGuts. If TetrominoGuts emits `"shape_changed"` and consumers react in the same frame, processing order depends on tree order. **Mitigation:** TetrominoGuts runs at Priority 50 (GUTS). Faces run at Priority 60. Legs run at Priority 20. Legs read offsets during their process (before Guts runs), Faces read during theirs (after). This is correct: Legs move based on current shape, Guts updates shape on rotation, Faces draw updated shape.

3. **Multi-cell collision shapes:** GridMovementLeg and GridRotationAdvanced validate all cell positions via physics queries. The piece entity itself may not need physical collision shapes. If it has no shapes, it won't register in `CDCollisionBuffer`. **Mitigation:** ActivePiece operates purely through query-based validation, not collision response. It should have no collision shapes (or disabled ones). This needs verification during Phase 2.

4. **Piece scene variants:** T-piece needs TSpinDetectorGuts; others don't. Options: (a) 7 scene variants, (b) single scene with TSpinDetectorGuts checking piece type, (c) BlockDropManager adds component at runtime. **Recommendation:** Option (b) — single scene, TSpinDetectorGuts checks TetrominoGuts.piece_type and skips if not T.

5. **Hold + preview position management:** BlockDropManager moves entities to world positions for preview/hold display. If the camera or viewport changes, these positions need updating. **Mitigation:** Use exported positions relative to the game scene. For the arcade cabinet (SubViewport), positions are within the game's coordinate space.

6. **1-frame delay in LineClearMonitor:** The delay after `"piece_settled"` ensures PieceSplitterArm finishes spawning cells. **Mitigation:** Same pattern as TSpinDetectorGuts (Plan 22). Document the timing dependency clearly.

7. **CDInputRouter DAS as global feature:** Adding DAS to CDInputRouter affects all games. The `das_delay = 0.0` default ensures no behavior change for non-grid games. **Mitigation:** Per-player configuration via exports. Grid games set `das_delay > 0`, continuous games leave at 0.

---

## Deferred to Later Plans

| Component | Deferred To | Reason |
|-----------|-------------|--------|
| Block Drop remixes (Invadertris, etc.) | Future remix plan | Core game first |
| Multiplayer Block Drop | Future plan | Single-player proves architecture |
| AnimatedFace for piece animations | Future plan | SpriteFace sufficient for Block Drop |
| Block Drop-specific UI (next box frame, board frame) | Polish pass | Scene-level drawing, no new components |

---

*End of Plan 26*