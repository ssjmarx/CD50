# V2 Composable Architecture — Design Rules

**Last Updated:** 2026-05-23  
**Status:** Canonical reference — supersedes individual plan docs for architectural decisions  
**Source:** Plans 19–26 + brainstorming docs

---

## 1. Core Philosophy

The V2 architecture is a "lessons learned" refactor of CD50's entity-component system. It pursues **signal-driven purity** — every interaction between components flows through signals, never through direct method calls or shared state mutation.

Three principles guide every decision:

1. **Composition over inheritance.** Entities are blank slates. All behavior comes from attached components. No game-specific scripts exist.
2. **Signals, not calls.** Components never call methods on other components. They emit signals and let the recipient decide what to do. This eliminates coupling and enables runtime rewiring.
3. **Single-purpose components.** Each component does one thing. A Brain generates intent. A Leg moves. An Arm affects the world. A Guts tracks internal state. If a component is doing two things, split it.

---

## 2. Base Class Architecture

### CDEntity (extends CharacterBody2D)

The blank entity. Routes signals, resolves velocity, manages its lifecycle. Owns no game logic.

- **What it is:** A node that exists in the physics world, with collision shape APIs and a velocity accumulator.
- **What it does NOT do:** Make decisions. Know about game rules. Understand what its components do.
- **Key APIs:**
  - Velocity accumulator: `request_velocity_set()`, `request_velocity_add()` — Legs submit requests, CDEntity resolves at Priority 30.
  - Position API: `request_position_set()`, `request_position_add()` — for grid/spatial legs that bypass velocity.
  - Collision Shape API: `set_collision_polygon()`, `set_collision_circle()`, `set_collision_rect()` — for runtime procedural shapes. **Default shape is a circle** (`set_collision_circle(radius)`) set from the `shape_size` export — circles are the cheapest collision shape. Editor-placed CollisionShape2D children or collision shape components override the default circle if present.
  - Lifecycle: `activate()`, `deactivate()` — pool-aware (returns to pool or frees).
  - Signal registration: `ensure_signal()` — idempotent, with type-mismatch warning.
- **Key signals on entity bus:** `"collision"`, `"request_deactivate"`, `"entity_deactivating"`, `"entity_activated"`, `"moved"`, `"rotated"`, `"shape_changed"`

### CDComponent2D (extends Node2D)

Base class for all entity-attached components. Provides `entity` and `game` references.

- **Auto-resolves** parent entity and ancestor CDGame in `_ready()`.
- **Category property** (`component_category`) determines processing priority.
- **Two-phase lifecycle:** `_ready()` for registration, `_on_initialize()` (deferred) for signal connections.
- **Pool lifecycle hooks:** `_on_entity_deactivating()`, `_on_entity_activated()` — override to reset state.

### CDStageComponent2D (extends Node2D)

Base class for components that live as children of CDGame (Goals, some CueCards). Has `game` reference but NO `entity` reference — would NPE if it tried to resolve an entity parent.

- **Priority 70** (STAGE).
- Used for: Goals, WaveCard relay, any CDGame-child that processes game bus signals.

### CDGame (extends Node2D)

The game coordinator. Generic container with zero game-specific logic.

- **State machine:** ATTRACT → PLAYING → GAME_OVER (with `GameResult` enum: VICTORY/DEFEAT/DRAW).
- **Game bus:** Dictionary-based signal system (`bus_emit()`, `bus_connect()`). No registration boilerplate.
- **Children:** CDCollisionBuffer, CDGroupRegistry, CDCollisionMatrix, CDObjectPool nodes, CDEntities, CDStageComponents, CDMarks, CDCueCards.
- **Key infrastructure:** `group_registry`, `collision_buffer`, `collision_matrix`.
- **Reset:** `reset_game()` reloads the entire scene. No per-component reset logic needed.

### CDCueCard (extends Control)

Base for UI display components. Provides `game` reference, label creation, Priority 70.

