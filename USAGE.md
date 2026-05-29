# USAGE — CD50 Composable Architecture

**Complete guide to patterns, anti-patterns, and code quality guidelines for the CD50 component system.**  
**Architecture version:** V2 (Plans 19–26)  
**Canonical reference:** `planning/V2 Rules.md`

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [The Signal Bus System](#2-the-signal-bus-system)
3. [Component Lifecycle](#3-component-lifecycle)
4. [Per-Category Usage Guide](#4-per-category-usage-guide)
5. [Core Patterns](#5-core-patterns)
6. [Anti-Patterns](#6-anti-patterns)
7. [Code Quality Guidelines](#7-code-quality-guidelines)
8. [Extending the Architecture](#8-extending-the-architecture)

---

## 1. Architecture Overview

### The Three Rules

Every component in CD50 follows three principles without exception:

1. **Composition over inheritance.** Entities are blank slates (`CDEntity extends CharacterBody2D`). All behavior comes from attached components. No game-specific scripts exist anywhere in the project.
2. **Signals, not calls.** Components never call methods on other components. They emit signals and let the recipient decide what to do. This eliminates coupling and enables runtime rewiring.
3. **Single-purpose components.** Each component does one thing. A Brain generates intent. A Leg moves. An Arm affects the world. A Guts tracks internal state. If a component is doing two things, split it.

### The Priority Pipeline

Every frame, components execute in a deterministic priority cascade. Lower priority = runs earlier. This eliminates frame-ordering bugs — every component knows exactly when it runs relative to every other component, regardless of scene tree position.

| Priority | Name | Category | What Runs Here | Why |
|----------|------|----------|----------------|-----|
| 5 | REGISTRATION | Registry | CDGroupRegistry dirty flush + `group_count_changed` emission | World state must be current before anyone reads it |
| 8 | INPUT | Input | CDInputRouter — processes raw input, routes to player brains | Input must be ready before brains read it |
| 10 | INTENT | Brain | Intent generators (PlayerMoveBrain, AIChaseBrain, etc.) | Decide what to do |
| 20 | STEERING | Legs | Movement executors (DirectMovementLeg, EngineLeg, etc.) | Calculate how to get there — submit velocity/position requests |
| 30 | PHYSICS | Entity | CDEntity resolves velocity accumulator, applies `move_and_collide()` | Actually move |
| 35 | COLLISION | Buffer | CDCollisionBuffer flushes buffered collisions | All entities have moved before collisions are reported |
| 40 | INTERACTION | Arm | Arms affect the outside world (damage, score, forces) | React to collisions, deal damage |
| 50 | STATE | Guts | Internal state (health, timers, resources) | Process damage, check for death |
| 60 | VISUAL | Face | Visual updates (vector drawing, sprite swaps, effects) | Visuals reflect final state |
| 65 | AUDIO | Voice | Sound components (entity-level and scene-level) | Audio reflects final state — after visuals |
| 70 | RULES | Stage | Game-level logic (Goals, CueCards, Directors, Spawners) | Score tracking, win/lose conditions, spawning |
| 99 | CLEANUP | — | Entity cleanup, pool return, group removal | All priority processing complete before any entity is removed |

**Mental model:**

```
REGISTRATION → INPUT → INTENT → STEERING → PHYSICS → COLLISION → INTERACTION → STATE → VISUAL → AUDIO → RULES → CLEANUP
 sync groups   read     "go!"    calc       moves     "you hit    damage       health   draw it   play it   score it   remove dead
                input             speed +    the       something"  to target    drops    on screen out loud  check win  return pool
                                   direction  thing
```

### Two Worlds: Entity Components vs Game Components

CD50 has two distinct component hierarchies:

**Entity Components** — Children of `CDEntity`. Run on every entity, every frame. Use the entity bus for high-frequency communication.

| Base Class | Extends | Has `entity` | Has `game` | Priority from category |
|------------|---------|-------------|-----------|----------------------|
| `CDComponent2D` | `Node2D` | Yes | Yes | Yes |

Categories: Brains (10), Legs (20), Arms (40), Guts (50), Faces (60), Voices (65).

**Game Components** — Children of `CDGame`. Manage game-level state, UI, spawning. Use the game bus for low-frequency events.

| Base Class | Extends | Has `entity` | Has `game` | Priority |
|------------|---------|-------------|-----------|----------|
| `CDStageComponent2D` | `Node2D` | No | Yes | 70 (RULES) |
| `CDCueCard` | `Control` | No | Yes | 70 (RULES) |
| `CDMark` | `Area2D` | No | Yes | Event-driven |

Categories: Cards, Goals, Directors, Marks, Projectors, Speakers, Trapdoors — all Stage (70).

---

## 2. The Signal Bus System

CD50 uses a hybrid signal system: two mechanisms chosen for what each is best at.

### Entity Bus (on CDEntity)

- **Mechanism:** Godot's native `add_user_signal()` — C++ backed, high performance
- **Characteristics:** Fixed signal types, high frequency (per-entity per-frame), typed parameter signatures
- **Best for:** The hot path — INTENT → STEERING → PHYSICS → COLLISION → INTERACTION → STATE → VISUAL pipeline
- **Registration:** `entity.ensure_signal("signal_name", [param_types])` — idempotent, warns on type mismatch
- **Connection:** `entity.connect("signal_name", callable)` — standard Godot signal connection

**Canonical signal types:**

| Type | Signature | Semantic | Used By |
|------|-----------|----------|---------|
| Directional | `(Vector2)` | Normalized direction — "go this way" | Brains → Legs |
| Positional | `(Vector2)` | World-space coordinates — "go to this point" | Brains → Legs |
| Action | `(StringName)` | Named action trigger (e.g., `&"shoot"`) | Brains → Arms |
| Action End | `(StringName)` | Named action release | Brains → Arms |
| Rotate | `(float)` | Spin direction (-1.0, 0.0, 1.0) | Brains → Legs |
| Curve | `(Curve2D, float)` | Path to follow and speed | Brains → Legs |
| Drop | `(int)` | Number of grid cells to drop | Brains → Legs |

**Standard entity bus signals:**

| Signal | Signature | Emitted By |
|--------|-----------|------------|
| `"collision"` | `(CDEntity, Vector2)` | CDCollisionBuffer at Priority 35 |
| `"request_deactivate"` | `()` | Any component requesting entity death |
| `"entity_deactivating"` | `()` | CDEntity during cleanup at Priority 99 |
| `"entity_activated"` | `()` | CDEntity on pool reuse activation |
| `"moved"` | `()` | CDEntity after position changes |
| `"rotated"` | `()` | CDEntity after rotation changes |
| `"shape_changed"` | `(PackedVector2Array)` | Procedural shape generators |

### Game Bus (on CDGame)

- **Mechanism:** Dictionary-based — `Dictionary[StringName, Array[Callable]]`
- **Characteristics:** Configurable signal names, low frequency (a few dozen events/frame total), Variant args
- **Best for:** Entity-to-game communication, game state events (score, lives, waves)
- **No registration needed:** `bus_emit()` with no connections = Dictionary miss = no-op. Zero boilerplate.

**API:**

| Method | Purpose |
|--------|---------|
| `game.bus_emit("signal_name")` | Broadcast with no args |
| `game.bus_emit("signal_name", [arg1])` | Broadcast with one arg |
| `game.bus_emit("signal_name", [arg1, arg2])` | Broadcast with multiple args |
| `game.bus_connect("signal_name", callable)` | Subscribe to a game bus signal |

**Performance note:** `bus_emit()` checks arg count to avoid Array boxing overhead. 0-arg and 1-arg emissions use `callable.call()` directly. `callv()` is only used for 2+ args. Since most game bus signals are 0-arg or 1-arg, this eliminates most allocation overhead.

**Standard game bus events:**

| Signal | Args | Emitted By | Consumed By |
|--------|------|------------|-------------|
| `"game_play"` | none | CDGame state machine | WaveCard, spawners |
| `"game_over"` | `[GameResult]` | CDGame.end_game() | CueCards, orchestrator |
| `"group_count_changed"` | `[StringName, int]` | CDGroupRegistry | GroupCountGoal |
| `"score_gained"` | `[int]` | ScoreOnCollisionArm, ScoreOnDeathArm | ScoreCard |
| `"lives_changed"` | `[int]` | LivesCard | UI, goals |
| `"lives_depleted"` | none | LivesCard | Game over goals |
| `"wave_start"` | `[int]` | WaveCard | Trapdoors |
| `"wave_cleared"` | none | GroupCountGoal | WaveCard |

### Why Hybrid?

Native signals on the game bus would require `bus_ensure()` registration boilerplate for every configurable signal name, with `TYPE_NIL` (Variant) args anyway — no type safety benefit. The Dictionary eliminates all registration code at negligible performance cost for game-level event frequencies.

### Cross-Bus Communication Patterns

**Pattern 1: Entity → Entity (Physics)**

```
CDEntity_A collides with CDEntity_B
  → CDCollisionBuffer flushes at Priority 35
  → emits "collision" on BOTH entity buses
  → Arms on each entity react independently
```

Physics is spatial, not hierarchical. Collision layers/masks determine who collides. The buffer ensures all entities have finished moving before any collision is reported.

**Pattern 2: Entity → Game (Announcer)**

```
Entity component calls game.bus_emit("score_gained", [100])
  → ScoreCard (Stage) receives it
  → Updates score
```

Any component can emit to the game bus to report entity state. This is a *pattern*, not a category — an Arm that announces runs at Priority 40, a Guts that announces runs at Priority 50.

**Pattern 3: Game → Entity (Controller)**

```
Stage controller queries CDGroupRegistry for entities in a group
  → Iterates entities
  → Emits directly on each entity's bus
```

Controllers ARE the brain for formation entities. No entity-level Brain needed — entities just need Legs that respond to the signals controllers emit.

**Pattern 4: Entity → Entity (Non-Physics Relay)**

```
Entity_A announces on game bus
  → Stage component (Controller) hears it
  → Controller emits on Entity_B's bus
```

Used when two entities need to communicate but aren't colliding. The game bus acts as a relay.

---

## 3. Component Lifecycle

### Two-Phase Initialization

Entity components use a two-phase init to solve the "other components don't exist yet" problem:

**Phase 1: `_ready()`**
- `super._ready()` resolves `entity` and `game` references
- Set `component_category` for priority
- Register entity bus signals via `entity.ensure_signal()`
- **Do NOT connect to signals here** — other components may not have registered their signals yet

**Phase 2: `_on_initialize()` (called deferred, after all `_ready()` calls complete)**
- Connect to entity bus signals
- Connect to game bus signals
- Read sibling component state
- **This is where the component "wakes up"**

Stage components (CDStageComponent2D, CDCueCard) often don't need `_on_initialize()` — they connect to the game bus (Dictionary-based, no ordering issues) directly in `_ready()` or via `call_deferred("_on_initialize")`.

### Two-Phase Deactivation

When `"request_deactivate"` is emitted (by an Arm during collision flush, or by a Guts during state processing):

**Phase 1: Immediate (during Priority 35–50 processing)**

1. `deactivate()` checks `state == ACTIVE`, returns if not
2. Sets `state = DEACTIVATING` — guards prevent double-deactivation
3. Calls `set_physics_process(false)` — entity won't move next frame
4. Queues `call_deferred("_complete_deactivation")` — cleanup deferred to end of frame

The entity remains fully functional during this phase: components stay connected, groups stay registered, entity stays visible. This ensures:
- **Symmetric collisions work correctly** — both entities' arms fire during the buffer flush
- **Group counts remain accurate** through Priority 70 (Rules)
- **Death visual effects** can render at Priority 60 (Faces) on the same frame

**Phase 2: Deferred Cleanup (Priority 99 — end of frame)**

1. Disables collision shapes via `set_deferred("disabled", true)`
2. Emits `"entity_deactivating"` — components disconnect signals, reset internal state
3. Removes entity from groups — marks GroupRegistry dirty (caught at Priority 5 next frame)
4. Returns to pool (`pool.release(self)`) or frees (`queue_free()`)

### Pool Lifecycle Hooks

| Signal | Direction | Override Purpose |
|--------|-----------|-----------------|
| `"entity_deactivating"` | Entity → Components | Reset all internal state, disconnect all signals |
| `"entity_activated"` | Entity → Components | Re-initialize, reconnect signals, restore defaults |

**Critical:** Every component that holds runtime state MUST reset it in `_on_entity_deactivating()`. Pooled entities re-enter the world with whatever state they left with. See [The Leaky Pool](#the-leaky-pool).

---

## 4. Per-Category Usage Guide

### Brains — INTENT (Priority 10)

**Role:** Generate intent from input or AI. Never touch velocity, never move the entity, never affect other entities.

**Base class:** `CDComponent2D` (via `CDEntityComponent`)

**Standard lifecycle template:**

```gdscript
func _ready():
    component_category = CDEnums.ComponentCategory.INTENT
    super._ready()

func _on_initialize():
    # Ensure all signals this brain emits exist on the entity
    entity.ensure_signal("move", [TYPE_VECTOR2])
    # Connect input sources
    if game.input_router:
        game.input_router.connect("input_move", _on_input_move)

func _physics_process(_delta):
    # Only emit intent signals — never touch velocity
    entity.emit_signal("move", direction)

func _on_entity_deactivating():
    super._on_entity_deactivating()
    if game.input_router and game.input_router.is_connected("input_move", _on_input_move):
        game.input_router.disconnect("input_move", _on_input_move)
    # Reset internal state
```

**Must-Includes:**
1. Set `component_category = INTENT` in `_ready()`
2. Call `entity.ensure_signal()` for all emit signals in `_on_initialize()`
3. Emit intent signals on the **entity** (not `self`)
4. Disconnect all connections in `_on_entity_deactivating()` with `is_connected()` guards
5. Reset internal state in `_on_entity_deactivating()`

**Signal types brains emit:**

| Signal | Type | Consumer |
|--------|------|----------|
| `move(Vector2)` | Directional | Legs |
| `move_to(Vector2)` | Positional | Legs |
| `aim(Vector2)` | Directional | Legs/Faces |
| `action(StringName)` | Named action | Arms |
| `action_end(StringName)` | Named release | Arms |
| `rotate(float)` | Spin | Legs |

**Brain subcategories:**

| Subcategory | Description | Examples |
|-------------|-------------|---------|
| Player | Driven by CDInputRouter | PlayerMoveBrain, PlayerAimBrain, PlayerActionBrain |
| AI Action | AI-driven firing/aiming | AIAimAtNearestBrain, AIRepeatActionBrain, AITractorBeamBrain |
| AI Movement | AI-driven navigation | AIChaseBrain, AIFleeBrain, AIOrbitBrain, AIFormationBrain, AIDiveBombBrain, AIPathMoveBrain, AIRandomSweepBrain, AITimedStepBrain, AIIdleWanderBrain |

**AI brain features:**
- `update_interval` — throttle how often targeting recalculates (0 = every frame)
- `targeting_noise` — add random offset to target position for imprecision
- `target_groups` — which entity groups to target
- Patrol modes: `LOOP`, `RETRACE`, `ONCE` (via `CDEnums.PatrolMode`)

**Constraint:** A Brain's `_physics_process` should only emit signals and update internal state. No direct mutation of entity properties. If a Brain is touching `velocity` or calling `request_velocity_set()`, split it into a Brain + Leg.

---

### Legs — STEERING (Priority 20)

**Role:** Execute movement from intent signals. Never generate intent. Legs respond to signals, they don't create them.

**Base class:** `CDComponent2D` (via `CDEntityComponent`)

**Standard lifecycle template:**

```gdscript
func _ready():
    component_category = CDEnums.ComponentCategory.STEERING
    super._ready()

func _on_initialize():
    entity.ensure_signal("move", [TYPE_VECTOR2])
    for sig in move_signals:
        entity.connect(sig, _on_move)

func _on_move(direction: Vector2):
    _input_direction = direction

func _physics_process(delta):
    if _input_direction != Vector2.ZERO:
        entity.request_velocity_set(_input_direction * speed)
    else:
        entity.request_velocity_set(Vector2.ZERO)
    _input_direction = Vector2.ZERO  # consumed

func _on_entity_deactivating():
    super._on_entity_deactivating()
    for sig in move_signals:
        if entity.is_connected(sig, _on_move):
            entity.disconnect(sig, _on_move)
    _input_direction = Vector2.ZERO
```

**Must-Includes:**
1. Set `component_category = STEERING` in `_ready()`
2. Use `@export_group("Listen Signals")` for input signal arrays
3. Call `entity.ensure_signal()` before connecting in `_on_initialize()`
4. Disconnect all connections with validity guards in `_on_entity_deactivating()`
5. Reset all runtime state in `_on_entity_deactivating()` (for object pool reuse)

**Entity Request API:**

| Method | Behavior |
|--------|----------|
| `request_velocity_set(vel)` | Override velocity entirely — only one `set` wins per frame |
| `request_velocity_add(vel)` | Add to current velocity — multiple `add` Legs coexist |
| `request_angular_set(rad/s)` | Override angular velocity |
| `request_rotation_set(rad)` | Set rotation directly |
| `request_rotation_add(rad)` | Add to current rotation |
| `request_position_set(pos)` | Teleport to position (bypasses velocity) |
| `request_position_add(offset)` | Shift position by offset (bypasses velocity) |

**Leg classification:**

| Type | API | Behavior | Examples |
|------|-----|----------|---------|
| Directional Setters | `request_velocity_set()` | Immediate direction, no momentum | DirectMovementLeg, DirectRotationLeg, GridMovementLeg, GridRotationLeg |
| Directional Adders | `request_velocity_add()` | Accumulated force, momentum persists | AccelerationMovementLeg, EngineLeg |
| Positional Setters | `request_velocity_set()` | Immediate toward target | DirectTargetLeg, TargetRotationLeg |
| Positional Adders | `request_velocity_add()` | Accumulated toward target | AccelerationTargetLeg |
| Utility Modifiers | Various | Friction, wrapping, alignment | LinearFrictionLeg, StaticFrictionLeg, ScreenWrapLeg, BoomerangLeg, GridAlignmentLeg, GridDropLeg |

**Setter vs Adder rule:** Only one `set`-based Leg should be on an entity. Multiple `add`-based Legs coexist naturally. Pair adder Legs with friction Legs to cap speed and provide deceleration.

**Position legs bypass velocity:** GridMovementLeg, GridDropLeg use the position API — no friction, no accumulator conflicts.

---

### Arms — INTERACTION (Priority 40)

**Role:** Affect the game state OUTSIDE the entity. Deal damage, announce score, apply forces, spawn projectiles. Never modify the entity's own velocity or internal health (that's Guts territory).

**Base class:** `CDComponent2D` (via `CDEntityComponent`)

**Standard lifecycle template:**

```gdscript
func _ready():
    component_category = CDEnums.ComponentCategory.INTERACTION
    super._ready()

func _on_initialize():
    for sig in collision_signals:
        entity.ensure_signal(sig, [TYPE_OBJECT, TYPE_VECTOR2])
        entity.connect(sig, _on_collision)

func _on_collision(collider: CDEntity, normal: Vector2):
    if not _is_valid_target(collider):
        return
    if is_instance_valid(collider) and collider.has_signal("take_damage"):
        collider.emit_signal("take_damage", damage_amount)

func _on_entity_deactivating():
    super._on_entity_deactivating()
    for sig in collision_signals:
        if entity.is_connected(sig, _on_collision):
            entity.disconnect(sig, _on_collision)
```

**Must-Includes:**
1. Set `component_category = INTERACTION` in `_ready()`
2. Connect listen signals in `_on_initialize()`
3. Disconnect in `_on_entity_deactivating()` with `is_connected()` guards
4. Use group filtering for collision/interaction arms
5. Support object pools for spawn-based arms

**Signal convention:** Arms use `@export_group("Listen Signals")` and `@export_group("Emit Signals")` — all signal names configurable via exports.

**Group filtering:**
- Empty array `[]` = affect everything (no filter, trust the collision matrix)
- Non-empty = only affect entities in at least one listed group
- Uses `_is_valid_target(collider)` / `_is_valid_source(collider)` helpers

**Arm subcategories:**

| Subcategory | Count | Description |
|-------------|-------|-------------|
| Collision Reactions | 9 | Respond to collision signals (damage, death, pushback, score, status) |
| Death Reactions | 2 | Respond to entity death (score, spawn) |
| Triggered Arms | 2 | Fire on active entity input (gun, tractor beam) |
| Powerup Arms | 2 | Powerup delivery/reception |
| Other | 1 | Specialized (piece splitting) |

**The On Hit / On Crash matrix** (see [Core Patterns](#the-on-hit--on-crash-pattern)):

| | Damage | Death (Deactivate) |
|---|---|---|
| **On Hit** (emit on *collider's* bus) | DamageOnHitArm | DeathOnHitArm |
| **On Crash** (emit on *own* bus) | DamageOnCrashArm | DeathOnCrashArm |

**Classic bullet:** `DamageOnHitArm` + `DeathOnCrashArm` — damages target, dies on walls.

**Joust variants** add comparative logic (velocity, Y position, custom property) with tiebreaker handling.

---

### Guts — STATE (Priority 50)

**Role:** Track INTERNAL entity state. Health, timers, resources, lock detection, shape. Purely self-centered — don't care about the outside world except for signals telling them to update.

**Base class:** `CDComponent2D` (via `CDEntityComponent`)

**Standard lifecycle template:**

```gdscript
var health: int = max_health

func _ready():
    component_category = CDEnums.ComponentCategory.STATE
    super._ready()

func _on_initialize():
    entity.ensure_signal("take_damage", [TYPE_INT])
    entity.ensure_signal("zero_health")
    entity.connect("take_damage", _on_take_damage)

func _on_take_damage(amount: int):
    health = max(0, health - amount)
    entity.emit_signal("health_changed", health)
    if health <= 0:
        entity.emit_signal("zero_health")

func _on_entity_deactivating():
    super._on_entity_deactivating()
    if entity.is_connected("take_damage", _on_take_damage):
        entity.disconnect("take_damage", _on_take_damage)
    health = max_health  # RESET for pool reuse

func _on_entity_activated():
    health = max_health  # RESTORE on pool reuse
```

**Must-Includes:**
1. Set `component_category = STATE` in `_ready()`
2. Use `@export_group("Listen Signals")` and `@export_group("Emit Signals")` consistently
3. Call `entity.ensure_signal()` before connecting in `_on_initialize()`
4. Disconnect all connections with validity guards in `_on_entity_deactivating()`
5. **Reset all runtime state** in `_on_entity_deactivating()` (for object pool reuse)
6. Implement `_on_entity_activated()` if the guts manages timers or physics processing

**Guts subcategories:**

| Subcategory | Count | Description | Examples |
|-------------|-------|-------------|---------|
| Pools | 3 | Numeric resources with depletion/regen | HealthpoolGuts, ShieldpoolGuts, ResourcepoolGuts |
| Death | 4 | Entity termination conditions | DieAtZeroHealthGuts, DieOffscreenGuts, DieOnTimerGuts, DieOutOfBoundsGuts |
| Physics | 3 | Collision and force handling | DeflectorBounceGuts, ImpulseReceiverGuts, ShapeColliderGuts |
| Detection | 2 | Entity sensing | LockDetectorGuts, VisionConeGuts |
| Input | 2 | Signal type adaptation | KBMGuts, MoveAdapterGuts |
| Game Logic | 4 | Rules, scoring, status | AnnouncerGuts, PointsGuts, StunGuts, TSpinDetectorGuts, TimerGuts |

**Pool pattern:** Starting value defaults to max when set to -1. All pools emit change signals for UI binding.

**Death pattern:** All use `entity.deactivate()` or emit `"request_deactivate"`. Activation delays prevent premature death on spawn.

**Adapter pattern:** Input guts (KBMGuts, MoveAdapterGuts) are pure signal translators with no internal state. They bridge Brains that emit one signal type to Legs that expect another.

---

### Faces — VISUAL (Priority 60)

**Role:** Visual representation. Draws shapes, renders effects, updates appearance. Reads entity state and reflects it visually. **A Face bug should never change game outcome.**

**Base class:** `CDComponent2D` (via `CDEntityComponent`)

**Standard lifecycle template:**

```gdscript
@tool
extends CDEntityComponent

func _ready():
    component_category = CDEnums.ComponentCategory.VISUAL
    super._ready()

func _on_initialize():
    entity.ensure_signal("shape_changed", [TYPE_PACKED_VECTOR2_ARRAY])
    entity.connect("shape_changed", _on_shape_changed)
    queue_redraw()

func _process(_delta):
    if Engine.is_editor_hint():
        queue_redraw()

func _draw():
    # Godot 2D drawing API
    draw_colored_polygon(points, color)

func _on_shape_changed(points: PackedVector2Array):
    _points = points
    queue_redraw()

func _on_entity_deactivating():
    super._on_entity_deactivating()
    if entity.is_connected("shape_changed", _on_shape_changed):
        entity.disconnect("shape_changed", _on_shape_changed)
```

**Must-Includes:**
1. Add `@tool` annotation for editor preview
2. Set `component_category = VISUAL` in `_ready()`
3. Add setter functions on exports that call `queue_redraw()` for live preview
4. Add `_process()` that calls `queue_redraw()` when `Engine.is_editor_hint()`
5. Ensure all entity signals exist with `entity.ensure_signal()` before connecting
6. Disconnect all connections in `_on_entity_deactivating()`

**The Binding System:** `VectorFace`, `PolygonFace`, and `SpriteFace` share a binding pattern using `CDFaceBinding` resources:

| Binding Property | Purpose |
|-----------------|---------|
| `signal_name` | Entity signal that triggers the frame change |
| `frame_index` | Which shape/texture to switch to |
| `restore_after` | Seconds before reverting to `default_frame` (0 = no restore) |

**Face types:**

| Face | Method | Use For |
|------|--------|---------|
| `VectorFace` | `draw_polyline()` | Open/closed vector shapes |
| `PolygonFace` | `draw_colored_polygon()` | Filled polygon shapes |
| `SpriteFace` | Child `Sprite2D` | Texture frames |
| `VectorEngineFace` | Procedural drawing | Single exhaust flame |
| `VectorThrusterFace` | Procedural drawing | 4 diagonal thruster flames |
| `DeathEffectFace` | Spawns CDEffect | Death visual effects |
| `MenacingVectorFace` | Extends VectorFace | CRT menace effects (glitch, static, glow, scan, corrupt) |

---

### Voices — AUDIO (Priority 65)

**Role:** Entity-level audio. Plays procedural sounds through `CDSoundBank`. **A Voice bug should be silent, not broken.**

**Base class:** `CDComponent2D` (via `CDEntityComponent`), always `@tool`

**Must-Includes:**
1. Add `@tool` annotation
2. Find `CDSoundBank` via `game.find_child("CDSoundBank")` in `_on_initialize()`
3. Use `entity.ensure_signal()` before connecting trigger signals
4. Disconnect in `_on_entity_deactivating()` with validity guards
5. Deregister from sound bank on deactivation / exit tree
6. Include preview infrastructure for editor testing

**Voice types:**

| Voice | Trigger | API | Use For |
|-------|---------|-----|---------|
| `SoundVoice` | One-shot on signal | `_bank.play_one_shot()` | Hit sounds, pickups, alerts |
| `ContinuousVoice` | Start/stop on signals | `_bank.start_continuous()` / `stop_continuous()` | Drones, hums, alarms |

**Key dependencies:** `CDSoundBank`, `CDSoundDef`, `CDNote`, `CDUtilities` (freq_from_note, wave_sample), `CDEnums.WaveShape`, `CDEnums.Effect`, `CDEnums.Semitone`.

**Signature system:** Sounds are identified by `"{wave_shape}_{effect}_{note}"`. Multiple entities playing the same signature share one audio stream.

---

### Stage Components — RULES (Priority 70)

**Role:** Game-level logic. Score tracking, win/lose conditions, wave management, spawning, UI. The only category that should know about "game" concepts like score, lives, victory, defeat.

#### Cards — Game-State Display

**Base class:** `CDCueCard extends Control`

```gdscript
func _ready():
    super._ready()
    # Initialize state
    _update_label()
    call_deferred("_on_initialize")

func _on_initialize():
    for sig in listen_signals:
        game.bus_connect(sig, _on_event)

func _on_event(args):
    # Update state, update label, emit to game bus
    _update_label()
```

**Cards:** ScoreCard, LivesCard, TimerCard, WaveCard. All track state and update labels.

#### Goals — Win/Lose Conditions

**Base class:** `CDStageComponent2D`

Fire-once-or-repeatable triggers that compare observed values against thresholds using `CDEnums.CountComparison` (`LESS_THAN`, `EQUAL_TO`, `GREATER_THAN`, `LESS_OR_EQUAL`, `GREATER_OR_EQUAL`).

**Goals:** GroupCountGoal (entity count condition), ScoreThresholdGoal (score threshold).

#### Directors — Game-Level Controllers

**Base class:** `CDStageComponent2D`

Observe and command groups of entities through the game bus and group registry. Command entities via their own signals (`entity.ensure_signal()`, `entity.emit_signal()`). Guard all entity access with `is_instance_valid()`.

**Directors:** FormationDirector, StageDirector, StateDirector, SwarmShootingDirector, SwoopDirector.

#### Marks — Spatial Detection Zones

**Base class:** `CDMark extends Area2D`

Event-driven spatial triggers. Auto-creates collision shapes, filters by groups, emits on game bus. Not a CDComponent2D — Area2D inheritance is required for physics detection.

**Marks:** CDMark (base), CountMark, MobileMark, OccupancyMark, SafeZoneMark, TimedMark.

#### Trapdoors — Stage Spawners

**Base class:** `CDStageTrapdoor` (non-virtual base, override virtual methods)

Trigger → Queue → Stagger → Spawn lifecycle with telefrag and safe zone support. Override `_get_spawn_count()`, `_get_spawn_position()`, `_get_spawn_scene()`.

**Trapdoors:** PointTrapdoor, EdgeTrapdoor, GridTrapdoor.

#### Projectors — Visual Post-Processing

**Base class:** `CDGameComponent` or `Control`

Screen-level visual effects. Use `_process()` (not `_physics_process()`) for visual animations.

**Projectors:** CRTProjector (CRT post-processing), CreditProjection (music credits overlay).

#### Speakers — Game-Level Audio

**Base class:** `CDStageComponent2D`

Game-level audio: synthesized one-shots, continuous tones, music playlist with crossfade.

**Speakers:** SoundSpeaker, ContinuousSpeaker, MusicSpeaker.

---

## 5. Core Patterns

### The On Hit / On Crash Pattern

V2 collision response follows a clean 2×2 matrix. Each cell is a single-purpose Arm:

| | Damage | Death (Deactivate) |
|---|---|---|
| **On Hit** (emit on *collider's* bus) | `DamageOnHitArm` | `DeathOnHitArm` |
| **On Crash** (emit on *own* bus) | `DamageOnCrashArm` | `DeathOnCrashArm` |

- **On Hit** = "I affect the other entity." Bullet hits enemy → damage goes to enemy.
- **On Crash** = "I affect myself." Bullet hits wall → bullet dies.
- **Joust variants** add comparative logic (velocity, Y position, custom property) with tiebreaker handling.
- **Classic bullet:** `DamageOnHitArm` + `DeathOnCrashArm` — damages target, dies on walls.

### The Collision Handler Pattern

**When to use:** Frame-perfect physics remainder resolution ONLY when the default collision response (SLIDE/BOUNCE/STOP) cannot produce the correct result because the response depends on what was hit.

**The guardrail — ask yourself:**

> *"Should this be a Leg component?"*

| Concern | Component Type | API | Timing |
|---------|---------------|-----|--------|
| "Move in this direction" | Leg | `request_velocity_set/add()` | Before physics (Priority 20) |
| "When I hit THIS, bounce THAT way" | Collision Handler Guts | `register_collision_handler()` | During physics (Priority 30) |
| "Deal damage on collision" | Arm | Entity bus signals | After collision buffer (Priority 35) |

**API:**

```gdscript
# Registration
entity.register_collision_handler(target_groups, handler_callable)
entity.unregister_collision_handler(handler_callable)

# Handler signature: func(collision: KinematicCollision2D) -> Vector2
#   - Receives the collision data
#   - Modifies entity.velocity directly (this IS physics resolution)
#   - Returns remaining movement vector
```

**Layer bitmask resolution:** Collision handlers resolve group names to layer bitmasks at registration time for zero-cost hot path matching — no string comparisons during `_physics_process`.

**Handler precedence:** Specific handlers first (keyed to groups) → catch-all handlers (empty groups) → default collision response.

### The Announcer Pattern

Any component can emit to the game bus to report entity state. An Arm that announces runs at Priority 40. A Guts that announces (AnnouncerGuts) runs at Priority 50. The announcer bridges entity bus signals to game bus signals, optionally filtered by qualifying groups.

### The Controller Pattern

Stage controllers emit directly on entity buses. They ARE the brain for formation entities — no entity-level Brain needed. Entities just need Legs that respond to the signals controllers emit.

### Group-as-State

Entity group membership IS entity state. An invader in group `"formation"` is in formation. When it dives, it's removed from `"formation"` and added to `"diving"`. `CDGroupRegistry` is the single source of truth for group counts, emitting `"group_count_changed"` when counts shift.

- No separate state variable needed
- Goals watch groups directly (GroupCountGoal)
- StateDirector manages transitions via `CDTransition` resources

### The Pseudogrid Pattern

Block Drop / Tetris uses **physics AS the grid.** There is no grid data structure.

- `GridMovementLeg` steps entities by fixed cell size, checking physics queries at the target position
- `GridAlignmentLeg` snaps entities to the pseudo-grid and corrects drift
- Everything is physics — no arrays, no occupancy maps, no grid classes

### Object Pooling

**Design principles:**

1. **Pool reference IS the toggle.** `null` = instantiate fresh, non-null = acquire from pool
2. **Entity routes itself.** `deactivate()` checks pool internally — pooled returns, non-pooled frees
3. **Pool as parent.** Pooled entities live as children of CDObjectPool. `find_ancestor()` walks through pool nodes transparently
4. **Separate acquire and activate.** Spawner acquires, configures, THEN activates

### The WaveCard Relay Pattern

```
CDGame emits "game_play" → WaveCard hears → emits "wave_start(1)" → Trapdoors fire
GroupCountGoal emits "wave_cleared" → WaveCard hears → emits "wave_start(2)" → Trapdoors fire again
```

Multiple WaveCards with different signal names enable independent wave cycles (e.g., asteroid waves vs UFO waves).

### The Trigger → Queue → Stagger → Spawn Lifecycle (Trapdoors)

1. **Trigger:** Hears game bus signal (e.g., `"wave_start"`)
2. **Queue:** Calculates spawn count, builds queue of indices
3. **Stagger:** Pops one index per `stagger_delay` interval
4. **Spawn:** Gets scene, gets position, telefrag check, apply spawn context, activate entity
5. **Complete:** Emits `"spawning_complete"` when queue drains

---

## 6. Anti-Patterns

### Signal Violations

#### The Phone Call

Calling a method directly on another component instead of emitting a signal.

```gdscript
# ❌ WRONG
collider.take_damage(5)

# ✅ CORRECT
collider.emit_signal("take_damage", 5)
```

The phone call creates hard coupling — the caller must know the callee's interface. Signals let the recipient decide what to do, and let games rewire behavior without code changes.

#### Premature Connection

Connecting to signals in `_ready()` instead of `_on_initialize()`.

```gdscript
# ❌ WRONG
func _ready():
    super._ready()
    entity.connect("collision", _on_collision)  # other components may not exist yet

# ✅ CORRECT
func _ready():
    super._ready()
    # registration only — ensure_signal, set category

func _on_initialize():
    entity.connect("collision", _on_collision)  # all components now exist
```

Other components haven't finished `_ready()` when your `_ready()` runs. Their signals may not be registered yet. `_on_initialize()` is called deferred, after all `_ready()` calls complete.

#### Hardcoded Signal Names

Not using `@export var` for signal names.

```gdscript
# ❌ WRONG
entity.connect("collision", _on_collision)  # can't be rewired

# ✅ CORRECT
@export var collision_signals: Array[StringName] = [&"collision"]
# connected in _on_initialize(), configurable per-game
```

Every signal name should be configurable so games can rewire the pipeline without code changes.

#### Cross-Entity Blind Emission

Emitting on another entity's bus without validity guards.

```gdscript
# ❌ WRONG
collider.emit_signal("take_damage", 5)  # collider might be dead

# ✅ CORRECT
if is_instance_valid(collider) and collider.has_signal("take_damage"):
    collider.emit_signal("take_damage", 5)
```

One dead entity reference = crash. Always guard cross-entity emissions.

### Accumulator Violations

#### Direct Velocity Override

Writing `entity.velocity =` from outside CDEntity's own physics loop.

```gdscript
# ❌ WRONG (from an Arm at Priority 40)
collider.velocity = deflected_velocity  # bypasses accumulator, creates ordering bugs

# ✅ CORRECT — use the accumulator
collider.request_velocity_set(deflected_velocity)

# ✅ ALSO CORRECT — use a collision handler (runs during Priority 30)
entity.register_collision_handler(groups, _handle_collision)
```

The accumulator exists to prevent frame-ordering bugs. If two components write `entity.velocity` directly, whoever runs last wins — and that order depends on scene tree position.

#### The Dueling Legs

Putting two `velocity_set`-based Legs on the same entity.

```gdscript
# ❌ WRONG — only one set wins per frame
entity.add_child(DirectMovementLeg.new())     # request_velocity_set()
entity.add_child(AnotherSetBasedLeg.new())    # also request_velocity_set()

# ✅ CORRECT — one set-based Leg, multiple add-based Legs
entity.add_child(DirectMovementLeg.new())     # request_velocity_set()
entity.add_child(LinearFrictionLeg.new())     # request_velocity_add()
```

Only one `set` wins per frame. Use `set`-based Legs for exclusive movement control, `add`-based Legs for composable forces.

### Category Violations

#### The Omnibrain

A Brain that also moves the entity, applies forces, or tracks health.

```gdscript
# ❌ WRONG
func _physics_process(delta):
    entity.request_velocity_set(direction * speed)  # this is a Leg
    entity.emit_signal("shoot", &"fire")            # this is an Arm
    health -= 1                                      # this is Guts
```

Brains generate intent ONLY. If a Brain is touching `velocity` or calling `request_velocity_set()`, split it into a Brain + Leg.

#### The Double Agent

A component that tracks internal state AND affects other entities.

```gdscript
# ❌ WRONG — one component doing two things
# tracks health AND deals damage to others
```

Should be two components: a Guts (tracks health, emits `"zero_health"`) and an Arm (deals damage on collision). The Guts emits a signal; the Arm listens.

#### Game Logic in CDEntity

Adding game-specific behavior to `cd_entity.gd`.

```gdscript
# ❌ WRONG — adding to cd_entity.gd
if collider.is_in_group("coins"):
    game.score += 10
```

CDEntity is a blank physics shell. Game rules belong in Stage components at Priority 70.

### Collision Misuse

#### The Physics Leg

Using a collision handler for movement that should be a Leg.

> *"Should this be a Leg component?"*

If the behavior is about **how the entity moves** — applying forces, setting velocity over time, friction, acceleration — it's a Leg. Use the accumulator. Collision handlers are for **what happens when movement is blocked** — custom bounce angles, one-way platforms, sticky surfaces.

#### Bypassing the Buffer

Reading collision results directly from `move_and_collide()` in a component.

```gdscript
# ❌ WRONG — not all entities have moved yet
func _physics_process(delta):
    var collision = entity.move_and_collide(entity.velocity * delta)
    if collision:
        deal_damage(collision.get_collider())

# ✅ CORRECT — use the collision buffer (Priority 35)
# Connect to "collision" signal, respond in _on_collision()
```

During Priority 30, other entities are still moving. Reading their position or colliding with them directly creates ordering inconsistencies. Use the collision buffer for all collision response.

### Pool / Lifecycle Violations

#### The Leaky Pool

Not resetting component state in `_on_entity_deactivating()`.

```gdscript
# ❌ WRONG — stale state persists across pool reuse
# (missing _on_entity_deactivating override)

# ✅ CORRECT
func _on_entity_deactivating():
    super._on_entity_deactivating()
    health = max_health
    timer = 0.0
    _is_active = false
```

When a pooled entity reactivates, stale state from its previous life persists. Every component that holds runtime state MUST reset it.

#### Premature Removal

Calling `queue_free()` directly on an entity.

```gdscript
# ❌ WRONG — bypasses two-phase lifecycle
entity.queue_free()

# ✅ CORRECT
entity.emit_signal("request_deactivate")
# or
entity.deactivate()
```

`queue_free()` bypasses the two-phase lifecycle, breaks group counts, and causes asymmetric collision bugs. Always use `deactivate()` or the `"request_deactivate"` signal.

### Configuration Anti-Patterns

#### Default Group Filters

Setting `target_groups` defaults to something other than `[]`.

```gdscript
# ❌ WRONG — overrides the collision matrix
@export var target_groups: Array[StringName] = [&"enemies"]

# ✅ CORRECT — trust the matrix, opt in to filtering
@export var target_groups: Array[StringName] = []
```

The collision matrix handles filtering at the C++ level. Components should trust the matrix by default and only add group filters as an opt-in escape hatch for special cases. Components with `target_groups = []` skip the GDScript filter check entirely — zero overhead.

#### The Singleton Assumption

Writing a component that assumes it's the only instance. The architecture is designed for many entities with the same component. Never use singletons for game state — use the game bus (`bus_emit`/`bus_connect`) or CDGroupRegistry for shared state.

---

## 7. Code Quality Guidelines

### Naming Conventions

| Entity | Convention | Example |
|--------|-----------|---------|
| Script files | `snake_case.gd` | `damage_on_hit_arm.gd` |
| Scene files | `snake_case.tscn` | `player_paddle.tscn` |
| Resource files | `snake_case.tres` | `wall_kick_data.tres` |
| Classes | `PascalCase` | `DamageOnHitArm`, `HealthpoolGuts` |
| Entity bus signals | Imperative verb or noun | `&"move"`, `&"collision"`, `&"take_damage"`, `&"zero_health"` |
| Game bus signals | Past tense or event noun | `&"score_gained"`, `&"wave_cleared"`, `&"lives_depleted"` |
| Lifecycle signals | Descriptive | `&"entity_deactivating"`, `&"entity_activated"`, `&"request_deactivate"` |
| Entity groups | Plural nouns | `&"enemies"`, `&"player"`, `&"balls"`, `&"bricks"`, `&"formation"`, `&"diving"` |

### Export Conventions

**Always use arrays for signal names:**

```gdscript
@export var on_score_changed: Array[StringName] = [&"score_changed"]
@export var move_signals: Array[StringName] = [&"move"]
@export var collision_signals: Array[StringName] = [&"collision"]
```

This enables runtime rewiring without code changes — a component that emits to one signal can be configured to emit to three.

**Group exports with `@export_group`:**

```gdscript
@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var on_death: Array[StringName] = [&"request_deactivate"]
```

**Defaults:**
- Signal names: `Array[StringName]` with sensible defaults matching the spec
- Group filters: `Array[StringName] = []` (empty = trust the collision matrix)
- Pool references: `null` by default (no pooling)

### Error Handling

**Two tiers:**

**Engine Components (Core/)** — Fail fast. If something is wrong at the engine level (missing required node, invalid configuration), print an error and stop. The game should not continue in a broken state.

**Game/Entity Components (everything else)** — Push error and continue. If a signal name doesn't exist, a type mismatch occurs, or a cross-entity emission finds no valid target, call `push_error()` and skip. The entity continues running. This prevents one misconfigured component from crashing the entire game.

**Cross-entity safety rule:** When emitting on another entity's bus, always guard with `is_instance_valid()` and `has_signal()`. If the target lacks the signal (e.g., a wall without HealthPoolGuts), silently skip — no error.

### Validity Guards

Always use these patterns when dealing with cross-entity references:

```gdscript
# Before emitting on another entity
if is_instance_valid(collider) and collider.has_signal("take_damage"):
    collider.emit_signal("take_damage", amount)

# Before disconnecting
if entity.is_connected("collision", _on_collision):
    entity.disconnect("collision", _on_collision)

# Before accessing game reference
if game and is_instance_valid(game):
    game.bus_emit("score_gained", [points])
```

### Editor Preview (@tool Pattern)

Visual components (Faces, Voices) should support editor preview:

```gdscript
@tool
extends CDEntityComponent

@export var preview_action: PreviewAction = PreviewAction.NONE:
    set(value):
        preview_action = PreviewAction.NONE  # reset immediately
        if Engine.is_editor_hint():
            match value:
                PreviewAction.PLAY: _preview_play()
                PreviewAction.STOP: _preview_stop()

func _process(_delta):
    if Engine.is_editor_hint():
        queue_redraw()  # live preview in editor
```

### Disconnect Pattern

Always guard disconnections. During deactivation, the entity or game may already be partially torn down:

```gdscript
func _on_entity_deactivating():
    super._on_entity_deactivating()
    for sig in listen_signals:
        if entity and entity.is_connected(sig, _on_handler):
            entity.disconnect(sig, _on_handler)
```

---

## 8. Extending the Architecture

### Decision Flowchart: What Category Is My New Component?

```
Does it generate intent (direction, target, action)?
  → BRAIN (Priority 10)
  
Does it execute movement or modify velocity/position?
  → LEG (Priority 20)

Does it affect OTHER entities or game state (damage, score, forces, spawn)?
  → ARM (Priority 40)

Does it track INTERNAL entity state (health, timers, resources)?
  → GUTS (Priority 50)

Does it draw visuals or render effects?
  → FACE (Priority 60)

Does it play entity-level audio?
  → VOICE (Priority 65)

Does it manage game-level logic (score, lives, waves, goals, spawning)?
  → STAGE (Priority 70)
```

### Step-by-Step: Creating a New Component

1. **Pick the correct category** using the flowchart above
2. **Choose the correct base class:**
   - Entity component → `CDEntityComponent` (has `entity` and `game`)
   - Game component → `CDStageComponent2D` (has `game` only)
   - UI display → `CDCueCard` (has `game` + label management)
   - Spatial trigger → `CDMark` (Area2D-based)
3. **Set `component_category`** in `_ready()`
4. **Register signals** with `entity.ensure_signal()` in `_ready()`
5. **Connect signals** in `_on_initialize()` (deferred)
6. **Implement processing** in `_physics_process()` (or `_process()` for visual/audio)
7. **Disconnect and reset** in `_on_entity_deactivating()`
8. **Export all signal names** as `Array[StringName]` with sensible defaults
9. **Use `@export_group("Listen Signals")` and `@export_group("Emit Signals")`**
10. **Group filter defaults** to `[]` (trust the collision matrix)
11. **Support pooling** if the component holds state — reset everything in deactivating/activated hooks
12. **Write a README.md** in the component's folder documenting exports, signals, and usage

### Adding New Signal Types

Signal types are fixed (defined by `add_user_signal()`), but signal names are always configurable via `@export`. To add a new signal contract:

1. Define the type signature: what arguments and types
2. Register with `entity.ensure_signal("signal_name", [TYPE_VEC2, ...])` in `_ready()`
3. Export the signal name as `@export var my_signal: Array[StringName] = [&"signal_name"]`
4. Document the semantic in the component's README

### Creating Custom Resources

The architecture uses custom resources extensively for data-driven configuration:

| Resource Type | Purpose | Examples |
|--------------|---------|---------|
| Triggers | Define when something happens | `CDSignalTrigger`, `CDGroupCountTrigger`, `CDTimerTrigger`, `CDCompositeTrigger` |
| Selectors | Define which entities to select | `CDAllSelector`, `CDFirstNSelector`, `CDNearestNSelector`, `CDRandomNSelector` |
| Curves | Define AI paths | `CDArcCurve`, `CDCircleCurve`, `CDHelixCurve`, `CDLissajousCurve`, `CDSpiralCurve`, etc. |
| Shapes | Define polygon points | `CDShape` (points + closed flag) |
| Transitions | Define group-as-state transitions | `CDTransition` (from/to group, trigger, selector, cooldown) |
| Director Rules | Define entity swap rules | `CDDirectorRule` (trigger, target group, swap scene, selector) |
| Sound Definitions | Define synthesized audio | `CDSoundDef` (wave, effect, notes, volume), `CDNote` (semitone, duration), `CDMusicTrack` |
| Spawn Context | Define spawn configuration | `CDSpawnContext` (velocity, rotation, flips), `CDGridLayout`, `CDGridEquation` |
| Collision Groups | Define collision relationships | `CDCollisionGroup` (group name + collides_with targets) |
| Wall Kicks | Define rotation offsets | `CDWallKick` (offset tables for Tetris-style rotation) |

### Building a New Game

No game script needed. Every game is a scene tree assembly:

1. Create a `CDGame` root node
2. Add infrastructure: `CDGroupRegistry`, `CDCollisionBuffer`, `CDCollisionMatrix`
3. Add stage components: `ScoreCard`, `LivesCard`, `GroupCountGoal`, `WaveCard`, trapdoors as needed
4. Add entities (`CDEntity` children) with appropriate components:
   - Player entities: Player Brain + Leg + Face + Voice
   - AI entities: AI Brain + Leg + Face + Arm
   - Projectiles: Leg + Death Arm(s) + Face
   - Obstacles: Guts + Face
5. Configure collision groups in `CDCollisionMatrix`
6. Wire signal names via exports — all names configurable, no code changes needed
7. Add audio: Speakers on CDGame, Voices on entities
8. Add visual post-processing: CRTProjector

**The architecture's power:** Swapping components creates entirely new games. Paddle Ball + asteroid entities = Meteor Rally. Same base components, different assembly, new game.

---

## Appendix: Component Count by Category

| Category | Priority | Count | Key Components |
|----------|----------|-------|----------------|
| Core | varies | ~12 | CDEntity, CDGame, CDComponent2D, CDStageComponent2D, CDCollisionBuffer, CDGroupRegistry, CDCollisionMatrix, CDInputRouter, CDEnums, CDObjectPool, CDSoundBank, CDUpdater |
| Brain | 10 | 16 | PlayerMove/Aim/Action/MoveToBrain, AIChase/Flee/Orbit/Formation/DiveBomb/Aim/RepeatAction/TractorBeam/PathMove/RandomSweep/TimedStep/IdleWanderBrain |
| Legs | 20 | 15 | DirectMovement/Acceleration/Engine/Target/RotationLeg, GridMovement/Rotation/Drop/AlignmentLeg, Friction (Linear/Static), Boomerang, ScreenWrap |
| Arms | 40 | 16 | DamageOnHit/Crash/JoustArm, DeathOnHit/Crash/JoustArm, ScoreOnCollision/DeathArm, PushbackArm, StatusOnHitArm, GunArm, SpawnOnDeathArm, PieceSplitterArm, PowerupDelivery/WingmanArm, TractorBeamArm |
| Guts | 50 | 19 | Healthpool/Shieldpool/ResourcepoolGuts, DieAtZeroHealth/Offscreen/OnTimer/OutOfBoundsGuts, DeflectorBounce/ImpulseReceiver/ShapeColliderGuts, LockDetector/VisionConeGuts, KBM/MoveAdapterGuts, Announcer/Points/Stun/TSpinDetector/TimerGuts |
| Faces | 60 | 7 | VectorFace, PolygonFace, SpriteFace, VectorEngineFace, VectorThrusterFace, DeathEffectFace, MenacingVectorFace |
| Voices | 65 | 2 | SoundVoice, ContinuousVoice |
| Stage | 70 | 28 | ScoreCard, LivesCard, TimerCard, WaveCard, GroupCountGoal, ScoreThresholdGoal, CDMark, CountMark, MobileMark, OccupancyMark, SafeZoneMark, TimedMark, FormationDirector, StageDirector, StateDirector, SwarmShootingDirector, SwoopDirector, SoundSpeaker, ContinuousSpeaker, MusicSpeaker, CRTProjector, CreditProjection, PointTrapdoor, EdgeTrapdoor, GridTrapdoor |

**Total: ~153 V2 scripts + 41 custom resources**