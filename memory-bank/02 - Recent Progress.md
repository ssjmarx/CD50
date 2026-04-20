# Recent Progress: GD50 — Development History

**Last Updated:** 2026-04-20

---

## Update 1: Project Foundation & Architecture Design

**Planning Document:** `planning/00 - overview.txt`

### What Was Planned
- A commercial collection of 10 classic arcade remakes with a modular "composable" architecture
- A "Solar System" hub — a 2D top-down view with the Sun at center, 10 planets orbiting (each representing a game), moons for game variants, and a "Cute Goth Witch" player avatar on a broomstick
- An Entity-Component approach with base `Actor.gd`, modular component scripts, and global autoload singletons (`GameRegistry`, `AssetManager`, `EntityFactory`)
- 10 base games: Pong, Breakout, Defender, Galaga, Frogger, Donkey Kong, Missile Command, Asteroids, Tetris, and one more

### What Was Actually Built
- The **core architecture** was established with a different naming convention than originally planned:
  - `Actor.gd` became `universal_body.gd` — a `CharacterBody2D` base class that provides a signal API (`move`, `shoot`, `aim`, `death`) and vector drawing capabilities
  - Components are organized into categories: **Brains** (input/AI), **Legs** (movement), **Arms** (weapons), **Components** (gameplay modifiers), **Rules** (game logic), **Flow** (UI/spawning)
  - The `EntityFactory` and `GameRegistry` singletons were **not** built; game scenes manage their own entity spawning
- **Kenney asset packs** (audio + fonts) were integrated
- A **CRT post-processing addon** was added for retro visual effects
- The Solar System hub was **not built** — games are launched directly

### Key Decisions
- Chose composition over inheritance: bodies are generic containers, behavior comes entirely from attached components
- Used Godot's group system for collision filtering (e.g., "paddles", "balls", "asteroids", "bricks")
- Vector graphics drawn via `_draw()` on `UniversalBody` rather than sprite assets (keeping a "code-first" visual approach)

---

## Update 2: Pong & Breakout

**Planning Document:** `planning/01 - Pong and Breakout.md`

### What Was Planned
- Pong: Two paddles, one ball, scoring walls, attract mode, AI opponent
- Breakout: Player paddle, ball, grid of breakable bricks with health, lives system, win condition
- Shared components between both games (paddle movement, ball physics, wall collisions)

### What Was Actually Built

**Pong** (`Games/pong.tscn` + `Scripts/Games/pong.gd`):
- Full Pong game with two paddles and a ball
- Game states: ATTRACT → PLAYING → GAME_OVER
- Player paddle uses **PlayerControl** (keyboard input) or **InterceptorAi** (AI tracking)
- AI paddle uses **InterceptorAi** with configurable `turning_speed`
- Ball has **PongAcceleration** (speeds up on paddle hits) and **AngledDeflector** on paddles creates angle-based bounces
- Goals (Area2D) at left/right edges trigger scoring
- **CollisionMarker** components on walls/goals play sounds on hit
- CRT visual effect overlay
- Interface component for score display and game state text

**Breakout** (`Games/breakout.tscn` + `Scripts/Games/breakout.gd`):
- Full Breakout game with paddle, ball, and brick grid
- Paddle uses **InterceptorAi** + **DirectMovement** + **AngledDeflector**
- Ball uses **PongAcceleration** (inherited from ball.tscn)
- Bricks are `Brick` bodies with **Health** components — color changes based on remaining HP
- **GroupMonitor** tracks "bricks" group — emits `group_cleared` when all bricks destroyed (win condition)
- **LivesCounter** tracks player lives — ball hitting the floor (Area2D) costs a life
- Floor detected via **CollisionMarker** on an Area2D
- Interface with attract text overlay

### Components Established
| Component | Category | Used In |
|-----------|----------|---------|
| `player_control` | Brain | Pong (P1 paddle) |
| `interceptor_ai` | Brain | Pong (P2 paddle), Breakout (paddle) |
| `direct_movement` | Leg | Pong paddles, Breakout paddle |
| `angled_deflector` | Component | Pong paddles, Breakout paddle |
| `pong_acceleration` | Component | Ball (Pong, Breakout) |
| `collision_marker` | Component | Walls, goals, floor |
| `health` | Component | Bricks |
| `group_monitor` | Rule | Breakout (brick count) |
| `lives_counter` | Rule | Breakout |
| `interface` | Flow | Pong, Breakout |

