# Plan 07: Tetris and Space Invaders

**Status:** 📝 Planning  
**Prerequisite:** Plan 06 ✅ (8 games, 62 components, procedural audio, effects system)

---

## Objective

Build **Tetris** and **Space Invaders** as pure UGS scene assemblies — zero game scripts. These two games stress-test the component architecture in new ways:

- **Space Invaders** introduces **formation movement** (groups of enemies moving in lockstep) and **bunkers** (destructible shields that take incremental damage from both sides). This is a natural extension of the existing system.
- **Tetris** introduces **grid-based discrete movement** and **row-based clearing** — a fundamentally different paradigm from the continuous physics all current games use. This will push the component library in new directions.

---

## Part 1: Space Invaders

### Core Mechanics
- Player cannon moves horizontally at the bottom of the screen, fires upward
- 5 rows × 11 columns of alien invaders march left/right, dropping down when hitting a wall
- Invader speed increases as fewer remain
- 4 destructible bunkers between player and invaders (degraded by bullets from both sides)
- UFO bonus flies across the top periodically (reuse PatrolAi from Plan 06)
- Game over if invaders reach the bottom or player is hit

### How Existing Components Map

| Space Invaders Element | Existing Component | How |
|------------------------|-------------------|-----|
| Player cannon movement | DirectMovement | lock_y = true, horizontal only |
| Player firing | GunSimple | fire upward |
| Player death | DieOnHit | hit by enemy bullet = death |
| Enemy firing | GunSimple | on invader bodies |
| Enemy bullet hits player | DamageOnHit | target_groups: ["players"] |
| Player bullet hits enemy | DamageOnHit + DieOnHit | target_groups: ["enemies"] |
| Bunker degradation | Health + DamageOnHit | bunkers have multi-HP |
| Player bullet hits bunker | DamageOnHit | target_groups: ["bunkers"] |
| Enemy bullet hits bunker | DamageOnHit | target_groups: ["bunkers"] |
| Bunker destroyed | DieOnHit | when Health = 0 |
| Score on enemy kill | ScoreOnDeath | listens to Health.zero_health |
| Score multiplier | GroupCountMultiplier | more invaders = higher multiplier |
| Invaders cleared wave | GroupMonitor | group_cleared → next wave |
| Ball/respawn tracking | GroupMonitor | player cannon respawn |
| Lives | LivesCounter | player cannon deaths |
| Score to win | PointsMonitor | threshold-based victory |
| UFO bonus | PatrolAi + GunSimple + Health + ScoreOnDeath | reuse from Asteroids |
| UFO patrol | PatrolAi | random horizontal path at top |
| Score display | Interface | POINTS_MULTIPLIER mode |
| Shoot sound | SoundSynth | procedural pew |
| Enemy march sound | SFXRamping / Beep | pitch increases as count decreases |
| Enemy explosion | DeathEffect | particle burst |
| Player explosion | DeathEffect | particle burst + debris |
| Wall bounces | CollisionMarker | left/right wall Area2Ds |

### What's Missing: Formation Movement

This is the hard part. Space Invaders enemies don't move individually — they march as a synchronized block. No existing component handles this.

**New Component: `formation_grid` (Brain)**

```
FormationGrid (UniversalComponent2D)
├── Exports:
│   ├── move_speed: float = 30.0          (pixels per second)
│   ├── step_down_distance: float = 20.0   (pixels dropped when wall hit)
│   ├── speed_increase: float = 5.0        (added to speed when member removed)
│   ├── direction: int = 1                 (1 = right, -1 = left)
│   ├── columns: int = 11
│   ├── rows: int = 5
│   ├── spacing: Vector2 = Vector2(16, 16) (space between members)
│   ├── target_group: String = "enemies"   (group to track member count)
│   └── wall_groups: Array[String] = ["walls"] (triggers direction change)
├── Role: Brain for ALL formation members (emits move on each)
├── Listens to: GroupMonitor.group_member_removed (speeds up)
├── Behavior:
│   ├── _physics_process:
│   │   ├── Get all members in target_group
│   │   ├── Move speed * direction * delta per frame
│   │   ├── Emit move(Vector2(direction, 0)) on each member
│   │   └── Check rightmost/leftmost member x against screen bounds
│   │       → If boundary hit: reverse direction, step all down
│   └── On member removed: speed += speed_increase
├── Key design:
│   ├── Single component drives ALL enemies (not per-enemy brains)
│   ├── Lives as a child of the UGS root (like WaveDirector/WaveSpawner)
│   ├── Emits `move` on each enemy's UniversalBody input signal
│   ├── Enemies don't need their own Brain — they're puppets of FormationGrid
│   └── Uses GroupMonitor's group_member_removed to speed up
└── Direction change:
    ├── Check formation bounds each frame
    ├── If rightmost member x > screen_right: direction = -1, step down
    └── If leftmost member x < screen_left: direction = 1, step down
```

