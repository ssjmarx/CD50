# Arms — Entity Action Components

`Arms` are `CDEntityComponent` scripts (category `INTERACTION`) that make an entity **do things** — react to collisions, fire projectiles, deliver powerups, split into pieces, or respond to death. They are the "outward-facing" action components: they listen for signals and, in response, emit signals or spawn entities.

Arms **never** mutate another component directly. They write data to a blackboard and emit a zero-arg signal; the receiver decides what to do.

## Subfolders

| Subfolder | Trigger | Purpose |
|-----------|---------|---------|
| `collision reactions/` | `collision` signal | Damage/death/pushback/score/status/capture on hit |
| `death reactions/` | `zero_health` / `entity_deactivating` | Score or spawn on death |
| `triggered arms/` | fire/shoot signal (from brain/input) | Gun, lasso, tractor-beam spawning |
| `powerup arms/` | `collision` / `receive_powerup` | Deliver or receive powerups |
| `other/` | game-specific signals | e.g. Block Drop piece splitting |

---

## Patterns

### 1. Interaction category
Every arm sets `component_category = CDEnums.ComponentCategory.INTERACTION` in `_ready()` before `super._ready()`.

### 2. Export grouping
Nearly every arm uses the same inspector layout:

```gdscript
@export var damage_amount: int = 1
@export var target_groups: Array[StringName]

@export_group("Blackboard Keys")
@export var damage_keys: Array[StringName] = [&"health_delta"]

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var damage_signals: Array[StringName] = [&"take_damage"]
```

Keys/signals default to `StringName` literals and are almost always arrays so an arm can emit/listen to multiple.

### 3. Write-to-blackboard, then emit zero-arg
Arms do **not** pass data through signal arguments. They write under configurable keys, then emit a zero-arg signal:

```gdscript
for key in damage_keys:
    collider.blackboard[key] = damage_amount
for sig in damage_signals:
    collider.bus_emit(sig)
```

### 4. Target / source filtering
Collision and beam arms share an identical helper. Empty `target_groups` = affect everyone.

```gdscript
func _is_valid_target(collider: CDEntity) -> bool:
    if target_groups.is_empty():
        return true
    for group in target_groups:
        if collider.is_in_group(group):
            return true
    return false
```

Self-affecting arms (`damage_on_crash`, `death_on_crash`) mirror this as `_is_valid_source` against `source_groups`.

### 5. Two ways to connect listen-signals
- **Direct:** `entity.connect(sig, handler)` — used by most collision arms.
- **Tracked:** `self.bus_connect(sig, handler)` — adds the signal if missing and tracks it for `CDBody` sleep/wake. Used by the triggered arms and `ScoreOnDeathArm`.

A hybrid exists: `entity.ensure_signal(sig)` then `entity.connect(sig, handler)`.

### 6. Spawn-from-scene-or-pool
`GunArm`, `LassoArm`, `SpawnOnDeathArm`, `PieceSplitterArm`, and `PowerupWingmanArm` all share this shape:

```gdscript
if pool:
    spawned = pool.acquire()
    if spawned == null:
        return
    spawned.global_position = pos
else:
    spawned = scene.instantiate()
    spawned.global_position = pos

CDUtilities.apply_spawn_context(spawned, spawn_context)

if inherit_velocity:
    spawned.velocity += entity.velocity

if pool:
    spawned.activate()
else:
    game.add_child(spawned)
```

Pooled entities are **activated**; fresh ones are **added to the tree**.

### 7. Joust comparison engine
`DamageOnJoustArm` and `DeathOnJoustArm` share a comparison engine driven by `CDEnums.EntityCompare` (`VELOCITY`, `Y_POSITION` inverted, `CUSTOM` property search), with `comparison_tolerance`, `tiebreaker` (`FIRE`/`DONT_FIRE`), and `invalid_action` (`FIRE`/`DONT_FIRE`).

### 8. Cleanup in `_on_entity_deactivating()`
Every arm overrides this, calls `super._on_entity_deactivating()`, then disconnects whatever it connected. Spawning arms also clear tracking arrays (e.g. `_live_bullets.clear()`).

---

## How to create a new arm

```gdscript
## MyNewArm
## <one-line description>

class_name MyNewArm extends CDEntityComponent

@export var damage_amount: int = 1
@export var target_groups: Array[StringName]

@export_group("Blackboard Keys")
@export var my_keys: Array[StringName] = [&"my_key"]

@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var response_signals: Array[StringName] = [&"my_response"]

func _ready() -> void:
    component_category = CDEnums.ComponentCategory.INTERACTION
    super._ready()

func _on_initialize() -> void:
    for sig in trigger_signals:
        entity.connect(sig, _on_trigger)   # or: self.bus_connect(sig, _on_trigger)

func _on_trigger(collider: CDEntity, _normal: Vector2) -> void:
    if not is_instance_valid(collider):
        return
    if not _is_valid_target(collider):
        return
    for key in my_keys:
        collider.blackboard[key] = damage_amount
    for sig in response_signals:
        collider.bus_emit(sig)

func _is_valid_target(collider: CDEntity) -> bool:
    if target_groups.is_empty():
        return true
    for group in target_groups:
        if collider.is_in_group(group):
            return true
    return false

func _on_entity_deactivating() -> void:
    super._on_entity_deactivating()
    for sig in trigger_signals:
        if entity.is_connected(sig, _on_trigger):
            entity.disconnect(sig, _on_trigger)
```

### Checklist

- [ ] Extend `CDEntityComponent`, set `component_category = INTERACTION` in `_ready()` (then `super._ready()`).
- [ ] Put the file in the subfolder matching its trigger.
- [ ] Use `@export_group("Listen Signals")` / `("Emit Signals")` / `("Blackboard Keys")`.
- [ ] Connect in `_on_initialize()`; disconnect in `_on_entity_deactivating()` (call `super` first).
- [ ] Prefer blackboard-write + zero-arg emit over signal payloads.
- [ ] If it spawns entities, follow the scene-or-pool shape and call `CDUtilities.apply_spawn_context()`.
- [ ] Filter targets with `_is_valid_target` / `_is_valid_source` rather than hardcoding groups.