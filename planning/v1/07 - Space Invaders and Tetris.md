# Plan 07 — Bug Blaster and Block Drop

**Created:** 2026-04-19  
**Status:** Final Plan — All decisions resolved

---

## New Components to Build

### 1. `grid_basic` (Flow — child of UniversalGameScript)

**Purpose:** Defines a grid in the scene with active occupancy tracking.

**Responsibilities:**
- Define rows, columns, cell size, origin position
- Expose `grid_to_world(row, col) → Vector2` and `world_to_grid(pos) → Vector2i`
- Bounds checking: `is_valid_cell(row, col) → bool`
- Maintain a 2D occupancy array — bodies register/unregister cells as they move
- Expose `is_occupied(row, col) → bool`
- Expose `register_cell(row, col, data)` and `unregister_cell(row, col)`
- Provide occupancy data for line-clear logic and collision queries

**Exports:**
- `rows: int`
- `columns: int`
- `cell_size: Vector2`
- `origin: Vector2`

**Games:** Both

---

### 2. `grid_movement` (Leg — child of UniversalBody)

**Purpose:** Translates `input_move` and `input_move_to` signals into discrete grid snaps.

**Responsibilities:**
- Find `grid_basic` in the scene (via group or parent traversal)
- Listen for `input_move` (direction) and `input_move_to` (target position)
- Store the most recent movement command between hops (Vector2.ZERO = no movement)
- On each hop tick: snap to the target grid cell instantly (no interpolation)
- Enforce grid bounds (prevent moving off-grid)
- Check occupancy before moving (optional, via `block_on_occupied`)
- Movement ratchets: configurable bools to block movement in specific directions
- Hard drop mode: listens for `input_fire` signal, immediately snaps as far south (increasing Y) as possible until hitting an obstacle or boundary

**Exports:**
- `hop_delay: float` — seconds the leg waits AFTER a move before accepting the next one (0 = instant chain). This produces classic "snappy" grid movement.
- `grid_name: String` — which grid_basic to find (if multiple exist)
- `block_on_occupied: bool` — whether movement into occupied cells is prevented
- `prevent_movement_up: bool` — block upward movement (prevents fighting gravity in Block Drop)
- `prevent_movement_down: bool` — block downward movement
- `prevent_movement_left: bool` — block leftward movement
- `prevent_movement_right: bool` — block rightward movement
- `enable_hard_drop: bool` — when true, `input_fire` triggers instant drop to floor

**Signal chain:**
```
Input sources emit on body signals:
  player_control  → body.input_move(LEFT/RIGHT)
  falling_ai      → body.input_move(DOWN)
  swarm_ai        → body.input_move(LEFT/RIGHT/DOWN)

grid_movement stores most recent command, snaps on hop tick:
  → reads stored direction
  → calculates next grid cell
  → checks ratchets, bounds, occupancy
  → snaps to exact position
```

**Games:** Both

---

### 3. `grid_rotation` (Leg — child of UniversalBody)

**Purpose:** Rotates in discrete steps, mirroring grid_movement's snap behavior. Ties facing direction to movement input and locks it to the grid.

**Responsibilities:**
- Listen for `input_move` signal
- Determine facing direction from movement input (ignores zero vectors)
- Snap rotation to nearest discrete step (90° default, optional 45°)
- Does not move the body — purely handles rotation

**Exports:**
- `rotation_step: int` — degrees per step (default 90, optional 45)
- `clockwise: bool` — rotation direction preference

**Future use:** Sokoban-style games where facing direction matters, grid-locked turrets.

**Games:** Block Drop (tetromino rotation), future games

---

### 4. `falling_ai` (Component — child of UniversalBody)

**Purpose:** Emits `body.input_move(DOWN)` on a timer. Gravity as an input source, not a movement handler.

**Responsibilities:**
- Internal timer counts `_process` delta against `fall_interval`
- When timer fires: emit `body.input_move.emit(Vector2.DOWN)`
- Can be paused (when piece is locked, during line clear animation)
- `grid_movement` handles the actual grid hop — ensures consistent snap behavior

**Exports:**
- `fall_interval: float` — seconds between downward moves
- `paused: bool` — runtime toggle

**Why a component, not a leg:** If gravity were a separate leg, you'd have two legs both moving the body independently. Player moves would snap to grid cells while gravity moves smoothly — producing weird hybrid behavior. By making gravity an input source that emits the same signal the player uses, everything flows through one `grid_movement` leg. The `prevent_movement_up` ratchet on `grid_movement` prevents the player from fighting gravity.

**Games:** Block Drop

---

### 5. `swarm_controller` (Flow — child of UniversalGameScript)

**Purpose:** Orchestrates synchronized movement of all invaders in a swarm.