---

## Update 3: Asteroids & Pongsteroids

**Planning Document:** `planning/02 - Asteroids and Pongsteroids.md`

### What Was Planned
- Asteroids: 360-degree ship movement, shooting, screen wrapping, asteroid splitting (big → medium → small)
- Pongsteroids: A hybrid game combining Pong elements (paddles, goals, ball) with Asteroids elements (asteroids floating in the field)
- New components: ScreenWrap, EngineSimple, GunSimple, SplitOnDeath, AimAi, RotationTarget

### What Was Actually Built

**Asteroids** (`Games/asteroids.tscn` + `Scripts/Games/asteroids.gd`):
- Player ship (`TriangleShip`) with vector-drawn triangle shape
- **ScreenWrap** component — ship and asteroids wrap around screen edges
- **GunSimple** component — fires bullets when `shoot` signal received
- **AimAi** + **RotationTarget** — ship aims toward nearest asteroid and rotates smoothly
- Asteroids (`Asteroid` body) with:
  - Random polygon generation for organic shapes
  - **Health** component — takes damage from bullets
  - **SplitOnDeath** component — spawns smaller asteroids on destruction
  - **ScreenWrap** component
  - HitBox/HurtBox pattern for damage detection
- **GroupMonitor** × 2: one for "asteroids" (win condition), one for player (death tracking)
- **LivesCounter** for player lives
- Wave-based spawning via the game script

**Pongsteroids** (`Games/pongsteroids.tscn` + `Scripts/Games/pongsteroids.gd`):
- Hybrid game: Pong field with paddles, ball, goals **PLUS** asteroids floating in the playfield
- Reuses exact same paddle setup as Pong (AngledDeflector + InterceptorAi + DirectMovement)
- Reuses ball with PongAcceleration
- Reuses CollisionMarker on walls and goals
- Asteroids coexist with the Pong ball — both games' physics interact
- This was the **key validation** of the component architecture: mixing elements from two different games required zero new components, just scene assembly

### New Components Added
| Component | Category | Purpose |
|-----------|----------|---------|
| `screen_wrap` | Component | Wrap position at screen edges |
| `split_on_death` | Component | Spawn smaller entities on death |
| `engine_simple` | Leg | Asteroids-style thrust movement |
| `engine_complex` | Leg | Advanced thrust with drag |
| `friction_linear` | Leg | Gradual velocity reduction |
| `friction_static` | Leg | Stop below velocity threshold |
| `rotation_direct` | Leg | Instant rotation to aim target |
| `rotation_target` | Leg | Smooth rotation toward aim target |
| `aim_ai` | Brain | Auto-aim toward target group |
| `gun_simple` | Arm | Fire bullet projectiles |
| `health` | Component | HP tracking + damage from groups |

### New Bodies Added
| Body | Purpose |
|------|---------|
| `triangle_ship` | Player ship (Asteroids) |
| `asteroid` | Destructible space rock |
| `ufo` | Enemy body (scene exists, not yet used in a game) |
| `bullet_simple` | Standard projectile |
| `bullet_wrapping` | Screen-wrapping projectile |

### Architecture Validation
Pongsteroids proved that the component model works for cross-game mixing. No new scripts were needed — the hybrid was assembled entirely from existing components in a new scene file.

---

## Update 4: Componentized Hub (Planning Only)

**Planning Document:** `planning/03 - Componentized Hub.md`

### What Was Planned
- Transitioning the game controller scripts (pong.gd, breakout.gd, etc.) from monolithic orchestrators to componentized systems
- A `UniversalGameScript` that acts as a generic game container, similar to how `UniversalBody` is a generic entity container
- Game flow (states, scoring, win/lose) handled by Rule and Flow components rather than the game script itself
- A hub/menu system for selecting games

