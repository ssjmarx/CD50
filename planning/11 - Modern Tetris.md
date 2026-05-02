# Modern Tetris Features

## Overview

Enhance the CD50 Tetris implementation with modern features while preserving full backward compatibility to original Tetris (1984) through toggleable components and export variables. Every feature can be disabled in the scene editor to downgrade to any historical version.

### Version Reference

| Version | Year | Key Features |
|---------|------|-------------|
| **Elektronika 60** | 1984 | Original — no lock delay, no ghost, no hold, no T-spin, pure random pieces |
| **Spectrum HoloByte** | 1988 | Short lock delay, simple scoring, Russian visual theme |
| **Nintendo NES** | 1989 | Lock delay, level speed curve, NES scoring table |
| **Nintendo Game Boy** | 1989 | Lock delay, battery save, simple scoring |
| **Tetris Guideline** | 2001+ | Ghost, hold, 7-bag, lock delay with move limit, T-spin, SRS rotation |
| **Modern Guideline** | 2018+ | All 2001 features + T-spin mini, combo, back-to-back bonus |

---

## Feature 1: Lock Delay Move Limit

### Purpose
Prevents "infinite spin" by capping how many times a player can reset the lock timer with moves/rotations while grounded. After the cap is exceeded, the piece locks immediately.

### Files
- `Scripts/Components/lock_detector.gd` — enhancement

### New Exports

```gdscript
# Maximum lock timer resets from moves/rotations while grounded.
# Original:   0 (no limit — piece locks instantly, no delay to reset)
# NES/GB:     0 (no limit — lock delay is short enough it doesn't matter)
# 2001:       15 (Guideline standard)
# Modern:     15
@export var max_lock_resets: int = 15
```

### New Runtime State

```gdscript
var _lock_reset_count: int = 0
```

### Behavior

- `_on_piece_moved()` and `_on_piece_rotated()`: increment `_lock_reset_count`. If `max_lock_resets > 0` and count exceeds max → `_execute_lock()` immediately.
- When `_is_locking` transitions to true (piece just landed): reset `_lock_reset_count = 0`.
- When lock is cancelled (piece leaves floor): reset `_lock_reset_count = 0`.
- When `max_lock_resets = 0`: no change to current behavior. Acts as unlimited resets.

### Existing Lock Delay Reference

```gdscript
# Lock delay: seconds before a grounded piece locks.
# Original:    0.0 (instant lock, no delay)
# NES:         ~0.5 (varies by level — higher levels are shorter)
# Game Boy:    ~0.5
# 2001+:       0.5 (Guideline standard)
# Modern:      0.5
@export var lock_delay: float = 0.5
```

---

## Feature 2: Pre-Lock Signal (T-Spin Prerequisite)

### Purpose
Provides a signal that fires BEFORE `piece_locked`, giving T-spin detection a chance to inspect the piece's final state while the multi-cell body still exists intact.

### Files
- `Scripts/Components/lock_detector.gd` — minor addition

### New Signal

```gdscript
# Emitted immediately before piece_locked, while the multi-cell body
# still exists. Use for T-spin detection and other pre-lock checks.
signal piece_pre_lock(cell_positions: Array[Vector2])
```

### Behavior

In `_execute_lock()`, emit `piece_pre_lock` immediately before `piece_locked`:

```gdscript
func _execute_lock() -> void:
    set_process(false)
    var cell_positions: Array[Vector2] = []
    # ... compute cell_positions (existing logic) ...
    piece_pre_lock.emit(cell_positions)  # NEW — T-spin detector listens here
    piece_locked.emit(cell_positions)    # EXISTING — spawner splits here
```

Signal ordering guarantees T-spin detection runs before the spawner splits the piece.

---

## Feature 3: Ghost Piece (Shadow)

### Purpose
Shows a transparent outline of the active piece at its projected landing position. Standard visual aid since 2001.

### Files
- `Scripts/Components/ghost_piece.gd` — **CREATE NEW**
- `Scripts/Bodies/tetromino.gd` — minor update
- `Scenes/Components/ghost_piece.tscn` — **CREATE NEW**

