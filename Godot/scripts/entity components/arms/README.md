# Arms

`Arms` are `CDEntityComponent` scripts that make an entity **do things** — react to collisions, fire projectiles, deliver powerups, split into pieces, or respond to death. They are the "outward-facing" action components of an entity: they listen for signals and emit signals (or spawn entities) in response.

Every script in this folder extends `CDEntityComponent` (see `Godot/scripts/core/base classes/cd_entity_component.gd`) and declares `component_category = CDEnums.ComponentCategory.INTERACTION`.

---

## Base class contract (`CDEntityComponent`)

Arms rely on the following members provided by the base class. These are real, not assumed:

| Member | Provided by base | Notes |
|---|---|---|
| `entity: CDEntity` | cached ref | The parent entity. Resolved in `_ready()`; safe to use from `_on_initialize()` onward. |
| `game: CDGame` | cached ref | The ancestor game node. Resolved in `_ready()`. |
| `_on_initialize()` | virtual | Override to connect listen-signals and read sibling state. Called once during activation. |
| `_on_entity_deactivating()` | virtual | Override to disconnect signals and reset state. Base implementation calls `set_physics_process(false)`. |
| `_on_entity_activated()` | virtual | Override to re-enable processing when recycled from a pool. |
| `bus_connect(signal_name, callable)` | helper | Adds the user signal to `entity` if missing, connects it, and tracks the connection (for `CDBody` sleep/wake). |
| `bus_disconnect(signal_name, callable)` | helper | Disconnects and untracks. |
| `component_category` | export | Set to `INTERACTION` by every arm in this folder. |

The lifecycle is two-phase:
1. `_ready()` resolves `entity`/`game` refs, then `call_deferred("_initialize")`.
2. `_initialize()` connects `entity_deactivating` / `entity_activated`, then calls `_on_initialize()`.

---

## Subfolder map

| Subfolder | Purpose | Trigger |
|---|---|---|
| `collision reactions/` | React when the entity's `collision` signal fires. | `collision` signal from the entity. |
| `death reactions/` | React when the entity dies (health hits zero or it deactivates). | `zero_health` or `entity_deactivating` signal. |
| `triggered arms/` | React to an explicit fire/shoot signal (player input, brain, etc.). | `shoot`, `fire_tractor_beam`, etc. |
| `powerup arms/` | Deliver or receive powerups on collision / signal. | `collision` or `receive_powerup`. |
| `other/` | Specialized arms that don't fit the above (e.g. Block Drop piece splitting). | Game-specific signals. |

---

## `collision reactions/`

All of these connect to one or more `collision` signals (default `&"collision"`) in `_on_initialize()`. The collision handler signature used throughout is:

```gdscript
func _on_collision(collider: CDEntity, _normal: Vector2) -> void:
```

They disconnect in `_on_entity_deactivating()`. Most gate their effect on an optional `target_groups` (empty = affect everything) via a private `_is_valid_target()` helper.