- `is_interface: bool` — when true, auto-creates a Label child for display.
- Each CueCard updates its label when state changes.

### CDMark (extends Area2D)

Base for spatial trigger zones. Emits on the game bus when bodies enter/exit.

- **Two shape modes:** Quick (auto-creates CircleShape2D from `shape_size` export — circles are cheapest) or Precise (editor-placed CollisionShape2D children, which override the default circle if present).
- **Two filter layers:** Physics collision mask (efficient) + `filter_groups` (logical group filtering).
- **Not a CDComponent2D** — Area2D inheritance is required for physics detection.

---

## 3. Processing Priority System

Every frame, Godot processes nodes in order of their `process_physics_priority` (lower = earlier). V2 assigns fixed priorities by component category:

| Priority | Name | Category | What Runs Here | Why |
|----------|------|----------|----------------|-----|
| 5 | REGISTRATION | Registry | CDGroupRegistry dirty flush + `group_count_changed` emission | World state must be current before anyone reads it |
| 8 | INPUT | Input | CDInputRouter — processes raw input, routes to player brains | Input must be ready before brains read it |
| 10 | INTENT | Brain | Intent generators (PlayerMoveBrain, ChaseNearestBrain, etc.) | Decide what to do |
| 20 | STEERING | Legs | Movement executors (EightWayWalk, FrictionLinear, etc.) | Calculate how to get there — submit velocity/position requests |
| 30 | PHYSICS | Entity | CDEntity resolves velocity accumulator, applies `move_and_collide()` | Actually move |
| 35 | COLLISION | Buffer | CDCollisionBuffer flushes buffered collisions | All entities have moved before collisions are reported |
| 40 | INTERACTION | Arm | Arms affect the outside world (damage, score, forces) | React to collisions, deal damage |
| 50 | STATE | Guts | Internal state (health, timers, resources) | Process damage, check for death |
| 60 | VISUAL | Face | Visual updates (CDFace vector drawing, CDProjection scene effects) | Visuals reflect final state |
| 65 | AUDIO | Voice | Sound components (CDVoice entity-level, CDSpeaker scene-level) | Audio reflects final state — after visuals |
| 70 | RULES | Stage | Game-level logic (Goals, CueCards, Controllers, StageSpawners) | Score tracking, win/lose conditions, spawning |

### The Pipeline (Mental Model)

```
REGISTRATION → INPUT → INTENT → STEERING → PHYSICS → COLLISION → INTERACTION → STATE → VISUAL → AUDIO → RULES
 sync groups   read     "go!"    calc       moves     "you hit    damage       health   draw it   play it   score it +
               input             speed +    the       something"  to target    drops    on screen out loud  check win
                                  direction  thing
```

### Infrastructure Components (No Priority Needed)

These Core/ components don't do per-frame processing and have no priority slot:

| Component | Role | Why No Priority |
|-----------|------|-----------------|
| CDObjectPool | Passive pool manager | Only responds to acquire/return calls |
| CDCollisionMatrix | Collision layer config | Setup-time only |
| CDEnums | Constants | Not a processing node |
| CDMark (Area2D) | Spatial trigger zones | Event-driven via Godot physics callbacks, no `_physics_process` |
| CDComponent2D | Base class | Sets priority from category, doesn't process itself |

**Within the same priority**, Godot processes children in scene tree order (top to bottom). Tree ordering only matters when two same-priority components listen to the **same signal** or perform conflicting operations in `_physics_process`. When components use the Capture-and-Replace pattern (e.g., ShieldPoolGuts intercepts `"take_damage"` and emits `"take_health_damage"` for HealthPoolGuts), signal synchrony guarantees correct ordering regardless of tree position — ShieldPool's handler runs to completion before HealthPool's handler fires.

---

## 4. Two-Phase Lifecycle

Entity components use a two-phase initialization to solve the "other components don't exist yet" problem:

