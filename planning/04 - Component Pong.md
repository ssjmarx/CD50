# Plan: Update 04 — Component Pong

## Goal

Complete refactor of Pong into the componentized architecture. The `pong.gd` game script is **eliminated**. The Pong scene uses `UniversalGameScript` as its root script. ALL Pong game behavior is recreated through reusable components.

**Attract mode is out of scope** — this update focuses solely on core gameplay behavior.

---

## Philosophy

This update is the proof-of-concept for the "Universal Architecture" (see `planning/brainstorming/universal architecture.md`). Instead of a game-specific script orchestrating logic, the scene itself IS the logic. Components are assembled in the scene tree, connected via signals on the UniversalGameScript blackboard, and the game runs autonomously.

**Before:** `pong.gd` (165 lines) → monolithic game coordinator
**After:** `UniversalGameScript` root + 14 component nodes → zero game-specific code

---

## Target Scene Tree

```
Pong (UniversalGameScript)
├── Ball (UniversalBody, Godot group: "balls")
│   ├── CollisionShape2D
│   ├── HitBox (Area2D)
│   ├── PongAcceleration (enhanced — auto-connects to parent collisions, config: group "paddles")
│   ├── AngledDeflector (enhanced — auto-connects to parent collisions, config: group "paddles")
│   ├── ScreenCleanup (new — frees ball when it leaves screen)
│   └── AudioStreamPlayer2D
├── Player (Paddle/UniversalBody, Godot group: "paddles")
│   ├── CollisionShape2D
│   ├── AngledDeflector (deflection_bias: 5, 1)
│   ├── PlayerControl
│   └── DirectMovement
├── Opponent (Paddle/UniversalBody, Godot group: "paddles")
│   ├── CollisionShape2D
│   ├── AngledDeflector (deflection_bias: 5, 1)
│   ├── InterceptorAi (target: Ball, turning_speed: 45, aim_inaccuracy: 0)
│   │   └── VariableTuner (listen: P1Goal body_entered, adjust: parent.turning_speed, +30)
│   └── DirectMovement
├── GroupMonitor (target_group: "balls")
├── WaveDirector (trigger: GROUP_CLEARED, trigger_value: "balls", wave_delay: 1.0, max_waves: 0)
├── WaveSpawner (ball ×1, SCREEN_CENTER, spawn_at_game_start: true, initial_velocity config)
├── P1Goal (Area2D)
│   ├── CollisionShape2D
│   ├── CollisionMarker (collision_groups: ["goals"])
│   ├── Goal (new — emits p1_score via UGS)
│   └── SoundOnCollision (new — plays goal sound on body_entered)
├── P2Goal (Area2D)
│   ├── CollisionShape2D
│   ├── CollisionMarker (collision_groups: ["goals"])
│   ├── Goal (new — emits p2_score via UGS)
│   └── SoundOnCollision
├── P1PointsMonitor (new — watches p1_score, target: 11, emits: victory)
├── P2PointsMonitor (new — watches p2_score, target: 11, emits: defeat)
├── TopWall (StaticBody2D)
│   ├── CollisionShape2D
│   └── CollisionMarker (collision_groups: ["walls"])
├── BottomWall (StaticBody2D)
│   ├── CollisionShape2D
│   └── CollisionMarker (collision_groups: ["walls"])
├── Interface (enhanced — connects to on_p1_score, on_p2_score)
├── CRT Shader (CanvasLayer — existing addon)
└── ColorRect (white center line)
```

---

## Required Changes

### 1. UniversalGameScript — Enhancements

**Location:** `Scripts/Core/universal_game_script.gd`

**Changes:**
- Add `collision_groups` export (Dictionary) so the collision matrix can be configured per-scene in the editor. In `_ready()`, if the dictionary is non-empty, call `setup_collision_groups()` automatically.
- Add three new signals:
  - `on_p1_score(amount: int)` — relayed when a Goal component registers a P1 score
  - `on_p2_score(amount: int)` — relayed when a Goal component registers a P2 score
  - `on_score(score_type, amount)` — generic score relay (optional, for future flexibility)
- Add internal score tracking: `p1_score: int`, `p2_score: int`
- Add relay methods: `add_p1_score(amount)`, `add_p2_score(amount)` — increment internal counters and emit the appropriate signals
- `on_points_changed` continues to work for generic score (single-player games)