### What Was Actually Built
- **This update was partially implemented.** The game scripts (pong.gd, breakout.gd, asteroids.gd, pongsteroids.gd) remain as the primary game orchestrators
- No hub/menu system was built
- Significant progress was made on the universal_game_script, with the creation of the collision_matrix and several rules and flow components.
- The component architecture for *entities* (Bodies + Brains + Legs + Arms) is well-established, but the *game-level* componentization has not yet been done
- This planning document set the stage for the current goal (Update 5: Component Pong)

### State After This Update
- 4 playable games exist with their own game scripts
- Entity-level components are mature and reusable
- Game-level logic (state machines, scoring, win conditions) is still embedded in individual game scripts
- Some game-level logic (wave spawning, group tracking) has been extracted out into generic scenes
- The UFO body exists as a scene but is not yet used in any game

---

## Update 5: Component Pong — Game-Level Componentization

**Planning Document:** `planning/04 - Component Pong.md`

### What Was Planned
- Rebuild Pong entirely from components — eliminate the monolithic `pong.gd` game script
- Prove that `UniversalGameScript` can serve as a generic game container with zero game-specific logic
- All game behavior (states, scoring, ball spawning, win/lose) handled by attached Rule/Flow/Component nodes
- New components: Goal, PointsMonitor, ScreenCleanup, SoundOnHit, VariableTuner
- Enhanced components: AngledDeflector (auto-connect), PongAcceleration (auto-connect), WaveSpawner (spawn at game start + initial velocity), Interface (dual display modes)

### What Was Actually Built

**`pong.gd` was DELETED.** Pong is now a pure scene assembly (`pong.tscn`) with a `UniversalGameScript` root node and 14+ attached component nodes. Zero game-specific code.

**New Components Built:**

| Component | Category | Purpose |
|-----------|----------|---------|
| `goal` | Rule | Area2D scoring zone — increments P1/P2/generic score on `body_entered` |
| `points_monitor` | Rule | Compares score against threshold → emits `victory`/`defeat` on UGS |
| `screen_cleanup` | Component | Frees parent when outside viewport bounds + margin |
| `sound_on_hit` | Flow | Plays sound on collision — works on both Area2D and UniversalBody parents |
| `variable_tuner` | Rule | Adjusts a parent property when a signal fires (used for AI difficulty ramp) |
| `property_override` | Core | Custom Resource for WaveSpawner to configure spawned entity properties |

**Enhanced Components:**

| Component | Enhancement |
|-----------|-------------|
| `angled_deflector` | Auto-connects to `parent.body_collided`, filters by `target_group`, modifies velocity directly |
| `pong_acceleration` | Auto-connects to `parent.body_collided`, filters by `target_group`, ramps speed |
| `wave_spawner` | Added `spawn_at_game_start`, `initial_velocity`, random angle/flip, `property_overrides` array |
| `interface` | Added `display_mode` (P1_P2_SCORE vs POINTS_MULTIPLIER), `state_changed` handler for UI transitions |
| `interceptor_ai` | Group-based targeting, `Vector2.ZERO` on no-target, aim angle initialization on first acquisition |
| `universal_body` | Default `_physics_process()` now uses `move_parent_physics()` for collision-aware bouncing |
| `common_enums` | Added `ScoreType`, `Condition`, `Result`, `AdjustmentMode`, `DisplayMode` enums |

**Bugs Fixed During Implementation:**
- `wave_spawner.gd`: `or` → `and` in signal source filtering (was returning early 100% of the time)
- `wave_spawner.gd`: Stale signal connections in `pong.tscn` from deleted `pong.gd` methods
- `universal_game_script.gd`: Score signals now emit running total (not increment)
- `sound_on_hit.gd`: `has_method()` → `has_signal()` for auto-detecting collision signals
- `interceptor_ai.gd`: Added `_initialized` flag to snap aim on first target acquisition (prevented sweeping)

### Architecture Validation
Component Pong proved that **game-level componentization works**. The same pattern used for entities (Bodies + Brains + Legs) now applies to games (UGS + Rules + Flow). No game-specific code was needed — Pong is an editor assembly of generic components on a generic game container.

