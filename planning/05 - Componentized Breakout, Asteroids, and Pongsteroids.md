# Componentized Breakout, Asteroids, and Pongsteroids

**Created:** 2026-04-16
**Scope:** Eliminate `breakout.gd`, `asteroids.gd`, and `pongsteroids.gd`. Revert all three to pure `UniversalGameScript` scene assemblies.
**Out of Scope:** Attract modes, AI swap mechanics. Press button → play → win/lose.

---

## Component Inventory: What We Have

After Component Pong, the following game-level components exist and are proven:

| Component | Category | Covers |
|-----------|----------|--------|
| `goal` | Rule | Area2D → score increment on body_entered |
| `points_monitor` | Rule | Score threshold → victory/defeat |
| `variable_tuner` | Rule | Signal → property adjustment on parent |
| `group_monitor` | Rule | Group empty → group_cleared, optional victory/defeat |
| `lives_counter` | Rule | Life tracking, lose_life(), lives_changed/lives_depleted |
| `wave_spawner` | Flow | Spawn entities in patterns, initial velocity, random angles |
| `wave_director` | Flow | Signal trigger → emit spawning_wave after delay |
| `sound_on_hit` | Flow | Play sound on collision (Area2D or UniversalBody) |
| `interface` | Flow | HUD with P1/P2 score or Points/Multiplier modes |
| `screen_cleanup` | Component | Free entity outside viewport |
| `angled_deflector` | Component | Pong-style bounce on body_collided + group filter |
| `pong_acceleration` | Component | Speed ramp on body_collided + group filter |
| `collision_marker` | Component | Collision group data for non-Body nodes |

---

## New Components Needed

These components fill gaps identified across all three games. Ordered by how many games use them.

### 1. `DamageOnHit` — Component (used by Breakout + Asteroids + Pongsteroids)

**Problem:** Ball/bullet hits a target with a Health component. Currently handled in game scripts.
**Solution:** Component that connects to `parent.body_collided` and/or an exportable signal, filters by `target_group`, calls `collider.get_node("Health").reduce_health(damage_amount)`.

```
Exports:
- target_group: String — only damage entities in this group
- damage_amount: int = 1
- listen_signal: String = "body_collided" — which parent signal to connect to

Behavior:
- _ready(): connect to parent[listen_signal]
- On collision: if collider.is_in_group(target_group) and collider.has_node("Health"):
    collider.get_node("Health").reduce_health(damage_amount)
```

**Breakout use:** On ball, targets "bricks"
**Asteroids use:** On player, listens to GunSimple's "target_hit", targets "asteroids"
**Pongsteroids use:** On ball, targets "asteroids"

**Design note:** For Asteroids, the gun emits `target_hit(target: Node2D)` not `body_collided(collider, normal)`. The signal arg format differs. Solution: export the signal name and use a generic callback that checks the first arg for `has_node("Health")`. The `target_group` filter handles the rest.

### 2. `ScoreOnDeath` — Rule (used by Breakout + Asteroids)

**Problem:** When an entity with Health dies, award score × multiplier. Currently handled per-game.
**Solution:** Component that listens to `get_tree().node_added`, auto-connects to `Health.zero_health` for matching groups, awards score on death.

```
Exports:
- target_group: String — which group to watch for deaths
- base_score: int = 1 — base points per kill
- use_size_scoring: bool = false — read asteroid.initial_size for score (Asteroids-specific)

Behavior:
- _ready(): connect get_tree().node_added
- On node_added matching group: connect Health.zero_health to _on_death
- On death: game.add_score(base_score * game.current_multiplier)
  If use_size_scoring: base_score = asteroid.initial_size + 1 (SMALL=1, MEDIUM=2, LARGE=3)
```

**Breakout use:** Watches "bricks", base_score = 1, awards score × multiplier
**Asteroids use:** Watches "asteroids", use_size_scoring = true, awards score × multiplier

### 3. `LifeLossZone` — Rule (used by Breakout)

**Problem:** Ball enters Floor Area2D → lose a life. Currently `_on_floor_body_entered` in breakout.gd.
**Solution:** Like Goal but for lives. Area2D component that calls `game.lives_counter.lose_life()` on body_entered.

```
Exports: (none beyond inherited)

Behavior:
- _ready(): parent.body_entered.connect(_on_body_entered)
- On body_entered: game.get_node("LivesCounter").lose_life()
```

**Breakout use:** On Floor Area2D

### 4. `ScoreMultiplier` — Rule (used by Breakout)