**Responsibilities:**
- Find all bodies in the target group
- Connect to each member's `swarm_ai` brain via signal bus
- Track member count, leftmost/rightmost/bottommost positions
- Issue move commands (left/right/down) to the entire swarm on a tick timer
- Detect when leftmost/rightmost member hits grid boundary → step down + reverse direction
- Speed ramp: tick interval decreases as members die (`tick_interval = base_interval * (living / total)`)
- Speed ramp is toggleable

**Exports:**
- `base_tick_interval: float` — starting time between moves
- `min_tick_interval: float` — fastest possible tick time
- `speed_ramp_enabled: bool` — toggle member-death speed ramping
- `step_down_distance: int` — rows to drop on direction reversal
- `invader_group: String` — group name to search for
- `bus_group: String` — signal bus group name (allows multiple independent swarms via swarm_bus_1, swarm_bus_2, etc.)

**Communication:** Signal bus pattern. `swarm_controller` emits on its `swarm_move(direction)` signal. Each `swarm_ai` finds the bus by group name and connects. Multiple swarms can coexist with different bus groups.

**Games:** Bug Blaster, future swarm-based games

---

### 6. `swarm_ai` (Brain — child of UniversalBody)

**Purpose:** Antenna brain that receives commands from `swarm_controller` and relays them as body movement signals.

**Responsibilities:**
- Find `swarm_controller` signal bus (via `bus_group` name) on ready
- Connect to its `swarm_move` signal
- On `swarm_move(direction)`: emit `body.input_move(direction)`

**Exports:**
- `bus_group: String` — which signal bus to connect to

**This is intentionally thin.** The intelligence lives in `swarm_controller`. The brain is just an antenna, keeping individual invaders autonomous — they die independently, their `grid_movement` handles their own interpolation.

**Games:** Bug Blaster

---

### 7. `shoot_ai_swarm` (Brain — child of UniversalBody)

**Purpose:** Formation-aware shooting AI. Checks that the body is on the edge of its formation before firing, preventing friendly fire and controlling which row shoots.

**Responsibilities:**
- On each physics tick, roll randomly to determine if firing
- Before firing: check if this body is on the configured edge of its formation (e.g., bottom row)
- If on edge and roll succeeds: emit `body.input_fire` in the direction of that edge
- Random roll odds ramp up to 100% as time approaches `max_shot_interval`, then reset on firing
- Edge detection uses a margin of error so slight positional differences don't cause members to seize up

**Exports:**
- `fire_directions: Dictionary` — toggleable directions (up/down/left/right as bools)
- `max_shot_interval: float` — longest possible time between shots. Each tick rolls with increasing probability until 100% at this interval, then resets.
- `edge_margin: float` — tolerance for edge detection (prevents precision issues)
- `fire_direction: Vector2` — direction of the fire signal emitted

**How it works in Bug Blaster:** Configure with `down: true`, other directions false. Only invaders on the bottom edge of the formation fire downward. When one is destroyed, the next one up becomes the new edge and starts firing.

**Games:** Bug Blaster, future formation-based games

---

### 8. `tetromino_formation` (Component — child of UniversalBody)

**Purpose:** Manages a multi-cell shape on the grid. The tetromino is one body that occupies 4 grid cells via an offsets array.

**Responsibilities:**
- Store relative grid offsets for each block in the formation
- Expose `get_all_cells() → Array[Vector2i]` (current position + offsets)
- Expose `can_move(direction) → bool` (check all cells against grid occupancy)
- Rotation: rotate the offsets array (90° multiplication)
- Landing detection: check if any cell's position below is occupied or out of bounds → trigger lock
- Lock delay: configurable grace period where player can still slide the piece. Timer starts when landing detected, resets if piece moves off floor.
- On lock: register all cells in `grid_basic`'s occupancy map, create visual sprites at those positions, deactivate the body
- Interactable followers: individual cells can be targeted (shot, etc.) for remix scenarios

**Exports:**
- `offsets: Array[Vector2i]` — relative cell positions
- `lock_delay: float` — seconds before piece locks after landing (0 = instant)
- `formation_group: String` — for edge detection by `shoot_ai_swarm`

**Why Head + Followers:** Followers are individually targetable for remix ideas (shoot individual blocks off a tetromino). This pattern also works for Centipede-style games where a chain of segments follows a head.

**Games:** Block Drop, future games (Centipede, etc.)

---

### 9. `tetromino_spawner` (Flow — child of UniversalGameScript)

**Purpose:** Spawns the next tetromino piece at the top of the grid.

**Responsibilities:**
- Maintain a bag/queue of upcoming pieces (7-bag randomizer or simple random)
- Spawn the active piece as a UniversalBody with the correct `tetromino_formation` offsets
- Signal the next piece to `interface` for preview display
- Configure `falling_ai.fall_interval` on each new piece based on current level