### State After This Update
- `pong.gd` deleted — Pong runs as a pure scene assembly
- Game-level component architecture is proven and operational
- 3 remaining games (Breakout, Asteroids, Pongsteroids) still use monolithic game scripts — ready to be componentized
- The path is clear: new games are editor assemblies, not code

---

## Update 6: Full Componentization — All Games Complete

**Planning Document:** `planning/05 - Componentized Breakout, Asteroids, and Pongsteroids.md`

### What Was Planned
- Componentize Breakout, Asteroids, and Pongsteroids — eliminate the last three monolithic game scripts
- Build cross-cutting components: DamageOnHit, ScoreOnDeath, ScoreOnHit, DieOnHit
- Extend WaveSpawner with GRID pattern, safe zone, spawn groups, game_over guards
- Extend WaveDirector with GAME_START trigger
- Build GroupCountMultiplier rule for Asteroids scoring
- Add auto_start to Timer
- Fix PropertyOverride for typed arrays

### What Was Actually Built

**ALL THREE GAME SCRIPTS DELETED.** `breakout.gd`, `asteroids.gd`, `pongsteroids.gd` are gone. All four games now run as pure scene assemblies with zero game-specific code. This was completed in a single day, building on weeks of preliminary component work.

**New Components Built:**

| Component | Category | Purpose |
|-----------|----------|---------|
| `damage_on_hit` | Arm | Deals damage to colliders in target_groups with Health component |
| `die_on_hit` | Component | Kills parent on collision (separate from damage for composition) |
| `die_on_timer` | Component | Kills parent after timer expires |
| `score_on_death` | Component | Awards points when parent dies (listens to sibling Health) |
| `score_on_hit` | Component | Awards points on collision (must be on scoring entity) |
| `group_count_multiplier` | Rule | Sets multiplier = count of entities in target group |

**Major Enhancements:**

| Component | Enhancement |
|-----------|-------------|
| `wave_spawner` | Safe zone (await-based, waits for unsafe groups to vacate radius), spawn_groups (add_to_group), spawn_components (attach scenes), game_over guards in both `_on_spawning_wave` and `_spawn_one`, POSITION spawn pattern, typed array fix in PropertyOverride |
| `wave_director` | GAME_START trigger type, max_waves limit, game_over guard, await-based wave_delay |
| `timer` | `auto_start` export — connects to `game.on_game_start` to begin automatically |
| `goal` | `lose_life` and `extra_life` modes beyond scoring |
| `universal_game_script` | Auto-emit property setters for `current_score` and `current_multiplier` |
| `common_enums` | Added GAME_START trigger, POSITION spawn pattern |

**Bugs Fixed:**
- `wave_spawner.gd`: PropertyOverride typed array assignment — uses `Array.assign()` for `Array[String]` properties
- `wave_spawner.gd`: Missing game_over guard — staggered spawns continued after game over
- `wave_director.gd`: Timer never started — added `auto_start` export to Timer component
- `wave_spawner.gd`: Expression parse bug — added input variable names to `expression.parse()`

### Architecture Validation — Complete

All four games prove the component architecture works at every level:
- **Entity-level** (Bodies + Brains + Legs + Arms): Validated since Pongsteroids (Update 3)
- **Game-level** (UGS + Rules + Flow): Validated with Component Pong (Update 5)
- **Cross-game remix**: Pongsteroids assembled from Pong + Asteroids components — zero new code
- **Full componentization**: All four games are editor assemblies, no game scripts

---

## Update 7: Dogfight + Bodies Purification + Scene Reorganization

**Planning Document:** `planning/06 - Asteroids Polish and More Remix Games.md` (started)

### What Was Built

**Dogfight** (`Games/dogfight.tscn`) — Pure scene assembly, zero game-specific script:
- Player triangle ship vs escalating waves of AI triangle ships, with asteroids as neutral obstacles
- 5-way factional collision groups: players, enemies, players_bullets, enemies_bullets, asteroids
- Enemy AI is a triple-brain stack: InterceptorAi (chase) + AimAi (aim) + ShootAi (auto-fire in vision cone)
- Escalating difficulty: enemy count = wave_number (wave 1 = 1 enemy, wave 2 = 2, etc.)
- Asteroids spawn every 6 seconds with AngledDeflector for chaotic bouncing
- LivesCounter (10 lives) for Asteroids-style game over
- Built entirely from existing components — only ShootAi was new

