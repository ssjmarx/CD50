# Recent Progress: GD50 — Development History

**Last Updated:** 2025-04-15

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

## Summary: What Exists vs What Was Planned

| Feature | Planned | Status |
|---------|---------|--------|
| Solar System Hub | Overview doc | ❌ Not built |
| Entity Component System | Overview doc | ✅ Fully operational |
| Pong | Plan 01 | ✅ Complete |
| Breakout | Plan 01 | ✅ Complete |
| Asteroids | Plan 02 | ✅ Complete |
| Pongsteroids | Plan 02 | ✅ Complete |
| UFO Enemy | Plan 02 | ⚠️ Scene exists, not in any game |
| Componentized Game Scripts | Plan 03 | ❌ Not started |
| Hub/Menu System | Plan 03 | ❌ Not started |
| 6 Additional Games | Overview | ❌ Not started |
| Meta/Narrative Layer | Brainstorming | ❌ Not started |