### Phase 1: `_ready()`
- `super._ready()` resolves `entity` and `game` references.
- Register entity bus signals via `entity.ensure_signal()`.
- Set processing priority from category.
- **Do NOT connect to signals here** — other components may not have registered their signals yet.

### Phase 2: `_on_initialize()` (called deferred, after all `_ready()` calls complete)
- Connect to entity bus signals.
- Connect to game bus signals.
- Read sibling component state.
- **This is where the component "wakes up."**

Stage components (CDStageComponent2D, CDCueCard) often don't need `_on_initialize()` — they connect to the game bus (Dictionary-based, no ordering issues) directly in `_ready()`.

---

## 5. Signal Architecture — The Hybrid Bus System

V2 uses two different signal mechanisms, chosen for what each is best at:

### Entity Bus (on CDEntity)

- **Mechanism:** Godot's native `add_user_signal()` — C++ backed.
- **Characteristics:** Fixed signal types, high frequency (per-entity per-frame), typed parameter signatures.
- **Best for:** INTENT → STEERING → PHYSICS → COLLISION → INTERACTION → STATE → VISUAL pipeline. The hot path.
- **Registration:** `entity.ensure_signal()` — idempotent, warns on type mismatch.
- **Connection:** `entity.connect(signal_name, callable)` — standard Godot signal connection.

### Game Bus (on CDGame)

- **Mechanism:** Dictionary-based — `Dictionary[StringName, Array[Callable]]`.
- **Characteristics:** Configurable signal names, low frequency (a few dozen events/frame total), Variant args.
- **Best for:** Entity-to-game communication (announcers), game-to-entity communication (controllers), game state events (score, lives, waves).
- **No registration needed:** `bus_emit()` with no connections = Dictionary miss = no-op. Zero boilerplate.
- **API:** `game.bus_emit(signal_name, args_array)` and `game.bus_connect(signal_name, callable)`.
- **`callv()` fast paths:** `bus_emit()` checks arg count to avoid Array boxing overhead. 0-arg and 1-arg emissions use `callable.call()` directly. `callv()` is only used for 2+ args. Since the majority of game bus signals are 0-arg or 1-arg, this eliminates most allocation overhead.

### Why Hybrid?

Native signals on the game bus would require `bus_ensure()` registration boilerplate for every configurable signal name, with `TYPE_NIL` (Variant) args anyway — no type safety benefit. The Dictionary eliminates all registration code at negligible performance cost for game-level event frequencies.

---

## 6. Signal Contracts

### Entity Bus — Canonical Signal Types

| Type | Signature | Semantic | Used By |
|------|-----------|----------|---------|
| `directional` | `(Vector2)` | Normalized direction vector — "go this way" | Brains → Legs |
| `positional` | `(Vector2)` | World-space coordinates — "go to this point" | Brains → Legs |
| `action` | `(StringName)` | Named action trigger (e.g., `&"shoot"`, `&"thrust"`) | Brains → Arms |
| `action_end` | `(StringName)` | Named action release | Brains → Arms |
| `rotate` | `(float)` | Spin direction (-1.0, 0.0, 1.0) | Brains → Legs |
| `curve` | `(Curve2D, float)` | Path to follow and speed | Brains → Legs |
| `drop` | `(int)` | Number of grid cells to drop | Brains → Legs |

**Rule:** Signal TYPE is fixed (defined by `add_user_signal()`). Signal NAME is configurable (`@export` with sensible defaults). Components must agree on BOTH name AND type.

### Entity Bus — Standard Collision Contract

```
"collision(collider: CDEntity, normal: Vector2)"
```

- Emitted by CDCollisionBuffer after Priority 35 flush.
- `collider` is the OTHER entity in the collision.
- `normal` is the collision normal pointing away from this entity.
- All collision-response Arms consume this signal.

### Entity Bus — Deactivation Contract