**New Components:**

| Component | Category | Purpose |
|-----------|----------|---------|
| `shoot_ai` | Brain | Scans for targets in a vision cone, auto-fires when target detected (configurable fire rate, vision angle, range) |
| `damage_on_joust` | Arm | Compares parent vs collider velocity on collision — faster body wins, slower takes damage. Configurable tie_breaker |

**Bodies Purification:**
All body scripts have had functional code excised. Bodies now contain **drawing code only** (shapes, colors, `_draw()` calls). All gameplay behavior (damage, health, bouncing, movement) is handled by attached components. The body is the blackboard and the visual — components are the behavior.

### New Body Scenes
| Scene | Purpose |
|-------|---------|
| `triangle_ship_modern` | Asteroids ship with modern twin-stick controls (engine_complex + rotation_target + direct_acceleration + friction_linear + screen_wrap) |

### Bodies Scene Reorganization

The `Scenes/Bodies/` folder was reorganized from a flat list into a three-tier directory structure:

```
Scenes/Bodies/
├── generic/        — Archetype templates (no brain, no faction, no color override)
├── player/         — Pre-rigged for player control (player brain, friendly color, player groups)
└── nonplayer/      — Pre-rigged as threats/obstacles (AI brains, hostile color, enemy groups)
```

**Rationale:** Previously, bodies were imagined as generic components configured per-game. This caused two problems:
1. **Annoying configuration** — especially for complex entities, setting up brains/groups/colors per game was tedious
2. **Player confusion** — visually identical entities with differing behaviors across games would be disorienting in rapid-fire game sequences

**New rule:** `extends UniversalBody` scripts contain drawing code only and serve as the visual identity for a specific entity type. Scenes in the three tiers tie that visual to a specific behavioral role (player, enemy, or neutral archetype). This means **visual identity = behavioral identity** — the player always knows what something does by what it looks like.

**All existing body scenes were reorganized:**
- `generic/` — asteroid, ball, brick, bullet_simple, bullet_wrapping, paddle, triangle_ship, triangle_ship_modern, ufo
- `player/` — player_bullet_simple, player_bullet_wrapping, player_paddle, player_triangle_ship, player_triangle_ship_modern
- `nonplayer/` — nonplayer_bullet_simple, nonplayer_bullet_wrapping, nonplayer_paddle, nonplayer_triangle_ship, nonplayer_triangle_ship_modern

**Scripts remain flat** in `Scripts/Bodies/` — the organizational split is at the scene level only.

---

## Update 8: Asteroids Polish + Procedural Audio + Remix Games

**Planning Document:** `planning/06 - Asteroids Polish and More Remix Games.md` (continued)

### What Was Built

#### Procedural Audio System

A complete procedural audio synthesis system was built, replacing the Kenney audio file assets for game sounds. All game audio is now generated at runtime.

**New Components:**

| Component | Category | Purpose |
|-----------|----------|---------|
| `sound_synth` | Flow | Procedural audio synthesis — generates waveforms (SQUARE, TRIANGLE, SAWTOOTH, SINE) with configurable frequency, duration, envelope (ATTACK, DECAY, SWEEP_UP, SWEEP_DOWN), volume. Supports exclusive mode |
| `music_ramping` | Flow | Reactive music — loops a SoundSynth template with pitch scaling as group count → 0. Classic "music speeds up as danger decreases" effect |
| `sfx_ramping` | Flow | Dynamic SFX — plays sounds with pitch/volume scaling based on group count or parameters |
| `beep` | Flow | Simple procedural beep — lightweight alternative to SoundSynth for basic audio feedback |

**Audio design patterns established:**
- Sound templates: SoundSynth configured once as a "template" that other components (MusicRamping, SFXRamping) reference
- Multi-channel architecture: multiple SoundSynth instances can play simultaneously (shoot sounds, bounce sounds, music)
- Exclusive mode: prevents the same sound from stacking (e.g., rapid-fire shooting only plays one bullet sound at a time)
- Phase accumulation bug was fixed in SoundSynth — audio playback is now clean