**Why a new Brain:** Existing Brains (InterceptorAi, AimAi, ShootAi, PatrolAi) all control ONE body. FormationGrid controls MANY bodies simultaneously with synchronized movement. It's a fundamentally different pattern — a "swarm brain."

**Why not WaveSpawner GRID:** WaveSpawner can position entities in a grid, but it's a one-time spawn event. FormationGrid is a persistent brain that continuously drives movement. They complement each other — WaveSpawner spawns the grid, FormationGrid moves it.

### What's Missing: Enemy Firing

Space Invaders has a specific firing pattern: one random bottom-row invader fires at a time, with a maximum number of bullets on screen. 

**New Component: `formation_gun` (Arm)**

```
FormationGun (UniversalComponent2D)
├── Exports:
│   ├── bullet_scene: PackedScene
│   ├── max_bullets: int = 3               (max on screen at once)
│   ├── fire_rate: float = 1.0             (seconds between shots)
│   ├── target_group: String = "enemies"   (formation members)
│   ├── bullet_group: String = "enemy_bullets"
│   └── aim_at_group: String = "players"   (targets to aim toward)
├── Role: Centralized gun for the formation (not per-enemy guns)
├── Behavior:
│   ├── Timer-based: every fire_rate seconds
│   ├── Count existing bullets in bullet_group
│   │   └── If count >= max_bullets: skip
│   ├── Get all members in target_group
│   │   └── Filter to bottom-row members (lowest y position per column)
│   ├── Pick random bottom-row member
│   ├── Spawn bullet at member's position
│   │   └── Bullet aims downward (or toward random player)
│   └── Add bullet to bullet_group
└── Key design:
    ├── Single component fires on behalf of ALL enemies
    ├── Picks from bottom-row only (authentic Space Invaders behavior)
    ├── Max bullets cap prevents bullet spam
    └── Lives as UGS child, not on any enemy body
```

**Why not GunSimple per enemy:** GunSimple fires from its parent's position on the `shoot` signal. Space Invaders enemies don't fire individually — the formation fires as a unit, picking a random bottom-row shooter. FormationGun centralizes this logic.

### What's Missing: Bunkers

Space Invaders bunkers are grid-like destructible shields. Each bunker is made of small blocks that can be individually destroyed.

**Option A: Bunker = Grid of Brick bodies**
- Spawn 4 bunkers, each as a grid of tiny bricks (3×5 or similar)
- Each brick has Health(1) + DamageOnHit
- Works with existing Brick body + WaveSpawner GRID pattern
- Problem: many small bodies = potentially expensive

**Option B: New `bunker` body with per-pixel health**
- Custom body that draws a bunker shape
- Tracks damage as a pixel grid
- On hit: remove pixels near the impact point
- Problem: requires functional code in body script (violates "bodies are drawing only")

**Recommendation: Option A** (grid of bricks). It's the componentized approach. 4 bunkers × ~15 blocks = 60 bodies. Should be fine for performance. Each bunker is a WaveSpawner with GRID pattern, spawn_groups: ["bunkers"]. Bricks have Health(1) + DamageOnHit (from both player_bullets and enemy_bullets target groups) + DieOnHit.

### Scene Assembly: `space_invaders.tscn`