```
"request_deactivate"     — Request death (entity checks pool, routes accordingly)
"entity_deactivating"    — Components reset internal state, disconnect from game bus
"entity_activated"       — Components re-initialize, reconnect (pool reuse)
```

- `request_deactivate` can be emitted by any component that decides the entity should die.
- CDEntity handles the routing: pooled entities return to pool, non-pooled entities are freed.
- **`entity_deactivating` is always emitted** before pool return or destruction. Components are guaranteed cleanup time regardless of lifecycle path — disconnect from game bus, reset state, fire death effects. Non-pooled entities get this signal too, then are freed at frame end via `call_deferred("queue_free")`.
- Components override `_on_entity_deactivating()` and `_on_entity_activated()` for pool lifecycle.

### Entity Bus — Movement Notification

```
"moved"                  — Emitted by CDEntity after position changes (from position API)
"rotated"                — Emitted by CDEntity after rotation changes
"shape_changed(points)"  — Emitted by procedural shape generators (e.g., AsteroidGuts)
```

### Game Bus — Standard Event Names

| Signal | Args | Emitted By | Consumed By |
|--------|------|------------|-------------|
| `"game_play"` | none | CDGame state machine | WaveCard, spawners |
| `"game_over"` | `[GameResult]` | CDGame.end_game() | CueCards, orchestrator |
| `"group_count_changed"` | `[StringName, int]` | CDGroupRegistry | GroupCountGoal |

---

## 7. Error Handling Policy

Two tiers:

### Engine Components (Core/) — Fail Fast
If something is wrong at the engine level (missing required node, invalid configuration), the component prints an error and stops. The game should not continue in a broken state.

### Game/Entity Components (everything else) — Push Error and Continue
If a signal name doesn't exist, a type mismatch occurs, or a cross-entity emission finds no valid target, the component calls `push_error()` and skips. The entity continues running. This prevents one misconfigured component from crashing the entire game.

**Cross-entity safety rule:** When emitting on another entity's bus, always guard with `is_instance_valid()` and `has_signal()`. If the target lacks the signal (e.g., a wall without HealthPoolGuts), silently skip — no error.

---

## 8. Export Conventions

### Array Exports for Multi-Value

All multi-value configuration uses `Array[Type]` — always arrays, even for single entries:

```gdscript
@export var on_score_changed: Array[StringName] = [&"score_changed"]
@export var move_signals: Array[StringName] = [&"move"]
```

This enables runtime rewiring without code changes. A component that emits to one signal can be configured to emit to three.

### Configurable Signal Names

Every non-infrastructure component has its signal names as `@export var` with `Array[StringName]` defaults — **always arrays, for both emission and consumption**:

```gdscript
# Emission: broadcast to all listed signals
@export var on_death: Array[StringName] = [&"request_deactivate"]
@export var on_score: Array[StringName] = [&"score_gained"]

# Consumption: listen for any of the listed signals
@export var collision_signals: Array[StringName] = [&"collision"]
@export var damage_signals: Array[StringName] = [&"take_damage"]
```

