# Plan 10 — Gridless Tetris: Decomposition, Physics-Based Line Clearing, and Full Composition

**Created:** 2026-05-02
**Status:** Final Plan
**Depends On:** Plan 07 (components built), Plan 12 (grid_movement refactored for Space Invaders)

---

## Goals

1. **Full Tetris implementation** — playable game as a pure scene assembly, zero game scripts
2. **Decompose `tetromino_formation.gd`** — break the 278-line god component into focused single-responsibility components
3. **Delete `grid_basic.gd`** — all grid movement uses the "simulated grid" pattern from Space Invaders (step by pixels, `test_move()` for occupancy, `move_parent()` for bounds)
4. **Physics-based line clearing** — a line_clear_monitor that scans world-space collision shapes instead of a grid data structure
5. **Maximum remix potential** — every component works with the existing architecture, enabling cross-game mashups (fill gaps in Space Invaders formations with tetrominos, attach arbitrary components to pieces, etc.)

---

## Architecture Overview

### What Gets Decomposed

Current `tetromino_formation.gd` (278 lines) handles 7 responsibilities:

| Responsibility | Current Location | New Home |
|---|---|---|
| Auto-fall timer | `_process` fall_timer | **NEW `grid_gravity.gd`** (Leg — direct movement, no signal chain) |
| Lateral movement | `_on_move` + `_try_step` | **`grid_movement.gd`** (exists — add DAS + multi-cell bounds) |
| Hard drop | `_on_shoot` | **`grid_movement.gd`** (exists — `enable_hard_drop`) |
| Rotation + wall kicks | `_try_rotate` | **NEW `grid_rotation_advanced.gd`** |
| Floor detection + lock delay | `_is_on_floor` + `_is_locking` | **NEW `lock_detector.gd`** |
| Lock execution | `_lock_piece` | **`lock_detector.gd`** emits signal → `tetromino_spawner` handles |
| Cell registration | `_lock_piece → grid.register_cell` | **DELETED** — collision shapes ARE the data |

**After decomposition:** `tetromino_formation.gd` is deleted entirely.

### Signal Flow

```
INPUT:
  player_control  → body.move(LEFT/RIGHT)     every frame while held
  player_control  → body.thrust()              on button press
  player_control  → body.shoot()               on button press

PROCESSING:
  grid_movement          ← body.move           step by 20px, DAS auto-repeat, multi-cell bounds check
  grid_movement          ← body.shoot          hard drop (enable_hard_drop)
  grid_gravity           (self-timed)          direct parent.move_parent(DOWN), no signal chain
  grid_rotation_advanced ← body.thrust         rotate offsets + wall kicks

LOCK CYCLE:
  grid_gravity     → grounded signal           → lock_detector (start lock delay)
  grid_gravity     → fell signal               → lock_detector (reset lock timer)
  lock_detector    → piece_locked signal        → tetromino_spawner (spawn singles + next piece)
  lock_detector    → piece_settled signal       → line_clear_monitor (scan rows)

LINE CLEAR:
  line_clear_monitor  → lines_cleared signal   → scoring, level up, collapse remaining cells
```

---

## Component Changes

### 1. `grid_movement.gd` — Add DAS + Multi-Cell Bounds (Enhancement)

**Why DAS belongs here, not in player_control:** `player_control.gd` emits `move(direction)` every physics frame from held input axes — it answers "is the button held right now?" DAS answers "the button has been held for X seconds, start auto-repeating the step at Y interval." DAS modifies how movement input is *processed*, which is a movement behavior. Keeping it in the movement leg avoids signal routing complexity.

**New exports:**
```
@export var das_delay: float = 0.0       # Seconds before auto-repeat starts (0 = no DAS)
@export var das_repeat: float = 0.05     # Seconds between repeated steps during DAS
```

