# Componentized Brick Breaker, Space Rocks, and Meteor Rally

**Created:** 2026-04-16
**Scope:** Eliminate `brick_breaker.gd`, `space_rocks.gd`, and `meteor_rally.gd`. Revert all three to pure `UniversalGameScript` scene assemblies.
**Out of Scope:** Attract modes, AI swap mechanics. Press button → play → win/lose.

---

## Component Inventory: What We Have

After Component Paddle Ball, the following game-level components exist and are proven:

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
| `angled_deflector` | Component | Paddle Ball-style bounce on body_collided + group filter |
| `paddle_ball_acceleration` | Component | Speed ramp on body_collided + group filter |
| `collision_marker` | Component | Collision group data for non-Body nodes |

---

## New Components Needed

These components fill gaps identified across all three games. Ordered by how many games use them.

### 1. `DamageOnHit` — Component (used by Brick Breaker + Space Rocks + Meteor Rally)

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

**Brick Breaker use:** On ball, targets "bricks"
**Space Rocks use:** On player, listens to GunSimple's "target_hit", targets "space_rocks"
**Meteor Rally use:** On ball, targets "space_rocks"

**Design note:** For Space Rocks, the gun emits `target_hit(target: Node2D)` not `body_collided(collider, normal)`. The signal arg format differs. Solution: export the signal name and use a generic callback that checks the first arg for `has_node("Health")`. The `target_group` filter handles the rest.

### 2. `ScoreOnDeath` — Rule (used by Brick Breaker + Space Rocks) + `SplitOnDeath` enhancement


## ScoreOnDeath — New Component (entity-attached)

```
Scripts/Components/score_on_death.gd — extends UniversalComponent
```

- [ ] **Create script** extending UniversalComponent
- [ ] **Exports:**
  - `base_score: int = 1`
  - `score_type: CommonEnums.ScoreType = GENERIC_SCORE`
- [ ] **`_ready()`:** Find ancestor UGS via `UniversalGameScript.find_ancestor(self)`, connect to sibling `Health.zero_health`
- [ ] **`_on_zero_health(_parent)`:** Compute `points = base_score * game.current_multiplier`, call `game.add_score(points)` (or the appropriate score method based on `score_type`)
- [ ] **Add to asteroid.tscn** as sibling to Health — `base_score = 1` (LARGE space_rocks start at 1)
- [ ] **Add to brick.tscn** as sibling to Health — `base_score = 1`

**Timing is confirmed safe.** Looking at `health.gd` lines 19-21:

```gdscript
zero_health.emit(parent)  # ← ScoreOnDeath runs to completion here
die()                      # ← disables components, then queue_free
```

`die()` doesn't run until all `zero_health` listeners finish. You're good.

---

## SplitOnDeath — Modify Existing (score propagation)

Currently at `Scripts/Components/split_on_death.gd` — already spawns fragments and decrements `initial_size`.

- [ ] **Add exports:**
  - `score_adjustment: int = 1` — how much to change child's ScoreOnDeath.base_score
  - `score_adjustment_mode: CommonEnums.AdjustmentMode = ADD` — SET or ADD
- [ ] **In `_on_parent_died()`, after spawning each fragment** (before `add_child`):
  - Check if fragment has a `ScoreOnDeath` child node
  - If yes, read its `base_score` and apply adjustment:
    - ADD: `fragment_score.base_score = parent_score.base_score + score_adjustment`
    - SET: `fragment_score.base_score = score_adjustment`
    - MULTIPLY: `fragment_score.base_score = parent_score.base_score * score_adjustment`
  - This works because properties are set **before** `add_child()`, so before the child's `_ready()` fires
- [ ] **Configure on asteroid's SplitOnDeath:** `score_adjustment = 1`, mode = ADD
  - LARGE (score=1) → spawns MEDIUM (score=2) → spawns SMALL (score=3)

---

## How it flows for Space Rocks

```
LARGE asteroid dies (ScoreOnDeath.base_score = 1)
  → Health.zero_health fires
    → ScoreOnDeath: awards 1 × multiplier ✓
    → SplitOnDeath: spawns 2 fragments
      → reads parent ScoreOnDeath.base_score (1)
      → ADD +1 to each fragment's ScoreOnDeath.base_score → 2
      → add_child (MEDIUM space_rocks, score = 2)

MEDIUM asteroid dies (ScoreOnDeath.base_score = 2)
  → awards 2 × multiplier ✓
  → splits → child ScoreOnDeath.base_score = 3

SMALL asteroid dies (ScoreOnDeath.base_score = 3)
  → awards 3 × multiplier ✓
  → no split (initial_size = 0, already handled)
```



