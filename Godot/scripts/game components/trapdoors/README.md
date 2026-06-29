# Trapdoors — Stage Spawner Components

`Trapdoors` are concrete subclasses of `CDStageTrapdoor` (in `core/base classes/`) that decide **what** to spawn, **where** to spawn it, and **how many** to spawn. The base class owns the rest of the lifecycle (trigger signals, staggered queue, pool vs. fresh instantiate, telefrag, safe-zone gating); concrete scripts only override virtual methods.

## Files

| File | Class | Pattern |
|------|-------|---------|
| `edge_trapdoor.gd` | `EdgeTrapdoor` | Evenly distributed along edges of `game.game_bounds`, with optional jitter |
| `grid_trapdoor.gd` | `GridTrapdoor` | Centered 2D grid; `@tool` with editor preview; Mode A (`CDGridLayout`) or Mode B (`spawn_scene` + `CDGridEquation`) |
| `point_trapdoor.gd` | `PointTrapdoor` | All spawns at the trapdoor's `global_position` with optional random offset |

---

## Patterns

### 1. Inherited base-class lifecycle
Every trapdoor inherits the full spawn lifecycle. Concrete scripts only override the three/four virtual methods below.

1. **Trigger** — A game-bus signal in `trigger_signals` (default `[&"wave_start"]`) fires. If `trigger_delay > 0`, the trapdoor waits; otherwise `_on_trigger()` runs immediately. Triggering is suppressed during `GAME_OVER`.
2. **Queue** — `_on_trigger()` reads the wave number from the blackboard (`wave_key`, default `&"wave_number"`) and calls `_populate_spawn_queue(wave_number)`. The default fills `_spawn_queue` with `0..count-1`, where `count` comes from `_get_spawn_count(wave_number)`.
3. **Stagger** — `_physics_process(delta)` drains the queue one index per `stagger_delay` seconds. Draining pauses while the zone is unsafe.
4. **Spawn** — For each index, `_spawn_one(index)` picks a scene + position (via the virtuals or `spawn_scenes`), acquires from `pool` (else fresh `instantiate()`), optionally telefrags overlapping bodies, applies `spawn_context`, and activates.
5. **Complete** — When the queue empties, the trapdoor writes `spawned_wave` to the blackboard and emits every signal in `on_spawning_complete`.

### 2. Virtual methods (the override surface)
```gdscript
func _get_spawn_count(_wave_number: int) -> int                # how many to spawn (used by default _populate_spawn_queue)
func _populate_spawn_queue(wave_number: int) -> void           # how to fill _spawn_queue (default fills 0..count-1)
func _get_spawn_position(_index: int, _total: int) -> Vector2  # where to spawn each
func _get_spawn_scene(_index: int, _total: int) -> PackedScene # what scene to spawn (abstract — always implement)
```
`_get_spawn_scene()` is abstract and must be implemented. `_get_spawn_count()` and `_get_spawn_position()` fall back to `0` and `global_position`. Override `_populate_spawn_queue()` only when queue logic isn't a simple range (e.g. grid skip logic). Never override `_on_trigger()` — it owns the GAME_OVER guard, wave read, timer reset, and physics toggle.

### 3. Configure behavior via inherited exports
Stagger, pool, telefrag, trigger/safe/unsafe signals, and the complete signal are all inherited exports — do **not** reimplement them.

### 4. Safe zones
`_zone_is_safe` starts `true`; `safe_signals`/`unsafe_signals` flip it. While unsafe, the stagger loop holds the queue without spawning (it does **not** discard it).

### 5. Editor preview (`@tool`)
`GridTrapdoor` is `@tool`. Editor previews override `_draw()` gated on `Engine.is_editor_hint()`, and export setters call `queue_redraw()` when `is_node_ready()`.

### 6. Equation evaluation
Equation-based counts go through `CDUtilities.evaluate_int(expr, var_names, var_values, context_label)`.

---

## How to create a new trapdoor

```gdscript
@tool   # only if you ship an editor preview
## MyTrapdoor
## <one-line description>

class_name MyTrapdoor extends CDStageTrapdoor

@export var spawn_scene: PackedScene
@export var spawn_count_equation: String = "3 + wave_number"

func _get_spawn_count(wave_number: int) -> int:
    return CDUtilities.evaluate_int(spawn_count_equation, ["wave_number"], [wave_number], "MyTrapdoor '%s'" % name)

func _get_spawn_position(_index: int, _total: int) -> Vector2:
    return global_position

func _get_spawn_scene(_index: int, _total: int) -> PackedScene:
    return spawn_scene
```

### Checklist

- [ ] `class_name …Trapdoor extends CDStageTrapdoor`.
- [ ] Add `@tool` only if shipping an editor preview.
- [ ] Implement `_get_spawn_scene()` (abstract).
- [ ] Override `_get_spawn_count()` and/or `_get_spawn_position()` to define count + position.
- [ ] Override `_populate_spawn_queue()` instead of `_on_trigger()` for non-range queue logic; never override `_on_trigger()`.
- [ ] Configure stagger/pool/telefrag/signals via inherited exports — don't reimplement.
- [ ] For an editor preview: override `_draw()` gated on `Engine.is_editor_hint()`, call `queue_redraw()` from setters.
- [ ] Use `CDUtilities.evaluate_int()` for equation-driven counts.