#### Asteroids Polish

The Asteroids game was fully polished with death effects, UFO enemy, reactive music, and visual polish:

**New Components:**

| Component | Category | Purpose |
|-----------|----------|---------|
| `death_effect` | Component | Spawns visual effect scenes on parent death (listens to Health.zero_health) |
| `patrol_ai` | Brain | Curve2D path following + random closed-loop path generation (for UFO patrol) |
| `vector_engine_exhaust` | Component | Visual-only engine exhaust flame when thrusting |

**New Effects:**

| Effect | Purpose |
|--------|---------|
| `death_particles` | Self-destructing particle burst on entity death |
| `death_broken_triangle_ship` | Self-destructing ship debris — broken triangle fragments drift apart |

**Asteroids game now features:**
- Death effects: asteroids explode with particles, ships break into debris
- UFO enemy: patrols via PatrolAi, aims and shoots via AimAi + ShootAi, spawns on timer
- Reactive music: MusicRamping with pitch scaling based on asteroid count
- Engine exhaust: visual flame when thrusting
- Sound synthesis: all sounds (shooting, bouncing, explosions, music) generated procedurally

#### Remix Games

Three new remix games were assembled:

**Pongout** (`Games/pongout.tscn`) — Pong + Breakout:
- Two paddles (player + InterceptorAi opponent) with brick grids shielding each goal
- Ball with DamageOnHit (bricks) + AngledDeflector + PongAcceleration
- First goal wins — player must break through opponent's brick shield to reach the goal
- VariableTuner boosts AI turning_speed per brick destroyed (defensive ramping)
- Status: ✅ Complete and working

**Breaksteroids** (`Games/breaksteroids.tscn`) — Breakout + Asteroids:
- Paddle at bottom, ball, asteroid grid with health and splitting
- Bottom goal = lose life, asteroids cleared = next wave
- Randomized asteroid shapes create unpredictable "space pinball" deflections
- MusicRamping reactive audio based on asteroid count
- Status: ✅ Complete and working

**Asterout** (`Games/asterout.tscn`) — Asteroids + Breakout:
- Modern controls + UFO dogfighting with brick shields (RingSpawner)
- Player ship vs shielded UFOs — break through brick ring to damage UFO
- Status: ⚠️ NOT WORKING WELL — needs to be remade
- **Known issue:** RingSpawner bricks parented to UFO body aren't detected by CollisionMatrix (only watches UGS root children). Player bullets phase through bricks. Fix: parent bricks to game root + manual position tracking in `_process()`

**New Components for Asterout:**

| Component | Category | Purpose |
|-----------|----------|---------|
| `ring_spawner` | Component | Spawns entities in a ring pattern around parent. Configurable radius, count, size, health, orbit speed |

**New Body Scenes:**

| Scene | Purpose |
|-------|---------|
| `generic/ufo_shielded.tscn` | UFO with RingSpawner brick shield (for Asterout) |

#### GroupMonitor Enhancement

`group_monitor.gd` was enhanced with a new signal:

| Signal | Purpose |
|--------|---------|
| `group_member_removed(group_name)` | Fires on each individual removal from the group (not just when group hits zero) |

This enables per-death tracking — e.g., VariableTuner can boost AI difficulty each time a brick is destroyed, rather than waiting for the entire group to be cleared.

### Known Bugs (Unfixed)

- `patrol_ai.gd`: Start position may not be correctly set — needs user fix
- `ufo_shielded.tscn`: UFO drawing scale may need adjustment

### Component Catalog (Updated)