```
UniversalGameScript
├── collision_groups:
│   ├── players, players_bullets
│   ├── enemies, enemies_bullets  
│   ├── bunkers, walls
│
├── Player Cannon (paddle.tscn or new cannon body)
│   ├── PlayerControl
│   ├── DirectMovement (lock_y = true, horizontal only)
│   ├── GunSimple (fires upward, max_bullets = 1)
│   ├── Health (max_health = 3, or use LivesCounter instead)
│   ├── DieOnHit (hit by enemies_bullets)
│   └── DeathEffect
│
├── Player Bullet (bullet_simple.tscn)
│   ├── DamageOnHit (target_groups: ["enemies", "bunkers"])
│   ├── DieOnHit
│   ├── ScreenCleanup (or DieOnTimer)
│   └── SoundSynth (shoot sound)
│
├── Enemy Invaders (spawned by WaveSpawner GRID)
│   └── Each invader body:
│       ├── Health (1 HP)
│       ├── ScoreOnDeath (row-based scoring via PropertyOverride)
│       ├── DeathEffect (particles)
│       └── No Brain — driven by FormationGrid
│
│   3 invader types (top row = 30pts, middle 2 rows = 20pts, bottom 2 rows = 10pts)
│   Different visuals per type (new body scenes or PropertyOverride color)
│
├── FormationGrid (Brain — drives all enemies)
│   ├── move_speed = 30, speed_increase = 5
│   ├── Listens to: GroupMonitor.group_member_removed → speed up
│   └── Detects screen edges → reverse + step down
│
├── FormationGun (Arm — fires for the formation)
│   ├── bullet_scene = enemy_bullet.tscn
│   ├── max_bullets = 3, fire_rate = 1.0
│   └── Picks random bottom-row invader, fires toward player
│
├── Enemy Bullet (bullet_simple.tscn variant)
│   ├── DamageOnHit (target_groups: ["players", "bunkers"])
│   ├── DieOnHit
│   └── ScreenCleanup
│
├── Bunkers (4 × WaveSpawner GRID)
│   ├── Each spawns a grid of tiny bricks
│   ├── Bricks: Health(1) + DamageOnHit (from both bullet groups) + DieOnHit
│   └── spawn_groups: ["bunkers"]
│
├── UFO Bonus (timer-spawned)
│   ├── PatrolAi (horizontal path at top)
│   ├── Health(1) + ScoreOnDeath (100-300 random)
│   ├── DieOnHit + DeathEffect
│   └── Timer (auto_start, loop, ~15s interval)
│
├── WaveSpawner (GAME_START, GRID pattern, spawns invaders)
│   ├── 11 columns × 5 rows
│   ├── PropertyOverrides: set score_per_row, color_per_row
│   └── spawn_groups: ["enemies"]
│
├── FormationGrid (see above)
├── FormationGun (see above)
│
├── GroupMonitor ("enemies") → WaveDirector → WaveSpawner (next wave)
├── GroupCountMultiplier ("enemies")
├── PointsMonitor (score threshold → victory)
├── LivesCounter (player cannon deaths)
├── Interface (POINTS_MULTIPLIER mode)
├── MusicRamping (invader march beat speeds up as count decreases)
└── Walls + CollisionMarkers
```

### New Components for Space Invaders

| Component | Category | Purpose |
|-----------|----------|---------|
| `formation_grid` | Brain | Synchronized formation movement for a group of bodies. Detects screen edges, reverses direction, steps down, speeds up as members are removed |
| `formation_gun` | Arm | Centralized firing for a formation. Picks random bottom-row member, fires toward player, respects max bullet cap |

### Modified Components

| Component | Change |
|-----------|--------|
| None | Space Invaders should work with existing components as-is |

### New Body Scenes

| Scene | Purpose |
|-------|---------|
| `generic/invader_squid.tscn` | Top-row invader (30pts, squid shape) |
| `generic/invader_crab.tscn` | Middle-row invader (20pts, crab shape) |
| `generic/invader_octopus.tscn` | Bottom-row invader (10pts, octopus shape) |
| `generic/cannon.tscn` | Player cannon (or reuse paddle) |

Note: If making 3 invader bodies feels excessive, a single `invader.tscn` with PropertyOverride for draw color per row would also work. The visual distinction is important for the player though.

---

## Part 2: Tetris

### ⚠️ Architecture Challenge

Tetris is fundamentally different from every existing game:
- **No physics** — discrete grid movement, not CharacterBody2D continuous movement
- **No collision in the physics sense** — pieces lock when they hit the stack, not on `body_collided`
- **Row clearing** — checking for complete horizontal rows and removing them
- **Single active piece** — only one tetromino is "alive" at a time

**The key question:** Can Tetris work within the UniversalBody + UniversalComponent architecture, or does it need a fundamentally different approach?