**Problem:** Multiplier increments on paddle hit, resets on life loss. Currently in breakout.gd.
**Solution:** Component that listens to a signal and increments game multiplier, with optional reset signal.

```
Exports:
- increment_source: Node — node whose signal triggers increment
- increment_signal: String — signal name for increment
- target_group: String = "" — only increment if signal arg is in this group
- increment_amount: int = 1
- reset_source: Node — node whose signal triggers reset
- reset_signal: String — signal name for reset
- reset_value: int = 1

Behavior:
- _ready(): connect both signals
- On increment signal: if target_group empty or arg in group: game.set_multiplier(game.current_multiplier + increment_amount)
- On reset signal: game.set_multiplier(reset_value)
```

**Breakout use:** increment on ball.body_collided (target_group = "paddles"), reset on game.lives_changed

### 5. `BallServer` — Flow (used by Breakout)

**Problem:** Reset ball position, wait, launch at angle. Currently `serve_ball()` in breakout.gd.
**Solution:** Component that resets and relaunches the parent ball when triggered by a signal.

```
Exports:
- serve_position: Vector2 = Vector2(320, 304)
- serve_angle_min: float = 5*PI/4
- serve_angle_max: float = 7*PI/4
- serve_speed: float = 150
- serve_delay: float = 1.0
- serve_on_game_start: bool = true
- serve_on_signal_node: NodePath — node whose signal triggers re-serve
- serve_on_signal: String — signal name

Behavior:
- _ready(): if serve_on_game_start: game.on_game_start.connect(_serve)
  Connect serve_on_signal from serve_on_signal_node
- _serve(): parent.position = serve_position, parent.velocity = ZERO, await delay, launch
```

**Breakout use:** serve_on_signal = game.lives_changed, position = (320, 304), upward angles

### 6. `Respawner` — Flow (used by Asteroids)

**Problem:** Ship dies → after delay + safe zone check → spawn new ship with components. Currently ~100 lines in asteroids.gd.
**Solution:** Component that watches a group, spawns from scene when group empties, with delay and safe zone check.

```
Exports:
- target_group: String — group to monitor
- spawn_scene: PackedScene — scene to instantiate
- respawn_delay: float = 3.0
- spawn_position: Vector2 = Vector2(320, 180)
- check_safe_zone: bool = false
- safe_zone_radius: float = 100.0
- child_components: Array[PackedScene] = [] — components to add to spawned entity
- max_respawns: int = 0 — 0 = unlimited

Behavior:
- _ready(): game.lives_changed.connect(_on_lives_changed) OR monitor group
- On group empty / lives_changed: if lives > 0 and not game_over:
    await respawn_delay
    if check_safe_zone: await _wait_for_safe_zone()
    instance = spawn_scene.instantiate()
    for comp in child_components: instance.add_child(comp.instantiate())
    game.add_child(instance)
```

**Asteroids use:** target_group = "players", spawn_scene = triangle_ship, child_components = [gun, screen_wrap, player_control, control_scheme], respawn_delay = 3.0, check_safe_zone = true

**Design question:** The control scheme selection (Original vs Modern) adds different Leg components. For a no-attract-mode scope, we could just pick one scheme and hardcode it. OR have a simple state-dependent setup. This is a design decision to make during implementation.

### 7. `GroupCountMultiplier` — Rule (used by Asteroids)

**Problem:** Multiplier = asteroid count, updated every frame. Currently in asteroids.gd `_physics_process`.
**Solution:** Component that sets game multiplier to the count of a group each frame.

```
Exports:
- target_group: String

Behavior:
- _physics_process(): game.set_multiplier(get_tree().get_nodes_in_group(target_group).size())
```

**Asteroids use:** target_group = "asteroids"

### 8. `GroupLifeLoss` — Rule (used by Asteroids)

**Problem:** When player ship dies (removed from "players" group), lose a life. Currently connected via `tree_exited`.
**Solution:** Component that watches a group and calls lose_life when it transitions from >0 to 0.

```
Exports:
- target_group: String

Behavior:
- _physics_process(): count nodes in group, if was >0 and now == 0: game.get_node("LivesCounter").lose_life()
```

**Asteroids use:** target_group = "players"

This is essentially a specialized GroupMonitor. Alternative: add `lose_life_on_clear: bool` to existing GroupMonitor. Less code, more cohesive. **Recommend extending GroupMonitor** rather than a new component.

---

## Component Breakout — Implementation Checklist