Defaults are generally one signal per export, but games can wire any combination — a component can listen for `"collision"` OR `"collided_by"`, or emit to both `"score_gained"` AND `"multiplier_changed"`. The method determines the **data shape** (what arguments are passed). The export determines the **signal names** (what it's called on the bus). Defaults match the spec, but every game can rewire without code changes.

### @export_group("Signal Emissions")

Stage components group their emission exports:

```gdscript
@export_group("Signal Emissions")
@export var on_lives_changed: Array[StringName] = [&"lives_changed"]
@export var on_lives_depleted: Array[StringName] = [&"lives_depleted"]
```

---

## 9. Component Category Rules

### BRAIN — INTENT (Priority 10)
- **Pure intent generators.** Never touch velocity, never move the entity, never affect other entities.
- **Consume:** CDInputRouter (player brains), CDGroupRegistry (AI brains), internal timers (timed brains).
- **Emit:** Entity bus signals — directional, positional, action, rotate, curve.
- **Rule:** A Brain's `_physics_process` should only emit signals and update internal state. No direct mutation of entity properties.

### LEGS — STEERING (Priority 20)
- **Movement executors.** Consume entity bus signals and submit velocity/position requests.
- **Never generate intent.** Legs respond to signals, they don't create them.
- **API:** `entity.request_velocity_set()`, `entity.request_velocity_add()`, `entity.request_position_set()`, `entity.request_position_add()`.
- **Velocity set vs add:** `set` overwrites (EightWayWalk), `add` accumulates (AccelDecel, FrictionLinear). Only one `set`-based Leg should be on an entity. Multiple `add`-based Legs coexist naturally.
- **Position legs bypass velocity:** GridMovementLeg, PathFollowerLeg use position API — no friction, no accumulator conflicts.

### ARM — INTERACTION (Priority 40)
- **Affects the game state OUTSIDE the entity.** Deals damage to others, announces score, applies forces.
- **Never modifies the entity's own velocity or internal health.** That's Guts territory.
- **Runs after collision buffer flush** — has access to this frame's collision data.

### GUTS — STATE (Priority 50)
- **Tracks INTERNAL entity state.** Health, timers, resources, lock detection, shape.
- **Purely self-centered.** Don't care about the outside world except for signals telling them to update.
- **Runs after Arms** — damage has been dealt, now process it.

### FACE — VISUAL (Priority 60)
- **Visual representation.** Draws shapes, renders effects, updates appearance.
- **Reads entity state** (position, rotation, health, etc.) and reflects it visually.
- **Never affects gameplay.** A Face bug should never change game outcome.

### VOICE — AUDIO (Priority 65)
- **Sound components.** CDVoice (entity-level), CDSpeaker (scene-level), audio playback and synthesis.
- **Runs after Faces** — audio reflects the final visual/gameplay state. A damage sound plays after the damage flash renders.
- **Never affects gameplay.** A Voice bug should be silent, not broken.

### STAGE — RULES (Priority 70)
- **Game-level logic.** Score tracking, win/lose conditions, wave management, spawning.
- **Lives on CDGame**, not on CDEntity. Uses CDStageComponent2D or CDCueCard base.
- **The only category that should know about "game" concepts** like score, lives, victory, defeat.

---

## 10. Cross-Bus Communication Patterns

### Pattern 1: Entity → Entity (Physics)

```
CDEntity_A (collides with) CDEntity_B
  → CDCollisionBuffer flushes at Priority 35
  → emits "collision" on BOTH entity buses
  → Arms on each entity react independently
```

Physics is spatial, not hierarchical. Collision layers/masks determine who collides. The buffer ensures all entities have finished moving before any collision is reported.

### Pattern 2: Entity → Game (Announcer)

```
Entity component calls game.bus_emit("score_gained", [100])
  → ScoreCard (Stage) receives it
  → Updates score
```

The **Announcer Pattern**: Any component can emit to the game bus to report entity state. This is a *pattern*, not a category. An Arm that announces runs at Priority 40. A Guts that announces runs at Priority 50.

### Pattern 3: Game → Entity (Controller)

```
Stage controller queries CDGroupRegistry for entities in a group
  → Iterates entities
  → Emits directly on each entity's bus
```

Controllers ARE the brain for formation entities. No entity-level Brain needed — entities just need Legs that respond to the signals controllers emit.

### Pattern 4: Entity → Entity (Non-Physics Relay)

```
Entity_A announces on game bus
  → Stage component (Controller) hears it
  → Controller emits on Entity_B's bus
```

Used when two entities need to communicate but aren't colliding. The game bus acts as a relay.

---

## 11. The On Hit / On Crash Pattern

V2 collision response follows a clean 2×2 matrix. Each cell is a single-purpose Arm:

| | Damage | Death (Deactivate) |
|---|---|---|
| **On Hit** (emit on *collider's* bus) | DamageOnHitArm | DeathOnHitArm |
| **On Crash** (emit on *own* bus) | DamageOnCrashArm | DeathOnCrashArm |

- **On Hit** = "I affect the other entity." Bullet hits enemy → damage goes to enemy.
- **On Crash** = "I affect myself." Bullet hits wall → bullet dies.
- **Classic bullet:** `DamageOnHitArm` + `DeathOnCrashArm` — damages target, dies on walls.
- **Joust variants** add comparative logic (velocity, Y position, custom property) with tiebreaker handling.

---

## 12. Spawning Patterns

### Two Worlds: Stage vs Entity

- **Stage spawners** (CDStageSpawner): Children of CDGame. Acquire entities from pools or instantiate fresh, place them in the world. Run at Priority 70.
- **Entity spawners** (GunSimpleArm, RingSpawnerArm): Components on CDEntities. Spawn projectiles from the entity's position. Run at their component's priority (usually ARM, Priority 40).

### CDStageSpawner Lifecycle

1. **Trigger:** Hears game bus signal (e.g., `"wave_start"` from WaveCard, `"game_play"` from CDGame).
2. **Acquire:** Gets entity from CDObjectPool (if configured) or instantiates fresh.
3. **Configure:** Sets position, velocity, property overrides.
4. **Activate:** Calls `entity.activate()` (pooled) or lets `_ready()` run (fresh).
5. **Done:** Emits `"wave_spawn_complete"` on game bus.

### CDObjectPool — Pool Reference IS the Toggle

- `CDObjectPool` export on spawners: `null` = instantiate fresh, non-null = acquire from pool.
- **Entity routes itself:** Callers always call `entity.deactivate()`. Entity checks `pool != null` internally.
- **Separate acquire and activate:** Spawner acquires, configures, THEN activates. Entity is fully configured before it "wakes up."

### WaveCard Relay Pattern

```
CDGame emits "game_play" → WaveCard hears → emits "wave_start(1)" → Spawners fire
GroupCountGoal emits "wave_cleared" → WaveCard hears → emits "wave_start(2)" → Spawners fire again
```

Multiple WaveCards with different signal names enable independent wave cycles (e.g., asteroid waves vs UFO waves).

---

## 13. Audio/Visual Architecture (Five-Layer System)

### Layer 1: CDVoice (Entity-Level Sound)
- Attached to CDEntities. Plays sounds on the entity bus.
- Handles procedural synthesis (SoundSynth ON_SIGNAL mode).
- Killed when entity deactivates.

### Layer 2: CDSpeaker (Scene-Level Sound)
- Attached to CDGame. Plays sounds on the game bus.
- Handles music, ambient, announcements.
- Survives entity lifecycle.

### Layer 3: CDSoundBank (Hybrid Pool)
- Pre-warmed pool of AudioStreamPlayer2D + AudioStreamGenerator pairs.
- CDVoice ON_SIGNAL routes through this pool instead of creating/destroying audio nodes.
- Centralized `_process` loop fills all active voices in one pass.

### Layer 4: CDFace (Entity Visuals)
- Draws entity appearance via `_draw()`.
- Responds to entity bus signals for visual changes (damage flash, shape change).
- CDFaceBinding: Maps entity bus signals to Face drawing methods (e.g., `"shape_changed"` → redraw polygon).

### Layer 5: CDProjection (Scene Visuals)
- Scene-level visual effects (CRT controller, screen shake, screen flash).
- Lives on CDGame, responds to game bus signals.

### CDShape — Shared Shape Contract

Both CDFace (visual drawing) and ShapeColliderGuts (physics collision) can consume the same shape data. A component like AsteroidGuts emits `"shape_changed"` with polygon points. Both CDFace and ShapeColliderGuts listen and apply — same data, two consumers, no coupling.

---

## 14. State Machine Patterns

### Group-as-State

Entities' group membership IS their state. An invader in group `"formation"` is in formation. When it dives, it's removed from `"formation"` and added to `"diving"`. The CDGroupRegistry tracks counts per group, emitting `"group_count_changed"` when counts shift.

- **No separate state variable needed.** Group membership is the state.
- **CDGroupRegistry is the single source of truth** for group counts.
- **Goals watch groups directly:** GroupCountGoal listens to `group_count_changed`.

### Controller Pattern

Stage controllers emit directly on entity buses. They ARE the brain for formation entities:

- SwarmGridStepController: Emits `move(Vector2)` to all entities in a group on a timer.
- SwarmBottomRowShootController: Emits `action(StringName)` to bottom-row entities.
- SwarmFormationController: Emits `move_to(Vector2)` to direct entities into formation slots.

Entities just need Legs that respond to the signals these controllers emit. No entity-level Brain needed.

### Resource-Driven Transitions

CDTransition custom resources define state machine transitions:

- **Triggers:** What signal causes the transition (CDTrigger — game bus signal name, group count threshold, timer).
- **Selectors:** What to do on transition (CDSelector — spawn, emit signal, change group, modify property).
- **Transitions are data**, not code. Configured in the editor.

---

## 15. The Pseudogrid Pattern

Block Drop / Tetris uses **physics AS the grid.** There is no grid data structure.

- **GridMovementLeg** steps entities by fixed cell size, checking physics queries at the target position.
- **GridAlignmentLeg** snaps entities to the pseudo-grid and corrects drift.
- **LineClearMonitor** scans rows via physics shape queries — if a row is full of settled cells, it's a line clear.
- **Everything is physics.** No arrays, no occupancy maps, no grid classes.

This works because:
1. Grid cells ARE entities with collision shapes.
2. Physics queries detect occupancy at any position.
3. The visual position IS the logical position — no coordinate transformation.

---

## 16. Object Pooling

### Design Principles

1. **Pool reference IS the toggle.** Null = instantiate fresh, non-null = acquire from pool.
2. **Entity routes itself.** `deactivate()` checks pool internally — pooled returns, non-pooled frees.
3. **Pool as parent.** Pooled entities live as children of CDObjectPool. Physics is spatial, `find_ancestor()` walks through pool nodes transparently.
4. **Separate acquire and activate.** Spawner acquires, configures, then activates.

### Pool Lifecycle Signals

| Signal | Direction | Purpose |
|--------|-----------|---------|
| `"entity_deactivating"` | Entity → Components | Reset state, disconnect from game bus |
| `"entity_activated"` | Entity → Components | Re-initialize, reconnect to game bus |

### Pool Compatibility

Pooled entities as children of CDObjectPool do not interfere with any signal pattern:

| Pattern | Mechanism | Pool Impact |
|---------|-----------|-------------|
| Entity ↔ Entity (physics) | Spatial collision layers | None |
| Entity → Game bus | `find_ancestor(CDGame)` | Walks through pool node |
| Game bus → Entity | CDGroupRegistry group queries | Group membership is on entity |
| Entity ↔ Entity (relay) | Announcer → Dictionary → Controller | Same path |

---

## 17. Naming Conventions

### File Naming

- **Scripts:** `snake_case.gd` — e.g., `damage_on_hit_arm.gd`, `health_pool_guts.gd`
- **Scenes:** `snake_case.tscn` — matches script name
- **Resources:** `snake_case.tres` — e.g., `wall_kick_resource.gd`

### Scene Organization (V2)

```
Godot/Scripts/
├── Core/       — Engine components (CDEntity, CDGame, CDComponent2D, etc.)
├── Brains/     — Intent generators (Priority 10)
├── Legs/       — Movement executors (Priority 20)
├── Arms/       — World-affecting components (Priority 40)
├── Guts/       — Internal state trackers (Priority 50)
├── Faces/      — Visual representation (Priority 60)
├── Voices/     — Entity-level sound
├── Stage/      — Game-level components (Priority 70)
├── Speakers/   — Scene-level sound
├── Spawners/   — Spawn components
└── Resources/  — Custom resources (WallKickResource, CDTransition, etc.)
```

### Signal Naming

- **Entity bus:** Imperative verb or noun — `&"move"`, `&"collision"`, `&"take_damage"`, `&"zero_health"`
- **Game bus:** Past tense or event noun — `&"score_gained"`, `&"wave_cleared"`, `&"lives_depleted"`
- **Lifecycle:** `&"entity_deactivating"`, `&"entity_activated"`, `&"request_deactivate"`

### Group Naming

- Plural nouns: `&"enemies"`, `&"player"`, `&"balls"`, `&"bricks"`, `&"formation"`, `&"diving"`
- Groups ARE state: an entity in `"formation"` is in formation state.

---

## 18. V1 Preservation

The entire V1 architecture moves to `Godot/v1/`. V2 lives at `Godot/` root. Both architectures coexist in the codebase — the itch.io demo runs on V1, the desktop/Steam version targets V2.

---

## Quick Reference: Component Count by Category

| Category | Priority | Name | Count (V2) | Key Components |
|----------|----------|------|------------|----------------|
| Core | varies | — | ~12 | CDEntity, CDGame, CDComponent2D, CDStageComponent2D, CDCollisionBuffer, CDGroupRegistry, CDCollisionMatrix, CDInputRouter, CDEnums, CDObjectPool |
| Registry | 5 | REGISTRATION | ~1 | CDGroupRegistry |
| Input | 8 | INPUT | ~1 | CDInputRouter |
| Brain | 10 | INTENT | 14 | PlayerMove/Aim/ActionBrain, ChaseNearestBrain, FleeNearestBrain, AimAtNearestBrain, OrbitBrain, ShootWhenAimedBrain, TimedStepBrain, PatrolPathBrain, RandomSweepBrain, IdleWanderBrain, FormationBrain, DiveBombBrain |
| Legs | 20 | STEERING | 18 | EightWayWalk, AccelDecel, EngineThrust, FrictionLinear/Static, SteeringLeg, BoomerangLeg, RotationDirect/Target, GridMovement/Rotation/Drop/Alignment, ScreenWrap/Clamp, PathFollower, SmoothTo |
| Entity | 30 | PHYSICS | ~1 | CDEntity (velocity resolution + move_and_collide) |
| Buffer | 35 | COLLISION | ~1 | CDCollisionBuffer |
| Arms | 40 | INTERACTION | 11 | DamageOnHit/CrashArm, DeathOnHit/CrashArm, DamageOnJoust/DeathOnJoustArm, ScoreOnCollision/DeathArm, AngledDeflectorArm, PushbackArm, StatusEffectArm, GunSimpleArm |
| Guts | 50 | STATE | 12 | HealthPool, DieAtZeroHealth, Points, DieOnTimer, DieOffscreen, ImpulseReceiver, ShieldPool, ResourcePool, Stun, LockDetector, TSpinDetector, ShapeCollider |
| Face | 60 | VISUAL | ~5 | VectorFace, FaceBindings, CDProjection |
| Voice/Speakers | 65 | AUDIO | ~6 | CDVoice variants (entity-level), CDSpeaker variants (scene-level) |
| Stage | 70 | RULES | 14 | CDCueCard, ScoreCard, MultiplierCard, LivesCard, TimerCard, WaveCard, CDMark, MobileMark, CountMark, TimedMark, GroupCountGoal, ScoreThresholdGoal, LivesDepletedGoal, TimerExpiredGoal |
| Spawners | 40/70 | INTERACTION/RULES | ~6 | Entity spawners (GunSimpleArm, Priority 40), Stage spawners (CDStageSpawner + variants, Priority 70) |
+++++++ REPLACE