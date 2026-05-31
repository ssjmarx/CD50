# V2 Blackboard Architecture — Signals + Blackboard Overhaul

**Created:** 2026-05-30  
**Status:** Proposed — pending implementation  
**Scope:** Rewrites signal communication for both entity bus and game bus  
**Supersedes:** V2 Rules Sections 5 (Signal Architecture) and 6 (Signal Contracts)

---

## 1. Problem Statement

The current hybrid bus system has three concrete pain points discovered while assembling Bug Blaster 2 (Galaga):

### Pain Point 1: Typed Signal Friction
User-defined signals carry typed arguments (`"move"(Vector2)`, `"move_to"(Vector2)`, `"action"(StringName)`). Components that should be interoperable can't communicate because their signal *signatures* differ, even when the *data* is compatible. MoveAdapterGuts exists purely to bridge `"move_to"(Vector2)` → `"move"(Vector2)`.

### Pain Point 2: Bandage Code
Components that listen to multiple signals with different argument shapes must pad their handlers with nullable Variant defaults:

```gdscript
# AnnouncerGuts — current
func _on_any_input(_arg1: Variant = null, _arg2: Variant = null) -> void:
```

This is fragile, ugly, and will grow worse as more signal types are added.

### Pain Point 3: The Type Contract Is a Lie
V2 Rules Section 6 defines canonical signal types (directional, positional, action). But `ensure_signal()` calls `add_user_signal(name)` with NO type parameters — all signals are already zero-arg. The "types" are a convention, not enforced. The system is untyped while pretending to be typed.

---

## 2. Architecture Rules

These rules replace V2 Rules Sections 5 and 6.

### Rule 1: All User-Defined Signals Are Zero-Arg

User-defined signals on both the entity bus and game bus carry NO arguments. They are pure notification mechanisms — "something happened." Data lives on the blackboard.

```gdscript
# BEFORE
entity.emit_signal("move", direction)
game.bus_emit("add_score", [100])

# AFTER
entity.blackboard["move_intent"] = direction
entity.emit_signal("move")  # zero-arg — or eliminated entirely if consumer polls
game.blackboard["score_delta"] = 100
game.bus_emit("add_score")  # zero-arg
```

### Rule 2: The Only Hardcoded Typed Signals Are Physics Interactions

These signals remain typed and are defined in `cdentity.gd`:

| Signal | Signature | Why Typed |
|--------|-----------|-----------|
| `"collision"` | `(CDEntity, Vector2)` | Emitted by CDCollisionBuffer during physics flush |
| `"collided_by"` | `(CDEntity, Vector2)` | Mirror of collision for the other entity |
| `"request_deactivate"` | `()` | Lifecycle — zero-arg already |
| `"entity_deactivating"` | `()` | Lifecycle — zero-arg already |
| `"entity_activated"` | `()` | Lifecycle — zero-arg already |

These are infrastructure, not user-defined. They don't cause interop pain because every component that listens to them expects the same signature.

### Rule 3: CDEntity and CDGame Expose a Blackboard Dictionary

Both base classes get a public `blackboard: Dictionary`. Components write transient state to it and read transient state from it.

```gdscript
# CDEntity
var blackboard: Dictionary = {}

# CDGame
var blackboard: Dictionary = {}
```

- **Transient** — cleared on lifecycle transitions
- **Unordered** — no processing priority implications
- **Schemaless** — any component can write any key
- **Typed by convention** — key names document expected types (see Section 6)

### Rule 4: Components That Need State Read It from the Blackboard

Components that do continuous work in `_physics_process` or `_process` read the blackboard for their inputs using a configurable key with a sensible default.

```gdscript
# DirectMovementLeg — reads move intent from blackboard
@export var move_keys: Array[StringName] = [&"move_intent"]
@export var speed: float = 200.0

func _physics_process(_delta: float) -> void:
    for key in move_keys:
        var intent: Vector2 = entity.blackboard.get(key, Vector2.ZERO)
        entity.request_velocity_set(intent.normalized() * speed)
```

