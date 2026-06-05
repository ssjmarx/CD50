# Arms — Entity Action Components

16 arm components that define what an entity **does** in response to events. All extend `CDEntityComponent` with `component_category = INTERACTION`.

Organized into 5 subcategories:
- **collision reactions/** — 9 scripts that respond to collision signals
- **death reactions/** — 2 scripts that respond to entity death
- **triggered arms/** — 2 scripts that fire on active entity input
- **powerup arms/** — 2 scripts for powerup delivery/reception
- **other/** — 1 specialized script (Block Drop piece splitting)

---

## Common Arm Pattern

Every arm follows the same lifecycle:

```
_ready()         → set component_category, call super._ready()
_on_initialize() → connect listen signals, ensure emit signals exist
_on_xxx()        → arm-specific logic (damage, spawn, push, etc.)
_on_entity_deactivating() → disconnect all listen signals
```

### Signal + Blackboard Convention

Arms use the **signal + blackboard** pattern for cross-entity and game-level communication:

1. **Write data** to the target's blackboard (entity or game)
2. **Emit zero-arg signal** to notify listeners

Arms use configurable export groups for both sides:

- **Listen Signals** — zero-arg entity signals the arm subscribes to (collision, zero_health, shoot, etc.)
- **Emit Signals** — zero-arg signals the arm fires after writing blackboard data
- **Emit Keys** — blackboard keys where the arm writes event data before signaling

All signals and keys are configurable via exports so arms work with any entity's signal set.

### Group Filtering

Most arms use `target_groups` or `source_groups` to filter which entities they affect:

- Empty array = affect everything (no filter)
- Non-empty = only affect entities in at least one listed group
- Uses `_is_valid_target(collider)` / `_is_valid_source(collider)` helper methods

### Object Pool Support

Spawn-based arms (`gun_arm`, `spawn_on_death`, `powerup_wingman`, `piece_splitter`) all support optional `CDObjectPool` via a `pool` export. When set, they use `pool.acquire()` / `entity.activate()` instead of `instantiate()` / `game.add_child()`.

### Must-Includes When Creating Arms

1. Extend `CDEntityComponent`
2. Set `component_category = CDEnums.ComponentCategory.INTERACTION` in `_ready()`
3. Connect listen signals in `_on_initialize()`
4. Disconnect in `_on_entity_deactivating()` with `is_connected()` guards
5. Use group filtering for collision/interaction arms
6. Support object pools for spawn-based arms

---

## Collision Reactions

Respond to `collision` signals. Each arm type targets a different recipient (self, collider) and effect (damage, death, push, score, status).

### Damage Arms

Write `incoming_damage` + `damage_source` to target's blackboard, then emit configurable `damage_signals` (default `take_damage`).

| Arm | Target | Effect |
|-----|--------|--------|
| `DamageOnCrashArm` | Self | Flat damage to self |
| `DamageOnHitArm` | Collider | Flat damage to collider |
| `DamageOnJoustArm` | Collider | Comparative property damage |

**Joust comparison modes** (`CDEnums.EntityCompare`):
- `VELOCITY` — damage scaled by velocity difference × `velocity_damage_scale`
- `Y_POSITION` — lower entity wins (inverted comparison)
- `CUSTOM` — compare any property by name via `custom_property_name`

**Joust tiebreakers** (`CDEnums.EntityCompareTiebreaker`):
- `DONT_FIRE` — no damage on tie
- `FIRE` — deal `minimum_damage` on tie

**Joust invalid action** (`CDEnums.EntityCompareInvalidAction`):
- `DONT_FIRE` — skip if property missing
- `FIRE` — deal `minimum_damage` if property missing

### Death Arms

| Arm | Target | Effect |
|-----|--------|--------|
| `DeathOnCrashArm` | Self | `request_deactivate` on self |
| `DeathOnHitArm` | Collider | `request_deactivate` on collider |
| `DeathOnJoustArm` | Collider | `request_deactivate` on collider (comparative) |

Death arms bypass the health pipeline entirely — they directly emit `request_deactivate`.

### Other Collision Arms

| Arm | Effect | Blackboard Write + Signal |
|-----|--------|--------------------------|
| `PushbackArm` | Physical impulse to collider | Writes impulse vector to collider's `impulse_keys`, emits `impulse_signals` |
| `ScoreOnCollisionArm` | Score to game bus | Reads `"points"` from entity blackboard; writes to `game.blackboard[scoring_keys]`, emits `score_signals` on game bus |
| `StatusOnHitArm` | Status effect to collider | Writes `status_name` + `duration` to collider's `status_keys` + `duration_keys`, emits `status_signals` |

---

## Death Reactions

Respond to entity death signals (default: `zero_health`). Fire once when the entity dies.

| Arm | Effect | Details |
|-----|--------|---------|
| `ScoreOnDeathArm` | Score to game bus | Reads `"points"` from entity blackboard; writes to `game.blackboard`, emits `score_gained` on game bus |
| `SpawnOnDeathArm` | Spawn entities at death position | Supports pool, spawn context, position/velocity inheritance |

---

## Triggered Arms

Actively triggered by entity input signals. The entity chooses when to fire these.

| Arm | Trigger | Effect |
|-----|---------|--------|
| `GunArm` | `shoot` signal | Spawns projectile with cooldown, optional max bullets, rotation inheritance |
| `TractorBeamArm` | `fire_tractor_beam` signal | Frame-based windup → capture → hold sequence; captures closest target in zone |

### GunArm Details

| Export | Default | Purpose |
|--------|---------|---------|
| `bullet_scene` | — | Projectile PackedScene |
| `pool` | null | Optional object pool |
| `cooldown` | 0.3s | Minimum time between shots |
| `max_bullets` | 0 | Max live projectiles (0 = unlimited) |
| `inherit_rotation` | true | Rotate projectile to match entity facing |

### TractorBeamArm Details

Frame-based active arm with 3 phases:
1. **Windup** (`windup_frames`) — entity emits `tractor_beam_windup`, tracks zone entries
2. **Capture** (at windup_frames) — finds closest target in zone, emits `player_captured` or `capture_missed`
3. **Hold** (`hold_frames`) — waits, then emits `tractor_beam_complete`

---

## Powerup Arms

| Arm | Effect | Details |
|-----|--------|---------|
| `PowerUpDeliveryArm` | Deliver powerup to collider | Emits `receive_powerup(powerup_id, entity)` on collider |
| `PowerupWingmanArm` | Spawn companion on powerup received | Checks `powerup_id` match, spawns with offset and optional pool |

---

## Other

| Arm | Effect | Details |
|-----|--------|---------|
| `PieceSplitterArm` | Split Block Drop piece into settled cells | On `piece_locked`, spawns individual `SettledCell` entities at each cell position, then deactivates self |
