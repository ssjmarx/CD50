# Plan 06: Space Rocks Polish and More Remix Games

**Status:** 🔄 Planning  
**Prerequisite:** Plan 05 ✅ (all games componentized)

---

## Objective

Full Space Rocks recreation: ship death animation, UFO enemy, warp, reactive music. Input system refactor for remappable buttons. Three new remix games that stress-test the component architecture.

---

## Part 1: Input Refactor

**Problem:** `UniversalBody._on_button_pressed()` hard-codes `button_r` → shoot, `button_l` → thrust. Any new actions (warp, etc.) have no signal path. Components can't listen for arbitrary button mappings.

**Current flow:**
```
PlayerControl → parent.button_pressed(InputEvent)
  → UniversalBody routes:
      button_r → shoot.emit()
      button_l → thrust.emit()
      anything → action.emit()  ← NO ARGUMENT, components can't filter
```

**New flow:**
```
PlayerControl → parent.button_pressed(InputEvent)
  → UniversalBody routes:
      button_r → shoot.emit()
      button_l → thrust.emit()
      anything → action.emit(button)  ← PASSES InputEvent
```

**Changes to `universal_body.gd`:**
- `action` signal signature: `action(button: InputEvent)` (was no args)
- `end_action` signal signature: `end_action(button: InputEvent)` (was no args)
- Dedicated `shoot`/`thrust` signals remain unchanged (backward compatible)

**Changes to existing components:**
- Any component currently listening to `action` or `end_action` needs to accept the new `InputEvent` parameter (even if it ignores it)
- Components that listen to `shoot`/`thrust` are unaffected

**New component pattern:**
- `space_rocks_warp` (and future components) connect to `parent.action`
- Filter inside the callback: `if button.is_action("button_3"): ...`
- This means every game action is remappable through Godot's Input Map — no code changes needed to rebind

**Why this approach:**
- Minimal change to existing architecture
- `shoot`/`thrust` keep working as-is for all existing games
- New actions ride on the generic `action` signal with filtering
- Fully remappable through Godot's Input Map editor

---

## Part 2: Death Effects

### Visual Effects

Two distinct death effect visuals:

**Effect A: Particle Burst** (white dots flying outward from impact point)
- Thin scatter of small white circles/dots radiating from center
- Used for asteroid destruction (by itself) and as part of ship death
- Self-destructing via DieOnTimer

**Effect B: Ship Debris** (6 small white line segments floating away)
- Six short line fragments that drift apart from center
- Each fragment disappears at a different interval (staggered DieOnTimer)
- Used ONLY for ship death (combined with particle burst)

### New Folder: `Scenes/Effects/`

One-off animation scenes that aren't bodies, components, or game scenes. Self-contained visual effects that spawn, play, and self-destruct.

**Effect C: Engine Flame** (small vector triangle pointing "down" relative to parent)
- Tiny triangle drawn behind the ship when thrusting
- Connects to parent's `thrust` signal → show, `end_thrust` signal → hide
- Position offset behind the ship body, rotation matches parent
- Could be a component that draws on the parent (simpler) or a child Node2D scene

```
Godot/Scenes/Effects/
├── death_effect_particles.tscn    ← Particle burst (Effect A)
├── death_effect_ship_debris.tscn  ← Ship debris lines (Effect B)
└── engine_flame.tscn              ← Thrust flame triangle (Effect C)
```

### New Component: `death_effect` (Component)

```
DeathEffect (UniversalComponent)
├── Exports:
│   ├── effect_scenes: Array[PackedScene]  (one or more effects to spawn)
├── Listens to: $Health.zero_health
├── On trigger:
│   ├── For each scene in effect_scenes:
│   │   ├── Instantiate at parent.global_position
│   │   ├── Set initial velocity/direction (if applicable)
│   │   └── Add to parent.get_parent()
│   └── Effect scenes handle their own lifetime (DieOnTimer)
```

### Scene Assembly for Space Rocks

**Asteroid death:** asteroid.tscn already has `SplitOnDeath` → add `DeathEffect` with `[death_effect_particles.tscn]`

**Ship death:** Add `DeathEffect` to triangle_ship.tscn (or via WaveSpawner `spawn_components`) with `[death_effect_particles.tscn, death_effect_ship_debris.tscn]`

**UFO death:** Add `DeathEffect` with `[death_effect_particles.tscn]` (same as asteroid)

