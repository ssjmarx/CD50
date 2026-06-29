# Guts — Entity State Components

`Guts` are `CDEntityComponent` scripts (category `STATE`) that implement the *internals* of an entity — health, timers, detection, death conditions, input translation, physics helpers, and resource pools.

## Subfolders

| Subfolder | Concern |
|-----------|---------|
| `death/` | Conditions that deactivate the entity (zero health, offscreen, timer, out-of-bounds) |
| `detection/` | Sensing the world / tracking other entities (leader tracker, lock detector, vision cone) |
| `game logic/` | Gameplay state machines & data holders (announcer, points, stun, timer, T-spin) |
| `input/` | Translating input into entity signals (keyboard/mouse merge, move-to→direction) |
| `physics/` | Collision & motion helpers (deflector bounce, impulse receiver, shape collider) |
| `pools/` | Regenerating/absorbing value pools (health, resource, shield) |

---

## Patterns

### 1. State category
Every Guts sets `component_category = CDEnums.ComponentCategory.STATE` in `_ready()` before `super._ready()`.

### 2. Signal-driven communication
Guts are **signal-driven**. Two connection styles appear (both valid — match the neighbors you're wiring to):

- **Bus-based (most common):**
  ```gdscript
  self.bus_connect(sig, handler)
  self.bus_disconnect(sig, handler)
  entity.bus_emit(sig)
  ```
- **Direct Godot signal:**
  ```gdscript
  entity.ensure_signal(sig)
  entity.connect(sig, handler)
  entity.disconnect(sig, handler)
  ```

Game-bus emission (for events the whole game should hear):
```gdscript
game.bus_emit(sig)
game.bus_emit_from(sig, entity)
```

### 3. Payloads via blackboard, zero-arg signals
Almost all signals are **zero-argument**. Payloads (damage amount, target, direction, status name) are passed through the **blackboard**, read inside the handler from a configured `*_key`:

```gdscript
entity.blackboard[key] = value
var v = entity.blackboard.get(key, default)
entity.blackboard.erase(key)
```

### 4. Export layout
```gdscript
@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"do_thing"]

@export_group("Emit Signals")
@export var done_signals: Array[StringName] = [&"thing_done"]

@export_group("Blackboard Keys")
@export var value_key: StringName = &"my_value"
```

### 5. Cleanup contract (pooled entities)
Every Guts overrides `_on_entity_deactivating()` (always starting with `super`):
1. Disconnect every signal it connected.
2. `erase` any blackboard keys it owns.
3. Reset private state to initial values.
4. `set_physics_process(false)` if it uses `_physics_process`.

If it uses `_physics_process`, override `_on_entity_activated()` to re-init defaults and re-enable processing for pool reuse.

---

## How to create a new Guts component

```gdscript
## MyNewGuts
## <one-line description>

class_name MyNewGuts extends CDEntityComponent

@export var some_config: float = 1.0

@export_group("Blackboard Keys")
@export var value_key: StringName = &"my_value"

@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"do_thing"]

@export_group("Emit Signals")
@export var done_signals: Array[StringName] = [&"thing_done"]

var _internal: float = 0.0

func _ready() -> void:
    component_category = CDEnums.ComponentCategory.STATE
    super._ready()

func _on_initialize() -> void:
    _internal = some_config
    entity.blackboard[value_key] = _internal
    for sig in trigger_signals:
        self.bus_connect(sig, _on_trigger)

func _on_trigger() -> void:
    _internal = entity.blackboard.get(value_key, _internal)
    for sig in done_signals:
        entity.bus_emit(sig)

func _on_entity_deactivating() -> void:
    super._on_entity_deactivating()
    for sig in trigger_signals:
        self.bus_disconnect(sig, _on_trigger)
    entity.blackboard.erase(value_key)
    _internal = some_config
    set_physics_process(false)
```

### Checklist

- [ ] Put the file in the subfolder matching its concern.
- [ ] `class_name …Guts extends CDEntityComponent`.
- [ ] Set `component_category = STATE` in `_ready()` before `super._ready()`.
- [ ] Group exports (`Listen Signals` / `Emit Signals` / `Blackboard Keys`); use `Array[StringName]` and `&"name"` defaults.
- [ ] Pass payloads via blackboard keys, not signal arguments.
- [ ] Connect in `_on_initialize()`; write default blackboard values.
- [ ] Override `_on_entity_deactivating()` (super first): disconnect, erase keys, reset state, disable processing.
- [ ] If using `_physics_process`, override `_on_entity_activated()` to re-init and re-enable processing.
- [ ] Pick one signal style (bus-based or direct) per component and stay consistent.