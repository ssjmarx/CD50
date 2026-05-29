# Guts — Entity State Components

18 guts components organized into 6 subcategories. Guts track **state**, **resources**, and **rules** for an entity. All extend `CDEntityComponent` with `component_category = STATE`.

Unlike Brains (which emit intent) and Legs (which execute movement), Guts are reactive — they listen to entity signals and update internal state, emit result signals, or modify entity behavior.

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
4. Call `entity.ensure_signal()` before connecting in `_on_initialize()`
5. Disconnect all connections with validity guards in `_on_entity_deactivating()`
6. Reset all runtime state in `_on_entity_deactivating()` (for object pool reuse)
7. Implement `_on_entity_activated()` if the guts manages timers or physics processing

---

## Subcategories

### pools/ — Resource Pools (3 scripts)

Track numeric resources with depletion, regeneration, and overflow patterns.

| Guts | Resource | Key Features |
|------|----------|-------------|
| `HealthpoolGuts` | Integer health | Damage, heal, invincibility, `zero_health` signal |
| `ShieldpoolGuts` | Float shield | Absorbs damage, recharges after delay, overflows to health |
| `ResourcepoolGuts` | Generic float | Spend with failure signal, passive regeneration |

**Pool pattern:** Starting value defaults to max when set to -1. All pools emit change signals for UI binding.

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
| `ImpulseReceiverGuts` | Apply external forces | Listens for impulse signal, calls `request_velocity_add()` |
| `ShapeColliderGuts` | Dynamic collision shapes | Overrides entity collision polygon, updates on signal |

**Physics pattern:** `DeflectorBounceGuts` uses the entity's `register_collision_handler()` system. Others are signal-reactive.

### detection/ — Entity Sensing (2 scripts)

Detect other entities or environmental conditions.

| Guts | Detects | Mechanism |
|------|---------|-----------|
| `LockDetectorGuts` | Grid entity landing (Tetris) | Lock delay with move/rotate reset limit |
| `VisionConeGuts` | Bodies in a forward cone | Dynamically created `Area2D` with `CollisionPolygon2D` |

**Detection pattern:** Both emit signals that other components (Brains, Arms) listen to for reactive behavior.

### input/ — Input Adaptation (2 scripts)

Convert between input signal types for compatibility between Brains and Legs.

| Guts | Converts | Purpose |
|------|----------|---------|
| `KBMGuts` | `move` + `move_to` → `steer` | Merges keyboard and mouse into unified steering |
| `MoveAdapterGuts` | `move_to` → `move` | Converts positional targets to direction vectors |

**Adapter pattern:** These are pure signal translators with no internal state. They bridge Brains that emit one signal type to Legs that expect another.

### game logic/ — Rules & Scoring (4 scripts)

Implement game-specific rules, scoring, and status effects.

| Guts | Purpose | Key Signals |
|------|---------|-------------|
| `AnnouncerGuts` | Entity bus → game bus relay | Filtered by qualifying groups |
| `PointsGuts` | Data holder for point value | Just an exported `points: int` |
| `StunGuts` | Temporarily disable Brains & Legs | Disables INTENT and STEERING categories |
| `TSpinDetectorGuts` | SRS 3-corner T-spin detection | Emits to game bus: `[is_t_spin, is_mini]` |
| `TimerGuts` | Count-down/count-up timer | Tick interval, pause/resume/reset |