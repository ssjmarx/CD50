# Plan: Space Rocks & Meteor Rally — Component Architecture Expansion

## Goal

1. **Refactor Paddle Ball** — Extract hardwired logic into reusable components (input, movement, deflection, speed boost)
2. **Build Space Rocks** — A new game that introduces rotation/thrust physics, screen wrapping, shooting, and destructible physics objects
3. **Build Meteor Rally** — A mashup game combining Paddle Ball arena + Space Rocks, proving the component architecture can compose hybrids

---

## Design Philosophy: Extract on Demand

Paddle Ball and Brick Breaker are working. Now we extract patterns into components *because Space Rocks needs them*, not speculatively. Each refactor should leave Paddle Ball working identically.

---

## Part 1: Paddle Ball Refactors

Before building Space Rocks, extract the following from existing components so they can be reused.

### 1.1 Ball: Extract Speed Boost into Component

**Current state:** `ball.gd` has `accelerate()`, `current_acceleration_level`, `acceleration_factor`, `acceleration_levels` baked in.

**Target state:** A `SpeedBoost` component node that attaches to the ball (or anything that needs escalating speed).

| Property | Type | Description |
|----------|------|-------------|
| acceleration_factor | float | Multiplier per boost (default 1.2) |
| max_levels | int | Max number of boosts (default 8) |

**Behavior:**
- Tracks `current_level` internally
- Exposes `boost()` — multiplies parent velocity by factor, increments level
- Exposes `reset()` — returns to level 1
- Emits `speed_changed(level)` so audio/visuals can react

**Impact on ball.gd:** Ball's `accelerate()` and `reset()` delegate to `$SpeedBoost.boost()` and `$SpeedBoost.reset()`. Ball keeps its `_draw()`, collision signal, and `custom_bounce()`.

### 1.2 Ball: Separate Physics Body from Gameplay Hitbox

**Current state:** Ball's `CollisionShape2D` handles both physics bouncing AND gameplay detection (bricks, paddles).

**Target state:**
```
Ball (CharacterBody2D)
├── CollisionShape2D      ← Layer 1: Physics (walls, paddles, space_rocks)
├── Hitbox (Area2D)       ← Layer 2: Gameplay (damages space_rocks, bricks)
│   └── CollisionShape2D
├── SpeedBoost (Node)
└── AudioStreamPlayer2D
```

**Why:** In Meteor Rally, the ball needs to physically bounce off space_rocks AND trigger their death via gameplay hitbox — simultaneously but independently. Physics bounce ≠ gameplay damage.

### 1.3 Paddle: Add Hurtbox Area2D

**Current state:** Paddle collision shape handles physics collision with ball.

**Target state:**
```
Paddle (CharacterBody2D)
├── CollisionShape2D      ← Layer 1: Physics (ball bouncing)
├── Hurtbox (Area2D)      ← Layer 2: Gameplay (receives damage)
│   └── CollisionShape2D
└── Deflector (Node)      ← Bounce angle calculation
```

**Why:** In Meteor Rally, space_rocks hitting the paddle is a gameplay event (damage/stun), not just a physics bounce. The Hurtbox catches this safely — if no Health component exists, the signal just fires harmlessly.

### 1.4 Extract Deflector Logic from Paddle

**Current state:** `paddle.gd` has `bounce_offset()` which calculates hit-angle ratio, and `Paddle Ball.gd` applies the `physics_angle.x * 5` multiplier.

**Target state:** A `Deflector` component on the paddle that encapsulates the full angle-calculation logic.

| Property | Type | Description |
|----------|------|-------------|
| deflection_strength | float | Multiplier for angle spread (default 5.0) |

**Behavior:**
- `calculate_deflection(ball_position: Vector2) -> Vector2` — returns normalized deflection angle
- Reads parent's global_position to compute offset
- Applies strength multiplier internally

**Impact:** Game scripts call `paddle.calculate_deflection(ball_pos)` instead of doing the math themselves.

### 1.5 AI Interceptor: Verify Compatibility

The interceptor already follows the "Brain" pattern — it calls `parent.set_direct_movement()`. No changes needed unless the paddle API changes during refactoring. Verify after other refactors.

---

## Part 2: Space Rocks

### New Components Required

#### 2.1 ScreenWrap Component
| Property | Type | Description |
|----------|------|-------------|
| viewport_size | Vector2 | Screen dimensions (default 640×360) |
| margin | float | Buffer before wrapping (default 8.0) |

**Behavior:**
- In `_physics_process()`, checks parent's global position
- If parent exits one side of viewport, teleports to opposite side
- Reusable for: space_rocks, ship, bullets, anything in a wrapping space