| File | Class | What it does (from the code) |
|---|---|---|
| `capture_on_hit_arm.gd` | `CaptureOnHitArm` | On hit, writes capture data to the **game blackboard** (`captured_entity`) and the **target's blackboard** (`captured_by`), emits `player_captured` on the target's bus, `capture_succeeded` + `tractor_beam_complete` on the captor's bus, flags the bullet via `did_capture`, then `entity.deactivate()`. Reads the captor from `entity.blackboard[captor_key]`. |
| `damage_on_crash_arm.gd` | `DamageOnCrashArm` | Damages **self** on collision. Writes `incoming_damage` + `damage_source` to `entity.blackboard`, emits `take_damage` on self. Gated by optional `source_groups`. Also `ensure_signal`s the damage signals on init. |
| `damage_on_hit_arm.gd` | `DamageOnHitArm` | Damages the **collider**. Writes `health_delta` + `damage_source` to `collider.blackboard`, emits `take_damage` on the collider. Gated by optional `target_groups`. |
| `damage_on_joust_arm.gd` | `DamageOnJoustArm` | Damages collider only if self "wins" a comparison. Modes via `CDEnums.EntityCompare`: `VELOCITY`, `Y_POSITION` (inverted), `CUSTOM` (property name search on entity + children). Scales velocity-damage by `velocity_damage_scale`, clamped to `minimum_damage`. Configurable `comparison_tolerance`, `tiebreaker`, and `invalid_action`. |
| `death_on_crash_arm.gd` | `DeathOnCrashArm` | Kills **self** on collision by emitting `request_deactivate` directly (bypasses health). Gated by optional `source_groups`. |
| `death_on_hit_arm.gd` | `DeathOnHitArm` | Kills the **collider** by emitting `request_deactivate` on it directly (bypasses health). Gated by optional `target_groups`. |
| `death_on_joust_arm.gd` | `DeathOnJoustArm` | Same comparison engine as `DamageOnJoustArm`, but emits `request_deactivate` on the collider instead of damage. |
| `pushback_arm.gd` | `PushbackArm` | Applies a physical impulse to the collider. Writes `external_impulse` to `collider.blackboard` and emits `external_impulse`. Direction = collision `normal` (`use_collision_normal = true`) or vector from self to collider. |
| `score_on_collision_arm.gd` | `ScoreOnCollisionArm` | On hit, reads `points` from `entity.blackboard` (written by a `PointsGuts` sibling), writes `score_gained` to the **game blackboard**, emits `score_gained` on the game bus. Ensures the signal exists on the game bus at init. |
| `status_on_hit_arm.gd` | `StatusEffectArm` *(note: filename is `status_on_hit_arm.gd`)* | Applies a status effect to the collider. Writes `pending_status` (= `status_name`) and `pending_status_duration` to `collider.blackboard`, emits `apply_status` on the collider. |

---

## `death reactions/`

React to the entity dying. The default listen-signal differs per file.

| File | Class | Listen signal | What it does |
|---|---|---|---|
| `score_on_death_arm.gd` | `ScoreOnDeathArm` | `zero_health` (connected via `self.bus_connect`) | Searches for a `PointsGuts` sibling at init (warns if missing). On death, reads `points` from it, writes `pending_score_add` to the game blackboard, emits `add_score` on the game bus. |
| `spawn_on_death_arm.gd` | `SpawnOnDeathArm` | `entity_deactivating` (connected via `entity.connect`) | Spawns `spawn_count` copies of `spawn_scene` at the entity's position. Supports `pool: CDObjectPool`, `spawn_context: CDSpawnContext`, `inherit_position`, `inherit_velocity`. |

> Note: `ScoreOnDeathArm` connects with `self.bus_connect(...)` but disconnects using `entity.is_connected(...)` / `entity.disconnect(...)` — a minor inconsistency present in the actual file.

---

## `triggered arms/`

React to an explicit fire/shoot signal (typically emitted by a brain or input component).

| File | Class | Listen signal | What it does |
|---|---|---|---|
| `gun_arm.gd` | `GunArm` | `shoot` (`self.bus_connect`) | Spawns a projectile from `bullet_scene` / `pool`. Enforces `cooldown` (seconds) and an optional `max_bullets` live-projectile cap (0 = unlimited). Tracks live bullets in `_live_bullets` and prunes invalid/`INACTIVE` entries each shot. Supports `inherit_rotation`, `spawn_context`. |
| `lasso_arm.gd` | `LassoArm` | `fire_tractor_beam` (`self.bus_connect`) | Spawns a lasso bullet (pool or scene), writes `captor` to the bullet's blackboard and `lasso_captor`/`lasso_target` to the entity's blackboard, optionally instantiates an `effect_scene` as a **child of the entity** at local `Vector2.ZERO`. Defers the actual spawn via `call_deferred` to avoid physics-state errors. |
| `tractor_beam_arm.gd` | `TractorBeamArm` | `fire_tractor_beam` (`self.bus_connect`) | A frame-based "active-frames" arm. Runs a `windup_frames` → capture → `hold_frames` sequence in `_physics_process`. At the windup frame it runs an **immediate** `PhysicsDirectSpaceState2D.intersect_shape()` query using `beam_shape`. On a hit it writes `captured_entity` to the game blackboard, `captured_by` to the target, and emits capture/miss/complete signals. Dynamically resolves `collision_mask` from `game.collision_matrix.get_layer_for_group(group)` at init. |