### Architecture

The ghost is a component attached to the active piece (via `active_piece_components` in `tetromino_spawner`). It projects the piece downward using the same physics query logic as hard drop, then stores the projected offsets on the parent body. The body's `_draw()` renders ghost offsets as polyline outlines.

**Why not a separate entity?** The active piece body already draws itself in `_draw()`. Adding ghost rendering there is a 3-line change. A separate entity would need its own collision avoidance, position tracking, and lifecycle management — heavier for no benefit.

### Component: `ghost_piece.gd`

```gdscript
extends UniversalComponent

# Grid spacing for projection. Must match grid_movement.step_size.
# All versions: 20.0 (standard cell size)
@export var step_size: float = 20.0

func _ready() -> void:
    # Defer to allow siblings to be ready
    call_deferred("_connect_signals")

func _connect_signals() -> void:
    # Listen to sibling movement and rotation signals
    for child in parent.get_children():
        if child.has_signal("moved") and child != self:
            child.moved.connect(_update_ghost)
        if child.has_signal("rotated"):
            child.rotated.connect(_update_ghost)
    # Initial ghost calculation
    _update_ghost()

func _update_ghost() -> void:
    var ghost = _project_landing()
    parent.ghost_offsets = ghost
    parent.queue_redraw()

# Project the piece straight down until blocked
func _project_landing() -> Array[Vector2i]:
    var displacement = 0
    while _can_drop_one_more(displacement):
        displacement += 1
    # Convert landing position back to offsets relative to parent
    var offsets: Array[Vector2i] = []
    for offset in parent.current_offsets:
        offsets.append(Vector2i(offset.x, offset.y + displacement))
    return offsets

# Test if piece can exist one step further down from current displacement
func _can_drop_one_more(current_displacement: int) -> bool:
    var space_state = parent.get_world_2d().direct_space_state
    var test_y = parent.global_position.y + (current_displacement + 1) * step_size
    for offset in parent.current_offsets:
        var cell_pos = Vector2(
            parent.global_position.x + offset.x * step_size,
            test_y + offset.y * step_size
        )
        # Bounds check
        if cell_pos.x < parent.x_min or cell_pos.x > parent.x_max:
            return false
        if cell_pos.y < parent.y_min or cell_pos.y > parent.y_max:
            return false
        # Physics occupancy check
        if _is_cell_occupied(space_state, cell_pos):
            return false
    return true

func _is_cell_occupied(space_state, cell_pos: Vector2) -> bool:
    var shape := RectangleShape2D.new()
    shape.size = Vector2(step_size, step_size)
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = shape
    query.transform = Transform2D(0, cell_pos)
    query.collision_mask = parent.collision_mask
    query.exclude = [parent.get_rid()]
    return space_state.intersect_shape(query).size() > 0

func _exit_tree() -> void:
    # Signal cleanup handled by parent freeing
    pass
```

### Body Update: `tetromino.gd`

New property:
```gdscript
# Ghost piece offsets — set by ghost_piece component. Empty = no ghost.
var ghost_offsets: Array[Vector2i] = []
```

Updated `_draw()`:
```gdscript
func _draw() -> void:
    # Draw filled cells (existing)
    for offset in current_offsets:
        var pos := Vector2(offset.x * tile_size, offset.y * tile_size)
        draw_rect(Rect2(pos - Vector2(tile_size / 2.0, tile_size / 2.0), Vector2(tile_size, tile_size)), color)

    # Draw ghost outline (polyline in piece color)
    for offset in ghost_offsets:
        var pos := Vector2(offset.x * tile_size, offset.y * tile_size)
        var half := Vector2(tile_size / 2.0, tile_size / 2.0)
        var rect := Rect2(pos - half, Vector2(tile_size, tile_size))
        draw_rect(rect, color, false, 1.0)  # unfilled, 1px border
```

### Toggleability
- **Attach component:** Ghost visible (modern)
- **Remove component:** No ghost_offsets ever set, ghost_offsets stays empty, no ghost drawn (original/NES/GB)

