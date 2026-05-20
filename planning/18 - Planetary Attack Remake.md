# Planetary Attack Remake

## Game Concept

The player controls a Mystery Ship and must **protect** an advancing Invader formation so it reaches the ground. The invaders march automatically using Bug Blaster swarm logic. Opposing them are ground-based cannons and bunkers. Triangle ships drift in and attack the invaders. An asteroid field adds chaos. The playfield is larger than one screen with a scrolling camera.

**Core Loop:** Fly the Mystery Ship → shoot threats → shield invaders with ring spawner → invaders reach ground = VICTORY.

---

## V1 Baseline State

The current `planetary_attack.tscn` contains:
- 4 PaddleCannons with boundary limits and AI
- 4 Barriers (bunkers)
- 4 WaveSpawners producing a 4-row invader formation
- SwarmController (auto-march, `bottom_action = VICTORY`)
- GroupMonitor for enemies (defeat) and players (lose life)
- LivesCounter, Timer (UFO spawning), SoundSynth
- Interface with lives display

**What works:** Invaders march down, cannons shoot them. Cannons usually win.

---

## V2 Design — 9 Elements

### 1. Mystery Ship (Player Body)

**Status:** NEW SCENE
**File:** `Scenes/Bodies/player/mystery_ship_player.tscn`

| Component | Source | Notes |
|-----------|--------|-------|
| Body | `ufo.gd` | Draws saucer shape |
| Brain | `player_control.gd` | Keyboard/mouse/gamepad |
| Legs | `direct_acceleration.gd` | Smooth 360° movement |
| Arm | `gun_simple.gd` | `mouse_input = true` for omnidirectional aiming |
| Shield | `ring_spawner.gd` | Finite shield ring, no regeneration |
| Health | `health.gd` | Damage tracking |
| Death | `death_effect.gd` + death particles | |
| Sound | `sound_synth.tscn` | Thrust sound |
| Groups | `players`, `player_cameras` | Camera tracking target |
| Bounds | `x/y min/max` | Set to playfield size |

### 2. Ring Spawner Shield

**Status:** EXISTING — no changes to `ring_spawner.gd`
- Spawns shield pieces in a ring around the player
- Pieces intercept bullets (collision group configuration)
- Shield does NOT regenerate — finite resource
- `spawn_groups` export controls what group the shield pieces belong to

### 3. Omnidirectional Shooting

**Status:** EXISTING — no changes
- `gun_simple.gd` with `mouse_input = true` aims at mouse cursor
- `player_control.gd` emits `aim_at` from mouse motion
- Same behavior as Space Rocks Inverted

### 4. Invader Formation (Auto-Advance)

**Status:** EXISTING — no script changes
- `swarm_controller.gd` already has `BottomAction.VICTORY`
- Scene sets `bottom_action = 3` (VICTORY)
- Bug Blaster marching logic, invaders start high and advance down
- `shoot_ai_swarm.gd` gives invaders Bug Blaster-style shooting

### 5. Protect Invaders (Win/Lose Conditions)

**Status:** EXISTING components, scene wiring

| Condition | Component | Config |
|-----------|-----------|--------|
| Victory | `swarm_controller.gd` | `bottom_action = VICTORY` |
| Defeat (invaders all dead) | `group_monitor.gd` | `target_group = "invaders"` |
| Lose life (player dies) | `group_monitor.gd` | `target_group = "players"`, `lose_life_on_clear = true` |

**Note:** Friendly fire is ON. The player can accidentally shoot invaders. This adds tension and skill expression.

### 6. Bunkers and Cannons

**Status:** EXISTING — scene configuration changes only
- 4 PaddleCannons spread across wider playfield bottom
- 4 Barriers as bunkers
- Increase `vision_range` on ClearShotAI for larger field
- Adjust `x_min/x_max` boundaries for wider spacing

### 7. Triangle Ships (Invader Hunters)

**Status:** NEW SCENE VARIANT + spawner setup
**File:** `Scenes/Bodies/nonplayer/nonplayer_triangle_ship_antiinvader.tscn`

- Based on `nonplayer_triangle_ship.tscn` with changed config:
  - `interceptor_ai.gd`: `target_group = "invaders"`
  - `aim_ai.gd`: `target_group = "invaders"`
  - `shoot_ai.gd`: fires at invaders