---

## `powerup arms/`

| File | Class | Trigger | What it does |
|---|---|---|---|
| `powerup_delivery_arm.gd` | `PowerUpDeliveryArm` | `collision` | On hit, writes `powerup_id` + `source_entity` to `collider.blackboard`, emits `receive_powerup` on the collider (only if `collider.has_signal(sig)`). Used by powerup pickups. |
| `powerup_wingman_arm.gd` | `PowerupWingmanArm` | `receive_powerup` (`entity.connect`, signal ensured first) | Receives `(received_id, _source)`. Only spawns the `companion_scene` if `received_id == powerup_id`. Supports pool, spawn_context, `spawn_offset`, `inherit_velocity`. |

---

## `other/`

| File | Class | Trigger | What it does |
|---|---|---|---|
| `piece_splitter_arm.gd` | `PieceSplitterArm` | `piece_locked` (passes `cell_positions: Array[Vector2]`) | Block-Drop-specific. Spawns a `settled_cell_scene` at each locked cell position, adds each to the `settled` group (for row-clear detection), emits `piece_settled` on the game bus, then emits `request_deactivate` on the entity. Supports a pool. |

---

## Common patterns observed in these files

These are patterns that **actually recur across multiple files in this folder** — use them as a reference, not as a prescription invented for this doc.

### 1. Export grouping

Nearly every arm uses the same `@export_group` layout:

```gdscript
# behavior/config exports at the top
@export var damage_amount: int = 1
@export var target_groups: Array[StringName]

@export_group("Blackboard Keys")
@export var damage_keys: Array[StringName] = [&"health_delta"]

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var damage_signals: Array[StringName] = [&"take_damage"]
```

Signal/key arrays default to `StringName` literals and are almost always arrays (so an arm can emit/listen to multiple).

### 2. Write-to-blackboard-then-emit

Most arms do **not** pass data through signal arguments. Instead they write to a blackboard under configurable keys, then emit a zero-argument signal:

```gdscript
for key in damage_keys:
    collider.blackboard[key] = damage_amount
for sig in damage_signals:
    collider.bus_emit(sig)
```

The receiver reads the blackboard when it handles the signal.

### 3. Target/source filtering

Collision/beam arms share an identical helper:

```gdscript
func _is_valid_target(collider: CDEntity) -> bool:
    if target_groups.is_empty():
        return true
    for group in target_groups:
        if collider.is_in_group(group):
            return true
    return false
```

Empty `target_groups` = affect everyone. (`damage_on_crash` / `death_on_crash` mirror this as `_is_valid_source` against `source_groups` because they affect *self*.)

### 4. Two ways to connect listen-signals

- **Direct:** `entity.connect(sig, handler)` — used by most collision arms.
- **Tracked:** `self.bus_connect(sig, handler)` — adds the signal if missing and tracks it for `CDBody` sleep/wake. Used by `GunArm`, `LassoArm`, `TractorBeamArm`, and `ScoreOnDeathArm`.

`PowerupWingmanArm` does a hybrid: `entity.ensure_signal(sig)` then `entity.connect(sig, handler)`.

### 5. Spawn-from-scene-or-pool

`GunArm`, `LassoArm`, `SpawnOnDeathArm`, `PieceSplitterArm`, and `PowerupWingmanArm` all follow the same shape:

```gdscript
if pool:
    spawned = pool.acquire()
    if spawned == null:
        return
    spawned.global_position = <pos>
else:
    spawned = scene.instantiate()
    spawned.global_position = <pos>

CDUtilities.apply_spawn_context(spawned, spawn_context)

if inherit_velocity:
    spawned.velocity += entity.velocity

if pool:
    spawned.activate()
else:
    game.add_child(spawned)
```