**Recommendation: Hybrid approach.** Tetrominos use UniversalBody (for the signal API and `_draw()`), but movement is handled by a new **GridHop** leg that snaps position to a grid. Row clearing is handled by a new **GridClear** rule component. The game "plays" on a grid rather than in continuous space.

### Core Mechanics
- 10-wide × 20-tall grid
- 7 tetromino shapes fall from the top
- Player moves left/right, rotates, soft-drops, hard-drops
- Completed rows clear, everything above shifts down
- Game over when a new piece can't spawn (stack reaches top)
- Scoring: 1 row = 100pts, 2 = 300, 3 = 500, 4 (Tetris) = 800

### How Existing Components Map

| Tetris Element | Existing Component | Fit |
|----------------|-------------------|-----|
| UGS game container | UniversalGameScript | ✅ Perfect |
| Player input | PlayerControl | ✅ Emits button signals |
| Score display | Interface | ✅ POINTS_MULTIPLIER mode |
| Game over detection | GroupMonitor or Timer | ⚠️ Needs adaptation |
| Score tracking | PointsMonitor | ✅ Score threshold for "win" |
| Piece shapes | UniversalBody `_draw()` | ✅ Drawing code only |
| Sound effects | SoundSynth / Beep | ✅ Move, rotate, drop, clear sounds |

### What's Missing: Grid Movement

**New Component: `grid_hop` (Leg)**

```
GridHop (UniversalComponent)
├── Exports:
│   ├── cell_size: Vector2 = Vector2(16, 16)  (grid cell dimensions in pixels)
│   ├── fall_speed: float = 1.0               (seconds per row)
│   ├── fall_acceleration: float = 0.0         (speed increase per cleared row)
│   ├── grid_origin: Vector2 = Vector2(0, 0)  (top-left corner of the grid in game coords)
│   ├── grid_columns: int = 10
│   ├── grid_rows: int = 20
│   └── soft_drop_speed: float = 0.05          (seconds per row when holding down)
├── Listens to: parent.move, parent.action (filtered to button events)
├── Emits: parent.grid_collided (new signal — when piece can't move further down)
├── Behavior:
│   ├── Tracks current grid position (col, row) instead of pixel position
│   ├── On move(Vector2): 
│   │   ├── Calculate target grid cell
│   │   ├── Check against GridClear's grid occupancy map
│   │   ├── If cell is empty: snap parent to new grid position (pixel pos = grid_origin + cell * cell_size)
│   │   └── If cell is occupied: don't move (or emit grid_collided if downward)
│   ├── On action("rotate_cw"): request rotation from GridClear
│   ├── On action("hard_drop"): drop to lowest valid position instantly
│   └── Timer-based fall: every fall_speed seconds, try to move down one row
│       ├── If can't move down: emit grid_collided → piece locks
│       └── Soft drop: override fall timer to soft_drop_speed
└── Key design:
    ├── Converts continuous movement signals into discrete grid snapping
    ├── All collision is grid-based (checked against occupancy map), NOT physics
    ├── The piece's physics position is SET by this component, not by move_and_collide
    └── GridHop owns the "active piece" movement; GridClear owns the "board state"
```

**Key challenge:** UniversalBody's default `_physics_process` calls `move_parent_physics()` which uses `move_and_collide()`. For Tetris, we need to bypass this entirely. GridHop should set `parent.velocity = Vector2.ZERO` every frame and instead position the parent directly. This means either:
- GridHop sets a flag that tells UniversalBody to skip physics (`parent.set_physics_process(false)` in `_ready`)
- Or GridHop overrides velocity to zero each frame

### What's Missing: Board State & Row Clearing

**New Component: `grid_clear` (Rule)**