**Delete:** `Scripts/Games/breakout.gd`
**Revert scene:** Root node → `UniversalGameScript` with no script

### Scene Assembly

Root: `UniversalGameScript`
- collision_groups: walls→[balls], balls→[walls,paddles,bricks], paddles→[balls], bricks→[balls], floors→[balls]

**Entities (existing, move to UGS children):**
- [ ] Paddle (PlayerControl + DirectMovement + AngledDeflector) — paddle already has these
- [ ] Ball (PongAcceleration + AngledDeflector + **DamageOnHit** targeting "bricks")
- [ ] Walls (StaticBody2D + CollisionMarker "walls")
- [ ] Floor (Area2D + CollisionMarker "floors" + **LifeLossZone**)
- [ ] Bricks — spawned by WaveSpawner or GridSpawner

**Rules:**
- [ ] LivesCounter (existing, 3 lives)
- [ ] GroupMonitor (target = "bricks", victory on clear)
- [ ] PointsMonitor (GENERIC_SCORE ≥ max, result = DEFEAT... actually Breakout doesn't have a defeat score threshold. Defeat = lives_depleted)
- [ ] **ScoreOnDeath** (target_group = "bricks", base_score = 1)
- [ ] **ScoreMultiplier** (increment on paddle hit, reset on life loss)
- [ ] **LifeLossZone** (on Floor)

**Flow:**
- [ ] **BallServer** (on Floor body_entered → re-serve after delay)
- [ ] **WaveSpawner** or grid spawner (spawn bricks on game_start)
- [ ] SoundOnHit (on Floor, play death sound)
- [ ] Interface (POINTS_MULTIPLIER mode)
- [ ] CRT + bloom

**Ball script cleanup:**
- [ ] Verify ball.gd doesn't need `accelerator.reset()` or `custom_bounce()` — these were removed during Component Pong? Check current state.

### Brick Spawning

The grid spawn with per-row health is the trickiest part. Options:

**Option A: Implement GRID in WaveSpawner** — Use the existing stubbed `SpawnPattern.GRID` with the grid_* exports. Per-row health: add a `row_health_equation: String` export like `"5 - row"` parsed at spawn time. Cleanest integration.

**Option B: Row-based health in brick.gd** — Brick determines its own max_health based on y-position. Simple but couples brick to game layout. `max_health = max(5 - floor((position.y - 40) / 11), 1)` or similar.

**Option C: New BrickGridSpawner component** — Purpose-built for Breakout. Most explicit but least reusable.

**Recommendation:** Option A (implement GRID in WaveSpawner with row health equation).

### Breakout Signal Flow

```
GAME START:
  UGS.start_game() → on_game_start
    → WaveSpawner spawns brick grid
    → BallServer serves ball from (320, 304)

GAMEPLAY:
  Ball physics → hits paddle (body_collided)
    → AngledDeflector deflects
    → PongAcceleration ramps speed
    → ScoreMultiplier increments
  Ball physics → hits brick (body_collided)
    → DamageOnHit reduces brick Health
    → Brick Health.zero_health
      → ScoreOnDeath awards score × multiplier
  Ball physics → hits wall → bounce (auto)
  Ball enters Floor Area2D
    → LifeLossZone → LivesCounter.lose_life()
      → lives_changed
        → ScoreMultiplier resets to 1
        → BallServer re-serves ball
      → lives_depleted → UGS.defeat()

WIN:
  All bricks destroyed → GroupMonitor("bricks").group_cleared
    → PointsMonitor not needed; GroupMonitor.victory_on_clear = true
    → UGS.victory()

LOSE:
  LivesCounter hits 0 → lives_depleted → UGS.defeat()
```

---

## Component Asteroids — Implementation Checklist

**Delete:** `Scripts/Games/asteroids.gd`
**Revert scene:** Root node → `UniversalGameScript` with no script

### Scene Assembly

Root: `UniversalGameScript`
- collision_groups: asteroids→[asteroids,ships], ships→[asteroids,bullets], bullets→[ships,asteroids]

**Entities:**
- [ ] Player ship (TriangleShip) — needs to be spawned by Respawner, not pre-placed in scene
- [ ] OR: keep Player in scene, let Respawner recreate it on death

**Components on Player:**
- [ ] GunSimple (ammo = bullet_simple)
- [ ] ScreenWrap
- [ ] PlayerControl
- [ ] Control scheme Legs (pick one, or make selectable)
- [ ] **DamageOnHit** (listening to GunSimple.target_hit, targeting "asteroids")

**Rules:**
- [ ] LivesCounter (existing, 3 lives)
- [ ] GroupMonitor (target = "asteroids", **victory_on_clear** = true)
- [ ] Extend GroupMonitor: add `lose_life_on_clear: bool` for PlayerMonitor
  - GroupMonitor (target = "players", lose_life_on_clear = true)
- [ ] **ScoreOnDeath** (target_group = "asteroids", use_size_scoring = true)
- [ ] **GroupCountMultiplier** (target_group = "asteroids")

**Flow:**
- [ ] **Respawner** (watches "players" group, spawns ship with gun + screen_wrap + controls)
- [ ] WaveSpawner (SCREEN_EDGES pattern, initial velocity inward, count = "4 + wave_number")
- [ ] WaveDirector (trigger = GROUP_CLEARED, trigger_value = "asteroids", wave_delay = 3.0)
- [ ] Interface (POINTS_MULTIPLIER mode)
- [ ] CRT + bloom

### Asteroids Signal Flow

```
GAME START:
  UGS.start_game() → on_game_start
    → WaveSpawner spawns initial asteroid wave
    → Respawner spawns player ship at center

GAMEPLAY:
  Player shoots → GunSimple fires bullet
    → Bullet hits asteroid → GunSimple.target_hit
      → DamageOnHit → asteroid.Health.reduce_health(1)
        → Health.zero_health → ScoreOnDeath awards (size+1) × multiplier
        → SplitOnDeath spawns smaller asteroids
  Player collides with asteroid → body_collided
    → Asteroid reduces ship Health (in asteroid._physics_process)
    → Ship dies → queue_free → "players" group empties
      → GroupMonitor("players", lose_life_on_clear) → LivesCounter.lose_life()
        → lives_changed → Respawner spawns new ship (delay + safe zone)
        → lives_depleted → UGS.defeat()
  All asteroids destroyed → GroupMonitor("asteroids").group_cleared
    → WaveDirector → WaveSpawner spawns next wave
  Every frame: GroupCountMultiplier sets multiplier = asteroid count

WIN:
  Waves continue indefinitely — Asteroids traditionally has no "win"
  BUT: if we want a win condition, could use PointsMonitor (GENERIC_SCORE ≥ threshold)
  OR: WaveDirector with max_waves → after N waves cleared, emit victory

LOSE:
  Lives depleted → UGS.defeat()
```

### Open Design Questions (Asteroids)

1. **Control scheme:** Original vs Modern. For no-attract-mode, simplest approach: pick one and hardcode. If both are desired, could use a lobby screen or key listener component.
2. **Win condition:** Asteroids is endless. Options: (a) no win condition, pure survival, (b) WaveDirector max_waves → PointsMonitor, (c) PointsMonitor with score threshold.
3. **Safe zone:** The safe zone check (no asteroids near center before spawning ship) is complex async logic. Could simplify to just a fixed delay, or implement in Respawner.

---

## Component Pongsteroids — Implementation Checklist

**Delete:** `Scripts/Games/pongsteroids.gd`
**Scene:** Copy `pong.tscn` + add asteroid systems

### The Remix: Pong + Asteroids

Pongsteroids should be assembled by:
1. **Copy `pong.tscn`** as the base
2. **Add WaveSpawner** for asteroids (SCREEN_EDGES, initial velocity inward)
3. **Add WaveDirector** for periodic asteroid spawning (or timer-based)
4. **Add "asteroids" collision group** to UGS collision_groups
5. **Add DamageOnHit** on ball targeting "asteroids"
6. **Add AngledDeflector** to asteroid scene (or configure via PropertyOverride... but can't add child nodes via PropertyOverride — need to modify asteroid.tscn or have AngledDeflector already in it)

### The Problem with Asteroid Deflection

In current pongsteroids, each asteroid gets an AngledDeflector with `bias = (5, 1)` added dynamically. Since we can't add child nodes via PropertyOverrides, options:

**Option A:** Add AngledDeflector to `asteroid.tscn` with disabled-by-default and a flag to enable. Ugly.

**Option B:** Create `asteroid_pongsteroids.tscn` — a variant of asteroid with AngledDeflector. Cleanest separation.

**Option C:** Add AngledDeflector to base `asteroid.tscn` with a `deflection_enabled: bool` export. Other games just leave it disabled.

**Recommendation:** Option B — a variant scene. Remixes ARE the point of the architecture.

### Periodic Spawning

Pongsteroids spawns asteroids every ~6 seconds, capped at 6 max. Options:

**Option A:** Add `max_alive: int` export to WaveSpawner — checks group count before spawning each entity. WaveDirector uses a Timer to trigger periodic waves.

**Option B:** New `PeriodicSpawner` component — combines timer + max count + spawn logic.

**Recommendation:** Option A (extend WaveSpawner with `max_alive`). Then use a Timer node + WaveDirector with TIMER_EXPIRED trigger.

### Pongsteroids Scene Assembly

Root: `UniversalGameScript` (copied from pong.tscn)
- collision_groups: walls→[balls], balls→[walls,paddles,asteroids,goals], paddles→[balls], asteroids→[balls,paddles,asteroids], goals→[balls]

**From Pong (copy as-is):**
- [ ] Player paddle (PlayerControl + DirectMovement)
- [ ] Opponent paddle (InterceptorAi + DirectMovement + VariableTuner)
- [ ] Ball (AngledDeflector + PongAcceleration + ScreenCleanup + SoundOnHit)
- [ ] Goals (Goal + CollisionMarker + SoundOnHit)
- [ ] Walls (CollisionMarker)
- [ ] PointsMonitor × 2 (P1 ≥ 11 = victory, P2 ≥ 11 = defeat)
- [ ] GroupMonitor ("balls") → WaveDirector → Ball WaveSpawner
- [ ] Interface (P1_P2_SCORE mode)

**Asteroid additions:**
- [ ] **DamageOnHit** on ball (target_group = "asteroids")
- [ ] WaveSpawner for asteroids (SCREEN_EDGES, initial velocity, spawn_at_game_start, max_alive = 6)
- [ ] WaveDirector (TIMER_EXPIRED trigger) or periodic spawn mechanism
- [ ] Timer node (6-second interval, autostart, fires timer_expired)
- [ ] Use `asteroid_pongsteroids.tscn` variant with AngledDeflector (5,1)

---

## Implementation Order

### Phase A: Cross-Cutting Components (build first, all games need these)
- [ ] `DamageOnHit` — Component, used by all three games
- [ ] `ScoreOnDeath` — Rule, used by Breakout + Asteroids
- [ ] Extend `GroupMonitor` with `lose_life_on_clear: bool`
- [ ] Implement `GRID` spawn pattern in WaveSpawner (for Breakout bricks)

### Phase B: Component Breakout
- [ ] `LifeLossZone` — Rule
- [ ] `ScoreMultiplier` — Rule
- [ ] `BallServer` — Flow
- [ ] Assemble breakout.tscn from UGS + components
- [ ] Test full game loop
- [ ] Delete `breakout.gd`

### Phase C: Component Asteroids
- [ ] `GroupCountMultiplier` — Rule
- [ ] `Respawner` — Flow (with safe zone support)
- [ ] Assemble asteroids.tscn from UGS + components
- [ ] Test full game loop
- [ ] Delete `asteroids.gd`

### Phase D: Component Pongsteroids (The Remix Test)
- [ ] Extend WaveSpawner with `max_alive: int`
- [ ] Create `asteroid_pongsteroids.tscn` variant with AngledDeflector
- [ ] Copy pong.tscn, add asteroid systems
- [ ] Test full game loop
- [ ] Delete `pongsteroids.gd`
- [ ] **Celebrate** — all four games running with zero game-specific scripts

---

## Summary: New Components

| Component | Category | Used By | Complexity |
|-----------|----------|---------|------------|
| `DamageOnHit` | Component | All three | Low |
| `ScoreOnDeath` | Rule | Breakout, Asteroids | Medium (auto-connect pattern) |
| `LifeLossZone` | Rule | Breakout | Low |
| `ScoreMultiplier` | Rule | Breakout | Medium (dual signal) |
| `BallServer` | Flow | Breakout | Low |
| `GroupCountMultiplier` | Rule | Asteroids | Low |
| `Respawner` | Flow | Asteroids | High (safe zone, child components) |

**Extensions to existing:**
| Component | Change |
|-----------|--------|
| `GroupMonitor` | Add `lose_life_on_clear: bool` |
| `WaveSpawner` | Implement GRID pattern, add `max_alive: int` |

**New scene variants:**
| Scene | Purpose |
|-------|---------|
| `asteroid_pongsteroids.tscn` | Asteroid with AngledDeflector for Pong-style bouncing |

**Total new scripts:** 7 (if all proposed as separate components)
**Total extended scripts:** 2
**Total deleted scripts:** 3 (breakout.gd, asteroids.gd, pongsteroids.gd)