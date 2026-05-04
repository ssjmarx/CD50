# Plan 14 — Snake and Light Cycles

**Created:** 2026-05-03  
**Status:** Active  
**Scope:** 2 new remakes (Snake, Light Cycles) — shared core component (`trail_spawner`)

---

## Why These Two Together

Snake and Light Cycles share the same fundamental mechanic: **a moving entity that leaves a trail of collision bodies behind it**. The `trail_spawner` component serves both games:

- **Light Cycles mode:** Permanent wall segments (no max length), die on any wall collision, multiplayer
- **Snake mode:** Growing body segments (max_length increases on eating), die on self/wall collision, food collection

Building both together means `trail_spawner` gets designed with both modes in mind from the start.

---

## Game 1 — Light Cycles (Tron)

### Game Design
- Top-down arena, 2+ cycles (1 player + AI opponents)
- Each cycle moves forward continuously at fixed speed
- Players turn 90° left/right (axis-aligned movement)
- Each cycle leaves a **permanent wall trail** behind it (static collision segments)
- Die on collision with any wall (own, opponent's, arena border)
- Last cycle alive wins the round
- Speed may increase over time

### Data Model
- Trail segments are static collision bodies spawned by `trail_spawner`
- Cycles move freely in axis-aligned directions at pixel precision
- Wall collisions handled by existing physics (`move_and_collide`)

### Reusable Components

| Component | Role |
|-----------|------|
| `player_control` | Player directional input |
| `engine_simple` | Continuous forward movement |
| `rotation_direct` | 90° snapping turns |
| `die_on_hit` | Death on wall collision |
| `damage_on_joust` | Cycle-cycle head-on collision |
| `points_monitor` | Round score tracking |
| `lives_counter` | Best-of-N rounds |
| `interface` | UI |
| `sound_synth` | Audio |
| `death_particles` | Cycle explosion |

### New Components

| Component | Category | Description |
|-----------|----------|-------------|
| `trail_spawner` | Components | Continuously spawns static collision bodies behind a moving entity. **Configurable:** segment size, spawn interval, `max_length` (0 = unlimited/permanent), group name. When `max_length > 0`, oldest segments despawn when exceeded. Emits `trail_segment_spawned`. Has `clear_trails()` for round cleanup. |
| `cycle_ai` | Brains | Moves forward, detects walls/opponents ahead via raycasts. Turns left or right to avoid. Configurable: look-ahead distance, reaction speed, aggression. |

### New Bodies

| Body | Description |
|------|-------------|
| `cycle` | Drawing only: small rectangle/arrow. Pure `_draw()` — no logic. |

### Assembly Sketch

```
UniversalGameScript (Light Cycles)
├── Interface
├── PointsMonitor
├── LivesCounter
├── WaveSpawner → spawns AI cycles
├── Player Cycle (UniversalBody)
│   ├── player_control
│   ├── engine_simple
│   ├── rotation_direct
│   ├── trail_spawner (permanent mode: max_length=0)
│   ├── die_on_hit
│   └── cycle (drawing)
├── AI Cycle (UniversalBody)
│   ├── cycle_ai
│   ├── engine_simple
│   ├── rotation_direct
│   ├── trail_spawner (permanent mode: max_length=0)
│   ├── die_on_hit
│   └── cycle (drawing)
└── SoundSynth instances
```

### Deliverable
Playable Light Cycles: player vs 1-3 AI cycles. Trails form walls. Die on collision. Best of 3 rounds. Arena border kills.

---

## Game 2 — Snake

### Game Design
- Grid-based arena (cell size configurable, e.g. 16px)
- Snake moves forward continuously, turns 90° (axis-aligned)
- Snake **grows** when it eats food (trail max_length increases)
- Die on collision with self (own trail) or walls (arena border)
- Score = food eaten × speed bonus
- Speed increases gradually as snake grows

### Data Model
- Uses `trail_spawner` in **following mode**: `max_length` starts at ~3, increases by 1 per food eaten
- Old segments despawn automatically when max_length exceeded → creates the "following body" effect
- Food is a simple body with collision; on eaten: emit signal, respawn at random open position

### Reusable Components

| Component | Role |
|-----------|------|
| `player_control` | Player directional input |
| `engine_simple` | Continuous forward movement |
| `rotation_direct` | 90° snapping turns |
| `die_on_hit` | Death on wall/self collision |
| `points_monitor` | Score tracking |
| `lives_counter` | Lives (typically 1 — one life per game) |
| `interface` | UI |
| `sound_synth` | Audio |
| `death_particles` | Death effect |

### New Components

| Component | Category | Description |
|-----------|----------|-------------|
| `food_spawner` | Components | Spawns a collectible body at a random open position in the arena. On collection (body collision): emits `food_eaten`, respawns at new position. Checks for overlap with existing trails to avoid spawning inside the snake. |

### New Bodies

| Body | Description |
|------|-------------|
| `food` | Drawing only: small circle/square. Pure `_draw()` — no logic. |

### Assembly Sketch

```
UniversalGameScript (Snake)
├── Interface
├── PointsMonitor
├── FoodSpawner
├── Player Snake (UniversalBody)
│   ├── player_control
│   ├── engine_simple
│   ├── rotation_direct
│   ├── trail_spawner (following mode: max_length starts ~3)
│   ├── die_on_hit (self + walls)
│   └── cycle (drawing — repurposed as snake head)
├── Food (UniversalBody)
│   └── food (drawing)
└── SoundSynth instances
```

### Deliverable
Playable Snake: snake grows when eating food, dies on self/wall collision, score tracks food eaten, speed increases over time.

---

## New Component Summary

| Component | Category | Used By | Complexity |
|-----------|----------|---------|------------|
| `trail_spawner` | Components | LC + Snake + future remixes | **Medium** — spawn static bodies on timer, optional max_length with FIFO despawn |
| `cycle_ai` | Brains | LC | **Low** — raycast wall avoidance + turning |
| `food_spawner` | Components | Snake | **Low** — spawn collectible at random open position |

---

## Implementation Order

| Step | What | Depends On | New Components |
|------|------|-----------|----------------|
| 1 | Create `trail_spawner` component | — | trail_spawner |
| 2 | Create `cycle` body | — | — |
| 3 | Create `cycle_ai` brain | trail_spawner | — |
| 4 | Assemble Light Cycles game | 1–3 | — |
| 5 | Playtest Light Cycles | 4 | — |
| 6 | Create `food` body | — | — |
| 7 | Create `food_spawner` component | trail_spawner | food_spawner |
| 8 | Assemble Snake game | 1, 6–7 | — |
| 9 | Playtest Snake | 8 | — |

---

## Design Considerations

1. **Trail Spawner modes** — The component needs to cleanly handle both modes: permanent walls (LC) and growing body (Snake). The `max_length` export (0 = infinite) handles this. When `max_length > 0`, oldest segments are freed when the count is exceeded.

2. **Self-collision in Snake** — The snake head must not die from its own immediately-adjacent segments. Options: (a) trail_spawner skips the first N segments for collision, (b) short grace period after turning, (c) head has a "safe zone" collision shape that excludes adjacent trail cells. Simplest: trail_spawner provides `ignore_recent` count — segments younger than N are in a different collision group.

3. **Food placement** — `food_spawner` needs to avoid placing food on existing trail segments. It can check the `walls` group for overlaps, or query trail_spawner directly for occupied positions.

4. **Round cleanup** — In Light Cycles (multi-round), `trail_spawner.clear_trails()` frees all spawned segments between rounds. Signal-driven: listen for round-end from `points_monitor`.

5. **Speed ramping** — Both games benefit from gradual speed increase. Could use `variable_tuner` on a timer, or a dedicated speed-ramp on the snake's `engine_simple`. No new component needed — existing tools handle this.