---

## Part 3: UFO Enemy

**Problem:** The UFO body scene exists (`Scenes/Bodies/ufo.tscn`) but has no brain, no weapons, no AI, and isn't used in any game.

**Reference:** `planning/brainstorming/ufo.md` — describes a PatrolAI that follows a Curve2D path.

**New Component: `patrol_ai` (Brain)**

```
PatrolAI (Node, extends UniversalComponent)
├── Exports:
│   ├── path: Curve2D (assigned in editor or generated on _ready)
│   ├── look_ahead_distance: float = 10.0
│   ├── loop: bool = true
│   └── generate_random_path: bool = false
├── Listens to: none (polls in _physics_process)
├── Behavior:
│   ├── Treats Curve2D as waypoint list
│   ├── Calculates direction to current target point
│   ├── Emits parent.left_joystick.emit(direction) — same pattern as InterceptorAI
│   ├── The body's _on_left_joystick applies axis locks, then emits move(direction)
│   ├── The Leg component receives move and decides how to apply it
│   └── Advances to next point when within look_ahead_distance
└── Random path generation:
    ├── Creates Curve2D with random screen-edge-to-screen-edge waypoints
    └── Keeps Path2D at (0,0) so points = global coordinates
```

**Why no speed export:** PatrolAI is a Brain — it decides WHERE to go, not HOW FAST. Speed is the Leg's job. This means the same PatrolAI on a UFO with DirectMovement behaves differently than on a UFO with EngineSimple, which is the whole point of the Brain→Body→Leg pattern.

### UFO Size Variants

The UFO scene has a `size` enum (LARGE = 1, SMALL = 0) similar to asteroid's `initial_size`. Size configures child components via PropertyOverride or ready-time setup:

| Property | Large UFO | Small UFO |
|----------|-----------|-----------|
| DirectMovement speed | ~100 (slower) | ~200 (faster) |
| AimAi accuracy/turning | Low (wobbly aim) | High (precise aim) |
| CollisionShape size | Bigger hitbox | Smaller hitbox |
| ScoreOnDeath | 6pts | 60pts |

**UFO Scene Assembly (`ufo.tscn`):**
```
UFO (UniversalBody)
├── CollisionShape2D (hitbox scaled by size)
├── PatrolAI (generate_random_path = true, loop = true) [Brain]
├── DirectMovement (speed set by size) [Leg]
├── AimAI (target_group = "players", accuracy set by size)
├── GunSimple (fires at player)
├── Health (max_health = 1)
├── ScoreOnDeath (base_score set by size)
├── DieOnHit
├── DamageOnHit (target_groups: ["players"])
├── DeathEffect (effect_scenes: [death_effect_particles.tscn])
├── ScreenWrap
├── FlyingSound
└── SoundOnHit
```

### Dual UFO Spawners with Adjusting Timers

**Timer Enhancement:** Add `adjust_on_loop` to the Timer component.
- Export: `adjust_on_loop: float = 0.0` — amount to add/subtract from `wait_time` each loop
- After each timeout: `wait_time = wait_time + adjust_on_loop`
- Clamped to a minimum (e.g., never below 5s) to prevent spam

**Large UFO Spawner:**
- Timer starts at ~10s, `adjust_on_loop = +2.0` (gets less frequent over time)
- WaveSpawner spawns large UFO, PropertyOverride sets size = LARGE
- Safe zone: scans entire screen for "enemies" group — won't spawn if any enemy exists

**Small UFO Spawner:**
- Timer starts at ~30s, `adjust_on_loop = -2.0` (gets more frequent over time)
- WaveSpawner spawns small UFO, PropertyOverride sets size = SMALL
- Same safe zone check — won't spawn if any enemy exists

**Result:** Early game = frequent large UFOs (slow, inaccurate, low-value). Late game = frequent small UFOs (fast, precise, high-value). At most one UFO on screen at a time.

**Integration into Space Rocks (`space_rocks.tscn`):**
```
├── LargeUfoTimer (Timer, auto_start, wait_time=10, adjust_on_loop=+2.0)
│   → WaveDirector → WaveSpawner
│       ├── spawns: ufo.tscn
│       ├── safe_zone: full screen, target_group: "enemies"
│       └── PropertyOverride: size = LARGE
├── SmallUfoTimer (Timer, auto_start, wait_time=30, adjust_on_loop=-2.0)
│   → WaveDirector → WaveSpawner
│       ├── spawns: ufo.tscn
│       ├── safe_zone: full screen, target_group: "enemies"
│       └── PropertyOverride: size = SMALL
```