- Spawned on a looping timer via `wave_director.gd` + `wave_spawner.gd`
- Spawn from edges/above the playfield
- Drift toward invaders and shoot at them

### 8. Asteroid Field

**Status:** EXISTING components — spawner setup
- `wave_director.gd` + `wave_spawner.gd` on a looping timer
- Uses `asteroid.gd` + `split_on_death.gd`
- Bullets from all sides hit asteroids → chaos
- Add `space_rocks` to collision matrix

### 9. Scrolling Camera

**Status:** NEW COMPONENT
**File:** `Scripts/Components/camera_midpoint.gd`
**Scene:** `Scenes/Components/camera_midpoint.tscn`

- UGS-level component (child of game node, not player)
- Tracks midpoint between mystery ship and mouse position
- Configurable lerp speed for smoothing
- Clamped to playfield bounds (camera never shows beyond the field)
- Finds tracked entity via configurable group name (default `"player_cameras"`)

---

## Collision Groups

Friendly fire is ON. The player must be careful not to shoot their own invaders.

| Group | Who's In It | Bullet Targets | Physical Targets |
|-------|-------------|----------------|------------------|
| `players` | Mystery Ship | — | `enemies` |
| `invaders` | Invader formation | `players`, `enemies` | `bricks` (pushed out of way) |
| `enemies` | Cannons, Triangle Ships | `invaders`, `players` | `players`, `invaders` |
| `players_bullets` | Player's bullets | `enemies`, `invaders`, `bricks`, `space_rocks` | — |
| `enemies_bullets` | Cannon/Triangle bullets | `invaders`, `players`, `bricks`, `space_rocks` | — |
| `bricks` | Bunker bricks, shield pieces | — | All bullets stop here; invaders push through |
| `space_rocks` | Asteroids | — | Physical collision with everything |

**Key behaviors:**
- Player bullets CAN hit invaders (friendly fire — skill element)
- Cannon bullets target invaders AND the player
- Invaders push through bunker bricks (clearing the path)
- Bricks stop all bullets from both sides
- Asteroids catch all bullets and split

---

## Implementation Phases

### Phase 1: Playfield Foundation

Make the playfield size configurable so all games default to identical behavior but Planetary Attack can go larger.

#### 1a. Add `playfield_size` to UGS
**File:** `Scripts/Core/universal_game_script.gd`
- Add `@export var playfield_size: Vector2 = Vector2(640, 360)`
- Default matches viewport — zero behavioral change for all existing games

#### 1b. Refine `screen_cleanup.gd`
**File:** `Scripts/Components/screen_cleanup.gd`
- Replace `get_viewport().get_visible_rect().size` with `game.playfield_size`
- Fallback to viewport size if no game ancestor

#### 1c. Refine `screen_wrap.gd`
**File:** `Scripts/Components/screen_wrap.gd`
- Same treatment: use `game.playfield_size` instead of viewport size
- Fallback to viewport size

#### 1d. Interface camera awareness
**File:** `Scripts/Flow/interface.gd` or scene
- Set `top_level = true` so Interface ignores parent transforms
- Keeps HUD pinned to viewport when camera scrolls

#### 1e. CRT verification (read-only)
**File:** `Scripts/Flow/crt_controller.gd`
- CRT lives on AO scene, operates on viewport — should work unchanged
- BackBufferCopy captures the full rendered frame including camera transforms
- Persistence SubViewport accumulates correctly with camera movement
- Verify during testing that phosphor trails look right with scrolling

### Phase 2: New Components

#### 2a. `camera_midpoint.gd`
**File:** `Scripts/Components/camera_midpoint.gd`
**Scene:** `Scenes/Components/camera_midpoint.tscn`

```
extends UniversalComponent2D

@export var camera_group: String = "player_cameras"
@export var lerp_speed: float = 5.0

var _camera: Camera2D

func _ready():
    _camera = Camera2D.new()
    add_child(_camera)

func _physics_process(delta):
    var nodes = get_tree().get_nodes_in_group(camera_group)
    if nodes.is_empty(): return
    var entity = nodes[0]
    if not is_instance_valid(entity): return

    var mouse_world = entity.get_global_mouse_position()
    var midpoint = (entity.global_position + mouse_world) / 2.0

    # Clamp to playfield
    var pf = game.playfield_size if game else Vector2(640, 360)
    var half = get_viewport().get_visible_rect().size / 2.0
    midpoint.x = clampf(midpoint.x, half.x, pf.x - half.x)
    midpoint.y = clampf(midpoint.y, half.y, pf.y - half.y)

    _camera.global_position = lerp(_camera.global_position, midpoint, lerp_speed * delta)
```