| Category | Count | Components |
|----------|-------|------------|
| Core | 7 | universal_body, universal_game_script, universal_component, universal_component_2d, collision_matrix, collision_group, property_override, common_enums |
| Bodies | 9 | ball, paddle, asteroid, brick, bullet_simple, bullet_wrapping, triangle_ship, ufo, ufo_shielded |
| Brains | 5 | player_control, interceptor_ai, aim_ai, shoot_ai, patrol_ai |
| Legs | 8 | direct_movement, direct_acceleration, engine_simple, engine_complex, friction_linear, friction_static, rotation_direct, rotation_target |
| Arms | 3 | gun_simple, damage_on_hit, damage_on_joust |
| Components | 14 | angled_deflector, collision_marker, death_effect, die_on_hit, die_on_timer, health, pong_acceleration, ring_spawner, score_on_death, score_on_hit, screen_cleanup, screen_wrap, split_on_death, vector_engine_exhaust |
| Rules | 7 | goal, points_monitor, variable_tuner, group_monitor, group_count_multiplier, lives_counter, timer |
| Flow | 7 | interface, sound_on_hit, sound_synth, music_ramping, sfx_ramping, beep, wave_director, wave_spawner |
| Effects | 2 | death_particles, death_broken_triangle_ship |
| **Total** | **62** | |

---

## Update 9: Grid Foundation + Space Invaders & Tetris Components

**Planning Document:** `planning/07 - Space Invaders and Tetris.md`

### What Was Planned
- Build Space Invaders and Tetris as the 9th and 10th games
- Create a grid system foundation shared by both games (grid_basic, grid_movement, grid_rotation)
- Build Space Invaders-specific components (swarm_controller, swarm_ai, shoot_ai_swarm)
- Build Tetris-specific components (falling_ai, tetromino_formation, tetromino_spawner, line_clear_monitor)
- Build shared utility components (variable_tuner_global)
- Enhance wave_spawner with grid_score_by_row and universal_body with autofire toggle

### What Was Actually Built

**Grid Foundation (Phase 1):**

| Component | Category | Purpose |
|-----------|----------|---------|
| `grid_basic` | Flow | Grid coordinate system + active occupancy tracking. Exposes `grid_to_world`, `world_to_grid`, bounds checking, register/unregister cells |
| `grid_movement` | Leg | Discrete grid snap movement with hop_delay, movement ratchets, occupancy checks, hard drop mode |
| `grid_rotation` | Leg | Discrete rotation steps (90°/45°), ties facing to movement input |

**Space Invaders Components (Phase 2):**

| Component | Category | Purpose |
|-----------|----------|---------|
| `swarm_controller` | Flow | Orchestrates synchronized swarm movement via signal bus pattern. Speed ramps as members die |
| `swarm_ai` | Brain | Antenna brain — receives swarm_controller commands, relays as body movement signals |
| `shoot_ai_swarm` | Brain | Formation-aware edge shooting. Random roll odds ramp to 100% over max_shot_interval |

**Tetris Components (Phase 3):**

| Component | Category | Purpose |
|-----------|----------|---------|
| `falling_ai` | Brain | Gravity as input source — emits `input_move(DOWN)` on timer. Routes through same signal chain as player input |
| `tetromino_formation` | Leg | Multi-cell shape management on grid. Offsets array, rotation, landing detection, lock delay, cell registration |
| `tetromino_spawner` | Flow | Spawns next tetromino piece at grid top. Bag/queue with 7-bag or random mode |
| `line_clear_monitor` | Rule | Generic line-clear detection for grid_basic. Horizontal/vertical/both, configurable clear direction |

**New Body:**

| Body | Purpose |
|------|---------|
| `tetromino` | Tetris piece — visual representation of a multi-cell grid piece. Scenes: tetromino.tscn (full piece), tetromino_single.tscn (single cell) |

**Other New Components:**

| Component | Category | Purpose |
|-----------|----------|---------|
| `warp_asteroids` | Leg | Emergency teleport with intangibility for Asteroids-style games (previously listed as "Skipped/Future") |

**New Body Scenes:**

| Scene | Purpose |
|-------|---------|
| `brick_damaging.tscn` | Brick variant that deals damage on contact |
| `tetromino.tscn` | Full tetromino piece (4 cells) |
| `tetromino_single.tscn` | Single tetromino cell/block |

**Scene Reorganizations:**