```
GridClear (UniversalComponent)
├── Exports:
│   ├── grid_columns: int = 10
│   ├── grid_rows: int = 20
│   ├── cell_size: Vector2 = Vector2(16, 16)
│   └── clear_score_thresholds: Array[int] = [0, 100, 300, 500, 800]  (1/2/3/4 rows)
├── Role: Manages the Tetris board state (occupancy grid) and clears complete rows
├── State:
│   ├── grid: Array[Array[int]] — 2D occupancy map (0 = empty, 1+ = occupied)
│   └── locked_pieces: Array[Node] — references to locked piece bodies
├── Behavior:
│   ├── Provides API for GridHop:
│   │   ├── is_cell_free(col, row) → bool
│   │   ├── can_place(cells: Array[Vector2i]) → bool  (for rotation checks)
│   │   └── get_drop_position(col, start_row) → int   (for hard drop)
│   ├── On grid_collided (from GridHop):
│   │   ├── Lock the current piece's cells into the grid
│   │   ├── Check each row for completion
│   │   ├── Clear complete rows
│   │   ├── Shift everything above cleared rows downward
│   │   ├── Emit row_clear signal with count (for scoring)
│   │   ├── Move visual representations down
│   │   └── Signal that a new piece is needed
│   └── Row clearing:
│       ├── For each row: if all columns filled → mark for clearing
│       ├── Remove marked rows, shift above rows down
│       └── Emit `rows_cleared(count)` → game can award score
└── Key design:
    ├── GridClear is the "board" — it owns the occupancy grid
    ├── GridHop is the "controller" — it moves the active piece, consulting GridClear
    ├── When piece locks: GridHop notifies GridClear → GridClear locks cells → checks rows → clears
    ├── Visual update: GridClear repositions the locked piece bodies downward
    └── Game over: GridClear detects that a new piece can't spawn (top cells occupied)
```

**Why two components instead of one:** GridHop handles real-time input/movement (Leg). GridClear handles board state and game logic (Rule). Separation of concerns. GridHop asks GridClear "can I move here?" and GridClear handles the consequences.

### What's Missing: Piece Spawning

**New Component: `piece_spawner` (Flow)**

```
PieceSpawner (UniversalComponent2D)
├── Exports:
│   ├── piece_scenes: Array[PackedScene]  (7 tetromino scenes: I, O, T, S, Z, J, L)
│   ├── spawn_groups: Array[String] = ["pieces"]
│   └── preview_count: int = 1            (how many upcoming pieces to show)
├── Role: Spawns the next tetromino at the top of the grid
├── Listens to: 
│   ├── game.on_game_start → spawn first piece
│   └── GridClear.piece_locked → spawn next piece
├── Behavior:
│   ├── Maintain a bag/queue of pieces (7-bag randomizer for fairness)
│   ├── On spawn trigger:
│   │   ├── Instantiate next piece scene
│   │   ├── Position at grid top center
│   │   ├── Check if spawn position is free (GridClear.can_place)
│   │   │   ├── If free: add to game, piece becomes active
│   │   │   └── If blocked: emit game_over on UGS
│   └── Preview: optional UI showing next N pieces
└── Key design:
    ├── 7-bag randomizer: shuffle all 7 pieces, deal them, reshuffle when empty
    ├── This ensures fair distribution (no droughts of I-pieces)
    └── Spawns at grid origin + center column
```

**Why not WaveSpawner:** WaveSpawner is designed for multi-entity waves with patterns. PieceSpawner spawns ONE piece at a time at a specific grid position, driven by the game's lock event. Different spawning paradigm.

### What's Missing: Tetromino Bodies

Each of the 7 Tetris shapes needs a body script that draws the shape and knows its cell offsets.

**New Body: `tetromino.gd` — extends UniversalBody**

```
Tetromino (UniversalBody)
├── Exports:
│   ├── shape: TetrominoShape (I, O, T, S, Z, J, L)
│   ├── color: Color (set per shape type)
│   └── cell_offsets: Array[Vector2i] (relative grid cells this shape occupies)
├── _draw():
│   ├── For each cell in cell_offsets:
│   │   ├── Draw filled rectangle at cell * cell_size
│   │   └── Draw outline
│   └── All shapes are drawing code only (no gameplay logic)
├── Rotation:
│   ├── cell_offsets rotate 90° clockwise/counterclockwise
│   │   └── Standard rotation: (x, y) → (-y, x) for CW
│   └── Wall kicks: checked by GridHop asking GridClear "can I be here?"
└── Signals: Uses standard UniversalBody input signals
```

**7 body scenes** (one per shape, all in `Scenes/Bodies/generic/`):
- `generic/tetromino_i.tscn` — I-piece (cyan)
- `generic/tetromino_o.tscn` — O-piece (yellow)
- `generic/tetromino_t.tscn` — T-piece (purple)
- `generic/tetromino_s.tscn` — S-piece (green)
- `generic/tetromino_z.tscn` — Z-piece (red)
- `generic/tetromino_j.tscn` — J-piece (blue)
- `generic/tetromino_l.tscn` — L-piece (orange)