### Version Config

| Version | Ghost Piece |
|---------|------------|
| Original | Off (remove component) |
| Spectrum HoloByte | Off |
| NES / Game Boy | Off |
| 2001+ | On |
| Modern | On |

---

## Feature 4: Hold Piece

### Purpose
Allows the player to swap the current piece with a held piece. One hold per drop — prevents hold abuse. Standard since 2001.

### Files
- `Scripts/Components/hold_relay.gd` — **CREATE NEW**
- `Scripts/Flow/tetromino_spawner.gd` — major update
- `Scenes/Components/hold_relay.tscn` — **CREATE NEW**

### Architecture

**Signal flow:**
```
player_control → body.action → hold_relay → game.hold_requested
                                                   ↓
                                    tetromino_spawner._on_hold_requested()
```

The relay pattern is necessary because the spawner is a child of the game node, not a sibling of the piece. The relay forwards the input signal to a game-level signal that the spawner listens to.

### Component: `hold_relay.gd`

```gdscript
extends UniversalComponent

# Forwards the parent body's "action" signal to a game-level "hold_requested" signal.
# This relay pattern lets the spawner (game-level) respond to piece-level input
# without creating a direct coupling.

func _ready() -> void:
    call_deferred("_connect")

func _connect() -> void:
    if parent and parent.has_signal("action"):
        parent.action.connect(_on_action)

func _on_action() -> void:
    if game and game.has_signal("hold_requested"):
        game.hold_requested.emit()

func _exit_tree() -> void:
    if parent and is_instance_valid(parent) and parent.has_signal("action"):
        parent.action.disconnect(_on_action)
```

~15 lines total. Pure signal relay.

### Spawner Update: `tetromino_spawner.gd`

#### New Exports

```gdscript
# Enable hold piece feature.
# Original/NES/GB:  false
# 2001+:            true
@export var enable_hold: bool = true

# World-space position to display the held piece (frozen entity).
# Set in scene editor to position the hold display left of the playfield.
@export var hold_origin: Vector2 = Vector2(80, 120)

# Game signal name to listen for hold requests.
# Should match the signal defined on the UGS or game coordinator.
@export var hold_signal_name: String = "hold_requested"
```

#### New Runtime State

```gdscript
var _held_piece: Node = null      # Reference to frozen held piece entity
var _can_hold: bool = true         # Reset to true when new piece spawns
```

#### New UGS Signal (add to game coordinator or via spawner)

```gdscript
# On the game node (universal_game_script or tetris coordinator):
signal hold_requested
```

If using the UGS `@warning_ignore("unused_signal")` pattern, add:
```gdscript
@warning_ignore("unused_signal")
signal hold_requested
```

#### New Behavior

**`_ready()` update:**
```gdscript
if enable_hold and game and game.has_signal(hold_signal_name):
    game.connect(hold_signal_name, _on_hold_requested)
```

**`_on_hold_requested()`:**
1. Guard: `if !_can_hold or !_active_piece or !enable_hold: return`
2. Set `_can_hold = false` (one hold per drop)
3. Freeze active piece: call `_freeze_piece(_active_piece)` (strip components, disable processing)
4. If `_held_piece` exists:
   - Store reference to old held
   - Set `_held_piece = _active_piece`
   - Move held to `hold_origin`
   - Unfreeze old held → it becomes the new active piece
   - Attach active components to new active piece
   - Set `_active_piece = old_held`
5. If no held piece:
   - Set `_held_piece = _active_piece`
   - Move held to `hold_origin`
   - Spawn next piece from bag normally (`_spawn_next()`)
6. Reset `_can_hold = true` only when a NEW piece spawns from `_spawn_next()` — NOT on hold swap

**`_spawn_next()` update:**
```gdscript
# After spawning a new piece from the bag:
_can_hold = true
```

**`_freeze_piece(piece)`:**
- Remove all active-piece components (legs, brains, lock_detector, ghost_piece, hold_relay, t_spin_detector)
- Call `set_process(false)` / `set_physics_process(false)` on piece
- Move to `hold_origin`