**Behavior:**
- When `das_delay > 0` and a non-zero direction is received via `_on_move`:
  - Store the held direction
  - On first press: execute one step immediately
  - After `das_delay` seconds of holding: start auto-repeating at `das_repeat` interval
  - When direction changes or goes to zero: reset DAS state
- When `das_delay = 0` (default): no change to current behavior

**Implementation note:** The DAS timer logic runs in `_process` alongside the existing `hop_delay` timer. These are separate timing systems — `hop_delay` gates how often *any* move executes, DAS gates how often a *held* move auto-repeats.

**Multi-cell bounds checking (enhancement):**

`_try_step()` currently only checks if the pivot point is in bounds (via `parent.move_parent()` clamping to `x_min/x_max/y_min/y_max`). For multi-cell bodies like tetrominos, the pivot can be in bounds while cells extend past the walls.

**New behavior:** Before executing a step, if the parent has a `current_offsets` property (i.e., it's a multi-cell body), check ALL cell positions against bounds:

```
# In _try_step(), after direction lock check and before physics test_move:
if parent.has_method("update_offsets"):  # multi-cell body
    for offset in parent.current_offsets:
        var cell_pos = parent.global_position + displacement + Vector2(offset.x * step_size, offset.y * step_size)
        if cell_pos.x < parent.x_min or cell_pos.x > parent.x_max:
            return false
        if cell_pos.y < parent.y_min or cell_pos.y > parent.y_max:
            return false
```

If no `current_offsets` exist (single-cell bodies like Space Invaders invaders), the existing pivot-only bounds check in `move_parent()` handles it. This is additive — zero impact on existing games.

---

### 2. `grid_gravity.gd` — NEW (Leg)

Gravity as a **direct movement force** — not routed through the Brain→Body→Leg signal chain. Moves the parent body downward on a timer by calling `parent.move_parent()` directly.

**Why not `falling_ai`:** `falling_ai` is a Brain that emits `parent.move.emit(DOWN)`, routing gravity through the same signal channel as player input. This causes problems:
- DAS timers and input queues in `grid_movement` can't distinguish gravity from player input
- Gravity steps fight with player horizontal movement for processing priority
- The signal chain adds latency and unpredictability to fall timing

Gravity isn't input — it's a world force. It should bypass the signal chain entirely.

**Responsibilities:**
1. Timer-based downward movement: every `fall_interval` seconds, attempt to move one step down
2. Check if movement is possible (physics occupancy via `test_move()` for all offsets + bounds check)
3. If yes → call `parent.move_parent()` directly, reset timer
4. If no → emit `grounded` signal (for lock_detector to start its lock delay countdown)
5. Support `paused` export for freezing gravity during line clear animations or game pause

**Exports:**
```
@export var fall_interval: float = 1.0     # seconds between gravity steps
@export var step_size: float = 20.0         # must match grid_movement.step_size and body tile_size
@export var paused: bool = false            # freeze gravity
```

**Signals:**
```
signal grounded    # emitted when gravity can't move the body down (floor or obstacle)
signal fell        # emitted after each successful gravity step (resets lock_detector timer)
```

**Runtime state:**
```
var _timer: float = 0.0
```

**Implementation:**
- `_process(delta)`: accumulate timer, attempt step when interval elapses
- Step check: if parent has `current_offsets`, check all offset cells for occupancy + bounds (same pattern as `grid_rotation_advanced._can_place_with_kick()`). If single-cell, use `parent.test_move()`.
- On successful step: `parent.move_parent(Vector2.DOWN * step_size)`, emit `fell`
- On blocked step: emit `grounded`, reset timer

**Relationship to lock_detector:** `lock_detector` listens to `grid_gravity.grounded` to start its lock delay countdown, and `grid_gravity.fell` to reset the lock delay. This replaces lock_detector's previous design of polling `parent.test_move()` itself — the gravity leg *is* the floor detector.

**`falling_ai.gd` status:** Remains in the codebase for non-Tetris use cases (simple "move DOWN on timer" brain behavior), but is no longer used by Tetris.

---

### 3. `grid_rotation_advanced.gd` — NEW (Leg)

Offset-based rotation for multi-cell bodies with wall kick support. Unlike `grid_rotation.gd` (which only rotates `parent.rotation` visually), this rotates the **collision shape offsets** — actual structural rotation.

**Responsibilities:**
1. Listen for rotation signal (configurable, default: `thrust`)
2. Read current offsets from parent body's `current_offsets` array
3. Rotate all offsets mathematically: CW → `Vector2i(-offset.y, offset.x)`, CCW → `Vector2i(offset.y, -offset.x)`
4. Call `parent.update_offsets(rotated_offsets)` — this rebuilds collision shapes at new positions
5. Validate the new configuration: check if any cell overlaps existing collision or is out of bounds
6. If invalid: try wall kick offsets (shift body position by `step_size` increments)
7. If a kick succeeds: apply position shift via `parent.move_parent()` + keep new offsets
8. If all kicks fail: revert to old offsets by calling `parent.update_offsets(old_offsets)`
9. Emit `rotated` signal on success
10. Reset lock timer on successful rotation (if lock_detector is present)

**Exports:**
```
@export var rotation_signal: String = "thrust"    # which body signal triggers rotation
@export var clockwise: bool = true
@export var step_size: float = 20.0               # must match grid_movement.step_size and body tile_size
@export var kick_offsets: Array[Vector2i] = [      # ordered kick attempts
    Vector2i(0, 0),
    Vector2i(-1, 0),
    Vector2i(1, 0),
    Vector2i(0, -1),
    Vector2i(-2, 0),
    Vector2i(2, 0)
]
```

**Validation method:** For each cell position (parent position + offset × step_size):
- Use `PhysicsDirectSpaceState2D.intersect_point()` to check for overlaps
- Exclude the parent body's own RID from the query
- Check against UniversalBody bounds (`x_min/x_max/y_min/y_max`)

**Kick mechanics:** Each kick offset is multiplied by `step_size` and applied as a position shift. The body attempts to move to the kicked position while keeping the rotated offsets. If the kicked position is valid, the body moves there. This means kicks are expressed in grid cells (Vector2i) and converted to pixels via step_size.

---

### 4. `lock_detector.gd` — NEW (Component)

Detects when a multi-cell body can't fall further, manages lock delay, and emits settlement signals. Does NOT handle spawning or splitting — that's `tetromino_spawner`'s job.

**Responsibilities:**
1. Listen to `grid_gravity.grounded` signal → start lock delay timer
2. Listen to `grid_gravity.fell` signal → cancel lock (piece moved down successfully)
3. If body moves laterally (listen to `grid_movement.moved` signal) → reset lock timer
4. If body rotates successfully (listen to `grid_rotation_advanced.rotated` signal) → reset lock timer
5. If lock timer expires → execute lock:
   - Emit `piece_locked` signal with the current cell positions (world positions of each offset)
   - The spawner (or any listener) handles what happens next (split into singles, spawn next piece, etc.)
6. If piece moves off the floor (successful downward move while locking was about to happen) → cancel lock

**Exports:**
```
@export var lock_delay: float = 0.5
```

**Signals:**
```
signal piece_locked(cell_positions: Array[Vector2])    # world positions of each cell when locked
signal lock_cancelled                                     # if piece somehow escapes the floor (edge case)
```

**Runtime state:**
```
var _is_locking: bool = false
var _lock_timer: float = 0.0
var _gravity_leg: Node     # reference to grid_gravity for grounded/fell signals
var _movement_leg: Node    # reference to grid_movement for moved signal
var _rotation_leg: Node    # reference to grid_rotation_advanced for rotated signal
```

**Implementation notes:**
- The `cell_positions` array in `piece_locked` is computed from `parent.global_position` + each offset in `parent.current_offsets × step_size`
- The lock detector does NOT poll `test_move()` itself — it relies on `grid_gravity` to be the floor detector
- The lock detector does NOT remove brains or legs — that's the spawner's responsibility
- The lock detector does NOT spawn singles — that's the spawner's responsibility
- This keeps the lock detector focused on one thing: "gravity says we're grounded, start the lock countdown"

---

### 5. `line_clear_monitor.gd` — REWRITE (Rule)

Physics-based line detection using world-space queries. Zero grid data structure dependency.

**Responsibilities:**
1. Define playfield area via exports (origin, cell_size, rows, columns)
2. Listen for `piece_settled` signal from tetromino_spawner (or any signal configured via export)
3. On trigger: scan for full rows
4. For each row y-position: query each cell x-position using `PhysicsDirectSpaceState2D.intersect_point()`
5. Filter results by `target_group` (e.g., "settled")
6. If all cells in a row have a body in the target group → row is full
7. Clear: `queue_free` all bodies in full rows
8. Collapse: find all remaining settled bodies above each cleared row, shift their position down by `cell_size.y`
9. Emit scoring signals (lines_cleared, level_changed, score_gained)

**Exports:**
```
@export var playfield_origin: Vector2             # top-left corner of playfield in world space
@export var cell_size: Vector2 = Vector2(20, 20)  # must match tetromino tile_size
@export var rows: int = 20
@export var columns: int = 10
@export var target_group: String = "settled"       # which group counts as "filled"
@export var listen_signal: String = "piece_settled" # signal name to listen for on game
@export var clear_delay: float = 0.3               # pause for clear animation
@export var lines_per_level: int = 10
@export var score_table: Array[int] = [0, 100, 300, 500, 800]
@export var margin: float = 2.0                    # position tolerance for queries
```

**Signals:**
```
signal lines_cleared(count: int, row_indices: Array[int])
signal level_changed(new_level: int)
signal score_gained(points: int)
```

**Row scanning algorithm:**
```
for row in range(rows):
    y_pos = playfield_origin.y + row * cell_size.y + cell_size.y / 2
    row_full = true
    for col in range(columns):
        x_pos = playfield_origin.x + col * cell_size.x + cell_size.x / 2
        query = PhysicsPointQueryParameters2D.new()
        query.position = Vector2(x_pos, y_pos)
        query.collision_mask = ... # layer for settled pieces
        results = space_state.intersect_point(query)
        # Filter by target_group membership
        if no valid result:
            row_full = false
            break
    if row_full:
        full_rows.append(row)
```

**Row clearing:** For each full row, iterate cells again, find bodies, `queue_free()` them.

**Row collapse:** After clearing, find all bodies in `target_group` that are above the cleared rows. For each cleared row (processed bottom-to-top), shift all bodies above it down by `cell_size.y`. This is done by iterating the `target_group` via `get_tree().get_nodes_in_group()`.

**Remix-friendly design:** The `target_group` export means you can configure it to look for ANY group. Space Invaders in "invaders" group? Set `target_group = "invaders"` and if tetrominos fill the gaps between invaders, the row clears. Mixed entity types work as long as they're in the target group and have collision shapes at the correct positions.

---

### 6. `tetromino_spawner.gd` — MAJOR UPDATE (Flow)

The spawner becomes the central coordinator for the lock-spawn cycle. It handles piece locking (splitting into singles), next piece spawning, preview display, and defeat detection. No `grid_basic` dependency.

**Responsibilities:**

1. **Detect lock:** Listen for `lock_detector.piece_locked` signal on the active piece
2. **Split into singles:** On lock, spawn a `tetromino_single` body at each cell position of the locked piece, then `queue_free()` the multi-cell piece
3. **Attach components to singles:** Configure an arbitrary list of component scenes to attach to each spawned single (e.g., health, score_on_death, etc.)
4. **Override properties on singles:** Configure an arbitrary list of property overrides on each spawned single (same pattern as `wave_spawner.property_overrides`)
5. **Spawn next piece:** Instantiate the next tetromino at the spawner's location
6. **Attach components to new piece:** Configure an arbitrary list of component scenes to attach to the new piece (e.g., grid_gravity, grid_movement, grid_rotation_advanced, lock_detector, player_control)
7. **Override properties on new piece:** Configure an arbitrary list of property overrides on the new piece
8. **Preview display:** Spawn the next piece on the board at a configurable preview position (as a real entity — enables preview of space invaders, bombs, or any custom piece type)
9. **Bag system:** Accept an arbitrary array of PackedScenes as the bag (no more hard-coded bag7)
10. **Defeat detection:** Check if spawn position is occupied before spawning; if so, emit `defeat`

**Exports:**
```
# Bag configuration
@export var bag: Array[PackedScene] = []                    # scenes to pick from (can be tetrominos, invaders, anything)
@export var randomizer_mode: String = "bag7"                # "bag7" or "random"

# Spawning
@export var cell_size: Vector2 = Vector2(20, 20)            # for computing cell positions
@export var settled_cell_scene: PackedScene                 # scene for individual settled cells
@export var settled_cell_components: Array[PackedScene] = [] # components to attach to each settled cell
@export var settled_cell_overrides: Array[PropertyOverride] = [] # property overrides for settled cells
@export var settled_group: String = "settled"               # group to add settled cells to

# Active piece configuration
@export var active_piece_components: Array[PackedScene] = [] # components to attach to active piece
@export var active_piece_overrides: Array[PropertyOverride] = [] # property overrides for active piece

# Preview
@export var preview_origin: Vector2 = Vector2(500, 40)      # where to spawn the preview entity
```

**Runtime state:**
```
var _active_piece: Node
var _preview_piece: Node
var _bag_queue: Array[int] = []      # indices into bag array
var _next_index: int = -1
```

**Lock cycle flow:**
```
lock_detector.piece_locked(cell_positions)
  → For each cell_position:
      - Instantiate settled_cell_scene
      - Set position to cell_position
      - Add to game as child
      - Add to settled_group
      - Attach settled_cell_components
      - Apply settled_cell_overrides
  → queue_free() the multi-cell active piece
  → Emit piece_settled signal (for line_clear_monitor)
  → Check defeat (is spawn position blocked?)
  → Spawn next piece
```

**Spawn flow:**
```
_spawn_next():
  1. Move preview piece to spawner location (or instantiate new if no preview)
  2. Attach active_piece_components (player_control, grid_gravity, grid_movement, grid_rotation_advanced, lock_detector)
  3. Apply active_piece_overrides
  4. Connect to lock_detector.piece_locked
  5. Spawn new preview piece at preview_origin
```

**Preview system:** The preview is a real spawned entity, placed at `preview_origin`. When it becomes the active piece, it's moved to the spawner's position and given active components. This means:
- Custom piece types (space invaders, bombs, power-ups) preview correctly
- No special preview rendering code needed
- Preview entity can be interacted with if desired (remix potential)

**Bag system:** Instead of hard-coded piece names and shape enums, the bag is an array of PackedScenes. Any scene can be in the bag:
- Standard tetrominos (tetromino.tscn with shape export)
- Single blocks (tetromino_single.tscn)
- Space invaders (invader.tscn)
- Custom piece scenes
- The randomizer picks from this array, not from a hard-coded dictionary

**Defeat detection:** Before spawning, use `PhysicsDirectSpaceState2D.intersect_point()` at the spawn position. If occupied by a settled cell → emit `game.defeat`.

---

### 7. `tetromino.gd` — MINOR UPDATE (Body)

Changes:
- `tetromino_single` variant: When used as a single cell, the body should draw one square at the origin with no offsets. Add a `single_cell: bool = false` export. When true, ignore shape/offsets, draw one tile_size square centered at origin, build one collision shape at origin.
- Keep `update_offsets()` for multi-cell rotation support
- `randomize_shape` should default to false (the spawner controls what gets spawned), but remain available for remix potential
- `current_offsets` should default to the shape offsets on ready (as it does now)

**Note:** `tetromino_single.tscn` will be updated to use `single_cell = true` and `randomize_shape = false`.

---

### 8. `grid_basic.gd` — DELETE

Remove script and scene after all dependent components are updated and Tetris is working.

**Consumers to update before deletion:**
- `tetromino_formation.gd` → being deleted
- `line_clear_monitor.gd` → being rewritten
- `tetromino_spawner.gd` → being updated
- No other components use `grid_basic` (Space Invaders doesn't use it)

---

### 9. `tetromino_formation.gd` — DELETE

Deleted after decomposition is complete. All responsibilities distributed to:
- `grid_gravity.gd` (new — direct gravity, no signal chain)
- `grid_movement.gd` (enhanced with DAS + multi-cell bounds)
- `grid_rotation_advanced.gd` (new)
- `lock_detector.gd` (new)
- `tetromino_spawner.gd` (updated)

---

## Tetris Scene Composition

```
UniversalGameScript (tetris)
├── CollisionMatrix (Core) — collision groups: pieces, settled, walls
├── TetrominoSpawner (Flow) — at playfield top-center, manages lock/spawn cycle
├── LineClearMonitor (Rule) — physics-based row scanning on piece_settled
├── Timer (Rule) — level timer
├── VariableTuner (Rule) — adjust grid_gravity.fall_interval on level_changed
├── PointsMonitor (Rule) — score threshold
├── Interface (Flow) — score, level
├── SoundSynth (Flow) — line clear sound, piece lock sound
│
├── [Playfield Walls] (StaticBody2D)
│   ├── Left wall — CollisionShape2D
│   ├── Right wall — CollisionShape2D
│   └── Bottom wall — CollisionShape2D
│
├── [Active Tetromino] (spawned by TetrominoSpawner)
│   ├── PlayerControl (Brain) — left/right/thrust/shoot input
│   ├── GridGravity (Leg) — direct downward movement on timer, bypasses signal chain
│   ├── GridMovement (Leg) — step_size=20, DAS, hard_drop, prevent_up=true, multi-cell bounds
│   ├── GridRotationAdvanced (Leg) — offset rotation with kicks
│   └── LockDetector (Component) — listens to grid_gravity.grounded, lock delay timer
│
└── [Settled Cells] (spawned by TetrominoSpawner on lock)
    └── tetromino_single bodies in "settled" group
```

**Entity bounds configuration on tetromino body:**
- `x_min`, `x_max` → playfield left/right boundaries (clamps lateral movement)
- `y_min` = 0, `y_max` → playfield bottom (clamps downward movement)

**Collision layers:**
- `pieces` — active tetrominos (collide with walls, settled cells)
- `settled` — locked single cells (collide with pieces, walls)
- `walls` — playfield boundaries (collide with everything)

---

## Build Order

| Step | Component | Action | Risk | Test |
|---|---|---|---|---|
| 1 | `grid_movement.gd` | Add DAS + multi-cell bounds check | Low — additive change, default off | Verify existing Space Invaders still works |
| 2 | `grid_gravity.gd` | Create new leg | Medium — new component, replaces falling_ai for Tetris | Test: tetromino falls on timer, stops at floor |
| 3 | `grid_rotation_advanced.gd` | Create new leg | Medium — new component, validation logic | Test: tetromino body, rotate with kicks, verify collision shapes rebuild |
| 4 | `lock_detector.gd` | Create new component | Medium — timing logic, listens to grid_gravity signals | Test: tetromino falls, stops at floor, locks after delay |
| 5 | `line_clear_monitor.gd` | Rewrite for physics | High — core game logic, collapse is tricky | Test: fill a row manually, verify it clears and collapses |
| 6 | `tetromino.gd` | Add single_cell export | Low — additive | Test: single cell draws and collides correctly |
| 7 | `tetromino_spawner.gd` | Major update | High — most complex change, coordinates lock/spawn cycle | Test: full spawn-lock-spawn cycle |
| 8 | `tetris.tscn` | Compose game scene | Medium — scene assembly, export configuration | Test: full gameplay loop |
| 9 | Delete old components | Delete `grid_basic` + `tetromino_formation` | Low — cleanup after verification | Verify no references remain |

---

## Remix Scenarios Enabled

| Scenario | How It Works |
|---|---|
| **Invadertris** | Put space invader scenes in the bag. Line_clear_monitor with `target_group = "invaders"` clears rows of invaders. |
| **Bomb pieces** | Put a custom "bomb" scene in the bag. On lock, bomb explodes nearby settled cells. |
| **Non-grid movement** | Remove grid_movement, attach direct_movement + engine_simple. Tetrominos fly freely with Asteroids controls. |
| **Shootable settled cells** | Add Health + DieOnHit to settled_cell_components. Shoot settled cells to destroy them. |
| **Gravity flip** | Set grid_gravity direction = UP, lock_detector listens to grounded signal, line_clear_monitor scans top-to-bottom. |
| **Centipede-style** | Attach LockDetector to a chain of segments. Each segment locks independently. |
| **Tetrominos as obstacles** | Spawn tetrominos via wave_spawner in any game. They settle via LockDetector and become terrain. |

---

## Files Changed Summary

| File | Action | Category |
|---|---|---|
| `Scripts/Legs/grid_movement.gd` | Enhancement (add DAS + multi-cell bounds) | Legs |
| `Scripts/Legs/grid_gravity.gd` | Create new | Legs |
| `Scripts/Legs/grid_rotation_advanced.gd` | Create new | Legs |
| `Scripts/Components/lock_detector.gd` | Create new | Components |
| `Scripts/Rules/line_clear_monitor.gd` | Rewrite | Rules |
| `Scripts/Flow/tetromino_spawner.gd` | Major update | Flow |
| `Scripts/Bodies/tetromino.gd` | Minor update (add single_cell) | Bodies |
| `Scenes/Legs/grid_gravity.tscn` | Create new | Scenes |
| `Scenes/Legs/grid_rotation_advanced.tscn` | Create new | Scenes |
| `Scenes/Components/lock_detector.tscn` | Create new | Scenes |
| `Scenes/Bodies/generic/tetromino_single.tscn` | Update (single_cell=true) | Scenes |
| `Scenes/Games/remakes/tetris.tscn` | Create new | Scenes |
| `Scripts/Flow/grid_basic.gd` | Delete | Flow |
| `Scenes/Flow/grid_basic.tscn` | Delete | Scenes |
| `Scripts/Legs/tetromino_formation.gd` | Delete | Legs |

---

## Open Decisions (Resolved)

| Decision | Resolution |
|---|---|
| Split on lock? | **Yes** — spawn individual cell bodies on lock, queue_free multi-cell body |
| Kick table | **Simple** — (0,0), (-1,0), (1,0), (0,-1), (-2,0), (2,0) |
| Playfield boundaries | **Both supported** — grid_movement works with physical walls AND x_min/x_max |
| Player control routing | **Attach to piece** — player_control on each spawned piece, removed on lock |
| Bespoke spawner vs wave_spawner | **Keep tetromino_spawner** — spawning complexity justifies a dedicated component |
| DAS location | **grid_movement** — not redundant with player_control (player_control emits raw held state, DAS transforms held→auto-repeat) |
| Gravity routing | **grid_gravity Leg** — direct `move_parent()`, not routed through Brain→Body→Leg signal chain. Gravity is a world force, not input. |
| Multi-cell bounds | **Enhance grid_movement** — offset-aware bounds check in `_try_step()`, additive change, no new component needed |

---

*End of Plan 10*