**Exports:**
- `piece_pool: Array[String]` — scene paths for each tetromino type
- `spawn_position: Vector2i` — grid cell where pieces spawn
- `randomizer_mode: enum` (RANDOM, BAG7)

**Games:** Block Drop

---

### 10. `line_clear_monitor` (Rule — child of UniversalGameScript)

**Purpose:** Generic line-clear detection. Monitors a `grid_basic` for completed lines (horizontal, vertical, or both) and clears them.

**Responsibilities:**
- Query `grid_basic` occupancy data for full lines
- On detection: clear the line, shift remaining cells, emit score signal
- Configurable for horizontal lines, vertical lines, or both
- Generic enough for mashups: could clear lines of Bug Blaster, puzzle game grids, etc.

**Exports:**
- `grid_name: String` — which grid to monitor
- `check_horizontal: bool`
- `check_vertical: bool`
- `clear_direction: Vector2` — direction cells shift after a line is cleared (default: DOWN for Block Drop)
- `score_per_line: int` — base score awarded per cleared line

**Games:** Block Drop, future mashup/puzzle games

---

### 11. `variable_tuner_global` (Rule — child of UniversalGameScript)

**Purpose:** Modifies a named property on ALL bodies in a group, not just the parent. Group-wide property changes in response to game events.

**Exports:**
- `source_node: Node`
- `source_signal: String`
- `filter_value: String = ""`
- `target_group: String` — group to search for members
- `target_property: String`
- `adjustment_amount: float`
- `adjustment_mode: CommonEnums.AdjustmentMode` (ADD/MULTIPLY/SET)

**Behavior:** On signal received, iterate all nodes in `target_group`, apply property adjustment to each.

**Games:** Block Drop (adjust fall speed on level up), general purpose

---

## Enhancements to Existing Components

### `universal_body` — Add `autofire` toggle

When enabled, held inputs produce repeated signal emissions at a configurable rate. Needed for Block Drop DAS (Delayed Auto Shift), useful for any grid-based game.

---

### `wave_spawner` — Add `grid_score_by_row`

Same pattern as existing `grid_health_by_row`. A top score value that gets subtracted by the row number (minimum 1). When spawning invaders, each row gets the appropriate `score_on_death` value.

---

## Games to Compose

### Bug Blaster

```
UniversalGameScript (bug_blaster)
├── grid_basic (11 cols × 6 rows)
├── swarm_controller (Flow) — bus_group: "swarm_bus_1"
├── wave_director (Flow)
├── wave_spawner (Flow) — grid_score_by_row enabled
├── interface (Flow)
├── group_monitor (Rule) — track invaders for wave completion
├── lives_counter (Rule) — player lives
├── collision_matrix (Core)
│
├── [Player Cannon]
│   ├── player_control (Brain)
│   ├── direct_movement (Leg) — lock_y + screen margins (NOT grid_movement)
│   ├── gun_simple (Arm)
│   └── health (Component)
│
├── [Invader Bodies] (×55, spawned by wave_spawner)
│   ├── swarm_ai (Brain) — bus_group: "swarm_bus_1"
│   ├── grid_movement (Leg)
│   ├── die_on_hit or health (Component)
│   ├── score_on_death (Component)
│   └── shoot_ai_swarm (Brain) — fires down, edge detection on bottom row
│
├── [Bullet Bodies]
│   ├── die_on_timer (Component)
│   ├── die_on_hit (Component) or damage_on_hit (Arm)
│   └── screen_cleanup (Component)
│
├── [Barrier Bodies] — composed from tightly packed 1 HP bricks
│   └── health (Component, 1 HP each)
│
└── [Mystery Ship] — bonus UFO
    ├── patrol_ai (Brain)
    ├── die_on_hit (Component)
    └── score_on_death (Component) — high score value
```

**Note on player movement:** The Bug Blaster player cannon uses `direct_movement` with lock_y and screen margins (existing UniversalBody features), NOT `grid_movement`. Only the invaders move on the grid.

**Barriers:** Composed from many small 1 HP bricks packed tightly together. When a bullet hits one, only that brick is destroyed, producing the locational damage effect from the original game. No new component needed — just scene composition.

**Mystery ship:** Uses existing components only (`patrol_ai` + `die_on_hit` + `score_on_death`). No new component needed.

**Invader type differentiation:** `wave_spawner`'s new `grid_score_by_row` handles different point values per row. Top rows worth more.

---

### Block Drop