**`_unfreeze_piece(piece)`:**
- Reattach active-piece components from `active_piece_components`
- Move to spawner position (spawn point)
- Call `set_process(true)` / `set_physics_process(true)`

### Toggleability
- **`enable_hold = false`:** Spawner never connects to hold signal. Relay component is inert.
- **Remove relay component:** No signal forwarded. Hold never triggers.
- Both should be set together for clean operation.

### Version Config

| Version | Hold Piece | Button |
|---------|-----------|--------|
| Original | Off (`enable_hold = false`) | N/A |
| Spectrum HoloByte | Off | N/A |
| NES / Game Boy | Off | N/A |
| 2001+ | On | Button 1 (Shift) |
| Modern | On | Button 1 (Shift) |

---

## Feature 5: T-Spin Detection

### Purpose
Detects when a T-piece is rotated into a tight slot (SRS corner rule). Awards bonus scoring. Distinguishes between full T-spin and T-spin mini (since 2018 Guideline).

### Files
- `Scripts/Components/t_spin_detector.gd` — **CREATE NEW**
- `Scenes/Components/t_spin_detector.tscn` — **CREATE NEW**

### Architecture

The detector is a component attached to the active piece. It tracks whether the last input was a rotation (vs. translation) and, when the piece locks, checks the SRS corner condition while the multi-cell body still exists.

**Signal timing (relies on Feature 2: piece_pre_lock):**
```
lock_detector._execute_lock()
  → piece_pre_lock.emit()    ← T-spin detector listens here
  → piece_locked.emit()      ← Spawner splits piece here
```

This guarantees the detector can read the piece's corners BEFORE the spawner splits it into singles.

### SRS T-Spin Rule

1. The last move before lock must be a rotation (not a translation)
2. The piece must be a T-piece
3. Check the 4 diagonal corners around the T-piece's center cell:
   - If **≥3 corners** are occupied → **Full T-spin**
   - If **2 corners** are occupied, both in the "front" direction (the beak) → **T-spin mini**
   - Otherwise → not a T-spin

### Component: `t_spin_detector.gd`