#### 2.2 Thrust Component (Rotation-Based Movement)
| Property | Type | Description |
|----------|------|-------------|
| thrust_force | float | Force applied when accelerating |
| max_speed | float | Speed cap |
| friction | float | Deceleration when not thrusting |

**Behavior:**
- Reads parent's `rotation` and an `input_direction` (from a controller component)
- When thrusting: applies force in the direction the parent is facing (`Vector2.from_angle(rotation)`)
- When not thrusting: applies friction to slow down
- Modifies parent's `velocity` directly
- Ship drifts realistically (no instant stop)

#### 2.3 RotateInput Component (Ship Controls)
| Property | Type | Description |
|----------|------|-------------|
| rotation_speed | float | Degrees per second |

**Behavior:**
- Left/Right arrows rotate the parent (`parent.rotation += direction * rotation_speed * delta`)
- Up arrow sets a `thrusting = true` flag (read by Thrust component)
- Spacebar triggers shooting (emits `shoot_requested` signal)

#### 2.4 Shooter Component
| Property | Type | Description |
|----------|------|-------------|
| projectile_scene | PackedScene | What to spawn |
| fire_rate | float | Seconds between shots |
| muzzle_offset | Vector2 | Offset from parent center for spawn point |

**Behavior:**
- Listens for `shoot_requested` signal (or checks input directly)
- Spawns projectile at parent's position + muzzle_offset, facing parent's rotation
- Enforces fire rate via Timer
- Projectile inherits parent's velocity + its own speed

#### 2.5 Bullet Scene
```
Bullet (CharacterBody2D)
├── CollisionShape2D      ← Layer 1: Physics
├── Hitbox (Area2D)       ← Layer 2: Gameplay (damages space_rocks)
│   └── CollisionShape2D
└── ScreenWrap (Node)     ← Wraps like everything else
```

**Behavior:**
- Moves in straight line at constant speed
- Destroys itself after max distance or time (auto-despawn)
- Does NOT bounce (unlike Ball)

#### 2.6 SplitOnDeath Component
| Property | Type | Description |
|----------|------|-------------|
| fragment_scene | PackedScene | The smaller asteroid scene |
| spawn_count | int | How many fragments (default 2) |
| fragment_speed | float | Random velocity magnitude for fragments |

**Behavior:**
- Listens to parent's Health `died` signal
- On death: spawns N fragments at parent's position with random velocities
- Adds fragments to the scene tree (via `get_tree().current_scene.add_child()`)

#### 2.7 Asteroid Scene
```
Asteroid (CharacterBody2D) — group: "space_rocks"
├── CollisionShape2D      ← Layer 1: Physics (ball, ship, other space_rocks)
├── Hitbox (Area2D)       ← Layer 2: Gameplay (damages ship)
│   └── CollisionShape2D
├── Hurtbox (Area2D)      ← Layer 2: Gameplay (receives damage from ball/bullets)
│   └── CollisionShape2D
├── Health (Node)         ← HP = 1
├── SplitOnDeath (Node)   ← Spawns smaller fragments
└── ScreenWrap (Node)     ← Wraps around screen
```

**Three sizes** (separate scenes or configured via exports):
- **Large** → splits into 2 Medium
- **Medium** → splits into 2 Small
- **Small** → destroyed completely (no SplitOnDeath, or spawn_count = 0)

**Movement:** Given a random initial velocity on spawn. No thrust — just drifts.

#### 2.8 Ship Scene
```
Ship (CharacterBody2D) — group: "ship"
├── CollisionShape2D
├── Hurtbox (Area2D)      ← Receives damage from space_rocks
│   └── CollisionShape2D
├── Health (Node)         ← HP = 1 (one-hit death, traditional Space Rocks)
├── RotateInput (Node)    ← Handles rotation + thrust + shoot input
├── Thrust (Node)         ← Applies velocity based on rotation
├── Shooter (Node)        ← Fires bullets
└── ScreenWrap (Node)     ← Wraps around screen
```

### Space Rocks Game Coordinator (`space_rocks.gd`)

**Responsibilities:**
- Spawn initial wave of large space_rocks (e.g., 4) with random positions and velocities
- Listen for asteroid `died` signals → award score (large=20, medium=50, small=100)
- Listen for ship `died` signal → lose a life, respawn ship (or game over)
- Track lives (start at 3)
- When all space_rocks destroyed → spawn next wave (more space_rocks)
- Game over: show text, ENTER to restart, ESC to quit

### Collision Layers Setup

| Layer | Name | Used By |
|-------|------|---------|
| 1 | Physics | Ship, Space Rocks, Bullets, Ball, Paddles, Walls |
| 2 | Gameplay | Hitboxes, Hurtboxes |