**Score balance:**
- Big asteroid: 1pts, Medium: 2pts, Small: 3pts
- Large UFO: 6pts, Small UFO: 60pts
- Multiplier: +1 for every Asteroid currently on screen (rewards dangerous play)

---

## Part 4: Warp

**New Component: `space_rocks_warp` (Leg)**

```
Space RocksWarp (UniversalComponent)
├── Exports:
│   ├── chance_of_death: float = 0.25 (1.0 is 100%)
│   ├── warp_duration: float = 0.5 (time spent warping, intangible during this period)
│   └── target_group: String = "players" (group to check for bounds)
├── Listens to: parent.action (filtered to button_3)
├── Behavior on warp:
│   ├── Disable all collision shapes on parent
│   ├── Hide parent
│   ├── Move parent to random position within screen bounds
│   ├── Zero out parent velocity
│   ├── Randomize parent rotation
│   ├── Start duration timer
│   ├── Unhide parent
│   ├── Check for random death (randf() < chance_of_death → trigger Health damage)
│   └── re-enable collision shapes
└── No cooldown — the chance of death IS the spam deterrent
```

**Key design:**
- Uses the new `action` signal with InputEvent argument
- Filters for `button.is_action("button_3")`
- Pure Leg component — no body-specific logic
- Intangibility = disabling CollisionShape2D children (same pattern as Health.die but temporary)
- Random position should avoid spawning on top of space_rocks (optional — could use safe zone logic from WaveSpawner)

**Assembly:** Add to triangle_ship.tscn or via spawn_components when creating the player ship in space_rocks.tscn.

---

## Part 5: Reactive Music

**New Component: `music_ramping` (flow)**

```
MusicRamping (UniversalComponent)
├── Exports:
│   ├── sound: AudioStream (the "doot DOOT" loop)
│   ├── target_group: String = "space_rocks" (group to watch)
│   ├── base_pitch: float = 1.0 (starting playback speed)
│   ├── max_pitch: float = 3.0 (fastest playback speed)
│   ├── initial_count: int = 0 (set on _ready, counts group at start)
├── Listens to: none (polls group count in _process)
├── Behavior:
│   ├── On _ready: play sound on loop, record initial group count
│   ├── Every frame: count nodes in target_group
│   ├── Calculate ratio: remaining / initial_count
│   ├── Map ratio to pitch: lerp(max_pitch, base_pitch, ratio)
│   │   (fewer enemies = higher pitch = faster music)
│   └── Stop/pause when group is empty
```

**Key design:**
- Uses AudioStreamPlayer2D for positional audio (or AudioStreamPlayer for global)
- Godot's `pitch_scale` property on AudioStreamPlayer controls playback speed
- Linear interpolation from base_pitch → max_pitch as group count → 0
- The initial_count capture means it works regardless of how many space_rocks spawn per wave
- Stops entirely when group empties

**Assembly:** Add to space_rocks.tscn as a child of the UGS root.

---

## Part 6: Remix Games

### 6A — Paddle Ballout (Paddle Ball + Brick Breaker)

**Concept:** Paddle Ball where each goal is shielded by a wall of brick_breaker bricks. One goal ends the game (not 11). Enemy AI difficulty ramps as their bricks are destroyed.

**Scene Assembly (`paddle_ballout.tscn`):**
```
UniversalGameScript (collision_groups: balls, paddles, bricks, walls, goals)
├── Player Paddle (PlayerControl + DirectMovement + AngledDeflector)
├── Enemy Paddle (InterceptorAi + DirectMovement + AngledDeflector)
├── Ball (DamageOnHit [target_groups: bricks] + ScoreOnHit + DieOnHit + ScreenCleanup + Paddle BallAcceleration)
├── Left Goal Area2D (Goal [P1_SCORE, score_amount=1])
│   └── Brick Grid (WaveSpawner GRID, positioned in front of goal)
│       └── Each brick: Health + ScoreOnDeath, spawn_group: "bricks_left"
├── Right Goal Area2D (Goal [P2_SCORE, score_amount=1])
│   └── Brick Grid (WaveSpawner GRID, positioned in front of goal)
│       └── Each brick: Health + ScoreOnDeath, spawn_group: "bricks_right"
├── GroupMonitor (balls) → WaveDirector → WaveSpawner (respawn ball)
├── GroupMonitor ("bricks_right") → VariableTuner (boost enemy InterceptorAi turning_speed)
├── PointsMonitor (P1_SCORE ≥ 1 → victory)
├── PointsMonitor (P2_SCORE ≥ 1 → defeat)
├── Interface (P1_P2_SCORE mode)
└── Walls + CollisionMarkers + SoundOnHits
```