### Rule 5: Components That Produce State Write It to the Blackboard

Components that create transient state write to the parent's blackboard using an array of configurable keys.

```gdscript
# PlayerMoveBrain — writes move intent to blackboard
@export var move_keys: Array[StringName] = [&"move_intent"]

func _physics_process(_delta: float) -> void:
    var direction := _get_input_direction()
    entity.blackboard[move_key] = direction
```

### Rule 6: Readers Use Sensible Defaults

When a component reads a key that doesn't exist on the blackboard, it uses a sensible default value. The default should produce "do nothing" behavior.

```gdscript
# No Brain present → key doesn't exist → Vector2.ZERO → no movement
var intent = entity.blackboard.get("move_intent", Vector2.ZERO)

# No HealthPoolGuts → key doesn't exist → 0.0 → full damage applied or no health logic
var health = entity.blackboard.get("health", 0.0)
```

This replaces the current `_received_input` tracking pattern. The default IS the idle state.

### Rule 7: Writers No-Op When Their Target Key Is Absent from the Target's Blackboard

For cross-entity writes (Arms writing to collider's blackboard), the writer checks whether the target key exists before writing. The key existing is the contract — if HealthPoolGuts is on the entity, the `"health"` key exists. No HealthPoolGuts = no key = no-op.

```gdscript
# DamageOnHitArm — writes damage to collider's blackboard
func _on_collision(collider: CDEntity, _normal: Vector2) -> void:
    for key in health_keys: # configurable array of keys to try and change
        if not is_instance_valid(collider):
            return
        if not collider.blackboard.has(key):
            return  # target has no health system — no-op
        collider.blackboard[key] -= damage_amount
        collider.emit_signal("damage_taken")  # zero-arg event notification
```

For same-entity writes (Brains, Guts), the key is always written regardless — the component owns its keys.

---

## 3. Two Communication Modes

| Mode | For Components That... | Example |
|------|----------------------|---------|
| **Poll blackboard** | Do continuous work in `_physics_process` / `_process` | Brains writing intent, Legs reading intent, Faces reading state, Goals reading game state |
| **Signal + blackboard** | Do intermittent work — need to be "woken up" | Arms on collision, Guts on damage, Voices on event, CueCards on score change |

### When to Use Each

- **Continuous data flow** (every frame): Blackboard only. No signal emission. The priority system guarantees producers (Priority 10) run before consumers (Priority 20+).
- **Intermittent events** (on occurrence): Write data to blackboard, then emit zero-arg signal. Consumers are woken by the signal, read data from the blackboard.
- **State that multiple consumers need**: Blackboard only. Multiple consumers read the same key. No fan-out signal needed.

---

## 4. The Parallel Pattern

Both buses follow identical rules:

| | Entity Bus (CDEntity) | Game Bus (CDGame) |
|---|---|---|
| **Blackboard** | `entity.blackboard: Dictionary` | `game.blackboard: Dictionary` |
| **Event signals** | Zero-arg user-defined + hardcoded physics (typed) | Zero-arg only |
| **Continuous data** | Brains write, Legs/Faces poll | Directors write, CueCards/Goals poll |
| **Event data** | Writer puts data on blackboard, then emits signal | Writer puts data on blackboard, then emits signal |
| **Clear lifecycle** | `blackboard.clear()` on deactivate | `blackboard.clear()` on reset/end_game |

---

## 5. API Changes

### CDEntity

```gdscript
# NEW — public blackboard
var blackboard: Dictionary = {}

# MODIFIED — deactivate clears blackboard
func deactivate() -> void:
    ...
    blackboard.clear()

# UNCHANGED — still works (already creates zero-arg signals)
func ensure_signal(signal_name: StringName) -> void:
    if not has_signal(signal_name):
        add_user_signal(signal_name)

# UNCHANGED — velocity/position/angular accumulator API
func request_velocity_set(v: Vector2) -> void: ...
func request_velocity_add(v: Vector2) -> void: ...
func request_position_set(p: Vector2) -> void: ...
func request_position_add(p: Vector2) -> void: ...
```

### CDGame

```gdscript
# NEW — public blackboard
var blackboard: Dictionary = {}

# MODIFIED — bus_emit drops args parameter
func bus_emit(signal_name: StringName) -> void:
    if _bus.has(signal_name):
        for callable in _bus[signal_name]:
            callable.call()

# MODIFIED — bus_connect unchanged (no args involved)
func bus_connect(signal_name: StringName, callable: Callable) -> void: ...

# MODIFIED — reset clears blackboard
func reset_game() -> void:
    ...
    blackboard.clear()
```

### CDComponent2D

```gdscript
# UNCHANGED — entity and game references still resolve in _ready()
# Components access blackboard via entity.blackboard or game.blackboard
```

---

## 6. Key Naming Conventions

### Entity Blackboard Keys

```
# --- Intent (written by Brains, read by Legs) ---
"move_intent"       — Vector2, directional intent (normalized or raw)
"aim_direction"     — Vector2, aim target direction
"target_position"   — Vector2, world-space target point
"rotation_intent"   — float, spin intent (-1.0 to 1.0)
"curve_path"        — Curve2D, path to follow (for path-following Legs)
"drop_amount"       — int, grid cells to drop (for grid Legs)

# --- State (written by Guts, read by anyone) ---
"health"            — float, current HP
"health_max"        — float, maximum HP
"points"            — int, point value of this entity
"shield"            — float, current shield strength
"resource"          — float, current resource amount
"timer"             — float, countdown timer value

# --- Event Data (written before emitting signal) ---
"incoming_damage"   — float, damage about to be applied
"action_name"       — StringName, which action triggered
"pushback_force"    — Vector2, knockback impulse
"score_delta"       — int, score change amount
"group_name"        — StringName, affected group
"group_count"       — int, new group count

# --- Physics (written by CDEntity post-resolution, read by Faces) ---
"position"          — Vector2, post-physics position
"rotation"          — float, post-physics rotation
"velocity"          — Vector2, current resolved velocity
```

### Game Blackboard Keys

```
# --- Score State ---
"score"             — int, current score
"score_delta"       — int, last score change
"multiplier"        — float, current score multiplier

# --- Lives State ---
"lives"             — int, current lives
"lives_delta"       — int, last lives change

# --- Wave State ---
"wave_number"       — int, current wave
"wave_cleared"      — bool, whether current wave is cleared

# --- Game State ---
"game_result"       — CDEnums.GameResult, game end state
"group_name"        — StringName, last changed group
"group_count"       — int, last changed group count

# --- Timer State ---
"game_timer"        — float, game elapsed time
```

### Naming Rules

- **Snake_case** — matches GDScript convention
- **Noun, not verb** — `"move_intent"` not `"moving"`, `"health"` not `"damaged"`
- **Intent suffix** for Brain outputs — `"move_intent"`, `"aim_direction"`
- **No component prefix** — keys are owned by the entity/game, not by a specific component

---

## 7. Signal Taxonomy (Revised)

### Entity Bus Signals

| Category | Signals | Mechanism |
|----------|---------|-----------|
| **Hardcoded physics** | `"collision"(CDEntity, Vector2)`, `"collided_by"(CDEntity, Vector2)` | Typed, defined in `cdentity.gd` |
| **Hardcoded lifecycle** | `"request_deactivate"()`, `"entity_deactivating"()`, `"entity_activated"()` | Zero-arg, defined in `cdentity.gd` |
| **User-defined events** | `"take_damage"()`, `"shoot"()`, `"swoop_complete"()`, `"health_depleted"()` | Zero-arg, data on blackboard |

### Game Bus Signals

| Category | Signals | Mechanism |
|----------|---------|-----------|
| **Game lifecycle** | `"game_play"()`, `"game_over"()`, `"game_reset"()` | Zero-arg, data on `game.blackboard` |
| **Game events** | `"score_changed"()`, `"wave_start"()`, `"group_count_changed"()`, `"lives_changed"()` | Zero-arg, data on `game.blackboard` |

### Eliminated Entity Bus Patterns

These signal types from V2 Rules Section 6 are **eliminated**:

| Old Type | Old Signature | New Mechanism |
|----------|---------------|---------------|
| `directional` | `(Vector2)` | Blackboard key `"move_intent"` |
| `positional` | `(Vector2)` | Blackboard key `"target_position"` |
| `action` | `(StringName)` | Blackboard key `"action_name"` + zero-arg signal |
| `action_end` | `(StringName)` | Blackboard key `"action_name"` + zero-arg signal |
| `rotate` | `(float)` | Blackboard key `"rotation_intent"` |
| `curve` | `(Curve2D, float)` | Blackboard keys `"curve_path"` + speed |
| `drop` | `(int)` | Blackboard key `"drop_amount"` |
| `moved` | `(Vector2, Vector2)` | Blackboard keys `"position"` + `"velocity"` |
| `rotated` | `(float, float)` | Blackboard keys `"rotation"` + angular |

---

## 8. Components Eliminated by This Architecture

| Component | Why Eliminated |
|-----------|---------------|
| MoveAdapterGuts | Brain writes `"target_position"`, Leg reads it and computes direction itself |
| KBMGuts | Keyboard Brain and Mouse Brain both write to `"move_intent"` — last writer wins |

---

## 9. Category-by-Category Migration Guide

### Brains (INTENT, Priority 10) — MAJOR CHANGE

**Current pattern:**
```gdscript
func _on_initialize():
    for sig in move_signals:
        entity.ensure_signal(sig)
        entity.connect(sig, _on_move)

func _physics_process(_delta):
    entity.emit_signal("move", direction)

func _on_entity_deactivating():
    for sig in move_signals:
        if entity.is_connected(sig, _on_move):
            entity.disconnect(sig, _on_move)
```

**New pattern:**
```gdscript
@export var move_key: StringName = &"move_intent"

func _physics_process(_delta):
    entity.blackboard[move_key] = _get_input_direction()
```

No signal emission, no connection, no cleanup. Brains become pure blackboard writers.

**Brains that still emit signals:** PlayerActionBrain (intermittent — "shoot" events), TimedStepBrain (intermittent step triggers). These emit zero-arg signals and put action data on the blackboard.

| Brain Component | Change |
|----------------|--------|
| PlayerMoveBrain | Pure blackboard writer |
| PlayerMoveToBrain | Pure blackboard writer (`"target_position"`) |
| PlayerAimBrain | Pure blackboard writer (`"aim_direction"`) |
| PlayerActionBrain | Blackboard + zero-arg signals (intermittent) |
| ChaseNearestBrain | Pure blackboard writer |
| FleeNearestBrain | Pure blackboard writer |
| AimAtNearestBrain | Pure blackboard writer |
| OrbitBrain | Pure blackboard writer |
| ShootWhenAimedBrain | Blackboard + zero-arg signal (intermittent fire) |
| TimedStepBrain | Blackboard + zero-arg signal (intermittent step) |
| PatrolPathBrain | Pure blackboard writer |
| RandomSweepBrain | Pure blackboard writer |
| IdleWanderBrain | Pure blackboard writer |
| FormationBrain | Pure blackboard writer |
| DiveBombBrain | Blackboard + zero-arg signals (start/stop) |
| AISwoopBrain | Hybrid: start/stop are signals, movement data is blackboard |

### Legs (STEERING, Priority 20) — MODERATE CHANGE

**Current pattern:**
```gdscript
func _on_initialize():
    for sig in move_signals:
        entity.ensure_signal(sig)
        entity.connect(sig, _on_move)

var _direction: Vector2 = Vector2.ZERO
var _received_input: bool = false

func _on_move(direction: Vector2):
    _direction = direction.normalized()
    _received_input = true

func _physics_process(_delta):
    if _received_input:
        entity.request_velocity_set(_direction * speed)
        _received_input = false
    else:
        entity.request_velocity_set(Vector2.ZERO)
```

**New pattern:**
```gdscript
@export var move_key: StringName = &"move_intent"

func _physics_process(_delta):
    var intent: Vector2 = entity.blackboard.get(move_key, Vector2.ZERO)
    entity.request_velocity_set(intent.normalized() * speed)
```

No signal connection, no `_received_input` tracking, no handler, no cleanup. The default value handles the "no input" case automatically.

**Velocity accumulator API is unchanged.** Legs still call `request_velocity_set()` and `request_velocity_add()`.

| Leg Component | Change |
|---------------|--------|
| DirectMovementLeg | Read `"move_intent"` from blackboard |
| AccelerationMovementLeg | Read `"move_intent"` from blackboard |
| EngineThrustLeg | Read `"move_intent"` and `"aim_direction"` from blackboard |
| LinearFrictionLeg | Unchanged (reads entity velocity directly) |
| StaticFrictionLeg | Unchanged |
| SteeringLeg | Read `"target_position"` from blackboard |
| BoomerangLeg | Unchanged (internal trajectory math) |
| RotationDirectLeg | Read `"rotation_intent"` from blackboard |
| RotationTargetLeg | Read `"aim_direction"` from blackboard |
| GridMovementLeg | Read `"move_intent"` from blackboard |
| GridRotationLeg | Read `"rotation_intent"` from blackboard |
| GridDropLeg | Read `"drop_amount"` from blackboard |
| GridAlignmentLeg | Unchanged (reads entity position directly) |
| ScreenWrapLeg | Unchanged (reads entity position directly) |
| ScreenClampLeg | Unchanged |
| PathFollowerLeg | Read `"curve_path"` from blackboard |
| SmoothToLeg | Read `"target_position"` from blackboard |

### Arms (INTERACTION, Priority 40) — MIXED

**Collision arms** listen to the hardcoded `"collision"` signal (stays typed). They write to the collider's blackboard and emit zero-arg signals on the collider.

**Current pattern (DamageOnHitArm):**
```gdscript
func _on_collision(collider: CDEntity, _normal: Vector2):
    if is_instance_valid(collider) and collider.has_signal("take_damage"):
        collider.emit_signal("take_damage", damage_amount)
```

**New pattern:**
```gdscript
@export var target_key: StringName = &"health"

func _on_collision(collider: CDEntity, _normal: Vector2):
    if not is_instance_valid(collider):
        return
    if not collider.blackboard.has(target_key):
        return  # target has no health system
    collider.blackboard[target_key] -= damage_amount
    collider.emit_signal("take_damage")  # zero-arg notification
```

**GunArm** listens for zero-arg `"shoot"` signal instead of typed signal. Unchanged otherwise.

| Arm Component | Change |
|---------------|--------|
| DamageOnHitArm | Write to collider blackboard + zero-arg signal |
| DeathOnHitArm | Emit `"request_deactivate"` on collider (already zero-arg) |
| DamageOnCrashArm | Write to own blackboard + zero-arg signal |
| DeathOnCrashArm | Emit `"request_deactivate"` on self (already zero-arg) |
| DamageOnJoustArm | Write to collider blackboard (comparative logic stays) |
| DeathOnJoustArm | Emit `"request_deactivate"` on loser |
| ScoreOnCollisionArm | Write to game blackboard + zero-arg game bus signal |
| PushbackArm | Write `"pushback_force"` to collider blackboard + zero-arg signal |
| GunArm | Listen for zero-arg `"shoot"` signal |
| StatusEffectArm | Write status data to collider blackboard + zero-arg signal |

### Guts (STATE, Priority 50) — MODERATE CHANGE

**HealthPoolGuts:**
```gdscript
# BEFORE
func _on_take_damage(amount: float):
    health -= amount

# AFTER
@export var health_key: StringName = &"health"

func _on_initialize():
    entity.blackboard[health_key] = max_health

func _on_take_damage():  # zero-arg
    var damage = entity.blackboard.get("incoming_damage", 0.0)
    var current = entity.blackboard.get(health_key, 0.0)
    var new_health = current - damage
    entity.blackboard[health_key] = new_health
    if new_health <= 0:
        entity.emit_signal("zero_health")
```

**AnnouncerGuts — simplified:**
```gdscript
# BEFORE
func _on_any_input(_arg1: Variant = null, _arg2: Variant = null) -> void:
    for rebroadcast in rebroadcast_signals:
        if include_self:
            game.bus_emit(rebroadcast, [entity])
        else:
            game.bus_emit(rebroadcast)

# AFTER
func _on_any_input() -> void:  # clean zero-arg
    if include_self:
        game.blackboard["announcer_entity"] = entity
    for rebroadcast in rebroadcast_signals:
        game.bus_emit(rebroadcast)
```

No more `_arg1 = null, _arg2 = null` bandage.

| Guts Component | Change |
|----------------|--------|
| HealthPoolGuts | Write `"health"` to blackboard, listen zero-arg `"take_damage"`, read `"incoming_damage"` |
| DieAtZeroHealthGuts | Poll `"health"` from blackboard, emit `"request_deactivate"` |
| PointsGuts | Write `"points"` to blackboard |
| DieOnTimerGuts | Write timer state to blackboard, emit zero-arg signal on expiry |
| DieOffscreenGuts | Unchanged (reads entity position directly) |
| ShieldPoolGuts | Write `"shield"` to blackboard, intercept damage |
| ResourcePoolGuts | Write `"resource"` to blackboard |
| StunGuts | Write stun state to blackboard |
| LockDetectorGuts | Write lock state to blackboard |
| ShapeColliderGuts | Write shape data to blackboard |
| DeflectorBounceGuts | Unchanged (collision handler, registered via API) |
| ImpulseReceiverGuts | Read `"pushback_force"` from blackboard |
| MoveAdapterGuts | **ELIMINATED** |
| KBMGuts | **ELIMINATED** |

### Faces (VISUAL, Priority 60) — MINOR CHANGE

Faces switch from signal-driven to polling blackboard in `_process`:

```gdscript
# BEFORE — signal handler for shape updates
func _on_shape_changed(points: PackedVector2Array):
    _points = points
    queue_redraw()

# AFTER — poll blackboard every frame
func _process(_delta):
    var new_points = entity.blackboard.get("shape_points", _points)
    if new_points != _points:
        _points = new_points
        queue_redraw()
    
    var health = entity.blackboard.get("health", -1.0)
    if health >= 0:
        _update_health_visual(health)
```

### Voices (AUDIO, Priority 65) — MINIMAL CHANGE

Listen for zero-arg signals, read sound config from blackboard.

### Stage Components (RULES, Priority 70) — MODERATE CHANGE

**ScoreCard:**
```gdscript
# BEFORE
func _on_add_score(amount: int):
    current_score += int(amount * current_multiplier)

# AFTER
func _on_add_score():  # zero-arg
    var delta = game.blackboard.get("score_delta", 0)
    current_score += int(delta * current_multiplier)
    game.blackboard["score"] = current_score
    _update_label(str(current_score))
    for sig in on_score_changed:
        game.bus_emit(sig)
```

**GroupCountGoal:**
```gdscript
# BEFORE
func _on_count_changed(group_name: StringName, count: int): ...

# AFTER
func _on_count_changed():  # zero-arg
    var group = game.blackboard.get("changed_group", "")
    var count = game.blackboard.get("group_count", 0)
    if group == target_group:
        _check_goal(count)
```

**Directors (Swoop, Formation, Shooting, State, Stage):**
- Most directors emit on entity buses — those emissions become zero-arg + blackboard write
- Directors that read game state poll `game.blackboard` instead of receiving typed args

**WaveCard:**
```gdscript
# BEFORE
func _on_wave_start(wave: int):
    current_wave = wave

# AFTER
func _on_wave_start():  # zero-arg
    current_wave = game.blackboard.get("wave_number", current_wave + 1)
```

---

## 10. Before/After Comparison

### Full Pipeline: Player Ship Movement

**BEFORE (6 operations, signal boilerplate):**
```
PlayerMoveBrain._physics_process:
    entity.ensure_signal("move")           # _ready phase
    entity.emit_signal("move", direction)  # _physics_process

DirectMovementLeg._on_initialize:
    entity.ensure_signal("move")
    entity.connect("move", _on_move)

DirectMovementLeg._on_move(direction):
    _direction = direction.normalized()
    _received_input = true

DirectMovementLeg._physics_process:
    if _received_input:
        entity.request_velocity_set(_direction * speed)
        _received_input = false
    else:
        entity.request_velocity_set(Vector2.ZERO)

DirectMovementLeg._on_entity_deactivating:
    entity.disconnect("move", _on_move)
    _direction = Vector2.ZERO
    _received_input = false
```

**AFTER (3 operations, no signal boilerplate):**
```
PlayerMoveBrain._physics_process:
    entity.blackboard["move_intent"] = direction

DirectMovementLeg._physics_process:
    var intent = entity.blackboard.get("move_intent", Vector2.ZERO)
    entity.request_velocity_set(intent.normalized() * speed)

DirectMovementLeg._on_entity_deactivating:
    # nothing to disconnect — no signals involved
```

### Full Pipeline: Bullet Hits Enemy

**BEFORE:**
```
DamageOnHitArm._on_collision(collider, normal):
    collider.emit_signal("take_damage", 5)

HealthPoolGuts._on_take_damage(amount):
    health -= amount
    if health <= 0:
        entity.emit_signal("zero_health")

DieAtZeroHealthGuts._on_zero_health():
    entity.emit_signal("request_deactivate")
```

**AFTER:**
```
DamageOnHitArm._on_collision(collider, normal):
    if collider.blackboard.has("health"):
        collider.blackboard["incoming_damage"] = 5
        collider.emit_signal("take_damage")  # zero-arg

HealthPoolGuts._on_take_damage():  # zero-arg
    var damage = entity.blackboard.get("incoming_damage", 0.0)
    entity.blackboard["health"] -= damage
    if entity.blackboard["health"] <= 0:
        entity.emit_signal("zero_health")  # zero-arg

DieAtZeroHealthGuts._on_zero_health():  # zero-arg
    entity.emit_signal("request_deactivate")
```

---

## 11. What Does NOT Change

- **Velocity/position/angular accumulator API** — `request_velocity_set()`, `request_velocity_add()`, etc.
- **Hardcoded collision signals** — `"collision"(CDEntity, Vector2)` stays typed
- **Hardcoded lifecycle signals** — `"request_deactivate"`, `"entity_deactivating"`, `"entity_activated"`
- **Collision handler registration** — `register_collision_handler()` / `unregister_collision_handler()`
- **CDCollisionBuffer** — flushes at Priority 35, emits typed collision signals
- **CDGroupRegistry** — group membership, `group_count_changed` (emits zero-arg, data on game blackboard)
- **CDObjectPool** — acquire/return/activate/deactivate
- **Processing priority cascade** — same priorities, same ordering guarantees
- **Collision matrix** — layer/bitmask resolution
- **CDInputRouter** — routes player input (its signals are infrastructure, not game-level)
- **Object pooling lifecycle** — two-phase deactivate, pool return

---

## 12. Future Consideration (Phase 2)

The **universal accumulator** pattern — where the blackboard itself handles ADD/SET/REPLACE combination modes for keys with multiple writers — is deferred to a future iteration. The current scope uses a simple Dictionary. If multi-writer patterns become painful, a `CDBlackboard` engine class with `declare(key, mode)` can be introduced without changing component interfaces (only internal write behavior changes).