### Phase 3: Planetary Attack Scene Assembly

#### 3a. UGS Configuration
- `game_title = "Planetary Attack"`
- `playfield_size = Vector2(1280, 720)` (2× viewport)
- Updated collision matrix (see table above)

#### 3b. Swarm Controller
- `bottom_action = VICTORY` (already set)
- `boundary_bottom` ≈ 660 (near bottom of 720-tall field)
- `boundary_left/right` ≈ 8 / 1272
- Invader spawn positions: y ≈ 80-200 (start high)
- `wave_speed_decrease = 0.1` (speed ramp)

#### 3c. Mystery Ship Player
- New scene `mystery_ship_player.tscn` (see Element 1 table)
- Bounds: x/y min/max set to 0,0,1280,720
- In group `"player_cameras"` for camera tracking

#### 3d. Camera
- Add `camera_midpoint.tscn` as child of UGS
- `camera_group = "player_cameras"`
- Reads `playfield_size` from game

#### 3e. Cannons + Bunkers
- Spread across wider 1280px bottom
- Cannon positions: ≈160, 400, 560, 800, 1040 (scaled from current)
- Barrier positions: alongside cannons
- Increase vision_range

#### 3f. Triangle Ship Spawners
- Timer (looping, ~20s)
- WaveDirector triggered by timer
- WaveSpawner with `nonplayer_triangle_ship_antiinvader.tscn`
- Spawn from playfield edges

#### 3g. Asteroid Field Spawner
- Timer (looping, ~30-45s)
- WaveDirector + WaveSpawner
- `asteroid.tscn` + `split_on_death`
- Add `space_rocks` collision group

### Phase 4: Polish and Testing
- Tune spawn rates, speeds, densities
- Test in AO rotation (CRT + Interface + transitions)
- Verify CRT phosphor trails with camera scrolling
- Test gamepad (camera midpoint with joystick aim)
- Balance: can invaders actually reach the ground with player help?

---

## Component Status Summary

### New Components (2)

| Component | Type | Description |
|-----------|------|-------------|
| `camera_midpoint.gd` | Script + Scene | Scrolling camera tracking midpoint of ship + mouse |
| `mystery_ship_player.tscn` | Scene only | Player UFO with shield, gun, player control |

### New Scene Variants (1)

| Scene | Based On | Change |
|-------|----------|--------|
| `nonplayer_triangle_ship_antiinvader.tscn` | `nonplayer_triangle_ship.tscn` | `target_group = "invaders"` on AI brains |

### Refined Components (3-4)

| Component | Change | Risk |
|-----------|--------|------|
| `universal_game_script.gd` | Add `playfield_size` export | None — default matches current |
| `screen_cleanup.gd` | Use `game.playfield_size` | None — fallback to viewport |
| `screen_wrap.gd` | Use `game.playfield_size` | None — fallback to viewport |
| `interface.tscn` or `interface.gd` | `top_level = true` | Low — test with existing games |

### Unchanged Components

- `swarm_controller.gd` — already has VICTORY option
- `ring_spawner.gd` — works as-is for shield
- `gun_simple.gd` — already supports mouse aiming
- `player_control.gd` — already emits aim_at
- `crt_controller.gd` — viewport-based, should work as-is
- All body scripts — drawing code only
- All AI brains — config changes only
- `wave_spawner.gd`, `wave_director.gd`, `timer.gd` — work as-is

---

## Files Touched

### Scripts
- `Scripts/Core/universal_game_script.gd` — add playfield_size export
- `Scripts/Components/screen_cleanup.gd` — use playfield_size
- `Scripts/Components/screen_wrap.gd` — use playfield_size
- `Scripts/Components/camera_midpoint.gd` — NEW
- `Scripts/Flow/interface.gd` — top_level = true (TBD if needed)

### Scenes
- `Scenes/Components/camera_midpoint.tscn` — NEW
- `Scenes/Bodies/player/mystery_ship_player.tscn` — NEW
- `Scenes/Bodies/nonplayer/nonplayer_triangle_ship_antiinvader.tscn` — NEW
- `Scenes/Games/inversions/planetary_attack.tscn` — MAJOR REBUILD