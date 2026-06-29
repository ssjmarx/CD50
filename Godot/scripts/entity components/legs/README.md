# Legs — Entity Steering Components

`Legs` are `CDEntityComponent` scripts (category `STEERING`) that translate intent into **motion requests**. They read input (almost always from the entity blackboard) and each frame push motion requests into the entity. The actual physics integration happens elsewhere; legs only **request** changes.

## Subfolders

| Subfolder | Mechanism | Reads |
|-----------|-----------|-------|
| `directional adders/` | `request_velocity_add` (momentum) | `move_direction` |
| `directional setters/` | `request_velocity_set` / `request_position_add` / `request_rotation_*` | `move_direction` |
| `positional adders/` | `request_velocity_add` (momentum, tapered) | `move_direction` + `move_distance` |
| `positional setters/` | `request_velocity_set` / `request_rotation_set` | `move_direction` + `move_distance` |
| `other/` | friction, wrapping, alignment, teleports | various |

**adders/** = legs that *accumulate* motion (momentum, friction, thrust).
**setters/** = legs that *snap* motion directly.

---

## Patterns

### 1. Steering category
Every leg sets `component_category = CDEnums.ComponentCategory.STEERING` in `_ready()` before `super._ready()`.

### 2. Work in `_physics_process`
All frame work happens in `_physics_process(delta)`. The first line is usually a guard like `if not entity: return`.

### 3. Input from the entity blackboard
Legs poll `entity.blackboard`:

```gdscript
var direction: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)
var distance: float  = entity.blackboard.get(distance_key, 0.0)
```

Keys are exported as `@export var *_key: StringName` with `&"..."` defaults under `@export_group("Blackboard Keys")`. Common keys:
- `move_direction` (Vector2)
- `move_distance` (float, pixels)
- `rotation_spin` (float: +1 CW / -1 CCW)
- `drop_count` (int)

### 4. Output via request calls
Legs **never** mutate position/velocity directly. They call one of:

| Call | Meaning |
|------|---------|
| `request_velocity_add(vec)` | Add an impulse/force (accumulates) |
| `request_velocity_set(vec)` | Hard-set velocity |
| `request_position_add(vec)` | Translate by a delta |
| `request_position_set(vec)` | Snap to a world position |
| `request_rotation_add(rad)` | Rotate by an angular delta |
| `request_rotation_set(rad)` | Set absolute rotation |
| `request_angular_set(rad/s)` | Set angular velocity |

The subfolder split mirrors this: **adders/** → `request_velocity_add`; **setters/** → `request_*_set`.

### 5. Signals over the entity bus
```gdscript
entity.bus_emit(sig)                                  # fire
entity.ensure_signal(sig)                             # declare
self.bus_connect(sig, callable) / bus_disconnect(...)  # subscribe/unsubscribe
```
Emit lists are `@export var *_signals: Array[StringName]` under `@export_group("Emit Signals")`. "After" signals (post-teleport, post-wrap) are deferred with `Callable.call_deferred()`.

### 6. Game-level access
Some legs reach up to the game:
- `game.game_bounds` (`Rect2` playfield) — `ScreenWrapLeg`.
- `game.blackboard` (game-wide blackboard) — `LeaderTeleportLeg` (selectable via a `BlackboardSource` enum).

### 7. Cleanup
Override `_on_entity_deactivating()` (always `super` first) and reset internal state for pool reuse. If you `bus_connect`, always `bus_disconnect` here. (A few stateless legs omit the hook.)

### 8. Grid-leg specifics
- **Sibling discovery** by script global name (avoids hard deps):
  ```gdscript
  child.get_script().get_global_name() == &"TetrominoGuts"
  ```
- **Collision probes** via `PhysicsPointQueryParameters2D` point-cast against `entity.get_world_2d().direct_space_state`, excluding the entity's own RID.

---

## How to create a new leg

1. **Pick the subfolder:** add (momentum via `request_velocity_add`) vs set (snap via `request_*_set`), directional (`move_direction`) vs positional (`move_direction` + `move_distance`). Utility legs go in `other/`.
2. Create `<name>_leg.gd` extending `CDEntityComponent` with a matching `class_name`.

```gdscript
## MyNewLeg
## <one-line description>

class_name MyNewLeg extends CDEntityComponent

@export var my_param: float = 100.0

@export_group("Blackboard Keys")
@export var direction_key: StringName = &"move_direction"

@export_group("Emit Signals")
@export var done_signals: Array[StringName] = [&"leg_done"]

func _ready() -> void:
    component_category = CDEnums.ComponentCategory.STEERING
    super._ready()

func _on_initialize() -> void:
    pass

func _physics_process(delta: float) -> void:
    if not entity:
        return
    var dir: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)
    if dir != Vector2.ZERO:
        entity.request_velocity_add(dir * my_param * delta)

func _on_entity_deactivating() -> void:
    super._on_entity_deactivating()
    # reset any internal state for pool reuse
```

### Checklist

- [ ] Put the file in the subfolder matching add/set + directional/positional (or `other/`).
- [ ] `class_name …Leg extends CDEntityComponent` (keep filename and class name in sync).
- [ ] Set `component_category = STEERING` in `_ready()` before `super._ready()`.
- [ ] Read input via `entity.blackboard.get(key, default)`; expose keys under `@export_group("Blackboard Keys")`.
- [ ] Drive motion **only** through `request_*` calls — never mutate `entity.velocity`/position directly.
- [ ] Expose signals under `@export_group("Emit Signals")`; fire with `entity.bus_emit(sig)` (defer "after" signals).
- [ ] If you `bus_connect`, `bus_disconnect` in `_on_entity_deactivating()` (super first) and reset all internal state (pooled entities).