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

### Signal Convention

Arms use **Listen Signals** and **Emit Signals** export groups:

- **Listen Signals** — entity-level signals the arm subscribes to (collision, zero_health, shoot, etc.)
- **Emit Signals** — signals the arm emits on other entities or the game bus

All signals are configurable via exports so arms work with any entity's signal set.

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

| Arm | Target | Effect | Signal Emitted |
|-----|--------|--------|----------------|
| `DamageOnCrashArm` | Self | Flat damage to self | `take_damage` on self |
| `DamageOnHitArm` | Collider | Flat damage to collider | `take_damage` on collider |
| `DamageOnJoustArm` | Collider | Comparative property damage | `take_damage` on collider |

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

| Arm | Effect | Details |
|-----|--------|---------|
| `PushbackArm` | Physical impulse to collider | Uses collision normal or direction vector; emits `external_impulse` |
| `ScoreOnCollisionArm` | Score to game bus | Reads points from sibling `PointsGuts`; emits `score_gained` on game |
| `StatusOnHitArm` | Status effect to collider | Sends `status_name` + `duration` via `apply_status` signal |

---

## Death Reactions

Respond to entity death signals (default: `zero_health`). Fire once when the entity dies.

| Arm | Effect | Details |
|-----|--------|---------|
| `ScoreOnDeathArm` | Score to game bus | Reads points from sibling `PointsGuts`; emits `score_gained` on game |
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