**Signal flow for goals:**
```
Goal component detects body_entered
  → calls parent.add_p1_score(1) or parent.add_p2_score(1)
    → UGS increments p1_score/p2_score
    → UGS emits on_p1_score(p1_score) or on_p2_score(p2_score)
      → Interface updates display
      → PointsMonitor checks against target
```

### 2. WaveSpawner — Enhancements

**Location:** `Scripts/Flow/wave_spawner.gd`

**New exports:**
- `spawn_at_game_start: bool = false` — if true, spawns one wave when `on_game_start` fires from UGS
- `initial_velocity: float = 0.0` — speed to apply to spawned entities
- `use_fixed_angle: bool = false` — if true, spawn entities facing a fixed angle
- `fixed_angle: float = 0.0` — angle in radians (only used if use_fixed_angle)
- `use_random_angle: bool = false` — if true, spawn with random angle within a range
- `random_angle_min: float = 0.0` — minimum random angle (radians)
- `random_angle_max: float = TAU` — maximum random angle (radians)
- `random_flip_h: bool = false` — randomly negate horizontal velocity component
- `random_flip_v: bool = false` — randomly negate vertical velocity component

**Behavior changes:**
- Connect to `parent.on_game_start` when `spawn_at_game_start` is true
- After spawning an entity, if `initial_velocity > 0`, set `entity.velocity` using the configured angle behavior
- Angle priority: fixed_angle > random_angle > default (no velocity change)

**Pong configuration:** `spawn_at_game_start: true`, `initial_velocity: 150`, `use_random_angle: true`, `random_angle_min: 3π/4`, `random_angle_max: 5π/4`, `random_flip_h: true`

### 3. PongAcceleration — Enhancement

**Location:** `Scripts/Components/pong_acceleration.gd`

**New exports:**
- `target_group: String = "paddles"` — group name to check against colliders

**Behavior changes:**
- In `_ready()`, automatically find parent's collision detection (for UniversalBody: connect to physics collision; for bodies with `move_parent_physics` returning collisions, listen for that)
- On collision, check if the collider is in `target_group`
- If match: call existing `accelerate()` logic
- If parent has no detectable collision system: print error message
- Remove dependency on being called externally — this component is now self-sufficient

**Note:** The `BallCollision` signal on Ball is now redundant and will be removed.

### 4. AngledDeflector — Enhancement

**Location:** `Scripts/Components/angled_deflector.gd`

**New exports:**
- `target_groups: Array[String] = []` — list of Godot groups to respond to (e.g., ["paddles"])

**Behavior changes:**
- In `_ready()`, automatically connect to parent's collision detection (same pattern as PongAcceleration)
- On collision, check if the collider is in any of `target_groups`
- If match: calculate deflection angle using existing `bounce_offset()` logic with `deflection_bias`
- Apply to parent's velocity: preserve speed, change direction to the deflection angle
- This component is now self-sufficient — no external script needs to call `bounce_offset()` or `custom_bounce()`

**Pong configuration on Ball:** `target_groups: ["paddles"]`, `deflection_bias: Vector2(5, 1)`

**Note:** The existing `bounce_offset()` method can remain for manual use, but the auto-connect behavior makes it unnecessary for the componentized Pong.

### 5. NEW RULES COMPONENT: Goal

**Location:** `Scripts/Rules/goal.gd` / `Scenes/Rules/goal.tscn`
**Extends:** Node

**Purpose:** Detects bodies entering a goal zone and emits score signals through the UniversalGameScript.

**Exports:**
- `score_type: ScoreType` — enum: P1_SCORE, P2_SCORE, GENERIC_SCORE
- `score_amount: int = 1` — points to award (supports negative for penalties)

**Enum:**
```
ScoreType { P1_SCORE, P2_SCORE, GENERIC_SCORE }
```

**Behavior:**
- In `_ready()`, connect to parent's `body_entered` signal (parent must be Area2D)
- On body_entered: call the appropriate method on the game script:
  - P1_SCORE → `parent.add_p1_score(score_amount)`
  - P2_SCORE → `parent.add_p2_score(score_amount)`
  - GENERIC_SCORE → `parent.add_score(score_amount)`