- Pooled entities are **activated** (`spawned.activate()`); fresh ones are **added to the tree** (`game.add_child(spawned)`).
- `CDUtilities.apply_spawn_context(spawned, spawn_context)` is applied in both paths when a context is set.

### 6. Joust comparison engine

`DamageOnJoustArm` and `DeathOnJoustArm` share an identical comparison engine driven by `CDEnums.EntityCompare`:

- `VELOCITY` → `ent.velocity.length()`
- `Y_POSITION` → `ent.global_position.y` (win condition inverted: self wins when `diff < 0`)
- `CUSTOM` → searches `ent.get(custom_property_name)`, then each child, for the property.

With `comparison_tolerance`, `tiebreaker` (`FIRE` / `DONT_FIRE`), and `invalid_action` (`FIRE` / `DONT_FIRE`) controlling edge cases. `DamageOnJoustArm` additionally scales velocity damage by `velocity_damage_scale` (clamped to `minimum_damage`).

### 7. Cleanup in `_on_entity_deactivating()`

Every arm overrides this, calls `super._on_entity_deactivating()`, and disconnects whichever signals it connected. Pooled/spawning arms also clear tracking arrays (e.g. `_live_bullets.clear()`).

---

## How to create a new arm

Based on the patterns above, a new arm in this folder typically looks like this skeleton. **Only copy what you actually need** — every arm here is a slimmed-down version of these ideas.

```gdscript
## MyNewArm
## <one-line description of what it does>

class_name MyNewArm extends CDEntityComponent

# --- behavior/config ---
@export var some_value: int = 1
@export var target_groups: Array[StringName]

@export_group("Blackboard Keys")
@export var my_keys: Array[StringName] = [&"my_key"]

@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var response_signals: Array[StringName] = [&"my_response"]

## ready
func _ready() -> void:
    component_category = CDEnums.ComponentCategory.INTERACTION
    super._ready()

## connect listen signals (and optionally find siblings / ensure emit signals exist)
func _on_initialize() -> void:
    for sig in trigger_signals:
        entity.connect(sig, _on_trigger)   # or: self.bus_connect(sig, _on_trigger)

## react to the trigger
func _on_trigger(collider: CDEntity, _normal: Vector2) -> void:
    if not is_instance_valid(collider):
        return
    if not _is_valid_target(collider):
        return

    # write data, then emit a zero-arg signal
    for key in my_keys:
        collider.blackboard[key] = some_value
    for sig in response_signals:
        collider.bus_emit(sig)

## standard target filter (empty target_groups = allow all)
func _is_valid_target(collider: CDEntity) -> bool:
    if target_groups.is_empty():
        return true
    for group in target_groups:
        if collider.is_in_group(group):
            return true
    return false

## disconnect on deactivation
func _on_entity_deactivating() -> void:
    super._on_entity_deactivating()
    for sig in trigger_signals:
        if entity.is_connected(sig, _on_trigger):
            entity.disconnect(sig, _on_trigger)
```

Checklist for a new arm:

- [ ] Extend `CDEntityComponent` and set `component_category = CDEnums.ComponentCategory.INTERACTION` in `_ready()` (then `super._ready()`).
- [ ] Put the file in the subfolder that matches its trigger (`collision reactions/`, `death reactions/`, `triggered arms/`, `powerup arms/`, or `other/`).
- [ ] Use the `@export_group("Listen Signals")` / `@export_group("Emit Signals")` / `@export_group("Blackboard Keys")` convention so signal/key names stay configurable.
- [ ] Connect in `_on_initialize()`; disconnect in `_on_entity_deactivating()` (call `super` first).
- [ ] Prefer **blackboard-write + zero-arg emit** over passing payload through signal arguments (matches every existing arm).
- [ ] If it spawns entities, follow the scene-or-pool shape and call `CDUtilities.apply_spawn_context()`.
- [ ] Filter targets with the `_is_valid_target` / `_is_valid_source` helper rather than hardcoding groups.