### 3. `LifeLossZone` — Rule (used by Brick Breaker)

**Problem:** Ball enters Floor Area2D → lose a life. Currently `_on_floor_body_entered` in brick_breaker.gd.
**Solution:** Like Goal but for lives. Area2D component that calls `game.lives_counter.lose_life()` on body_entered.

```
Exports: (none beyond inherited)

Behavior:
- _ready(): parent.body_entered.connect(_on_body_entered)
- On body_entered: game.get_node("LivesCounter").lose_life()
```

**Brick Breaker use:** On Floor Area2D

### 4. `ScoreOnHit` - Component

combination of score on death and my existing _on_hit components

### 5. `BallServer` — Flow (used by Brick Breaker)

NOPE this is handled with spawners

### 6. `Respawner` — Flow (used by Space Rocks)

NOPE this is handled with spawners

### 7. `GroupCountMultiplier` — Rule (used by Space Rocks)

**Problem:** Multiplier = asteroid count, updated every frame. Currently in space_rocks.gd `_physics_process`.
**Solution:** Component that sets game multiplier to the count of a group each frame.

```
Exports:
- target_group: String

Behavior:
- _physics_process(): game.set_multiplier(get_tree().get_nodes_in_group(target_group).size())
```

**Space Rocks use:** target_group = "space_rocks"

### 8. `GroupLifeLoss` — Rule (used by Space Rocks)

add `lose_life_on_clear: bool` (and logic) to existing GroupMonitor. Less code, more cohesive. **Recommend extending GroupMonitor

---

## Component Brick Breaker — Implementation Checklist

**Delete:** `Scripts/Games/brick_breaker.gd`
**Revert scene:** Root node → `UniversalGameScript` with no script

### Scene Assembly

Root: `UniversalGameScript`
- collision_groups: walls→[balls], balls→[walls,paddles,bricks], paddles→[balls], bricks→[balls], floors→[balls]

**Entities (existing, move to UGS children):**
- [ ] Paddle (PlayerControl + DirectMovement + AngledDeflector) — paddle already has these
- [ ] Ball (Paddle BallAcceleration + AngledDeflector + **DamageOnHit** targeting "bricks")
- [ ] Walls (StaticBody2D + CollisionMarker "walls")
- [ ] Floor (Area2D + CollisionMarker "floors" + **LifeLossZone**)
- [ ] Bricks — spawned by WaveSpawner or GridSpawner