```gdscript
extends UniversalComponent

# Enable T-spin detection.
# Original/NES/GB:   false (no T-spin concept)
# 2001:              true (basic T-spin, no mini)
# Modern:            true (full + mini)
@export var enable_t_spin: bool = true

# Grid spacing for corner checks. Must match grid_movement.step_size.
@export var step_size: float = 20.0

# Runtime state
var _last_was_rotation: bool = false

func _ready() -> void:
    call_deferred("_connect_signals")

func _connect_signals() -> void:
    # Track rotation vs. movement
    for child in parent.get_children():
        if child.has_signal("rotated"):
            child.rotated.connect(_on_rotated)
        if child.has_signal("moved") and child != self:
            child.moved.connect(_on_moved)
    
    # Listen for pre-lock from lock_detector sibling
    for child in parent.get_children():
        if child.has_signal("piece_pre_lock"):
            child.piece_pre_lock.connect(_on_pre_lock)
            break

func _on_rotated() -> void:
    _last_was_rotation = true

func _on_moved() -> void:
    _last_was_rotation = false

func _on_pre_lock(_cell_positions: Array[Vector2]) -> void:
    if not enable_t_spin:
        return
    if not _last_was_rotation:
        game.t_spin_result.emit(false, false)
        return
    if not ("shape" in parent and parent.shape == parent.Shape.T):
        game.t_spin_result.emit(false, false)
        return
    
    _check_t_spin()

func _check_t_spin() -> void:
    var space_state = parent.get_world_2d().direct_space_state
    var center = parent.global_position
    
    # 4 diagonal corners relative to T-piece center
    var corners = [
        center + Vector2(-1, -1) * step_size,  # top-left
        center + Vector2(1, -1) * step_size,   # top-right
        center + Vector2(-1, 1) * step_size,   # bottom-left
        center + Vector2(1, 1) * step_size,    # bottom-right
    ]
    
    var blocked_count := 0
    var blocked_indices: Array[int] = []
    
    for i in range(4):
        if _is_occupied(space_state, corners[i]):
            blocked_count += 1
            blocked_indices.append(i)
    
    # Full T-spin: 3+ corners blocked
    if blocked_count >= 3:
        game.t_spin_result.emit(true, false)  # is_t_spin=true, is_mini=false
        return
    
    # T-spin mini: exactly 2 corners blocked, both in "front" direction
    # "Front" corners depend on T-piece rotation state
    if blocked_count == 2:
        var front_pair = _get_front_corner_indices()
        if blocked_indices == front_pair:
            game.t_spin_result.emit(true, true)  # is_t_spin=true, is_mini=true
            return
    
    game.t_spin_result.emit(false, false)

# Determine which 2 corners are "front" (beak direction) based on rotation
func _get_front_corner_indices() -> Array[int]:
    # T-piece facing UP (beak up): front corners = bottom-left(2) and bottom-right(3)
    # T-piece facing RIGHT (beak right): front = top-left(0) and bottom-left(2)
    # T-piece facing DOWN (beak down): front = top-left(0) and top-right(1)
    # T-piece facing LEFT (beak left): front = top-right(1) and bottom-right(3)
    #
    # Rotation state can be inferred from current_offsets
    # The "beak" cell is the offset that doesn't share a row with the others
    var offsets = parent.current_offsets
    # Find the beak: the offset that's unique in its row
    var row_counts: Dictionary = {}
    for o in offsets:
        var row = o.y
        if not row_counts.has(row):
            row_counts[row] = []
        row_counts[row].append(o)
    
    # The row with only 1 cell is the beak row
    var beak_offset: Vector2i = Vector2i.ZERO
    for row in row_counts:
        if row_counts[row].size() == 1:
            beak_offset = row_counts[row][0]
            break
    
    # Determine facing from beak direction
    if beak_offset.y < 0:    # beak points UP
        return [2, 3]        # bottom corners
    elif beak_offset.y > 0:  # beak points DOWN
        return [0, 1]        # top corners
    elif beak_offset.x > 0:  # beak points RIGHT
        return [0, 2]        # left corners
    else:                    # beak points LEFT
        return [1, 3]        # right corners

func _is_occupied(space_state, pos: Vector2) -> bool:
    var query := PhysicsPointQueryParameters2D.new()
    query.position = pos
    query.collide_with_areas = false
    query.collide_with_bodies = true
    var results = space_state.intersect_point(query)
    for result in results:
        var body = result["collider"]
        if body and body != parent and body.is_in_group("settled_pieces"):
            return true
    return false

func _exit_tree() -> void:
    # Signal cleanup handled by parent freeing
    pass
```

### New UGS Signal

```gdscript
# On the game node:
@warning_ignore("unused_signal")
signal t_spin_result(is_t_spin: bool, is_mini: bool)
```

### Toggleability
- **Remove component:** No T-spin detection at all (original/NES/GB)
- **`enable_t_spin = false`:** Component exists but always emits `(false, false)` — no T-spin bonus

### Version Config

| Version | T-Spin | Mini Detection |
|---------|--------|---------------|
| Original | Off (remove component) | N/A |
| Spectrum HoloByte | Off | N/A |
| NES / Game Boy | Off | N/A |
| 2001+ | On | Off (`enable_t_spin = true` but no mini path) |
| Modern | On | On |

---

## Feature 6: Enhanced Scoring System

### Purpose
Adds combo, back-to-back, T-spin scoring, and configurable score type routing to `line_clear_monitor.gd`. All features are toggleable.

### Files
- `Scripts/Rules/line_clear_monitor.gd` — major update

### Scoring Philosophy

CD50 uses a **points + multiplier** paradigm. Every scoring event specifies:
1. **The score value** (base points from scoring tables)
2. **The score type** (which UGS method to route to: `add_score`, `add_p1_score`, `add_p2_score`, `add_multiplier`)

This lets the same scoring component serve single-player, versus, and cooperative modes purely through configuration.