**New components needed: NONE.** Pure scene assembly.

---

### 6B — Asterout (Space Rocks + Brick Breaker)

**Concept:** Triangle ship with modern controls dogfighting against shielded UFOs. Each UFO has a ring of tiny bricks childed to it that act as a destructible shield. The shield moves with the UFO. Chip away the shield to get shots at the UFO underneath.

**Scene Assembly (`asterout.tscn`):**
```
UniversalGameScript (collision_groups: players, bullets, enemies, bricks, walls)
├── Player Ship (triangle_ship)
│   ├── PlayerControl
│   ├── EngineComplex (button_only = false, modern joystick steering)
│   ├── FrictionLinear
│   ├── DirectMovement
│   ├── RotationTarget (independent_aim)
│   ├── GunSimple
│   ├── ScreenWrap
│   ├── Health (max_health = 3)
│   └── DieOnHit
├── Bullet (bullet_simple)
│   ├── DamageOnHit (target_groups: ["enemies", "bricks"])
│   ├── DieOnHit
│   └── ScreenCleanup
├── WaveSpawner (spawns UFOs)
│   ├── Spawns ufo.tscn with RingSpawner attached via spawn_components
│   └── spawn_groups: ["enemies"]
│
│   UFO body includes:
│   ├── PatrolAI + DirectMovement + AimAI + GunSimple + Health + ScoreOnDeath
│   ├── DieOnHit + DamageOnHit + DeathEffect + ScreenWrap + SoundOnHit
│   └── RingSpawner (spawn_scene: brick.tscn, ring_radius: 30, spawn_count: 12, spawn_size: 4×4)
│       └── Spawns brick children in a ring on _ready → moves with UFO automatically
├── WaveDirector (GAME_START trigger)
├── GroupMonitor ("enemies") → win condition
├── LivesCounter
├── GroupCountMultiplier ("enemies")
├── Interface (POINTS_MULTIPLIER mode)
└── Timer (auto_start, loop) → WaveDirector → more UFOs
```

