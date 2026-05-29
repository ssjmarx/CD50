# Patterns & Anti-Patterns

**Last Updated:** 2026-05-29
**Full reference:** `USAGE.md` — the canonical, in-depth guide to all patterns, anti-patterns, and code quality guidelines.

This file is a quick-reference index for AI agents working on the CD50 codebase. For detailed explanations, examples, and the complete priority pipeline, see `USAGE.md`.

---

## The Three Rules

1. **Composition over inheritance** — CDEntity is a blank physics shell. All behavior comes from components.
2. **Signals, not calls** — Components never call methods on other components. They emit signals.
3. **Single-purpose components** — Each component does one thing. Split if it does two.

---

## The Priority Pipeline

```
REGISTRATION(5) → INPUT(8) → INTENT(10) → STEERING(20) → ENTITY(30) → COLLISION(35) → INTERACTION(40) → STATE(50) → VISUAL(60) → AUDIO(65) → RULES(70) → UPDATE(90) → [deferred cleanup]
```

Reserved for infrastructure (never set by components): REGISTRATION, INPUT, ENTITY, COLLISION, UPDATE.

Component categories: INTENT=Brains, STEERING=Legs, INTERACTION=Arms, STATE=Guts, VISUAL=Faces, AUDIO=Voices, RULES=Stage.

---

## Core Patterns (Quick Reference)

| Pattern | Summary | See USAGE.md Section |
|---------|---------|---------------------|
| On Hit / On Crash | 2×2 collision matrix: DamageOnHit/Crash, DeathOnHit/Crash + Joust variants | Core Patterns |
| Collision Handler | `register_collision_handler()` for frame-perfect physics remainder ONLY | Core Patterns |
| Announcer | Entity bus → game bus bridge via AnnouncerGuts | Core Patterns |
| Controller | Stage directors emit directly on entity buses (no Brain needed) | Core Patterns |
| Group-as-State | Entity group membership IS entity state. CDGroupRegistry is source of truth. | Core Patterns |
| Pseudogrid | Physics IS the grid. No grid data structures. | Core Patterns |
| Object Pooling | Pool reference IS the toggle. Entity routes itself. Separate acquire/activate. | Core Patterns |
| WaveCard Relay | CDGame → WaveCard → Trapdoors. Multiple WaveCards = independent wave cycles. | Core Patterns |
| Two-Phase Init | `_ready()` for registration, `_on_initialize()` (deferred) for connections | Component Lifecycle |
| Two-Phase Deactivation | Immediate state change + deferred cleanup. Symmetric collisions preserved. | Component Lifecycle |

---

## Anti-Patterns (Quick Reference)

| Anti-Pattern | Why It's Wrong | Do Instead |
|-------------|---------------|------------|
| **The Phone Call** — calling methods on other components | Hard coupling, can't rewire | Emit signals |
| **Premature Connection** — connecting in `_ready()` | Other components don't exist yet | Connect in `_on_initialize()` |
| **Hardcoded Signal Names** — not using `@export` | Can't rewire per-game | `@export var signals: Array[StringName]` |
| **Cross-Entity Blind Emission** — no validity guards | Dead reference = crash | Guard with `is_instance_valid()` + `has_signal()` |
| **Direct Velocity Override** — `entity.velocity =` | Bypasses accumulator, ordering bugs | Use `request_velocity_set()` / `request_velocity_add()` |
| **Dueling Legs** — two set-based Legs on one entity | Only one set wins per frame | One set + multiple add-based Legs |
| **The Omnibrain** — Brain that moves/applies forces | Violates single-purpose | Split into Brain + Leg + Arm |
| **The Double Agent** — component tracks state AND affects others | Violates single-purpose | Split into Guts + Arm |
| **Game Logic in CDEntity** — adding rules to the entity | CDEntity is a blank shell | Use Stage components |
| **The Physics Leg** — collision handler for movement | Collision handlers are for bounce, not thrust | Use Leg + accumulator |
| **Bypassing the Buffer** — reading collisions in `_physics_process` | Other entities haven't moved yet | Use collision buffer signals |
| **The Leaky Pool** — not resetting state on deactivation | Stale state persists across pool reuse | Reset everything in `_on_entity_deactivating()` |
| **Premature Removal** — `queue_free()` on entity | Bypasses two-phase lifecycle | Use `entity.deactivate()` or `"request_deactivate"` |
| **Default Group Filters** — non-empty `target_groups` default | Overrides the collision matrix | Default to `[]`, trust the matrix |
| **The Singleton Assumption** — assuming only one instance | Architecture is designed for many entities | Use game bus or CDGroupRegistry for shared state |

---

## Key Conventions

- **Entity bus signals:** Imperative verb or noun (`"move"`, `"collision"`, `"take_damage"`)
- **Game bus signals:** Past tense or event noun (`"score_gained"`, `"wave_cleared"`, `"lives_depleted"`)
- **Entity groups:** Plural nouns (`"enemies"`, `"player"`, `"balls"`, `"formation"`, `"diving"`)
- **Export groups:** Always `@export_group("Listen Signals")` and `@export_group("Emit Signals")`
- **Group filter defaults:** Always `[]` (empty = trust collision matrix)
- **Disconnect pattern:** Always guard with `is_connected()` before disconnecting
- **Editor preview:** Faces and Voices use `@tool` + `Engine.is_editor_hint()`

---

## Signal Buses

### Entity Bus (native Godot signals)

**Hardcoded on CDEntity:** `collision`, `collided_by`, `moved`, `rotated`, `request_deactivate`, `entity_deactivating`, `entity_activated`

**Common dynamic signals (via `ensure_signal()`):** `move`, `move_to`, `aim`, `action`, `action_end`, `shoot`, `take_damage`, `heal`, `zero_health`, `health_changed`, `shape_changed`, `apply_status`, `status_began`, `status_ended`, `external_impulse`, `start_shooting`, `stop_shooting`, `piece_locked`, `timer_expired`, `timer_tick`, `grid_drop`, `rotate`, `step_blocked`, `rotation_blocked`, `spend_resource`, `resource_depleted`, `shield_hit`, `shield_broken`, `receive_powerup`, `path_finished`, `patrol_complete`, `sweep_complete`

### Game Bus (Dictionary on CDGame)

**Hardcoded by CDGame:** `game_state_changed`, `game_play`, `game_over`

**Common from stage components:** `score_gained`, `score_changed`, `multiplier_changed`, `lives_changed`, `lives_depleted`, `wave_start`, `wave_changed`, `track_changed`, `swoop_complete`, `t_spin_detected`, plus mark entry/exit signals

---

## Entity Init Dependency

**⚠️ Current limitation:** Entity initialization depends on CDGame infrastructure (group registry, collision buffer, input router, object pool). Entities cannot run standalone outside a CDGame scene tree. This coupling is a known constraint.