Physics bodies use Layer 1 for solid collisions. Area2D hitboxes/hurtboxes use Layer 2 for damage detection. This keeps "bouncing" separate from "damage."

---

## Part 3: Meteor Rally (The Mashup)

### Concept
Standard Paddle Ball (two paddles, one ball, scoring goals) with space_rocks floating through the arena. The ball bounces off space_rocks (physics), destroys them (gameplay), and does NOT speed up on asteroid hits — only on paddle hits.

### Game Coordinator (`meteor_rally.gd`)

**Inherits or heavily references `Paddle Ball.gd` logic with additions:**

- Spawn standard Paddle Ball setup (2 paddles, ball, walls, goals)
- Timer spawns large space_rocks from random edges every N seconds
- Ball collision logic branches:
  - **Paddle hit:** Deflect + accelerate (standard Paddle Ball) + reset multiplier
  - **Asteroid hit (physics):** Bounce (reflect off normal), do NOT accelerate
  - **Asteroid hit (gameplay):** Ball's Hitbox triggers asteroid's Hurtbox → asteroid takes damage → potentially splits
  - **Wall hit:** Standard bounce
- Space Rocks can hit paddles (Hurtbox detects, optional stun/damage)
- Scoring: Paddle Ball goals + asteroid destruction points

### Scene Tree
```
Meteor Rally (Node2D) — meteor_rally.gd
├── Walls (StaticBody2D)
├── player (Paddle)           ← Refactored paddle with Hurtbox
├── opponent (Paddle)         ← With AI Interceptor
│   └── InterceptorAi
├── ball (Ball)               ← Refactored ball with Hitbox
├── P1 Goal (Area2D)
├── P2 Goal (Area2D)
├── AsteroidSpawner (Timer)   ← Spawns space_rocks periodically
├── UI
│   ├── P1 Score
│   ├── P2 Score
│   └── Win/Lose/Continue Text
├── CRT (CanvasLayer)
└── CRT - bloom (WorldEnvironment)
```

### Key Design Test
Meteor Rally proves the architecture works if:
1. **Paddle scene** works in Paddle Ball, Brick Breaker, and Meteor Rally without modification
2. **Ball scene** handles both paddle-deflection and asteroid-bounce without game-specific code in the ball script
3. **Asteroid scene** works identically in Space Rocks and Meteor Rally
4. **Health component** works on bricks, space_rocks, and (optionally) the ship

---

## Build Order

### Phase A: Paddle Ball Refactors (Don't Break Paddle Ball!)
1. Extract `SpeedBoost` component from ball → verify Paddle Ball + Brick Breaker still work
2. Add `Hitbox` Area2D child to ball → verify physics still works
3. Add `Hurtbox` Area2D child to paddle → verify Paddle Ball still works
4. Extract `Deflector` component from paddle → verify Paddle Ball bounce angles unchanged
5. Verify AI Interceptor still works with refactored paddle

### Phase B: Space Rocks Components
6. Build `ScreenWrap` component
7. Build `Thrust` component (rotation-based movement)
8. Build `RotateInput` component
9. Build `Shooter` component + `Bullet` scene
10. Build `SplitOnDeath` component
11. Build `Asteroid` scene (Large, Medium, Small variants)
12. Build `Ship` scene

### Phase C: Space Rocks Game
13. Build `space_rocks.gd` game coordinator
14. Build `Space Rocks.tscn` scene
15. Playtest and tune

### Phase D: Meteor Rally
16. Build `meteor_rally.gd` (Paddle Ball coordinator + asteroid spawning)
17. Build `Meteor Rally.tscn` scene
18. Tune ball behavior (bounce off space_rocks but don't accelerate)
19. Playtest the mashup

---

## Risks / Open Questions

- **CharacterBody2D vs RigidBody2D for space_rocks:** CharacterBody2D gives precise control but requires manual collision resolution between space_rocks. RigidBody2D handles elastic collisions automatically but reduces control. **Recommendation:** Start with CharacterBody2D (consistent with existing architecture). If asteroid-to-asteroid bouncing feels wrong, switch to RigidBody2D for space_rocks only.
- **Ball behavior in Meteor Rally:** The ball needs to physically bounce off space_rocks AND trigger their gameplay death simultaneously. The Layer separation (Physics Layer 1 vs Gameplay Layer 2) handles this, but needs testing to ensure the timing works (physics bounce + health reduction in the same frame).
- **Collision layer complexity:** Adding Layer 2 for gameplay hitboxes/hurtboxes requires updating existing scenes. Paddle Ball and Brick Breaker can stay on Layer 1 only until they need the split.