**Pong configuration:**
- P1Goal: `score_type: P2_SCORE` (ball enters P1's goal → P2 scores)
- P2Goal: `score_type: P1_SCORE` (ball enters P2's goal → P1 scores)

### 6. Interface — Enhancement

**Location:** `Scripts/Rules/interface.gd`

**Changes:**
- Connect to `parent.on_p1_score` → calls `set_p1_score()`
- Connect to `parent.on_p2_score` → calls `set_p2_score()`
- These connections are added in `_ready()` alongside existing connections

### 7. NEW FLOW COMPONENT: SoundOnCollision

**Location:** `Scripts/Flow/sound_on_collision.gd` / `Scenes/Flow/sound_on_collision.tscn`
**Extends:** Node (or AudioStreamPlayer2D)

**Purpose:** Plays a sound when the parent node detects a body entering its collision area.

**Exports:**
- `sound: AudioStream` — the sound to play

**Behavior:**
- In `_ready()`, connect to parent's `body_entered` signal (parent must be Area2D)
- On body_entered: play the configured sound
- Requires an internal AudioStreamPlayer (or extends it directly)

**Pong configuration:** Attached to P1Goal and P2Goal, plays the goal scored sound (`threeTone1.ogg`)

### 8. NEW RULES COMPONENT: VariableTuner

**Location:** `Scripts/Rules/variable_tuner.gd` / `Scenes/Rules/variable_tuner.tscn`
**Extends:** Node

**Purpose:** Listens for a configurable signal from a configurable node and adjusts a configurable variable on its parent by a configurable amount. Generic "signal → property change" bridge.

**Exports:**
- `source_node: NodePath` — node to listen to
- `source_signal: String` — signal name to connect to
- `target_property: String` — property name on parent to modify (e.g., "turning_speed")
- `adjustment_amount: float` — value to ADD to the property (negative to subtract, works as multiplier if needed)
- `adjustment_mode: AdjustmentMode` — enum: ADD, MULTIPLY, SET

**Enum:**
```
AdjustmentMode { ADD, MULTIPLY, SET }
```

**Behavior:**
- In `_ready()`, connect `source_node.source_signal` to internal handler
- On signal received: modify `parent.target_property` by `adjustment_amount` using the configured mode
- ADD: `parent[target_property] += adjustment_amount`
- MULTIPLY: `parent[target_property] *= adjustment_amount`
- SET: `parent[target_property] = adjustment_amount`

**Pong configuration (on InterceptorAi):**
- `source_node`: NodePath to P1Goal
- `source_signal`: "body_entered"
- `target_property`: "turning_speed"
- `adjustment_amount`: 30.0
- `adjustment_mode`: ADD

### 9. NEW RULES COMPONENT: PointsMonitor

**Location:** `Scripts/Rules/points_monitor.gd` / `Scenes/Rules/points_monitor.tscn`
**Extends:** Node

**Purpose:** Monitors a points value (p1_score, p2_score, or generic score) on the game script and emits victory/defeat when it reaches a target.

**Exports:**
- `score_type: ScoreType` — which score to watch (P1_SCORE, P2_SCORE, GENERIC_SCORE)
- `target_score: int = 11` — threshold to trigger
- `condition: Condition` — enum: GREATER_OR_EQUAL, LESS_OR_EQUAL
- `result: Result` — enum: VICTORY, DEFEAT

**Enums:**
```
ScoreType { P1_SCORE, P2_SCORE, GENERIC_SCORE }
Condition { GREATER_OR_EQUAL, LESS_OR_EQUAL }
Result { VICTORY, DEFEAT }
```

**Behavior:**
- In `_ready()`, connect to the appropriate signal on parent (UGS):
  - P1_SCORE → `parent.on_p1_score`
  - P2_SCORE → `parent.on_p2_score`
  - GENERIC_SCORE → `parent.on_points_changed`
- On score update: check if condition is met (e.g., score >= target_score)
- If met: emit `parent.victory()` or `parent.defeat()` based on result

**Pong configuration:**
- P1PointsMonitor: `score_type: P1_SCORE`, `target_score: 11`, `condition: GREATER_OR_EQUAL`, `result: VICTORY`
- P2PointsMonitor: `score_type: P2_SCORE`, `target_score: 11`, `condition: GREATER_OR_EQUAL`, `result: DEFEAT`

### 10. NEW COMPONENT: ScreenCleanup

**Location:** `Scripts/Components/screen_cleanup.gd` / `Scenes/Components/screen_cleanup.tscn`
**Extends:** Node

**Purpose:** The conceptual opposite of ScreenWrap. Frees the parent node when it goes off-screen past a configurable buffer. Used to clean up entities that leave the play area (balls going into goals, bullets leaving the arena, etc.).

**Exports:**
- `margin: int = 16` — buffer pixels beyond screen edge before cleanup triggers

**Behavior:**
- In `_physics_process()`, check parent position against viewport bounds + margin
- If parent is outside bounds: call `parent.queue_free()`
- Viewport bounds: x < -margin, x > 640 + margin, y < -margin, y > 360 + margin

**Pong usage:** Attached to Ball. When ball enters a goal Area2D, it passes through and exits the screen. ScreenCleanup frees it. GroupMonitor then detects "balls" group is empty → triggers WaveDirector → respawns ball.

---

## Cleanup: Ball Script Changes

**Location:** `Scripts/Bodies/ball.gd`

**Removals:**
- `BallCollision` signal — no longer needed (PongAcceleration and AngledDeflector auto-connect)
- `custom_bounce()` method — no longer needed (AngledDeflector handles angle changes directly)
- `accelerate()` method — no longer needed (PongAcceleration is self-sufficient)
- `reset()` method — no longer needed (ball is destroyed and respawned, not reused)
- `_on_pong_acceleration_speed_changed()` handler — keep if Ball still needs sound changes, but connection pattern may change

**The Ball body becomes much simpler:** it moves, bounces off physics colliders, plays collision sounds, and that's it. All game-specific behavior (acceleration, deflection, cleanup) is handled by attached components.

---

## Cleanup: Paddle Script Changes

**Location:** `Scripts/Bodies/paddle.gd`

**Removals:**
- `bounce_offset()` method — no longer called externally (AngledDeflector handles its own deflection)

**The Paddle body remains simple:** collision shape, visual, and AngledDeflector as a child for other entities to query.

---

## Cleanup: Deleted Files

- `Scripts/Games/pong.gd` — **DELETED** (entire point of this update)
- The Ball's `BallCollision` signal and related methods

---

## Signal Flow: Complete Pong Game Loop

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

Suggested order to build and test incrementally:

### Phase A: UGS + Core Infrastructure
1. Add collision_groups export + auto-setup to UniversalGameScript
2. Add p1_score/p2_score tracking and signals to UniversalGameScript
3. Build Goal component
4. Build PointsMonitor component
5. Test: verify score tracking works with debug prints

### Phase B: Enhanced Components
6. Enhance PongAcceleration (auto-connect + group filtering)
7. Enhance AngledDeflector (auto-connect + group filtering + velocity update)
8. Build VariableTuner component
9. Test: verify ball acceleration, deflection, and AI ramping

### Phase C: Flow Components
10. Enhance WaveSpawner (spawn_at_game_start + initial_velocity + angle config)
11. Build ScreenCleanup component
12. Build SoundOnCollision component
13. Enhance Interface (connect to on_p1_score/on_p2_score)

### Phase D: Assembly
14. Clean up Ball script (remove redundant signal/methods)
15. Clean up Paddle script (remove bounce_offset)
16. Delete pong.gd
17. Build new pong.tscn with UniversalGameScript root + all components
18. Playtest full game loop

---

## Attract Mode (Deferred)

Attract mode requires additional components:
- **AI swap mechanism** — replace PlayerControl with InterceptorAi in attract state, swap back on game start
- **AI randomizer** — VariableTuner could potentially serve this role with MULTIPLY mode + random source
- **State-dependent UI** — ATTRACT_TEXT show/hide tied to state changes

These will be addressed in a future update. For now, the componentized Pong starts directly in PLAYING state with PlayerControl already attached.

---

## Risks & Considerations

1. **Auto-connect collision detection pattern:** Both PongAcceleration and AngledDeflector need to detect collisions on their parent. Ball uses `move_parent_physics()` which returns a KinematicCollision2D. The auto-connect pattern needs a consistent way to hook into this. Consider having Ball (or UniversalBody) emit a generic `body_collided(collider, normal)` signal that any component can listen to.

2. **VariableTuner with string-based property access:** Using `parent[target_property]` requires the property to exist and be the right type. Print clear error messages if property not found.

3. **PointsMonitor ScoreType enum:** This enum (P1_SCORE, P2_SCORE, GENERIC_SCORE) is shared with Goal. Consider defining it in CommonEnums or a shared location to avoid duplication.

4. **Scene tree complexity:** 14+ component nodes is a lot of configuration. The inspector will be busy. This is expected for the "composition over inheritance" trade-off.

5. **Ball death timing:** ScreenCleanup must free the ball AFTER Goal has processed the body_entered signal. Since both react to the same body_entered, ensure Goal processes first (scene order / process priority).
</task_progress>
</write_to_file>