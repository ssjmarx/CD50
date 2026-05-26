# Plan 22: V2 Arms + Guts

## Overview

Build the complete library of V2 Arm and Gut components. Arms affect the game state *outside* the entity (deal damage, apply forces, announce score). Guts track *internal* entity state (health, timers, resources, lock detection). 

By strictly separating these into Priority 40 (Arms) and Priority 50 (Guts), we solve the "I shot you but you shot me and we both lived" paradox. The order is deterministic:

1. Physics Buffer flushes collisions (Priority 35).
2. **Arms** deal damage and apply effects based on those collisions (Priority 40).
3. **Guts** process that damage, check for death, and clean up (Priority 50).

No gameplay is built. The goal is a complete, tested catalog of components that can be composed into any game entity.

**Depends on:** Plan 19 (Core Infrastructure), Plan 19.5 (Object Pools), Plan 20 (Stage), Plan 21 (Brains + Legs)

---

## The Announcer Pattern

Any component can use the **announcer pattern** — emitting signals to the game bus instead of (or in addition to) the entity bus. This is a *pattern*, not a category. Components that announce run at their normal priority:

- An Arm that announces (e.g., ScoreOnDeathArm emits `score_gained` to game bus) → Priority 40
- A Guts that announces (e.g., TSpinDetectorGuts emits `t_spin_detected` to game bus) → Priority 50

This is complementary to the **controller pattern** (Stage components that emit on entity buses). Controllers command entities. Announcers report entity state to the world.

---

## The On Hit / On Crash Pattern

V2 collision response follows a clean 2×2 matrix. Each cell is a single-purpose Arm:

| | Damage | Death (Deactivate) |
|---|---|---|
| **On Hit** (emit on *collider's* bus) | DamageOnHitArm | DeathOnHitArm |
| **On Crash** (emit on *own* bus) | DamageOnCrashArm | DeathOnCrashArm |

**Classic bullet:** `DamageOnHitArm` + `DeathOnCrashArm`
- Bullet hits enemy → DamageOnHit emits `take_damage` on enemy's bus
- Bullet hits wall → DeathOnCrash emits `request_deactivate` on own bus

**Spikes/hazards:** `DeathOnHitArm` — kills target instantly, bypasses health
**Player vehicle:** `DamageOnCrashArm` — player takes damage on any collision

The **OnJoust** variants add comparative logic (velocity, Y position, or custom property) with tiebreaker and invalid-comparison handling.

---

## Arms (11 Components)

Category: `ARM` (Priority 40). Arms affect the game state *outside* the entity. They deal damage, apply forces, or announce score. They never modify the entity's own `velocity` or internal `HealthPool`.

### Collision Response Arms (6)

#### DamageOnHitArm
**Role:** Deals a flat amount of damage to whatever the entity collides with.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"collision(collider: CDEntity, normal: Vector2)"` |
| **Generates** | Collider's entity bus: `"take_damage(amount: int, source: CDEntity)"` |
| **Exports** | `damage_amount: int = 1` <br> `target_group: StringName = &"enemies"` <br> `collision_signal: StringName = &"collision"` <br> `damage_signal: StringName = &"take_damage"` |
| **Process** | On collision, validates `collider` is in `target_group` and `is_instance_valid()`. If so, guards with `collider.has_signal(damage_signal)` and emits `damage_signal` on the *collider's* entity bus. If the collider lacks the signal (e.g., a wall without HealthPoolGuts), silently skips — no error. This follows the V2 cross-entity safety rule from Plan 19. |
| **V1 Predecessor** | `damage_on_hit.gd` |

#### DeathOnHitArm
**Role:** Instantly kills whatever the entity collides with. Bypasses health pipeline entirely.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"collision(collider: CDEntity, normal: Vector2)"` |
| **Generates** | Collider's entity bus: `"request_deactivate"` |
| **Exports** | `target_group: StringName = &"enemies"` <br> `collision_signal: StringName = &"collision"` |
| **Process** | On collision, validates `collider` is in `target_group` and `is_instance_valid()`. If so, emits `"request_deactivate"` on the *collider's* entity bus. |
| **Use Case** | Instakill zones, spikes, certain projectile types. Use DamageOnHitArm if you want the target to go through the health pipeline (for score, death effects, etc.). |

#### DamageOnCrashArm
**Role:** Deals damage to the entity itself when it collides with anything.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"collision(collider: CDEntity, normal: Vector2)"` |
| **Generates** | Own entity bus: `"take_damage(amount: int, source: CDEntity)"` |
| **Exports** | `damage_amount: int = 1` <br> `source_group: StringName = &""` (empty = any collision) <br> `collision_signal: StringName = &"collision"` <br> `damage_signal: StringName = &"take_damage"` |
| **Process** | On collision, if `source_group` is empty OR collider is in `source_group`, emits `damage_signal` on *own* entity bus with self as source. |
| **Use Case** | Player vehicles taking damage on impact, bullets that die on wall contact (combined with DieAtZeroHealthGuts). |

#### DeathOnCrashArm
**Role:** Instantly kills the entity itself when it collides with anything.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"collision(collider: CDEntity, normal: Vector2)"` |
| **Generates** | Own entity bus: `"request_deactivate"` |
| **Exports** | `source_group: StringName = &""` (empty = any collision) <br> `collision_signal: StringName = &"collision"` |
| **Process** | On collision, if `source_group` is empty OR collider is in `source_group`, emits `"request_deactivate"` on *own* entity bus. |
| **Use Case** | Bullets dying on wall contact. V1 `die_on_hit.gd` was this behavior. |

#### DamageOnJoustArm
**Role:** Deals damage to the collider based on a comparative property check (velocity, Y position, or custom).

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"collision(collider: CDEntity, normal: Vector2)"` |
| **Generates** | Collider's entity bus: `"take_damage(amount: int, source: CDEntity)"` |
| **Exports** | `comparison_mode: JoustCompare = JoustCompare.VELOCITY` <br> `velocity_damage_scale: float = 0.01` <br> `minimum_damage: int = 1` <br> `comparison_tolerance: float = 0.0` <br> `tiebreaker: JoustTiebreaker = JoustTiebreaker.DONT_FIRE` <br> `invalid_comparison: JoustInvalidAction = JoustInvalidAction.DONT_FIRE` <br> `custom_property_name: StringName = &""` (for CUSTOM_GUTS mode) <br> `target_group: StringName = &"enemies"` <br> `collision_signal: StringName = &"collision"` <br> `damage_signal: StringName = &"take_damage"` |
| **Process** | On collision, validates collider. Compares property based on `comparison_mode`. If self wins, emits `damage_signal` on collider's bus with scaled damage. On tie, uses `tiebreaker`. On invalid comparison (e.g., collider lacks the property), uses `invalid_comparison`. |
| **V1 Predecessor** | `damage_on_joust.gd` |

**JoustCompare Enum:**
- `VELOCITY` — Compare relative velocity magnitude. Higher speed wins. Damage scales with difference × `velocity_damage_scale`.
- `Y_POSITION` — Compare Y coordinates. Lower Y (higher on screen) wins. Classic Joust behavior.
- `CUSTOM_GUTS` — Compare a named property on a Guts component (e.g., `current_health` from HealthPoolGuts). Higher value wins.

#### DeathOnJoustArm
**Role:** Instantly kills the collider based on the same comparative property check as DamageOnJoustArm. Bypasses health pipeline.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"collision(collider: CDEntity, normal: Vector2)"` |
| **Generates** | Collider's entity bus: `"request_deactivate"` |
| **Exports** | `comparison_mode: JoustCompare = JoustCompare.VELOCITY` <br> `comparison_tolerance: float = 0.0` <br> `tiebreaker: JoustTiebreaker = JoustTiebreaker.DONT_FIRE` <br> `invalid_comparison: JoustInvalidAction = JoustInvalidAction.DONT_FIRE` <br> `custom_property_name: StringName = &""` <br> `target_group: StringName = &"enemies"` <br> `collision_signal: StringName = &"collision"` |
| **Process** | Same comparison logic as DamageOnJoustArm. If self wins, emits `"request_deactivate"` on collider's bus instead of damage. |

---

### Scoring Arms (2)

**Design principle:** Each entity is responsible for its own scoring events. Score components read their **own** entity's `PointsGuts`. They never look into another entity to find a score value.

#### ScoreOnCollisionArm
**Role:** Announcer arm. Emits `score_gained(int)` to the game bus when the entity collides with a valid target. The value comes from the entity's own `PointsGuts`.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"collision(collider: CDEntity, normal: Vector2)"` |
| **Generates** | Game bus: `"score_gained(amount: int)"` |
| **Exports** | `target_group: StringName = &"enemies"` <br> `collision_signal: StringName = &"collision"` |
| **Process** | On collision, validates collider is in `target_group`. Reads `PointsGuts.points` from own entity. Emits `"score_gained"` on game bus with that value. |
| **Use Case** | A "pinball bumper" that awards a score every time it gets hit, but doesn't die. |
| **V1 Predecessor** | `score_on_hit.gd` |

#### ScoreOnDeathArm
**Role:** Announcer arm. Emits `score_gained(int)` to the game bus when the entity receives a death signal. The value comes from the entity's own `PointsGuts`.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"zero_health"` |
| **Generates** | Game bus: `"score_gained(amount: int)"` |
| **Exports** | `death_signal: StringName = &"zero_health"` |
| **Process** | On `"zero_health"`, reads `PointsGuts.points` from own entity. Emits `"score_gained"` on game bus with that value. |
| **Use Case** | An enemy asteroid that awards points when destroyed. The asteroid owns its own point value and announces it on death. |
| **V1 Predecessor** | `score_on_death.gd` |

---

---

### Force/Status Arms (2)

#### PushbackArm
**Role:** Applies a physical impulse to another entity on collision. Requires `ImpulseReceiverGuts` on the target to actually apply the velocity.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"collision"` |
| **Generates** | Collider's entity bus: `"external_impulse(impulse: Vector2)"` |
| **Exports** | `push_force: float = 500.0` <br> `target_group: StringName = &""` <br> `use_collision_normal: bool = true` <br> `collision_signal: StringName = &"collision"` <br> `impulse_signal: StringName = &"external_impulse"` |
| **Process** | On collision, validates target. Calculates impulse direction (collision normal if `use_collision_normal`, else direction to collider). Emits `impulse_signal` on collider's bus. |

#### StatusEffectArm
**Role:** Applies a named status effect to a target on collision. Decouples the *application* from the *execution*.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"collision"` |
| **Generates** | Collider's entity bus: `"apply_status(status_name: StringName, duration: float)"` |
| **Exports** | `status_name: StringName = &"stun"` <br> `duration: float = 2.0` <br> `target_group: StringName = &""` <br> `collision_signal: StringName = &"collision"` <br> `status_signal: StringName = &"apply_status"` |
| **Process** | On collision, validates target. Emits `status_signal` on collider's bus with `status_name` and `duration`. |

---

## Guts (12 Components)

Category: `GUTS` (Priority 50). Guts track internal state. They are purely self-centered — they don't care about the outside world except for signals telling them to update their internal variables.

### Collision Handler (1)

#### DeflectorBounceGuts
**Role:** Collision handler that deflects off target groups with angled bounce physics. Uses the collision handler API (Section 12 of V2 Rules) for frame-perfect physics remainder resolution. Self-contained — owns its own deflection config, no separate Arm needed.

| Aspect | Detail |
|--------|--------|
| **Registers** | Collision handler via `entity.register_collision_handler(target_groups, handler)` — resolved to layer bitmask at registration time for zero-cost hot path matching |
| **Generates** | Modifies `entity.velocity` directly (collision handler pattern — this IS physics resolution) |
| **Exports** | `target_groups: Array[StringName] = []` (empty = handle all collisions, trust the matrix. Set specific groups for ROUTING e.g. `[&"paddles"]` = deflect off paddles only, walls get default BOUNCE) <br> `deflection_bias: Vector2 = Vector2(1, 1)` (X/Y bias for deflection angle — higher X = wider horizontal deflection) <br> `restitution: float = 1.0` (1.0 = perfect elastic, <1.0 = energy loss, >1.0 = energy gain) |
| **Process** | On collision with a target group entity: (1) Calculate raw offset from entity to collider, normalized. (2) Apply `deflection_bias` to X/Y components. (3) Re-normalize. (4) Set `entity.velocity = direction * speed * restitution`. (5) Return `collision.get_remainder().slide(normal)` for the remaining movement. Collisions with non-target entities fall through to the default collision response (BOUNCE/SLIDE/STOP per CDEntity export). |
| **Use Case** | Pong ball (scene override): `target_groups = [&"paddles"]` — bounces off paddles with offset-based angles, bounces normally off walls. Default (empty): handles all collisions with deflection — useful for Breakout paddles and bumpers. |
| **Why not an Arm on the paddle?** The ball already knows what it's deflecting off of via `target_groups`. Adding a second component just to hold two floats is over-engineering for current requirements. If per-surface variation is ever needed (Pinball flippers vs bumpers), create a game-specific component at that time. |

---

### Collision Shape (1)

#### ShapeColliderGuts
**Role:** Listens for runtime shape changes and applies them to CDEntity's collision via the Collision Shape API. Enables procedural shapes (asteroids) and shared visual/physics shapes (triangle ship, paddle).

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"shape_changed(points: PackedVector2Array)"` |
| **Generates** | Calls `entity.set_collision_polygon()`, `entity.set_collision_circle()`, or `entity.set_collision_rect()` |
| **Exports** | `static_points: PackedVector2Array` (optional — if set, applies on init for static entities) |
| **Process** | 1. On `_on_initialize()`: if `static_points` is set and non-empty, call `entity.set_collision_polygon(static_points)`. <br> 2. On `"shape_changed"`: call `entity.set_collision_polygon(points)` with the received array. |

**Static use case:** Triangle ship has a pre-authored `PackedVector2Array` in the export. ShapeColliderGuts applies it on init. No signal needed.
**Dynamic use case:** AsteroidGuts generates random polygon points at runtime, emits `"shape_changed"`. ShapeColliderGuts applies it. VectorFace also hears `"shape_changed"` and draws the same points — both components consume the same signal.

**Cross-references:** CDEntity Collision Shape API defined in Plan 19. AsteroidGuts (game-specific Guts) not defined in this plan — it's a game implementation component.

---

### Health & Death (3)

#### HealthPoolGuts
**Role:** The single source of truth for an entity's life force.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: configurable damage signal (default `"take_damage"`), `"heal(amount: int)"` |
| **Generates** | Entity bus: `"health_changed(current: int, delta: int)"`, `"zero_health"` |
| **Exports** | `max_health: int = 3` <br> `starting_health: int = -1` (defaults to `max_health`) <br> `invincible: bool = false` <br> `damage_signal: StringName = &"take_damage"` |
| **Process** | Maintains `_current_health`. On `damage_signal`, if not invincible, reduces health. Emits `"health_changed"`. If `_current_health <= 0`, emits `"zero_health"`. On `"heal"`, increases health (capped at `max_health`), emits `"health_changed"`. |
| **Note** | When paired with ShieldPoolGuts, change `damage_signal` to `&"take_health_damage"` so ShieldPool is the primary damage consumer. |
| **V1 Predecessor** | `health.gd` |

#### DieAtZeroHealthGuts
**Role:** Kills the entity when health reaches zero. Decoupled from HealthPool so you can have invincible enemies or boss phase triggers at 0 HP instead of dying.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"zero_health"` |
| **Generates** | Entity bus: `"request_deactivate"` (calls `entity.deactivate()`) |
| **Process** | Hears `"zero_health"`, immediately calls `entity.deactivate()`. |
| **V1 Predecessor** | Part of `health.gd` |

#### PointsGuts
**Role:** Pure data holder for how much an entity is worth. Read by ScoreOnCollisionArm/ScoreOnDeathArm on the **same entity**.

| Aspect | Detail |
|--------|--------|
| **Exports** | `points: int = 100` |
| **Process** | None. Data-only component. |
| **Note** | Not needed for Tetris (LineClearMonitor is the single source of truth for Tetris scoring). Used for non-Tetris games where entity death/hit awards score. |

---

### Self-Destruction (2)

#### DieOnTimerGuts
**Role:** Destroys the entity after a set duration. For bullets, bombs, power-up durations.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Engine delta |
| **Generates** | Entity bus: `"timer_expired"`, `"request_deactivate"` |
| **Exports** | `lifespan: float = 3.0` |
| **Process** | Counts down from `lifespan`. On zero, emits `"timer_expired"` then `"request_deactivate"`. |
| **V1 Predecessor** | `die_on_timer.gd` |

#### DieOffscreenGuts
**Role:** Destroys entity if it leaves the game bounds.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity `global_position` |
| **Generates** | Entity bus: `"request_deactivate"` |
| **Exports** | `margin: float = 50.0` (extra pixels beyond game bounds) <br> `activation_delay: float = 1.0` (prevents dying on spawn) |
| **Process** | Tracks position. Waits `activation_delay` after init. If outside `game.game_bounds` + margin, triggers deactivation. |
| **V1 Predecessor** | `screen_cleanup.gd` |

---

### Force Reception (1)

#### ImpulseReceiverGuts
**Role:** Listens for sudden external forces (knockback, explosions) and applies them to the velocity accumulator for one frame.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"external_impulse(impulse: Vector2)"` |
| **Generates** | `entity.request_velocity_add(impulse)` |
| **Process** | On `"external_impulse"`, immediately adds the vector to the velocity accumulator. This ensures knockback respects friction and other legs. |

---

### Resource Pools (2)

#### ShieldPoolGuts
**Role:** A rechargeable health buffer that sits on top of `HealthPoolGuts`. Damage hits this first.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"take_damage"` (primary consumer) |
| **Generates** | Entity bus: `"shield_hit"`, `"shield_broken"`, `"shield_recharged"`, `overflow_signal` with remaining damage |
| **Exports** | `max_shield: float = 50.0` <br> `recharge_delay: float = 3.0` <br> `recharge_rate: float = 10.0` <br> `overflow_signal: StringName = &"take_health_damage"` |
| **Process** | On `"take_damage"`, absorbs damage into shield. If damage exceeds current shield, emits `overflow_signal` with the remainder (consumed by HealthPoolGuts). If no damage taken for `recharge_delay`, regenerates shield at `recharge_rate`. Emits `"shield_hit"` on absorb, `"shield_broken"` when depleted, `"shield_recharged"` when full. |
| **Pipeline** | `take_damage` → ShieldPoolGuts → `take_health_damage` → HealthPoolGuts. When ShieldPool is present, HealthPoolGuts's `damage_signal` should be set to `&"take_health_damage"`. |
| **Tree ordering** | Both ShieldPoolGuts and HealthPoolGuts run at Priority 50. Godot processes same-priority siblings in tree order. **ShieldPoolGuts MUST be placed above HealthPoolGuts in the scene tree** so it processes `take_damage` first and emits `take_health_damage` before HealthPoolGuts runs. This ordering is fragile — document it clearly in the component's comments. |

#### ResourcePoolGuts
**Role:** Generic pool for stamina, mana, or ammo.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"spend_resource(amount: float)"` |
| **Generates** | Entity bus: `"resource_changed(current: float)"`, `"resource_depleted"` |
| **Exports** | `max_resource: float = 100.0` <br> `regen_rate: float = 5.0` |
| **Process** | Subtracts amount. If < 0, emits `"resource_depleted"` and blocks further spending. Regenerates over time at `regen_rate`. |

---

### Status Effects (1)

#### StunGuts
**Role:** Temporarily disables Brains and Legs when a stun status is applied.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"apply_status(status_name: StringName, duration: float)"` |
| **Generates** | Entity bus: `"status_began"`, `"status_ended"` |
| **Exports** | `target_status: StringName = &"stun"` |
| **Process** | If `status_name` matches `target_status`, disables all child components of category BRAIN and LEGS for `duration` seconds. Re-enables them when duration expires. Emits status signals for visual feedback. |

---

### Grid/Tetris Specific (2)

#### LockDetectorGuts
**Role:** Detects when a grid entity can't fall further, manages lock delay, and emits settlement signals.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"collision"`, `"moved"`, `"rotated"` |
| **Generates** | Entity bus: `"piece_locked"` |
| **Exports** | `lock_delay: float = 0.5` <br> `max_resets: int = 15` (prevents infinite spin) <br> `collision_signal: StringName = &"collision"` <br> `move_signal: StringName = &"moved"` <br> `rotate_signal: StringName = &"rotated"` |
| **Process** | On `"collision"` from below, starts lock timer. On `"moved"` or `"rotated"`, resets timer (up to `max_resets`). When timer expires, emits `"piece_locked"`. |
| **V1 Predecessor** | `lock_detector.gd` |

#### TSpinDetectorGuts
**Role:** Uses the SRS 3-corner rule to detect T-spins when a T-shaped piece locks. Uses the **announcer pattern** — emits directly to the game bus, not the entity bus.

| Aspect | Detail |
|--------|--------|
| **Consumes** | Entity bus: `"rotated"`, `"piece_locked"` |
| **Generates** | Game bus: `"t_spin_detected(is_t_spin: bool, is_mini: bool)"` (announcer pattern) |
| **Exports** | `corner_cast_distance: float = 10.0` <br> `lock_signal: StringName = &"piece_locked"` <br> `rotate_signal: StringName = &"rotated"` |
| **Process** | Tracks rotation inputs. On `"piece_locked"`, performs 4 corner raycasts around the piece's pivot. Evaluates corners hit against SRS rules, determines if it's a full T-Spin or Mini. Announces result to game bus. |
| **Note** | Nothing on the entity consumes T-Spin state. The LineClearMonitor (Stage) uses this announcement to modify scoring. The 1-frame scan delay in LineClearMonitor ensures `t_spin_detected` arrives before scoring. |
| **V1 Predecessor** | `t_spin_detector.gd` |

---

## V1 → V2 Migration Map

| V1 Script | V2 Component(s) | Key Changes |
|-----------|-----------------|-------------|
| `damage_on_hit.gd` | DamageOnHitArm | Same concept, configurable signal names, group filtering |
| `damage_on_joust.gd` | DamageOnJoustArm + DeathOnJoustArm | Expanded with comparison enum, tiebreaker, invalid handling |
| `die_on_hit.gd` | DeathOnCrashArm | V1 killed self on collision → V2 "on crash" pattern |
| `score_on_hit.gd` | ScoreOnCollisionArm | Now reads own PointsGuts, uses announcer pattern |
| `score_on_death.gd` | ScoreOnDeathArm | Now reads own PointsGuts, uses announcer pattern |
| `die_on_timer.gd` | DieOnTimerGuts | Direct migration |
| `screen_cleanup.gd` | DieOffscreenGuts | Direct migration with activation_delay |
| `health.gd` | HealthPoolGuts + DieAtZeroHealthGuts | V1 combined HP + death → V2 split for composability |
| `lock_detector.gd` | LockDetectorGuts | Direct migration |
| `t_spin_detector.gd` | TSpinDetectorGuts | Now uses announcer pattern (game bus, not entity bus) |
| (none) | DamageOnCrashArm, DeathOnHitArm | New — completes the 2×2 collision matrix |
| (none) | DeathOnJoustArm | New — completes the joust pair |
| (none) | PushbackArm + ImpulseReceiverGuts | New — knockback system |
| (none) | StatusEffectArm + StunGuts | New — status effect system |
| (none) | ShieldPoolGuts | New — rechargeable shield with pipeline damage routing |
| (none) | ResourcePoolGuts | New — generic resource pool |
| (none) | PointsGuts | Data-only component holding entity point value |
| (none) | ShapeColliderGuts | Applies CDShape to CDEntity collision via API — enables procedural + shared shapes |

---

## Implementation Order

### Phase 1: Core Collision (prove the 2×2 pattern)
1. DamageOnHitArm → prove collision → other entity bus
2. DeathOnCrashArm → prove collision → own entity bus
3. DamageOnCrashArm → prove self-damage pipeline
4. DeathOnHitArm → prove instakill on collider

### Phase 2: Health Pipeline
5. HealthPoolGuts → prove damage consumption + zero_health emission
6. DieAtZeroHealthGuts → prove death pipeline: DamageOnHit → HealthPool → DieAtZero → deactivate
7. PointsGuts → data-only, test with scoring arms

### Phase 3: Self-Destruction
8. DieOnTimerGuts → prove timed deactivation
9. DieOffscreenGuts → prove bounds check deactivation

### Phase 4: Scoring
10. ScoreOnCollisionArm → prove announcer pattern (collision → read own PointsGuts → game bus)
11. ScoreOnDeathArm → prove announcer pattern (zero_health → read own PointsGuts → game bus)

### Phase 5: Shield + Resources
12. ShieldPoolGuts → prove damage pipeline: take_damage → shield → overflow → health
13. ResourcePoolGuts → prove spend/regen/depleted cycle

### Phase 6: Force + Status
14. PushbackArm + ImpulseReceiverGuts → prove knockback chain
15. StatusEffectArm + StunGuts → prove status application + component disable

### Phase 7: Joust
16. DamageOnJoustArm → prove all 3 comparison modes + tiebreaker + invalid
17. DeathOnJoustArm → prove joust instakill variant

### Phase 8: Tetris-Specific
18. LockDetectorGuts → prove lock delay + reset logic
19. TSpinDetectorGuts → prove announcer pattern (entity bus → game bus `t_spin_detected`)

---

## Proof / Testing

### Test 1: Bullet vs Enemy (Full Death Pipeline)
- Bullet: DamageOnHitArm + DeathOnCrashArm + DieOnTimerGuts
- Enemy: HealthPoolGuts(3) + DieAtZeroHealthGuts + PointsGuts(100) + ScoreOnDeathArm
- Bullet hits enemy → DamageOnHit emits `take_damage(1)` on enemy bus → HealthPool reduces to 2
- Bullet hits wall → DeathOnCrash emits `request_deactivate` on own bus
- Enemy takes 3 hits → HealthPool emits `zero_health` → DieAtZero kills → ScoreOnDeathArm awards score

### Test 2: Shield Pipeline
- Entity: ShieldPoolGuts(50) + HealthPoolGuts(3, `damage_signal = &"take_health_damage"`) + DieAtZeroHealthGuts
- Take 30 damage → ShieldPool absorbs, emits `shield_hit`
- Take 30 damage → ShieldPool absorbs 20, emits `shield_broken`, overflows 10 as `take_health_damage`
- HealthPoolGuts receives `take_health_damage(10)` → reduces HP to 2
- Wait recharge_delay → ShieldPool regenerates

### Test 3: Joust (Y Position)
- Entity A at Y=100, Entity B at Y=200
- DeathOnJoustArm on Entity A with `comparison_mode = Y_POSITION`
- Collision → A has lower Y (higher on screen) → A wins → B dies
- Reverse positions → B wins → A would die if B also had the arm

### Test 4: Joust (Custom Guts)
- Entity A with HealthPoolGuts(5 HP, current 4)
- Entity B with HealthPoolGuts(3 HP, current 2)
- DamageOnJoustArm on A with `comparison_mode = CUSTOM_GUTS`, `custom_property_name = &"current_health"`
- Collision → A (4) > B (2) → A deals damage to B

### Test 5: Knockback Chain
- Enemy: ImpulseReceiverGuts + FrictionLinear
- Explosion: PushbackArm(push_force = 500)
- On collision → Pushback emits `external_impulse` → ImpulseReceiver adds to velocity → Friction decelerates

### Test 6: Stun Chain
- Enemy: StunGuts + ChaseNearestBrain + EightWayWalk
- Attacker: StatusEffectArm(status = "stun", duration = 2.0)
- On collision → StatusEffect emits `apply_status("stun", 2.0)` → StunGuts disables Brain + Legs → entity stops for 2s → resumes

### Test 7: T-Spin Detect + Announce
- ActivePiece: TSpinDetectorGuts + LockDetectorGuts
- Player rotates T-piece into tight space → locks
- TSpinDetector hears `piece_locked` → corner raycasts → detects T-Spin
- Emits `t_spin_detected(true, false)` on game bus (announcer pattern)
- LineClearMonitor receives `piece_settled`, checks game bus state for T-Spin, awards bonus score

---

## File Structure

```
Godot/Scripts/
├── Arms/
│   ├── damage_on_hit_arm.gd
│   ├── death_on_hit_arm.gd
│   ├── damage_on_crash_arm.gd
│   ├── death_on_crash_arm.gd
│   ├── damage_on_joust_arm.gd
│   ├── death_on_joust_arm.gd
│   ├── score_on_collision_arm.gd
│   ├── score_on_death_arm.gd
│   ├── pushback_arm.gd
│   └── status_effect_arm.gd
├── Guts/
│   ├── deflector_bounce_guts.gd    # Collision handler for angled bounce physics
│   ├── shape_collider_guts.gd      # Applies CDShape to entity collision
│   ├── health_pool_guts.gd
│   ├── die_at_zero_health_guts.gd
│   ├── points_guts.gd
│   ├── die_on_timer_guts.gd
│   ├── die_offscreen_guts.gd
│   ├── impulse_receiver_guts.gd
│   ├── shield_pool_guts.gd
│   ├── resource_pool_guts.gd
│   ├── stun_guts.gd
│   ├── lock_detector_guts.gd
│   └── t_spin_detector_guts.gd
```

---

## Risks & Open Questions

1. **ShieldPool → HealthPool pipeline timing:** ShieldPoolGuts consumes `take_damage` at Priority 50 and emits `take_health_damage` in the same frame. HealthPoolGuts also runs at Priority 50. If Godot processes children in tree order, ShieldPool must be above HealthPool in the scene tree. **Mitigation:** Document this ordering requirement, or use `call_deferred` for the overflow emission so HealthPool processes it next frame.

2. **Joust custom property access:** `CUSTOM_GUTS` comparison mode needs to read a property from a Guts component on the collider. This requires knowing which component has the property. **Options:** (a) Use Godot's `get()` with the property name on the collider entity directly, (b) require a specific node path. Option (a) is more flexible but less type-safe. Recommend option (a) with a `push_error()` if the property doesn't exist.

3. **StunGuts component disable approach:** Disabling BRAIN and LEGS children by category requires iterating children and checking their category. This assumes categories are stored as a property on `CDComponent2D`. If not, we need a group-based or metadata-based approach. **Resolution:** Confirm category property exists on CDComponent2D during Plan 19 implementation.

4. **TSpinDetector timing with LineClearMonitor:** TSpinDetectorGuts announces to the game bus at Priority 50. LineClearMonitor scans after `piece_settled` (from PieceSplitterArm at Priority 40) with a 1-frame delay. The 1-frame delay ensures TSpinDetectorGuts has already announced. **Risk:** If the 1-frame delay is ever removed, T-Spin detection breaks silently. **Mitigation:** Document the timing dependency clearly in LineClearMonitor.

5. **DeathOnHitArm vs DamageOnHitArm redundancy:** Both emit on the collider's bus, just with different signals. The composability benefit (clear intent, bypass health for instakill) outweighs the code duplication. Both are ~20 lines each.

</task_progress>