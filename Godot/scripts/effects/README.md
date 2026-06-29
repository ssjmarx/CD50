# Effects — Self-Drawing Visual Effects

`Effects` are one-off (or manually-driven) drawing effects that paint directly with Godot's `_draw()` API on a `Node2D`. They do **not** use `CPUParticles2D` / `GPUParticles2D` — everything is hand-rolled. Every script extends the shared base **`CDEffect`** (`Godot/scripts/core/infrastructure/cd_effect.gd`).

## Files

| File | Class | Pattern |
|------|-------|---------|
| `broken_ship_effect.gd` | `BrokenShipEffect` | Spinning line fragments that drift out and fade (self-freeing) |
| `death_particle_effect.gd` | `DeathParticleEffect` | Burst of single-pixel particles (self-freeing) |
| `scrolling_stars_effect.gd` | `CDScrollingStarsEffect` | Scrolling/wrapping starfield background (self-freeing) |
| `twinkling_stars_effect.gd` | `CDTwinklingStarsEffect` | Non-scrolling starfield with alpha twinkle (self-freeing) |
| `tractor_cone_effect.gd` | `TractorConeEffect` | Vacuum particles toggled by a parent component (`lifetime = 0`) |
| `lasso_effect.gd` | `LassoEffect` | Dynamic rope between two entities, driven by blackboard + bus signals (`lifetime = 0`) |

---

## Patterns

### 1. The base contract (`CDEffect`)
- `@export var lifetime: float = 1.0` — in `_ready()`, if `> 0.0`, a one-shot `SceneTreeTimer` calls `queue_free()`. Set `0.0` to disable auto-free for toggled effects.
- `@export var colors: Array[Color] = []` — palette; empty → treated as `[Color.WHITE]`.
- `get_random_color()` — picks `colors.pick_random()`, or `Color.WHITE` when empty.
- Subclasses that override `_ready()` **must** call `super._ready()` or the auto-free timer never arms.

### 2. Update loop choice
- `_physics_process(delta)` — for frame-rate-independent motion (`BrokenShipEffect`, `DeathParticleEffect`).
- `_process(delta)` — for pure-visual / real-time-driven animation (the starfields, `TractorConeEffect`, `LassoEffect`).
- Either way, call `queue_redraw()` each tick so `_draw()` re-runs.

### 3. Parallel-array state
Per-element state is stored in parallel arrays indexed in lockstep (one array per attribute: `_positions`, `_velocities`, `_sizes`, `_colors`, `_types`, etc.). Seed them in `_ready()` using `get_random_color()` for colors. Keep `_draw()` a pure function of that state.

### 4. Two lifetimes
- **Self-freeing** (`BrokenShipEffect`, `DeathParticleEffect`, the starfields): tune `lifetime`, `count`, and `speed` together. The node frees itself.
- **Toggled** (`TractorConeEffect`): set `lifetime = 0`, `set_process(false)` in `_ready()`, expose `start_*()` / `stop_*()` methods that flip processing on/off. The parent component owns the instance.

### 5. Optional runtime coupling (`LassoEffect`)
When an effect must read runtime data, parent it to a `CDEntity`, read endpoints from `entity.blackboard`, connect event-bus signals (`lasso_end`, `player_captured`) via `bus_connect`, and guard endpoints with `is_instance_valid(...)` before drawing.

---

## How to create a new effect

```gdscript
## MyNewEffect
## <one-line description>

class_name MyNewEffect extends CDEffect

@export var particle_count: int = 30
@export var spread_speed: float = 150.0

var _positions: Array[Vector2] = []
var _velocities: Array[Vector2] = []
var _colors: Array[Color] = []

func _ready() -> void:
    super._ready()                    # arms the lifetime auto-free timer
    for i in particle_count:
        _positions.append(Vector2.ZERO)
        var angle := randf() * TAU
        var speed := randf_range(spread_speed * 0.3, spread_speed)
        _velocities.append(Vector2(cos(angle), sin(angle)) * speed)
        _colors.append(get_random_color())

func _physics_process(delta: float) -> void:
    for i in _positions.size():
        _positions[i] += _velocities[i] * delta
    queue_redraw()

func _draw() -> void:
    for i in _positions.size():
        draw_rect(Rect2(_positions[i] - Vector2(0.5, 0.5), Vector2.ONE), _colors[i])
```

### Toggled variant

```gdscript
func _ready() -> void:
    super._ready()
    set_process(false)                # idle until started

func start_effect() -> void:
    set_process(true)

func stop_effect() -> void:
    set_process(false)
```

### Checklist

- [ ] Extend `CDEffect` and declare a `class_name`.
- [ ] Call `super._ready()` first (arms auto-free).
- [ ] Add `@export` tunables (counts, speeds, sizes); reuse the inherited `colors` palette.
- [ ] Pick `_physics_process` (motion) or `_process` (visuals); call `queue_redraw()` each tick.
- [ ] Store per-element state in parallel arrays; seed with `get_random_color()`.
- [ ] Override `_draw()` using the Godot 2D draw API.
- [ ] Self-freeing → tune `lifetime`. Toggled → `lifetime = 0` + `start_*()` / `stop_*()`.
- [ ] If runtime-coupled, parent to a `CDEntity`, read `blackboard`, connect via `bus_connect`, guard endpoints.
- [ ] Keep it self-contained and drawing-only — no business logic or game state.