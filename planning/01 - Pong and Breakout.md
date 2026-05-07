# Plan: Paddle Ball & Brick Breaker — Shared Components

## Goal

Build Paddle Ball and Brick Breaker as the first two playable games, using shared components from the start. These two games will validate the composable architecture before building the wider framework.

---

## Design Philosophy: Concrete First, Abstract Second

Build these games with components in mind, but don't over-abstract prematurely. Extract shared patterns once both games are working. The refactor from two games is cheap — the refactor from five is not.

---

## Component Design

### Ball
| Property | Type | Description |
|----------|------|-------------|
| speed | float | Initial launch speed |
| bounciness | float | Physics restitution |
| weight | float | For future spin/physics effects |

**Behavior:**
- `CharacterBody2D` for full control over bounce angles (especially paddle-hit-angle in Paddle Ball)
- Uses `move_and_collide()` and reflects velocity on collision
- Emits signals: `ball_hit(body)`, `ball_off_screen(side)` (Paddle Ball scoring), `ball_lost()` (Brick Breaker life lost)
- `serve(direction: Vector2)` — launch the ball in a given direction
- `reset()` — return to center, zero velocity

**Used by:** Paddle Ball, Brick Breaker

---

### Paddle
| Property | Type | Description |
|----------|------|-------------|
| width | float | Paddle width |
| height | float | Paddle height |
| speed | float | Max movement speed |
| locked_axis | Vector2 | Which axes are locked (0 = locked, 1 = free) |

**Behavior:**
- Exposes `set_target_position(pos: Vector2)` or `set_velocity(vel: Vector2)`
- Does NOT handle its own input — whatever drives it (player input, AI) calls its movement methods
- Respects axis locks (e.g., Paddle Ball locks to Y, Brick Breaker locks to X)
- Emits signal: `ball_hit_paddle(ball)` — allows game script to modify ball angle based on hit position

**Used by:** Paddle Ball, Brick Breaker

---

### Brick
| Property | Type | Description |
|----------|------|-------------|
| health | int | Hits required to destroy (default 1) |
| position | Vector2 | Grid position |

**Behavior:**
- On ball collision: decrement health by 1
- If health ≤ 0: emit `brick_destroyed()` signal and queue_free
- Emits signals: `brick_hit(current_health)`, `brick_destroyed()`

**Used by:** Brick Breaker (primary), Moon mashup (spawned in Paddle Ball arena)

---

### AI Interceptor (Simple Intercept AI)
| Property | Type | Description |
|----------|------|-------------|
| tracked_target | Node2D | What to pursue |
| speed_cap | float | Max speed (so it's beatable) |
| reaction_delay | float | Optional lag before reacting |

**Behavior:**
- Does NOT know it's attached to a paddle — just moves its parent toward the tracked target
- Calls the parent's `set_target_position()` toward the target's position
- In Paddle Ball: attached to opponent paddle, tracks the ball → since paddle is Y-locked, creates convincing opponent behavior
- Future reuse: missiles, enemies, any pursuit behavior

**Used by:** Paddle Ball (opponent), future: Missile Command, enemies

---

## Game Coordinator Scripts

These are the scripts that live in each game's scene and orchestrate the components.

### Paddle Ball Game Script
- Sets up the arena: walls (top/bottom `StaticBody2D` for bouncing, left/right for scoring)
- Configures paddles (lock to Y axis, set positions)
- Attaches AI Interceptor to opponent paddle, sets tracked_target = ball
- Tracks score (left vs right)
- Draws the center net (visual only)
- On `ball_off_screen(side)`: increment score, call `ball.reset()`, `ball.serve()`
- Win condition: first to N points

### Brick Breaker Game Script
- Sets up the arena: walls (top + sides `StaticBody2D` for bouncing, bottom = open)
- Configures paddle (lock to X axis, position at bottom)
- Places brick grid (rows × columns, configurable health per row)
- Tracks lives (start at 3)
- On `ball_lost()`: decrement lives, `ball.reset()`, `ball.serve()`
- On `brick_destroyed()`: check if all bricks gone → level complete or next level
- Win condition: destroy all bricks

---

## Scene Tree Sketches

### Paddle Ball
```
Paddle Ball (Node2D) — Paddle BallGame.gd
├── Walls (Node2D)
│   ├── TopWall (StaticBody2D)
│   ├── BottomWall (StaticBody2D)
│   ├── LeftScoreZone (Area2D)
│   └── RightScoreZone (Area2D)
├── Net (Line2D or ColorRect)
├── PlayerPaddle (Paddle scene)
├── OpponentPaddle (Paddle scene)
│   └── AIInterceptor (Node — AI script)
├── Ball (Ball scene)
└── UI
    ├── LeftScore (Label)
    └── RightScore (Label)
```

### Brick Breaker
```
Brick Breaker (Node2D) — Brick BreakerGame.gd
├── Walls (Node2D)
│   ├── TopWall (StaticBody2D)
│   ├── LeftWall (StaticBody2D)
│   └── RightWall (StaticBody2D)
├── PlayerPaddle (Paddle scene)
├── Ball (Ball scene)
├── Bricks (Node2D)
│   ├── Brick (×N, placed by game script)
│   └── ...
└── UI
    ├── Lives (Label)
    └── Score (Label)
```

---

## Build Order

1. **Ball** — Most architecturally important; everything connects to it via signals
2. **Paddle** — Second most shared; get movement and input right
3. **Paddle Ball** — Simplest complete game; validates ball + paddle + walls
4. **AI Interceptor** — Makes Paddle Ball a real game (opponent)
5. **Brick** — New component, but simple (health decrement + signals)
6. **Brick Breaker** — Second game; validates that components reuse cleanly
7. **Moon mashup** — Paddle Ball arena + Brick Breaker bricks spawned in the middle

---

## Key Decisions

- **`CharacterBody2D`** for the ball (not `RigidBody2D`) — more control over bounce angles
- **Paddle is input-agnostic** — driven by external callers (player input or AI), not self-driven
- **Signals for all inter-object communication** — ball emits `ball_hit`, bricks emit `brick_destroyed`, game scripts listen and react
- **Game scripts are coordinators** — they set up the scene, configure components, and listen to signals; no game logic lives in the components themselves

---

## Risks / Open Questions

- **Paddle-ball angle control in Paddle Ball:** Need to decide if the paddle modifies the ball's bounce angle based on where it hit (standard Paddle Ball behavior). If so, the paddle should emit `ball_hit_paddle(ball, hit_position_ratio)` and the game script (or ball itself) adjusts velocity.
- **Ball speed escalation:** Both games traditionally speed up over time. Ball could have an `accelerate(factor)` method, called by the game script on each hit.
- **Screen size/resolution:** Should be decided early so wall positions are consistent. Common Godot default is 1152×648 or 1280×720.