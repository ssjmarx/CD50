# Current Goal: Component Pong

**Planning Document:** `planning/04 - Component Pong.md`  
**Status:** 🔲 Not Started  
**Objective:** Rebuild Pong entirely from components — eliminate the monolithic `pong.gd` game script in favor of a `UniversalGameScript` with attached Flow/Rule/Component nodes.

---

## Why This Matters

The entity-level component architecture (Bodies + Brains + Legs + Arms) is proven and working. Pongsteroids validated that components can be freely mixed across game types. However, the **game-level logic** (state machines, scoring, win/lose conditions, ball respawning) is still hardcoded in individual game scripts (`pong.gd`, `breakout.gd`, etc.).

This update is the critical next step: proving that the same component pattern works at the **game level**, not just the entity level. If successful, every future game becomes an assembly of game-level components rather than a custom script.

---

## The Vision: `UniversalGameScript` (UGS)

Replace `pong.gd` with a generic `UniversalGameScript` — a minimal container that provides:

1. **Game State Machine:** States (ATTRACT, PLAYING, GAME_OVER, PAUSED) with `state_changed` signal
2. **Collision Group Auto-Setup:** Export a list of groups; UGS automatically sets up group tracking on ready
3. **Score Tracking:** Built-in P1/P2 score counters with signals (`on_p1_score`, `on_p2_score`)
4. **Victory/Defeat Conditions:** Emits `victory()` and `defeat()` signals based on score thresholds

The UGS should contain **zero game-specific logic**. All Pong-specific behavior (ball spawning, acceleration, goal detection) moves into components.

---

## New Components to Build

### Flow Components
| Component | Purpose |
|-----------|---------|
| **Goal** | Area2D-based component. Detects when a body enters the goal zone. Increments the appropriate score on the UGS. |
| **PointsMonitor** | Rule component. Listens to UGS score signals. When a score reaches a configurable threshold (e.g., 11), emits `victory()` or `defeat()` on the UGS. |
| **ScreenCleanup** | Removes (frees) bodies that leave the visible screen area. Replaces the "ball goes off screen and gets freed" logic. |

### Enhanced Existing Components
| Component | Enhancement |
|-----------|-------------|
| **PongAcceleration** | Add auto-connect pattern: detect parent collisions automatically, filter by target group. Remove reliance on Ball's `BallCollision` signal. |
| **AngledDeflector** | Same auto-connect + group filtering pattern. Update parent velocity directly instead of relying on callback. |
| **WaveSpawner** | Add `spawn_at_game_start: bool` and `initial_velocity/angle` config so it can serve as the ball spawner. |
| **Interface** | Connect to UGS `on_p1_score`/`on_p2_score` signals instead of reading from the game script directly. |

### New Rule/Component Types
| Component | Purpose |
|-----------|---------|
| **VariableTuner** | Listens for a signal (e.g., goal scored) and adjusts a property on a target node. Used for AI difficulty ramping (increase InterceptorAi `turning_speed` after each goal). |
| **SoundOnCollision** | Plays a sound effect when a collision occurs with a specific group. Soft requirement that parent is a universalbody or has a collisionmarker. |

---

## Signal Flow: Complete Component Pong

```
START:
  Player presses Enter → UGS.start_game() → on_game_start emitted
    → WaveSpawner hears on_game_start (spawn_at_game_start)
      → Spawns Ball at screen center with random angle + velocity

GAMEPLAY:
  Ball moves → hits paddle (physics collision)
    → PongAcceleration detects "paddles" group → accelerates ball
    → AngledDeflector detects "paddles" group → deflects ball angle
  Ball moves → hits wall → physics bounce (automatic)

SCORING:
  Ball enters P1Goal Area2D
    → Goal component calls UGS.add_p2_score(1)
      → UGS emits on_p2_score(1)
        → Interface updates P2 score display
        → P2PointsMonitor checks 1 >= 11? No
    → SoundOnCollision plays goal sound
    → Ball continues past goal → exits screen
      → ScreenCleanup frees Ball
        → GroupMonitor detects "balls" group empty → emits group_cleared("balls")
          → WaveDirector hears group_cleared("balls") → waits 1s → emits spawning_wave
            → WaveSpawner spawns new Ball at center

  VariableTuner hears P1Goal.body_entered
    → Adjusts InterceptorAi.turning_speed += 30 (AI difficulty ramp)

WIN/LOSE:
  P1 reaches 11 → P1PointsMonitor emits UGS.victory()
    → UGS transitions to GAME_OVER, shows WIN_TEXT
  P2 reaches 11 → P2PointsMonitor emits UGS.defeat()
    → UGS transitions to GAME_OVER, shows LOSE_TEXT
```

---

## Implementation Order

### Phase A: UGS + Core Infrastructure
1. Add `collision_groups` export + auto-setup to `UniversalGameScript`
2. Add `p1_score`/`p2_score` tracking and signals to `UniversalGameScript`
3. Build **Goal** component
4. Build **PointsMonitor** component
5. Test: verify score tracking works with debug prints

### Phase B: Enhanced Components
6. Enhance **PongAcceleration** (auto-connect + group filtering)
7. Enhance **AngledDeflector** (auto-connect + group filtering + velocity update)
8. Build **VariableTuner** component
9. Test: verify ball acceleration, deflection, and AI ramping

### Phase C: Flow Components
10. Enhance **WaveSpawner** (`spawn_at_game_start` + `initial_velocity` + angle config)
11. Build **ScreenCleanup** component
12. Build **SoundOnCollision** component
13. Enhance **Interface** (connect to `on_p1_score`/`on_p2_score`)

### Phase D: Assembly
14. Clean up Ball script (remove redundant signal/methods)
15. Clean up Paddle script (remove `bounce_offset`)
16. **Delete `pong.gd`**
17. Build new `pong.tscn` with `UniversalGameScript` root + all components
18. Playtest full game loop

---

## Key Design Decisions to Make

1. **Auto-connect collision pattern:** How do PongAcceleration and AngledDeflector detect collisions on their parent? Options:
   - Ball emits a generic `body_collided(collider, normal)` signal
   - Components read `get_last_slide_collision()` from parent
   - Components connect to parent's existing signals

2. **VariableTuner string-based property access:** Using `parent[target_property]` is fragile. Need clear error messages.

3. **ScoreType enum:** PointsMonitor and Goal share a `ScoreType` enum (P1_SCORE, P2_SCORE, GENERIC_SCORE). Should this live in a shared location?

4. **Scene tree complexity:** 14+ component nodes is a lot of Inspector configuration. This is the expected trade-off for composition over inheritance.

5. **Ball death timing:** ScreenCleanup must free the ball AFTER Goal has processed the `body_entered` signal. Scene order / process priority matters.

---

## Deferred Items (Future Updates)

- **Attract Mode:** AI swap mechanism (replace PlayerControl with InterceptorAi in attract state, swap back on game start)
- **AI Randomizer:** VariableTuner could serve this role with MULTIPLY mode + random source
- **State-dependent UI:** ATTRACT_TEXT show/hide tied to state changes

---

## Success Criteria

- [ ] `pong.gd` is **deleted** — no game-specific script exists
- [ ] Pong runs identically to the current version using only UGS + components
- [ ] All game logic (states, scoring, spawning, win/lose) is handled by components
- [ ] The same UGS can theoretically run Breakout, Asteroids, etc. with different component configurations
</task_progress>
</write_to>