### New Exports

```gdscript
# ── Feature Toggles ──────────────────────────────────────────────

# Enable combo bonus for consecutive line-clearing drops.
# Original/NES/GB:   false
# 2001+:             true
@export var enable_combo: bool = true

# Enable back-to-back bonus (1.5× for consecutive Tetrises or T-spins).
# Original/NES/GB:   false
# 2001:              false (not in early Guideline)
# Modern:            true
@export var enable_back_to_back: bool = true

# Enable T-spin bonus scoring. Requires t_spin_detector component.
# Original/NES/GB:   false
# 2001+:             true
@export var enable_t_spin_scoring: bool = true

# Add to game multiplier on each level up.
# Original:          false (no multiplier system)
# NES/GB:            false (level only affects speed)
# Modern:            true (multiplier grows with level)
@export var enable_level_up_multiplier: bool = true

# ── Score Type Routing ───────────────────────────────────────────
# Determines which UGS score method each event uses.
# CommonEnums.ScoreType: P1_SCORE, P2_SCORE, POINTS, MULTIPLIER
# All versions:  POINTS (default single-player routing)
# Versus:        P1_SCORE or P2_SCORE per player's monitor
# Cooperative:   POINTS (shared score pool)

@export var line_score_type: CommonEnums.ScoreType = CommonEnums.ScoreType.POINTS
@export var combo_score_type: CommonEnums.ScoreType = CommonEnums.ScoreType.POINTS
@export var t_spin_score_type: CommonEnums.ScoreType = CommonEnums.ScoreType.POINTS
@export var level_score_type: CommonEnums.ScoreType = CommonEnums.ScoreType.MULTIPLIER

# ── Scoring Tables ───────────────────────────────────────────────

# Base points for 1/2/3/4 line clears (indexed by line count).
# These are multiplied by the current level.
# Original:    [0, 100, 300, 500, 800] (no level multiplier — pure flat)
# NES:         [0, 40, 100, 300, 1200] × level
# Game Boy:    [0, 40, 100, 300, 1200] × level
# 2001+:       [0, 100, 300, 500, 800] × level
# Modern:      [0, 100, 300, 500, 800] × level
@export var score_table: Array[int] = [0, 100, 300, 500, 800]

# Bonus points for T-spin with 0/1/2/3 line clears.
# Only used when enable_t_spin_scoring = true and t_spin_result = full.
# Original/NES/GB:  N/A (feature off)
# 2001+:            [400, 800, 1200, 1600]
# Modern:           [400, 800, 1200, 1600]
@export var t_spin_table: Array[int] = [400, 800, 1200, 1600]

# Bonus points for T-spin mini with 0/1/2 line clears.
# Only used when enable_t_spin_scoring = true and t_spin_result = mini.
# Original/NES/GB:  N/A
# 2001:             N/A (no mini detection)
# Modern:           [100, 200, 400]
@export var t_spin_mini_table: Array[int] = [100, 200, 400]

# Combo bonus points (indexed by combo count).
# Combo resets to 0 when a drop clears no lines.
# Original/NES/GB:  N/A (feature off)
# 2001+:            [0, 50, 100, 150, 200, 300, 400, 500, ...]
# Modern:           [0, 50, 100, 150, 200, 300, 400, 500, ...]
@export var combo_table: Array[int] = [0, 50, 100, 150, 200, 300, 400, 500]

# Back-to-back multiplier applied to Tetrises and T-spins when the
# previous clear was also a Tetris or T-spin.
# Original/NES/GB:  N/A (feature off)
# 2001:             N/A
# Modern:           1.5 (50% bonus)
@export var b2b_multiplier: float = 1.5

# Multiplier added to game.current_multiplier per level up.
# Original/NES/GB:  0 (no multiplier system)
# Modern:           1 (+1 multiplier per level)
@export var level_up_multiplier_bonus: int = 1
```

### New Runtime State

