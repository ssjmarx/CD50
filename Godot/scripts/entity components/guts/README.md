# Guts — Entity State Components

19 guts components organized into 6 subcategories. Guts track **state**, **resources**, and **rules** for an entity. All extend `CDEntityComponent` with `component_category = STATE`.

Unlike Brains (which produce intent) and Legs (which execute movement), Guts are reactive — they listen to entity signals and update internal state, write to entity blackboard, emit result signals, or modify entity behavior.

---

## Common Guts Pattern

```
_ready()                   → set component_category = STATE
_on_initialize()           → ensure signals, connect listeners, set initial state
_physics_process(delta)    → tick timers, recharge pools, check death conditions
_on_entity_deactivating()  → disconnect signals, reset state
_on_entity_activated()     → restore initial state, re-enable physics processing
```

### Must-Includes When Creating Guts

1. Extend `CDEntityComponent`
2. Set `component_category = CDEnums.ComponentCategory.STATE` in `_ready()`
3. Use `@export_group("Listen Signals")` and `@export_group("Emit Signals")` consistently
4. Export configurable blackboard keys with sensible defaults (e.g., `value_key: StringName = &"health"`)
5. Write state changes to `entity.blackboard[key]` for other components to read
6. Call `entity.ensure_signal()` before connecting in `_on_initialize()`
7. Disconnect all connections with validity guards in `_on_entity_deactivating()`
8. Reset all runtime state in `_on_entity_deactivating()` (for object pool reuse)
9. Implement `_on_entity_activated()` if the guts manages timers or physics processing

---

## Subcategories

### pools/ — Resource Pools (3 scripts)

Track numeric resources with depletion, regeneration, and overflow patterns. All pools write current value and delta to the entity blackboard on every change.

| Guts | Resource | Blackboard Keys | Key Signals |
|------|----------|-----------------|-------------|
| `HealthpoolGuts` | Integer health | `value_key` (`"health"`), `delta_key` (`"health_delta"`) | `zero_health`, `health_depleted`, `health_full` |
| `ShieldpoolGuts` | Float shield | `value_key`, `delta_key` | `shield_broken`, `shield_full` |
| `ResourcepoolGuts` | Generic float | `value_key`, `delta_key` | `resource_depleted`, `spend_failed` |

**Pool pattern:** Starting value defaults to max when set to -1. Pools read `damage_signals` (default `take_damage`) for incoming damage — the signal+blackboard pattern where arms write `incoming_damage` to blackboard before signaling. All pools write value and delta to blackboard on every change for downstream components to read.

### death/ — Entity Termination (4 scripts)

Destroy or deactivate the entity when specific conditions are met.

| Guts | Trigger | Notes |
|------|---------|-------|
| `DieAtZeroHealthGuts` | `zero_health` signal | Bridges healthpool to deactivation |
| `DieOffscreenGuts` | Leaves all camera views | Uses `VisibleOnScreenNotifier2D`, has activation delay |
| `DieOnTimerGuts` | Timer expires | Emits `timer_expired` before deactivation |
| `DieOutOfBoundsGuts` | Exits `game_bounds` + margin | Has activation delay to prevent spawn deaths |

**Death pattern:** All use `entity.deactivate()` or emit `request_deactivate`. Activation delays prevent premature death on spawn.

### physics/ — Collision & Forces (3 scripts)

Handle physical interactions between entities.

| Guts | Purpose | Mechanism |
|------|---------|-----------|
| `DeflectorBounceGuts` | Angled bounce on collision | Registered collision handler, configurable bias & restitution |
| `ImpulseReceiverGuts` | Apply external forces | Reads impulse from entity blackboard (`impulse_keys`), calls `request_velocity_add()` |
| `ShapeColliderGuts` | Dynamic collision shapes | Overrides entity collision polygon, updates on signal |

**Physics pattern:** `DeflectorBounceGuts` uses the entity's `register_collision_handler()` system. `ImpulseReceiverGuts` reads the impulse vector written by `PushbackArm` from the entity blackboard.

### detection/ — Entity Sensing (2 scripts)

Detect other entities or environmental conditions.

| Guts | Detects | Mechanism |
|------|---------|-----------|
| `LockDetectorGuts` | Grid entity landing (Tetris) | Lock delay with move/rotate reset limit |
| `VisionConeGuts` | Bodies in a forward cone | Dynamically created `Area2D` with `CollisionPolygon2D` |

**Detection pattern:** Both emit signals that other components (Brains, Arms) listen to for reactive behavior.

### input/ — Input Adaptation (2 scripts)

Convert between blackboard key formats for compatibility between Brains and Legs.

| Guts | Converts | Purpose |
|------|----------|---------|
| `KBMGuts` | Keyboard + mouse blackboard keys → unified direction | Reads `move_key` and `target_key`, writes `direction_key` |
| `MoveAdapterGuts` | Target position → direction vector | Reads `target_key`, writes `direction_key` |

**Adapter pattern:** These are pure blackboard translators with no internal state. They bridge Brains that write one key format to Legs that read another. They poll source keys every frame and write converted output.

### game logic/ — Rules & Scoring (5 scripts)

Implement game-specific rules, scoring, and status effects.

| Guts | Purpose | Blackboard / Signals |
|------|---------|----------------------|
| `AnnouncerGuts` | Entity bus → game bus relay | Relays entity signals to game bus, filtered by qualifying groups |
| `PointsGuts` | Data holder for point value | Writes `points` to entity blackboard; `ScoreOnCollisionArm` reads via `entity.blackboard.get("points", 0)` |
| `StunGuts` | Temporarily disable Brains & Legs | Reads `pending_status` from blackboard on `apply_status` signal; disables INTENT and STEERING categories for duration |
| `TSpinDetectorGuts` | SRS 3-corner T-spin detection | Writes results to game blackboard, emits on game bus |
| `TimerGuts` | Count-down/count-up timer | Tick interval, pause/resume/reset; writes elapsed/remaining to entity blackboard |