**Key design:**
- Modern controls: EngineComplex + FrictionLinear + DirectMovement + RotationTarget
- UFOs patrol and shoot (PatrolAI + AimAI + GunSimple)
- Brick shields are **childed to the UFO** — they move with it automatically (Godot's transform parenting)
- Tiny 4×4 pixel bricks arranged in a ring around the UFO body
- Player must chip through the shield ring to expose the UFO hitbox
- Shield regenerates? No — once bricks are gone, the UFO is exposed permanently

**Why childing works here:** Bricks are UniversalBody scenes with their own CollisionShape2D. As children of the UFO body, their `global_position` updates automatically when the parent moves. Their collision layers/groups remain independent — bullets hit "bricks" group first, then "enemies" once the shield is gone.

**New component: `ring_spawner` (Flow)**

```
RingSpawner (UniversalComponent)
├── Exports:
│   ├── spawn_scene: PackedScene (e.g., brick.tscn)
│   ├── ring_radius: float = 30.0
│   ├── spawn_count: int = 12
│   ├── spawn_size: Vector2 = Vector2(4, 4) (overrides spawned body width/height)
│   └── spawn_groups: Array[String] = ["bricks"]
├── _ready:
│   ├── For i in spawn_count:
│   │   ├── var body = spawn_scene.instantiate()
│   │   ├── body.width = spawn_size.x, body.height = spawn_size.y
│   │   ├── body.get_node("CollisionShape2D").shape.size = spawn_size
│   │   ├── var angle = TAU * i / spawn_count
│   │   ├── body.position = Vector2.from_angle(angle) * ring_radius
│   │   ├── for group in spawn_groups: body.add_to_group(group)
│   │   └── parent.add_child(body)
```

**Why RingSpawner instead of modifying WaveSpawner:** WaveSpawner always parents to `game.add_child()` and is driven by wave events. RingSpawner is a different class of spawner — it runs once on `_ready`, parents to its own body, and arranges children in a ring. Same family as WaveSpawner, different purpose. Keeps both components simple.

**Why it lives in Flow:** It spawns entities into the game, same category as `wave_spawner`. The `Scripts/Flow/` directory is the right home.

---

### 6C — Rock Breaker (Brick Breaker + Space Rocks)

**Concept:** You are the Brick Breaker paddle at the bottom. Your weapon is a ball. Space Rocks with health float near the top. They split on death. Don't let the ball fall.

**Scene Assembly (`rock_breaker.tscn`):**
```
UniversalGameScript (collision_groups: paddles, balls, space_rocks, walls)
├── Player Paddle
│   ├── PlayerControl
│   ├── DirectMovement (lock_y = true)
│   └── AngledDeflector (target_group: balls)
├── Ball (ball)
│   ├── DamageOnHit (target_groups: ["space_rocks"])
│   ├── Paddle BallAcceleration
│   └── (no ScreenCleanup — bottom Goal handles death)
├── Bottom Goal Area2D (Goal [lose_life mode])
├── WaveSpawner (GRID pattern, spawns space_rocks)
│   ├── Asteroid bodies with Health + ScoreOnDeath + SplitOnDeath
│   ├── PropertyOverrides: set Health.max_health per size, small random velocities
│   └── spawn_groups: ["space_rocks"]
├── WaveDirector (GAME_START trigger)
├── GroupMonitor ("space_rocks") → WaveDirector → spawn next wave
├── GroupMonitor ("balls") → WaveDirector → WaveSpawner (respawn ball)
├── LivesCounter
├── GroupCountMultiplier ("space_rocks")
├── Interface (POINTS_MULTIPLIER mode)
└── Walls (top, left, right) + CollisionMarkers + SoundOnHits
```

**Key design:**
- Space Rocks use size-as-health: Big=3hp, Medium=2hp, Small=1hp
- SplitOnDeath reduces size on death — existing behavior
- PropertyOverride in WaveSpawner sets Health.max_health per asteroid size
- Ball falling through bottom = Goal in lose_life mode = LivesCounter decrement
- Ball respawns via GroupMonitor("balls") → WaveDirector → WaveSpawner

**New components needed: NONE** (size-as-health, no color coding needed).

---

## Component Summary

### New Components (6)

| Component | Category | Purpose | Used By |
|-----------|----------|---------|---------|
| `death_effect` | Component | Spawn visual effect scenes on parent death | Ship, asteroid, UFO |
| `patrol_ai` | Brain | Curve2D path following + random path generation | UFO (Space Rocks, Asterout) |
| `space_rocks_warp` | Leg | Emergency teleport with random death chance, no cooldown | Ship (Space Rocks) |
| `music_ramping` | Rule | Loop sound with pitch scaling based on group count | Space Rocks |
| `ring_spawner` | Flow | Spawn child entities in a ring around parent on _ready | UFO shields (Asterout) |
| `health_color` (optional) | Component | Change parent draw color based on Health HP | Rock Breaker space_rocks |

### Modified Components (3)

| Component | Change |
|-----------|--------|
| `universal_body` | `action`/`end_action` signals now pass InputEvent argument |
| `timer` | Add `adjust_on_loop` export — adds/subtracts from wait_time each loop |
| Any component listening to `action`/`end_action` | Accept new InputEvent parameter |

### New Scenes

| Scene | Type | Purpose |
|-------|------|---------|
| `Scenes/Effects/death_effect_particles.tscn` | Effect | Particle burst (white dots) |
| `Scenes/Effects/death_effect_ship_debris.tscn` | Effect | 6 floating line segments |
| `Scenes/Effects/engine_flame.tscn` | Effect | Thrust flame triangle (show/hide on thrust signal) |
| `paddle_ballout.tscn` | Game | Paddle Ballout remix |
| `asterout.tscn` | Game | Asterout remix |
| `rock_breaker.tscn` | Game | Rock Breaker remix |

### New Folder

```
Godot/Scenes/Effects/   ← One-off self-destructing visual effect scenes
```

### No Game Scripts

All games (space_rocks updated + 3 new remixes) run as pure UGS scene assemblies. Zero new `.gd` files in `Scripts/Games/`.

---

## Implementation Order

### Phase A: Input Refactor
1. Update `universal_body.gd` — `action`/`end_action` signals pass InputEvent
2. Update any existing components that listen to `action`/`end_action` to accept the new parameter
3. Verify existing games still work

### Phase B: Death Effects + Engine Flame
1. Build `death_effect.gd` (Component) — spawn effect scenes on zero_health
2. Build `Scenes/Effects/death_effect_particles.tscn` — particle burst (white dots flying outward)
3. Build `Scenes/Effects/death_effect_ship_debris.tscn` — 6 line segments floating away at staggered intervals
4. Build `Scenes/Effects/engine_flame.tscn` — small triangle that shows on `thrust`, hides on `end_thrust`
5. Add DeathEffect to asteroid scene (particles only)
6. Add DeathEffect to ship (particles + ship debris)
7. Add EngineFlame to triangle_ship scenes

### Phase C: UFO + Polish Components
1. Build `patrol_ai.gd` (Brain) — Curve2D path following + random path generation
2. Build `space_rocks_warp.gd` (Leg) — teleport on button_3 with intangibility
3. Build `music_ramping.gd` (Rule) — looping sound with pitch scaling on group count
4. Assemble UFO scene (`ufo.tscn`) — PatrolAI + DirectMovement + AimAI + GunSimple + Health + ScoreOnDeath + DieOnHit + DamageOnHit + DeathEffect + ScreenWrap + SoundOnHit
5. Update `space_rocks.tscn` — add UFO timer/WaveDirector/WaveSpawner, warp on ship, MusicRamping
6. Test full Space Rocks

### Phase D: Paddle Ballout
1. Assemble `paddle_ballout.tscn` — paddles, ball with DamageOnHit, two brick grids, Goals, PointsMonitor, VariableTuner
2. Test Paddle Ballout

### Phase E: Asterout
1. Build `ring_spawner.gd` (Flow) — spawn child entities in a ring around parent on _ready
2. Assemble `asterout.tscn` — triangle ship with modern controls, UFO spawner with RingSpawner for shield bricks
3. Test Asterout

### Phase F: Rock Breaker
1. Assemble `rock_breaker.tscn` — paddle, ball, asteroid grid with health/split, bottom Goal
2. Test Rock Breaker

---

## Success Criteria

- [ ] `action`/`end_action` signals pass InputEvent — components can filter by action name
- [ ] Existing games unaffected by input refactor
- [ ] Space Rocks explode with particle burst effect
- [ ] Ship explodes with particle burst + floating debris lines
- [ ] UFO has LARGE/SMALL size variants with different speed, accuracy, score
- [ ] Large UFOs spawn frequently early, taper off; small UFOs ramp up over time
- [ ] At most one UFO on screen at a time (safe zone check)
- [ ] Timer adjust_on_loop works — wait_time changes each cycle
- [ ] Ship can warp (button_3) — teleports with random death chance (25%), no cooldown
- [ ] Reactive music speeds up as asteroid count decreases
- [ ] Paddle Ballout is playable — bricks shield goals, one goal ends the game
- [ ] RingSpawner spawns brick children in a ring around UFO body
- [ ] Asterout is playable — modern controls, UFO dogfighting with brick shields
- [ ] Rock Breaker is playable — paddle + ball vs asteroid grid
- [ ] All games are pure UGS scene assemblies, zero game scripts

---

## Open Questions

- **Asterout brick placement:** ✅ Decided — bricks childed to UFO as shield ring (4×4 px), moves with parent.
- **Rock Breaker asteroid coloring:** Size-based health (existing) or color-based (new health_color component)? Recommend size-based.
- **UFO spawn frequency in Space Rocks:** ~15-20 seconds via Timer?
- **Paddle Ballout AI scaling:** Per-brick or per-group-cleared? Recommend per-group-cleared.
- **Asterout wave structure:** Endless waves with Timer, or fixed number of UFOs per round?
- **MusicRamping initial count:** Captured on _ready, or set via export? Recommend captured on _ready.
- **Warp safe landing:** Should warp avoid spawning on space_rocks? Optional enhancement.
- **Death effect scenes:** Should these be Node2D scripts with `_draw()` and `_physics_process`, or use GPUParticles2D? Recommend `_draw()` for consistency with the project's vector art style.