Or: **one body script** `tetromino.gd` with shape as an export, and **7 scenes** that configure it. Each scene sets `shape`, `color`, and `cell_offsets` via exports. The script draws based on these exports.

**Or even simpler:** one scene `generic/tetromino.tscn` and PieceSpawner sets the shape/color/cell_offsets via PropertyOverride when spawning. But this might be annoying to configure per-shape in the spawner. Recommend one scene per shape for clarity.

### Scene Assembly: `tetris.tscn`

```
UniversalGameScript
├── GridClear (Rule)
│   ├── grid_columns = 10, grid_rows = 20
│   ├── Manages board occupancy
│   ├── Detects completed rows, clears them
│   ├── Emits: rows_cleared(count), piece_locked, game_over_blocked
│
├── PieceSpawner (Flow)
│   ├── piece_scenes: [I, O, T, S, Z, J, L]
│   ├── Listens to: on_game_start, GridClear.piece_locked
│   ├── 7-bag randomizer
│   └── Checks spawn position via GridClear → game over if blocked
│
├── GridBoard visual (Node2D or Control)
│   ├── Draws the grid background, grid lines
│   ├── Optional: boundary walls (so pieces can't escape)
│   └── Pure visual — no logic
│
├── Next Piece Preview (Interface extension or separate)
│   └── Shows upcoming piece(s)
│
├── PointsMonitor (score threshold → "victory" / level complete)
├── GroupCountMultiplier or custom speed_increase
├── Interface (POINTS_MULTIPLIER mode + level display)
├── SoundSynth (move, rotate, drop, clear sounds)
├── MusicRamping (background music, speeds up with level)
│
└── The active tetromino is spawned into the game tree:
    Tetromino (UniversalBody)
    ├── GridHop (Leg — handles grid movement, consults GridClear)
    ├── PlayerControl (Brain — emits move/action signals)
    └── Drawing code only (shape + color from exports)
```

### New Components for Tetris

| Component | Category | Purpose |
|-----------|----------|---------|
| `grid_hop` | Leg | Discrete grid movement for a single body. Snaps to grid cells, checks occupancy, handles fall timer, rotation, hard drop |
| `grid_clear` | Rule | Manages grid occupancy map. Locks pieces, detects and clears completed rows, shifts cells down, signals game over |
| `piece_spawner` | Flow | Spawns tetromino pieces one at a time with 7-bag randomizer. Checks spawn validity. Driven by game start + piece lock events |

### New Body Scenes

| Scene | Purpose |
|-------|---------|
| `generic/tetromino_i.tscn` | I-piece (4 in a row) |
| `generic/tetromino_o.tscn` | O-piece (2×2 square) |
| `generic/tetromino_t.tscn` | T-piece |
| `generic/tetromino_s.tscn` | S-piece |
| `generic/tetromino_z.tscn` | Z-piece |
| `generic/tetromino_j.tscn` | J-piece |
| `generic/tetromino_l.tscn` | L-piece |

Or: one shared `tetromino.gd` script with shape as export, configured per scene.

---

## Component Summary

### New Components (5 total)

| Component | Category | Game | Purpose |
|-----------|----------|------|---------|
| `formation_grid` | Brain | Space Invaders | Synchronized group movement, screen-edge detection, speed ramp |
| `formation_gun` | Arm | Space Invaders | Centralized formation firing, bottom-row random pick, max bullet cap |
| `grid_hop` | Leg | Tetris | Discrete grid movement, cell snapping, fall timer, rotation |
| `grid_clear` | Rule | Tetris | Grid occupancy map, row detection, row clearing, shift-down |
| `piece_spawner` | Flow | Tetris | 7-bag piece spawning, spawn validity check |

### New Body Scenes (10 total)

