# Marks — Trigger-Zone Components

`Marks` are `Area2D`-based trigger zones that detect bodies entering/exiting a region and communicate with the rest of the game through the **game bus** (zero-arg signals) and the **game blackboard**. They are the primary way a scene reacts to entities touching a region of space.

## Files

| File | Class | Extends | Pattern |
|-----|-------|---------|---------|
| `cd_mark.gd` | `CDMark` | `Area2D` | Base mark: filter by group, write blackboard, emit game-bus + entity-bus signals, auto-create collision shape, swap shape at runtime |
| `count_mark.gd` | `CountMark` | `CDMark` | Counts **unique** bodies; fires when `target_count` reached |
| `mobile_mark.gd` | `MobileMark` | `CDMark` | Lerps to follow a target entity; inherits detection unchanged |
| `occupancy_mark.gd` | `OccupancyMark` | `CDMark` | Per-group occupancy counter; emits on every change |
| `safe_zone_mark.gd` | `SafeZoneMark` | `CDMark` | Safe/unsafe state-transition sensor |
| `timed_mark.gd` | `TimedMark` | `CDMark` | Times how long bodies stay inside; progress ticks + completion |

---

## Patterns

### 1. Ancestor lookup
A mark resolves its owning game controller in `_ready()` and **must** be a descendant of a `CDGame` node:

```gdscript
@onready var game: CDGame = CDGame.find_ancestor(self)
```

All bus/blackboard access goes through `game`.

### 2. Auto collision shape
`_ensure_collision_shape()` runs in `_ready()`:
- Reuse an existing `CollisionShape2D` child if present.
- Otherwise create one with a `CircleShape2D` of radius `shape_size`, stored in `_auto_shape`.

The shape can be swapped at runtime (see strategy below).

### 3. Filter, then dispatch to an overrideable hook
`CDMark._ready()` wires Godot's `body_entered` / `body_exited` to **final** handlers `_on_body_entered` / `_on_body_exited`. Those run the group filter (`_passes_filter`), then dispatch to **overrideable** hooks:

```gdscript
func _on_body_entered(body: Node2D) -> void:
    if not _passes_filter(body):
        return
    _handle_body_entered(body)
```

**Subclasses override `_handle_body_*`, never `_on_body_*`.** The body received in an override is already filtered.

### 4. The base behavior (`CDMark._handle_body_entered`)
1. Writes the body to `game.blackboard[entered_body_key]`.
2. Calls `_emit_enter(body)`.

`_emit_enter` / `_emit_exit` are **emit-only** helpers (no blackboard write): they fire every signal in `on_entered` / `on_exited` on the game bus, and every signal in `on_entered_entity` / `on_exited_entity` on **that entity's** bus (when the body is a `CDEntity`).

### 5. Three base-reuse strategies
A subclass picks one and documents it in its header:

| Strategy | How | Fires base signals? | Used by |
|----------|-----|---------------------|---------|
| **Replace base** | Override `_handle_body_*`, do **not** call `super` or `_emit_enter` | No — only your own signals fire | `OccupancyMark`, `SafeZoneMark` |
| **Reuse via `super`** | Override `_handle_body_*`, call `super._handle_body_entered(body)` first | Yes — then add your own logic | `CountMark`, `TimedMark` |
| **Reuse via emit helper** | Override `_handle_body_*`, do your own blackboard write, then call `_emit_enter(body)` | Yes | (documented fallback) |
| **Don't override** | Inherit `_handle_body_*` entirely | Yes | `MobileMark` |

### 6. Signal / blackboard conventions
- Every "emit" export is an `Array[StringName]` — listing multiple fires all of them for the same event.
- All emitted bus signals are **zero-argument**. Payloads are delivered through the blackboard, written immediately before emitting.
- Every blackboard key is an `@export StringName` with a sensible default; repoint to avoid collisions in scenes with multiple marks.

### 7. Game access
- `game.bus_emit(sig)` / `game.bus_connect(sig, callable)` — game bus.
- `game.blackboard[key]` — shared state.
- `game.collision_matrix.configure(self)` — applied if set.
- `game.group_registry.get_nearest(group, position)` — used by `MobileMark`.

---

## How to create a new mark

```gdscript
## MyNewMark
## <one-line description; which base-reuse strategy you picked>

class_name MyNewMark extends CDMark

@export_group("Blackboard Keys")
@export var my_key: StringName = &"mark_my_value"

@export_group("Emit Signals")
@export var on_my_event: Array[StringName] = [&"my_event"]

func _handle_body_entered(body: Node2D) -> void:
    # Option A — replace base: no super, no _emit_enter
    # Option B — reuse via super:
    super._handle_body_entered(body)
    # Option C — reuse via emit helper (after your own blackboard write):
    # game.blackboard[entered_body_key] = body
    # _emit_enter(body)

    game.blackboard[my_key] = body
    for sig in on_my_event:
        game.bus_emit(sig)
```

### Checklist

- [ ] `class_name …Mark extends CDMark`; live under a `CDGame` node.
- [ ] Override `_handle_body_*` hooks — **never** `_on_body_*` (those own the filter step).
- [ ] Pick and document one base-reuse strategy (replace / super / emit helper / don't override).
- [ ] Group exports: `Emit Signals` for `Array[StringName]`, `Blackboard Keys` for `StringName`.
- [ ] Make all bus signals zero-arg; write payloads to the blackboard immediately before emitting.
- [ ] Reuse `CDMark` helpers: `_emit_enter(body)` / `_emit_exit(body)`, `_passes_filter(body)` (already applied for you), `_auto_shape`.
- [ ] For per-frame logic, override `_physics_process(delta)` (`MobileMark`, `TimedMark`); for one-time deferred setup, override `_on_initialize()` (call `super` first).