```gdscript
var _combo_count: int = 0            # Consecutive drops that cleared ≥1 line
var _is_b2b_eligible: bool = false   # Last clear was Tetris (4) or T-spin
var _last_t_spin: bool = false       # Last piece lock was T-spin
var _last_t_spin_mini: bool = false  # Last piece lock was T-spin mini
```

### Updated Signal Connections

```gdscript
func _ready() -> void:
    # Existing
    if game and game.has_signal(listen_signal):
        game.connect(listen_signal, _on_piece_settled)
    # NEW: Listen for T-spin results
    if enable_t_spin_scoring and game and game.has_signal("t_spin_result"):
        game.connect("t_spin_result", _on_t_spin_result)
```

### Updated `_check_and_clear()` Logic

```
1. Find full rows
2. If no rows cleared:
     If enable_combo: reset _combo_count = 0
     Return
3. Determine base score:
     If T-spin full:   lookup t_spin_table[line_count] × level
     If T-spin mini:   lookup t_spin_mini_table[line_count] × level
     If regular:        lookup score_table[line_count] × level
4. If enable_back_to_back AND _is_b2b_eligible AND (Tetris or T-spin):
     Apply b2b_multiplier to base score
5. If enable_combo AND _combo_count > 0:
     Add combo_table[_combo_count] (capped to table size)
6. Route total score via _apply_score(total, line_score_type)
7. Route combo bonus via _apply_score(combo_bonus, combo_score_type)
8. Update _is_b2b_eligible = (Tetris or T-spin)
9. If enable_combo: increment _combo_count
10. If enable_level_up_multiplier AND level changed:
      game.add_multiplier(level_up_multiplier_bonus)
11. Existing: pause, clear, collapse
```

### New Helper: `_apply_score()`

```gdscript
func _apply_score(amount: int, score_type: CommonEnums.ScoreType) -> void:
    match score_type:
        CommonEnums.ScoreType.POINTS:
            game.add_score(amount)
        CommonEnums.ScoreType.P1_SCORE:
            game.add_p1_score(amount)
        CommonEnums.ScoreType.P2_SCORE:
            game.add_p2_score(amount)
        CommonEnums.ScoreType.MULTIPLIER:
            game.add_multiplier(amount)
```

### Version Config Summary

| Export | Original | NES/GB | 2001 | Modern |
|--------|----------|--------|------|--------|
| `score_table` | `[0,100,300,500,800]` | `[0,40,100,300,1200]` | `[0,100,300,500,800]` | `[0,100,300,500,800]` |
| `enable_combo` | false | false | true | true |
| `enable_back_to_back` | false | false | false | true |
| `enable_t_spin_scoring` | false | false | true | true |
| `enable_level_up_multiplier` | false | false | true | true |
| `b2b_multiplier` | N/A | N/A | N/A | 1.5 |
| `level_up_multiplier_bonus` | 0 | 0 | 1 | 1 |
| `line_score_type` | POINTS | POINTS | POINTS | POINTS |

---

## Existing Spawner Configuration Reference

These exports already exist in `tetromino_spawner.gd` and should be set per version:

```gdscript
# Preview count (number of upcoming pieces shown).
# Original:    0 (no preview)
# NES:         1
# Game Boy:    1
# 2001+:       3 (Guideline standard)
# Modern:      5 (some implementations)
@export var preview_count: int = 3

# Spawn origin position (world space).
@export var spawn_origin: Vector2 = Vector2(200, 60)

# Preview display origin (world space, pieces array left-to-right).
@export var preview_origin: Vector2 = Vector2(480, 120)

# Component scenes to attach to each spawned active piece.
# Modern config includes: grid_movement, grid_rotation_advanced,
#   player_control, lock_detector, ghost_piece, hold_relay, t_spin_detector
# Original config: grid_gravity only (no rotation, no player control)
# NES config: grid_movement, grid_rotation, player_control, lock_detector
@export var active_piece_components: Array[PackedScene] = []
```

---

## Build Order