```
UniversalGameScript (block_drop)
├── grid_basic (10 cols × 20 rows) — active occupancy tracking
├── tetromino_spawner (Flow) — random piece generation
├── line_clear_monitor (Rule) — horizontal line detection and clearing
├── variable_tuner_global (Rule) — adjust fall speed on level up
├── interface (Flow) — score, level, next piece preview
├── group_monitor (Rule) — game over detection
├── collision_matrix (Core)
│
├── [Active Tetromino] (UniversalBody, spawned by tetromino_spawner)
│   ├── player_control (Brain) — left/right input
│   ├── falling_ai (Component) — emits input_move(DOWN) on timer
│   ├── grid_movement (Leg) — snap to grid, prevent_movement_up=true, enable_hard_drop=true
│   ├── grid_rotation (Leg) — 90° rotation steps
│   ├── tetromino_formation (Component) — 4-cell offsets, lock delay
│   └── [4 × Square sprites] — visual children at formation offsets
│
├── [Settled Squares] — data in grid_basic occupancy map (not bodies)
│
└── [Preview Piece] (UI only — signaled by tetromino_spawner)
```

**Signal flow for active piece:**
```
Input sources:
  player_control  → body.input_move(LEFT/RIGHT)    [on keypress]
  player_control  → body.input_fire()               [hard drop trigger]
  player_control  → body.input_rotate()             [rotation]
  falling_ai      → body.input_move(DOWN)           [on timer]

Movement handlers:
  grid_movement   ← ALL input_move signals
                  ← prevent_movement_up = true (can't fight gravity)
                  ← enable_hard_drop = true (input_fire = instant drop south)
  grid_rotation   ← input_rotate signals
                  ← 90° discrete snap
```

---

## Build Order

### Phase 1 — Grid Foundation (both games)
1. `grid_basic` (Flow) — grid coordinate system + active occupancy
2. `grid_movement` (Leg) — discrete snap movement with hop_delay, ratchets, hard drop
3. `grid_rotation` (Leg) — discrete rotation steps
4. Test: single body on a grid, move with `player_control` + `grid_movement`, rotate with `grid_rotation`

### Phase 2 — Bug Blaster
5. `swarm_controller` (Flow) — swarm orchestration with signal bus
6. `swarm_ai` (Brain) — antenna brain for swarm commands
7. `shoot_ai_swarm` (Brain) — formation-aware edge shooting
8. `wave_spawner` enhancement — add `grid_score_by_row`
9. Compose Bug Blaster game scene
10. Test: full gameplay loop

### Phase 3 — Block Drop
11. `falling_ai` (Component) — gravity as input source
12. `tetromino_formation` (Component) — multi-cell shape + lock delay
13. `tetromino_spawner` (Flow) — piece generation
14. `line_clear_monitor` (Rule) — generic line clearing
15. `variable_tuner_global` (Rule) — group-wide property changes
16. `universal_body` enhancement — add `autofire` toggle
17. Compose Block Drop game scene
18. Test: full gameplay loop

---

## Component Inventory Summary

### New Components (11)

| # | Component | Type | Category | Games |
|---|---|---|---|---|
| 1 | `grid_basic` | Flow | Flow | Both |
| 2 | `grid_movement` | Leg | Legs | Both |
| 3 | `grid_rotation` | Leg | Legs | Block Drop, future |
| 4 | `falling_ai` | Component | Components | Block Drop |
| 5 | `swarm_controller` | Flow | Flow | Bug Blaster |
| 6 | `swarm_ai` | Brain | Brains | Bug Blaster |
| 7 | `shoot_ai_swarm` | Brain | Brains | Bug Blaster |
| 8 | `tetromino_formation` | Component | Components | Block Drop, future |
| 9 | `tetromino_spawner` | Flow | Flow | Block Drop |
| 10 | `line_clear_monitor` | Rule | Rules | Block Drop, future |
| 11 | `variable_tuner_global` | Rule | Rules | Both |

### Enhancements (2)

| Component | Enhancement |
|---|---|
| `universal_body` | Add `autofire` toggle for DAS |
| `wave_spawner` | Add `grid_score_by_row` (same pattern as grid_health_by_row) |

### Reused As-Is (15)

| Component | Games |
|---|---|
| `player_control` | Both |
| `direct_movement` | Bug Blaster (player cannon) |
| `gun_simple` | Bug Blaster |
| `health` | Bug Blaster |
| `die_on_hit` | Both |
| `die_on_timer` | Bug Blaster |
| `score_on_death` | Both |
| `screen_cleanup` | Bug Blaster |
| `group_monitor` | Both |
| `lives_counter` | Bug Blaster |
| `timer` | Both |
| `wave_director` | Bug Blaster |
| `wave_spawner` | Bug Blaster |
| `interface` | Both |
| `collision_matrix` | Both |
| `damage_on_hit` | Bug Blaster |
| `patrol_ai` | Bug Blaster (mystery ship) |

---

*End of Plan 07*