| Scene | Game | Purpose |
|-------|------|---------|
| `generic/invader_squid.tscn` | Space Invaders | Top-row alien (30pts) |
| `generic/invader_crab.tscn` | Space Invaders | Middle-row alien (20pts) |
| `generic/invader_octopus.tscn` | Space Invaders | Bottom-row alien (10pts) |
| `generic/cannon.tscn` | Space Invaders | Player cannon |
| `generic/tetromino_i.tscn` | Tetris | I-piece |
| `generic/tetromino_o.tscn` | Tetris | O-piece |
| `generic/tetromino_t.tscn` | Tetris | T-piece |
| `generic/tetromino_s.tscn` | Tetris | S-piece |
| `generic/tetromino_z.tscn` | Tetris | Z-piece |
| `generic/tetromino_j.tscn` | Tetris | J-piece |
| `generic/tetromino_l.tscn` | Tetris | L-piece |

(Or 4 Space Invaders scenes + 1 shared tetromino script = 5 new script files)

### Modified Components: NONE

All existing components work as-is. The new games only ADD components.

---

## Implementation Order

### Phase A: Space Invaders
1. Build 3 invader body scripts (squid, crab, octopus) — drawing code only
2. Build cannon body script — drawing code only
3. Build `formation_grid.gd` (Brain) — synchronized formation movement
4. Build `formation_gun.gd` (Arm) — centralized formation firing
5. Assemble `space_invaders.tscn` — WaveSpawner GRID for invaders, bunkers, player cannon, UFO
6. Test Space Invaders

### Phase B: Tetris
1. Build `tetromino.gd` body script — shape drawing with cell_offsets export
2. Build 7 tetromino scenes (or 1 scene + PropertyOverride)
3. Build `grid_hop.gd` (Leg) — discrete grid movement
4. Build `grid_clear.gd` (Rule) — board state, row clearing
5. Build `piece_spawner.gd` (Flow) — 7-bag spawning
6. Assemble `tetris.tscn` — GridClear + PieceSpawner + GridHop + Interface
7. Test Tetris

### Recommended: Space Invaders First
- Space Invaders is a natural fit for the existing system (just needs formation movement)
- Tetris introduces a fundamentally new paradigm (grid-based)
- Starting with the easier game validates the new components before tackling the harder one

---

## Success Criteria

- [ ] Space Invaders: 5×11 alien grid marches left/right, steps down at edges
- [ ] Space Invaders: Alien march speed increases as aliens are destroyed
- [ ] Space Invaders: Random bottom-row alien fires periodically (max 3 bullets)
- [ ] Space Invaders: 4 destructible bunkers degrade from both player and enemy fire
- [ ] Space Invaders: UFO bonus flies across top periodically
- [ ] Space Invaders: Game over when aliens reach bottom or player dies
- [ ] Space Invaders: Scoring works (different points per alien row, UFO bonus)
- [ ] Tetris: All 7 tetromino shapes spawn and display correctly
- [ ] Tetris: Pieces move on a discrete grid (left, right, rotate, soft drop, hard drop)
- [ ] Tetris: Pieces lock when they land on the stack or bottom
- [ ] Tetris: Completed rows clear and cells above shift down
- [ ] Tetris: Game over when new piece can't spawn
- [ ] Tetris: 7-bag randomizer for fair piece distribution
- [ ] Both games: Pure UGS scene assemblies, zero game scripts
- [ ] Both games: Score displayed via Interface component

---

## Open Questions

- **Space Invaders animation:** Do aliens animate (two frames switching on each step)? If so, the body script needs frame-switching logic triggered by the formation step. Could be a new component `frame_switch` or handled in the body draw code with a toggle.
- **Tetris physics bypass:** How should GridHop coexist with UniversalBody's default `_physics_process`? Options: (a) disable physics on the body, (b) set velocity to zero each frame, (c) add a `disable_physics` export to UniversalBody. Recommend (c) for cleanliness.
- **Tetris locked piece visuals:** When a piece locks, should it stay as the same UniversalBody (frozen in place)? Or should GridClear destroy it and redraw the board state? Recommend keeping the body frozen — simpler, and destruction effects can play on clear.
- **Space Invaders invader count:** Authentic = 5×11 = 55 invaders. Is this too many bodies for the component system? Should work fine — current games handle similar counts.
- **Bunker implementation:** Grid of tiny bricks vs custom bunker body? Recommend grid of bricks (componentized).
- **Space Invaders player death:** One-hit kill (DieOnHit) or multi-hit (Health)? Authentic is 3 lives via LivesCounter, one-hit per cannon.
- **Tetris scoring system:** Classic NES (1/3/5/8 × level) or simplified flat scoring? Recommend flat (100/300/500/800) with PointsMonitor.