| Step | Feature | Files | Complexity |
|------|---------|-------|------------|
| 1 | Lock delay move limit | `lock_detector.gd` | Low — one export, one counter, two guards |
| 2 | Pre-lock signal | `lock_detector.gd` | Low — one signal, one emit line |
| 3 | Ghost piece | `ghost_piece.gd` (new), `tetromino.gd` (minor), `.tscn` (new) | Medium |
| 4 | Hold piece | `hold_relay.gd` (new), `tetromino_spawner.gd` (major), `.tscn` (new) | High |
| 5 | T-spin detection | `t_spin_detector.gd` (new), `.tscn` (new) | High |
| 6 | Enhanced scoring | `line_clear_monitor.gd` (major) | High |
| 7 | Scene composition | `tetris.tscn` — attach new components, configure exports | Medium |

---

## Files Summary

| File | Action | Description |
|------|--------|-------------|
| `Scripts/Components/lock_detector.gd` | Enhance | Add `max_lock_resets`, `piece_pre_lock` signal |
| `Scripts/Components/ghost_piece.gd` | **Create** | Ghost projection component |
| `Scripts/Components/hold_relay.gd` | **Create** | Signal relay for hold input |
| `Scripts/Components/t_spin_detector.gd` | **Create** | SRS T-spin corner detection |
| `Scripts/Bodies/tetromino.gd` | Minor update | Add `ghost_offsets`, polyline drawing |
| `Scripts/Flow/tetromino_spawner.gd` | Major update | Hold state, swap logic, `_can_hold` |
| `Scripts/Rules/line_clear_monitor.gd` | Major update | Combo, B2B, T-spin scoring, score routing |
| `Scenes/Components/ghost_piece.tscn` | **Create** | Ghost piece scene |
| `Scenes/Components/hold_relay.tscn` | **Create** | Hold relay scene |
| `Scenes/Components/t_spin_detector.tscn` | **Create** | T-spin detector scene |
| `Scenes/Games/remakes/tetris.tscn` | Update | Attach new components, configure exports |

---

## "Electronika 60" Configuration (Minimal Tetris)

To recreate the original 1984 experience, configure in the scene editor:

```
tetromino_spawner:
  preview_count = 0
  active_piece_components = [grid_gravity, player_control]  # minimal
  enable_hold = false

lock_detector:
  lock_delay = 0.0          # instant lock
  max_lock_resets = 0       # no limit (moot — no delay to reset)

line_clear_monitor:
  enable_combo = false
  enable_back_to_back = false
  enable_t_spin_scoring = false
  enable_level_up_multiplier = false
  score_table = [0, 100, 300, 500, 800]

Remove from active_piece_components:
  ghost_piece.tscn
  hold_relay.tscn
  t_spin_detector.tscn
  grid_rotation_advanced.tscn  (original had no rotate button)
```

## "NES Tetris" Configuration

```
tetromino_spawner:
  preview_count = 1
  active_piece_components = [grid_movement, grid_rotation, player_control, lock_detector]
  enable_hold = false

lock_detector:
  lock_delay = 0.5
  max_lock_resets = 0       # no limit (NES speed handles difficulty)

line_clear_monitor:
  enable_combo = false
  enable_back_to_back = false
  enable_t_spin_scoring = false
  enable_level_up_multiplier = false
  score_table = [0, 40, 100, 300, 1200]

Remove:
  ghost_piece.tscn
  hold_relay.tscn
  t_spin_detector.tscn
```

## "Modern Guideline" Configuration (Default)

```
tetromino_spawner:
  preview_count = 3
  active_piece_components = [grid_movement, grid_rotation_advanced, player_control,
                             lock_detector, ghost_piece, hold_relay, t_spin_detector]
  enable_hold = true

lock_detector:
  lock_delay = 0.5
  max_lock_resets = 15

line_clear_monitor:
  enable_combo = true
  enable_back_to_back = true
  enable_t_spin_scoring = true
  enable_level_up_multiplier = true
  score_table = [0, 100, 300, 500, 800]
  t_spin_table = [400, 800, 1200, 1600]
  t_spin_mini_table = [100, 200, 400]
  b2b_multiplier = 1.5
  level_up_multiplier_bonus = 1