**Rules:**
- [ ] LivesCounter (existing, 3 lives)
- [ ] GroupMonitor (target = "bricks", victory on clear)
- [ ] PointsMonitor (GENERIC_SCORE ≥ max, result = DEFEAT... actually Brick Breaker doesn't have a defeat score threshold. Defeat = lives_depleted)
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
- [ ] Verify ball.gd doesn't need `accelerator.reset()` or `custom_bounce()` — these were removed during Component Paddle Ball? Check current state.

### Brick Spawning

The grid spawn with per-row health is the trickiest part. Options:

**Option A: Implement GRID in WaveSpawner** — Use the existing stubbed `SpawnPattern.GRID` with the grid_* exports. Per-row health: add a `row_health_equation: String` export like `"5 - row"` parsed at spawn time. Cleanest integration.

**Option B: Row-based health in brick.gd** — Brick determines its own max_health based on y-position. Simple but couples brick to game layout. `max_health = max(5 - floor((position.y - 40) / 11), 1)` or similar.

**Option C: New BrickGridSpawner component** — Purpose-built for Brick Breaker. Most explicit but least reusable.

**Recommendation:** Option A (implement GRID in WaveSpawner with row health equation).

### Brick Breaker Signal Flow

```
GAME START:
  UGS.start_game() → on_game_start
    → WaveSpawner spawns brick grid
    → BallServer serves ball from (320, 304)

GAMEPLAY:
  Ball physics → hits paddle (body_collided)
    → AngledDeflector deflects
    → Paddle BallAcceleration ramps speed
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

## Component Space Rocks — Implementation Checklist

**Delete:** `Scripts/Games/space_rocks.gd`
**Revert scene:** Root node → `UniversalGameScript` with no script

### Scene Assembly

Root: `UniversalGameScript`
- collision_groups: space_rocks→[space_rocks,ships], ships→[space_rocks,bullets], bullets→[ships,space_rocks]

**Entities:**
- [ ] Player ship (TriangleShip) — needs to be spawned by Respawner, not pre-placed in scene
- [ ] OR: keep Player in scene, let Respawner recreate it on death

**Components on Player:**
- [ ] GunSimple (ammo = bullet_simple)
- [ ] ScreenWrap
- [ ] PlayerControl
- [ ] Control scheme Legs (pick one, or make selectable)
- [ ] **DamageOnHit** (listening to GunSimple.target_hit, targeting "space_rocks")

**Rules:**
- [ ] LivesCounter (existing, 3 lives)
- [ ] GroupMonitor (target = "space_rocks", **victory_on_clear** = true)
- [ ] Extend GroupMonitor: add `lose_life_on_clear: bool` for PlayerMonitor
  - GroupMonitor (target = "players", lose_life_on_clear = true)
- [ ] **ScoreOnDeath** (target_group = "space_rocks", use_size_scoring = true)
- [ ] **GroupCountMultiplier** (target_group = "space_rocks")

**Flow:**
- [ ] **Respawner** (watches "players" group, spawns ship with gun + screen_wrap + controls)
- [ ] WaveSpawner (SCREEN_EDGES pattern, initial velocity inward, count = "4 + wave_number")
- [ ] WaveDirector (trigger = GROUP_CLEARED, trigger_value = "space_rocks", wave_delay = 3.0)
- [ ] Interface (POINTS_MULTIPLIER mode)
- [ ] CRT + bloom

### Space Rocks Signal Flow

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
        → SplitOnDeath spawns smaller space_rocks
  Player collides with asteroid → body_collided
    → Asteroid reduces ship Health (in asteroid._physics_process)
    → Ship dies → queue_free → "players" group empties
      → GroupMonitor("players", lose_life_on_clear) → LivesCounter.lose_life()
        → lives_changed → Respawner spawns new ship (delay + safe zone)
        → lives_depleted → UGS.defeat()
  All space_rocks destroyed → GroupMonitor("space_rocks").group_cleared
    → WaveDirector → WaveSpawner spawns next wave
  Every frame: GroupCountMultiplier sets multiplier = asteroid count

WIN:
  Waves continue indefinitely — Space Rocks traditionally has no "win"
  BUT: if we want a win condition, could use PointsMonitor (GENERIC_SCORE ≥ threshold)
  OR: WaveDirector with max_waves → after N waves cleared, emit victory

LOSE:
  Lives depleted → UGS.defeat()
```

### Open Design Questions (Space Rocks)

1. **Control scheme:** Original vs Modern. For no-attract-mode, simplest approach: pick one and hardcode. If both are desired, could use a lobby screen or key listener component.
2. **Win condition:** Space Rocks is endless. Options: (a) no win condition, pure survival, (b) WaveDirector max_waves → PointsMonitor, (c) PointsMonitor with score threshold.
3. **Safe zone:** The safe zone check (no space_rocks near center before spawning ship) is complex async logic. Could simplify to just a fixed delay, or implement in Respawner.

---

## Component Meteor Rally — Implementation Checklist

**Delete:** `Scripts/Games/meteor_rally.gd`
**Scene:** Copy `paddle_ball.tscn` + add asteroid systems

### The Remix: Paddle Ball + Space Rocks

Meteor Rally should be assembled by:
1. **Copy `paddle_ball.tscn`** as the base
2. **Add WaveSpawner** for space_rocks (SCREEN_EDGES, initial velocity inward)
3. **Add WaveDirector** for periodic asteroid spawning (or timer-based)
4. **Add "space_rocks" collision group** to UGS collision_groups
5. **Add DamageOnHit** on ball targeting "space_rocks"
6. **Add AngledDeflector** to asteroid scene (or configure via PropertyOverride... but can't add child nodes via PropertyOverride — need to modify asteroid.tscn or have AngledDeflector already in it)

### The Problem with Asteroid Deflection

In current meteor_rally, each asteroid gets an AngledDeflector with `bias = (5, 1)` added dynamically. Since we can't add child nodes via PropertyOverrides, options:

**Option A:** Add AngledDeflector to `asteroid.tscn` with disabled-by-default and a flag to enable. Ugly.

**Option B:** Create `asteroid_meteor_rally.tscn` — a variant of asteroid with AngledDeflector. Cleanest separation.

**Option C:** Add AngledDeflector to base `asteroid.tscn` with a `deflection_enabled: bool` export. Other games just leave it disabled.

**Recommendation:** Option B — a variant scene. Remixes ARE the point of the architecture.

### Periodic Spawning

Meteor Rally spawns space_rocks every ~6 seconds, capped at 6 max. Options:

**Option A:** Add `max_alive: int` export to WaveSpawner — checks group count before spawning each entity. WaveDirector uses a Timer to trigger periodic waves.

**Option B:** New `PeriodicSpawner` component — combines timer + max count + spawn logic.

**Recommendation:** Option A (extend WaveSpawner with `max_alive`). Then use a Timer node + WaveDirector with TIMER_EXPIRED trigger.

### Meteor Rally Scene Assembly

Root: `UniversalGameScript` (copied from paddle_ball.tscn)
- collision_groups: walls→[balls], balls→[walls,paddles,space_rocks,goals], paddles→[balls], space_rocks→[balls,paddles,space_rocks], goals→[balls]

**From Paddle Ball (copy as-is):**
- [ ] Player paddle (PlayerControl + DirectMovement)
- [ ] Opponent paddle (InterceptorAi + DirectMovement + VariableTuner)
- [ ] Ball (AngledDeflector + Paddle BallAcceleration + ScreenCleanup + SoundOnHit)
- [ ] Goals (Goal + CollisionMarker + SoundOnHit)
- [ ] Walls (CollisionMarker)
- [ ] PointsMonitor × 2 (P1 ≥ 11 = victory, P2 ≥ 11 = defeat)
- [ ] GroupMonitor ("balls") → WaveDirector → Ball WaveSpawner
- [ ] Interface (P1_P2_SCORE mode)

**Asteroid additions:**
- [ ] **DamageOnHit** on ball (target_group = "space_rocks")
- [ ] WaveSpawner for space_rocks (SCREEN_EDGES, initial velocity, spawn_at_game_start, max_alive = 6)
- [ ] WaveDirector (TIMER_EXPIRED trigger) or periodic spawn mechanism
- [ ] Timer node (6-second interval, autostart, fires timer_expired)
- [ ] Use `asteroid_meteor_rally.tscn` variant with AngledDeflector (5,1)

---

## Implementation Order

### Phase A: Cross-Cutting Components (build first, all games need these)
- [ ] `DamageOnHit` — Component, used by all three games
- [ ] `ScoreOnDeath` — Rule, used by Brick Breaker + Space Rocks
- [ ] Extend `GroupMonitor` with `lose_life_on_clear: bool`
- [ ] Implement `GRID` spawn pattern in WaveSpawner (for Brick Breaker bricks)

### Phase B: Component Brick Breaker
- [ ] `LifeLossZone` — Rule
- [ ] `ScoreMultiplier` — Rule
- [ ] `BallServer` — Flow
- [ ] Assemble brick_breaker.tscn from UGS + components
- [ ] Test full game loop
- [ ] Delete `brick_breaker.gd`

### Phase C: Component Space Rocks
- [ ] `GroupCountMultiplier` — Rule
- [ ] `Respawner` — Flow (with safe zone support)
- [ ] Assemble space_rocks.tscn from UGS + components
- [ ] Test full game loop
- [ ] Delete `space_rocks.gd`

### Phase D: Component Meteor Rally (The Remix Test)
- [ ] Extend WaveSpawner with `max_alive: int`
- [ ] Create `asteroid_meteor_rally.tscn` variant with AngledDeflector
- [ ] Copy paddle_ball.tscn, add asteroid systems
- [ ] Test full game loop
- [ ] Delete `meteor_rally.gd`
- [ ] **Celebrate** — all four games running with zero game-specific scripts

---

## Summary: New Components

| Component | Category | Used By | Complexity |
|-----------|----------|---------|------------|
| `DamageOnHit` | Component | All three | Low |
| `ScoreOnDeath` | Rule | Brick Breaker, Space Rocks | Medium (auto-connect pattern) |
| `LifeLossZone` | Rule | Brick Breaker | Low |
| `ScoreMultiplier` | Rule | Brick Breaker | Medium (dual signal) |
| `BallServer` | Flow | Brick Breaker | Low |
| `GroupCountMultiplier` | Rule | Space Rocks | Low |
| `Respawner` | Flow | Space Rocks | High (safe zone, child components) |

**Extensions to existing:**
| Component | Change |
|-----------|--------|
| `GroupMonitor` | Add `lose_life_on_clear: bool` |
| `WaveSpawner` | Implement GRID pattern, add `max_alive: int` |

**New scene variants:**
| Scene | Purpose |
|-------|---------|
| `asteroid_meteor_rally.tscn` | Asteroid with AngledDeflector for Paddle Ball-style bouncing |

**Total new scripts:** 7 (if all proposed as separate components)
**Total extended scripts:** 2
**Total deleted scripts:** 3 (brick_breaker.gd, space_rocks.gd, meteor_rally.gd)