- **Game scenes** reorganized from flat `Scenes/Games/` into three subdirectories: `originals/` (Dogfight), `remakes/` (Pong, Breakout, Asteroids), `remixes/` (Pongsteroids, Pongout, Breaksteroids, Asterout)
- **Player/nonplayer bullet scenes removed** — bullets now use generic scenes with per-game collision groups configured in the editor, simplifying the body scene inventory

**Debug scene added:** `Scenes/Debug/grid_test.tscn` for validating grid components

### Status
- Grid foundation: ✅ Built (grid_basic, grid_movement, grid_rotation)
- Space Invaders components: ✅ Built (swarm_controller, swarm_ai, shoot_ai_swarm)
- Tetris components: ✅ Built (falling_ai, tetromino_formation, tetromino_spawner, line_clear_monitor)
- Space Invaders game scene: 🔲 Not yet composed
- Tetris game scene: 🔲 Not yet composed
- Enhancements (wave_spawner grid_score_by_row, universal_body autofire, variable_tuner_global): 🔲 Not yet built

### Component Catalog (Updated)

| Category | Count | Components |
|----------|-------|------------|
| Core | 8 | universal_body, universal_game_script, universal_component, universal_component_2d, collision_matrix, collision_group, property_override, common_enums |
| Bodies | 9 | ball, paddle, asteroid, brick, bullet_simple, bullet_wrapping, tetromino, triangle_ship, ufo |
| Brains | 8 | player_control, interceptor_ai, aim_ai, shoot_ai, shoot_ai_swarm, patrol_ai, falling_ai, swarm_ai |
| Legs | 12 | direct_movement, direct_acceleration, engine_simple, engine_complex, friction_linear, friction_static, rotation_direct, rotation_target, grid_movement, grid_rotation, tetromino_formation, warp_asteroids |
| Arms | 3 | gun_simple, damage_on_hit, damage_on_joust |
| Components | 14 | angled_deflector, collision_marker, death_effect, die_on_hit, die_on_timer, health, pong_acceleration, ring_spawner, score_on_death, score_on_hit, screen_cleanup, screen_wrap, split_on_death, vector_engine_exhaust |
| Rules | 8 | goal, points_monitor, variable_tuner, group_monitor, group_count_multiplier, lives_counter, timer, line_clear_monitor |
| Flow | 11 | interface, sound_on_hit, sound_synth, music_ramping, sfx_ramping, beep, grid_basic, swarm_controller, tetromino_spawner, wave_director, wave_spawner |
| Effects | 2 | death_particles, death_broken_triangle_ship |
| **Total** | **75** | |

---

## Summary: What Exists vs What Was Planned

| Feature | Planned | Status |
|---------|---------|--------|
| Solar System Hub | Overview doc | ❌ Not built |
| Entity Component System | Overview doc | ✅ Fully operational |
| Game-Level Component System | Plan 03/04 | ✅ All 8 games componentized |
| Pong | Plan 01/04 | ✅ Componentized — no game script |
| Breakout | Plan 01/05 | ✅ Componentized — no game script |
| Asteroids | Plan 02/05 | ✅ Componentized + polished (death effects, UFO, reactive music) |
| Pongsteroids | Plan 02/05 | ✅ Componentized — no game script |
| Dogfight | Plan 06 | ✅ Componentized — no game script |
| Pongout | Plan 06 | ✅ Componentized — working |
| Breaksteroids | Plan 06 | ✅ Componentized — working |
| Asterout | Plan 06 | ⚠️ Exists but needs remake (RingSpawner collision bug) |
| Space Invaders | Plan 07 | 🔧 Components built, game scene not yet composed |
| Tetris | Plan 07 | 🔧 Components built, game scene not yet composed |
| Grid System | Plan 07 | ✅ grid_basic + grid_movement + grid_rotation |
| Swarm System | Plan 07 | ✅ swarm_controller + swarm_ai + shoot_ai_swarm |
| Procedural Audio System | — | ✅ SoundSynth + MusicRamping + SFXRamping + Beep |
| Warp/Asteroids Emergency Teleport | Plan 06→07 | ✅ warp_asteroids leg built |
| Hub/Menu System | Plan 03 | ❌ Not started |
| Meta/Narrative Layer | Brainstorming | ❌ Not started |
