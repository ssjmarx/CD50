# `scripts/effects/`

Visual effect scripts. Every file here is a one-off (or manually-driven) drawing effect
that paints directly with Godot's `_draw()` API. They do **not** use `CPUParticles2D` /
`GPUParticles2D`; everything is hand-rolled on a `Node2D`.

All scripts in this folder extend the shared base class **`CDEffect`**, so read that first.

---

## Base class: `CDEffect`

> Lives in `scripts/core/infrastructure/cd_effect.gd` — documented here because every
> effect in this folder inherits from it and the behavior matters.

```gdscript
class_name CDEffect extends Node2D
```

A lightweight visual effect. The defining behavior is **auto-free by timer**:

- `@export var lifetime: float = 1.0` — seconds before this node self-destructs.
  In `_ready()`, if `lifetime > 0.0`, a one-shot `SceneTreeTimer` is created and its
  `timeout` signal is connected to `queue_free()`.
- `@export var colors: Array[Color] = []` — palette for the effect. If empty, treated as
  `[Color.WHITE]`.
- `func get_random_color() -> Color` — returns `colors.pick_random()`, or `Color.WHITE`
  when the array is empty.

### Implications for subclasses

Because `CDEffect._ready()` arms the lifetime timer, subclasses that override `_ready()`
**must** call `super._ready()` or the effect will never auto-free. Every script in this
folder does call `super._ready()`.

Subclasses typically call `get_random_color()` to pick a color per particle/fragment/star.

> Note on `lifetime`: some effects (e.g. `TractorConeEffect`) are meant to be toggled on/off
> by a parent component rather than self-destructing. For those, set `lifetime = 0.0` in the
> inspector — that disables the auto-free timer entirely (the `> 0.0` guard).

---

## File reference

### `broken_ship_effect.gd` — `BrokenShipEffect`

Spinning line fragments that drift outward and fade. Used for **ship death** effects.

```gdscript
class_name BrokenShipEffect extends CDEffect
```

| Export | Type | Default | Purpose |
|---|---|---|---|
| `fragment_length` | `float` | `12.0` | Length of each line fragment |
| `line_count` | `int` | `4` | Number of fragments to spawn |
| `spread_speed` | `float` | `12.0` | Maximum outward drift speed per fragment |
| `spin_speed` | `float` | `1.0` | Maximum rotation speed per fragment |

**Per-fragment state** is stored in parallel arrays: `_positions`, `_rotations`,
`_rotation_speeds`, `_velocities`, `_lifetimes`, `_fragment_colors`. `_elapsed` tracks
total time since spawn.

- `_ready()`: calls `super._ready()`, then fills the arrays. Each fragment gets a random
  start rotation (`0..TAU`), random rotation speed, a random outward velocity whose speed
  is `randf_range(spread_speed * 0.3, spread_speed)`, a per-fragment lifetime in the range
  `0.5 * lifetime .. lifetime`, and a color from `get_random_color()`.
- `_physics_process(delta)`: advances `_elapsed`, integrates positions and rotations, then
  `queue_redraw()`.
- `_draw()`: for each fragment, **skips** it once `_elapsed >= _lifetimes[i]` (i.e. fragments
  vanish one at a time). Each visible fragment is drawn as a rotated line segment of length
  `fragment_length` centered on its position.

> "Fade" here is implemented by fragments expiring at staggered lifetimes, **not** by alpha.

---

### `death_particle_effect.gd` — `DeathParticleEffect`

A burst of single-pixel particles that fly outward. Used for **entity death explosions**.

```gdscript
class_name DeathParticleEffect extends CDEffect
```

| Export | Type | Default | Purpose |
|---|---|---|---|
| `particle_count` | `int` | `50` | Number of particles in the burst |
| `spread_speed` | `float` | `200.0` | Maximum outward speed per particle |

**Per-particle state:** parallel arrays `_positions`, `_velocities`, `_particle_colors`.

- `_ready()`: calls `super._ready()`, seeds all particles at `Vector2.ZERO`, gives each a
  random direction (`0..TAU`) and speed in `spread_speed * 0.3 .. spread_speed`, and a color
  via `get_random_color()`.
- `_physics_process(delta)`: integrates positions, `queue_redraw()`.
- `_draw()`: draws each particle as a 1×1 `Rect2` via `draw_rect` at `(_positions[i] - 0.5)`.

> Particles never expire individually; the whole node is freed by the inherited `lifetime`
> timer. Tune `particle_count`, `spread_speed`, and `lifetime` together.

---

### `lasso_effect.gd` — `LassoEffect`

A visual "rope" that dynamically connects two entities. It is **data-driven**: it reads its
endpoints from the parent `CDEntity`'s blackboard at spawn time and switches shape based on
game events.

```gdscript
extends CDEffect
class_name LassoEffect
```

Two drawing states (enum `RopeState`):

- **`LOOSE`** — a sine wave between captor and target (the bullet/lasso phase).
- **`TAUT`** — a straight line between captor and target (the captured-player phase).

| Export group | Export | Default | Purpose |
|---|---|---|---|
| Blackboard Keys | `captor_key` | `&"lasso_captor"` | Blackboard key on the parent entity for the captor node |
| Blackboard Keys | `target_key` | `&"lasso_target"` | Blackboard key on the parent entity for the target node |
| Blackboard Keys | `game_captured_key` | `&"captured_entity"` | Blackboard key on the game for the captured player |
| Visuals | `wave_amplitude` | `8.0` | Sine wave height (LOOSE state) |
| Visuals | `wave_length` | `40.0` | Pixels per full sine cycle (LOOSE state) |
| Visuals | `rope_width` | `2.0` | Line/polyline width |

**Internal state:** `_state`, `_source_entity` (the parent `CDEntity`), `_captor`, `_target`,
`_rope_color`. `@onready var game = CDGame.find_ancestor(self)`.

- `_ready()`:
  - calls `super._ready()`, picks `_rope_color` via `get_random_color()`;
  - requires its parent to be a `CDEntity` — otherwise `push_error(...)` and `queue_free()`;
  - reads `_captor` and `_target` from `_source_entity.blackboard` using the configured keys;
  - connects `"lasso_end"` on the source entity (if it has `bus_connect`) to `_on_lasso_end`;
  - connects `"player_captured"` on the game (if it has `bus_connect`) to `_on_player_captured`.
- `_process(_delta)`: if either endpoint is no longer valid, nulls them out; always
  `queue_redraw()`.
- `_draw()`: returns early if there is no `_captor`/`_target`; converts both endpoints from
  global to local space; `LOOSE` → `_draw_sine_wave(p1, p2)`, `TAUT` → `draw_line(...)`.
- `_draw_sine_wave(p1, p2)`: builds a `PackedVector2Array` along the segment using a **fixed
  2.0px step** (chosen to prevent shimmer/jitter), with phase computed from absolute distance
  so it behaves like a repeating texture; drawn anti-aliased with `draw_polyline(..., true)`.
- `_on_player_captured()`: reads `game_captured_key` from `game.blackboard`, points `_target`
  at it, and switches to `TAUT`.
- `_on_lasso_end()`: `queue_free()`.

> This effect couples to the blackboard + event-bus conventions (`bus_connect`,
> `CDGame.find_ancestor`). It is the only effect in this folder that is not purely self-
> contained drawing.

---

### `scrolling_stars_effect.gd` — `CDScrollingStarsEffect`

A starfield where stars scroll (drift) downward and wrap around the edges. Configurable size,
speed, density, and shape.

```gdscript
class_name CDScrollingStarsEffect extends CDEffect
```

```gdscript
enum StarType { CIRCLE, FOUR_POINT, SIX_POINT }
```

| Export | Type | Default | Purpose |
|---|---|---|---|
| `star_count` | `int` | `100` | Number of stars |
| `min_speed` | `Vector2` | `(0, 10)` | Minimum per-star velocity |
| `max_speed` | `Vector2` | `(0, 50)` | Maximum per-star velocity |
| `min_size` | `float` | `1.0` | Minimum star radius |
| `max_size` | `float` | `4.0` | Maximum star radius |
| `star_colors` | `Array[Color]` | white/red/blue/orange/green | Palette |
| `effect_width` | `float` | `0.0` | Field width; `0` ⇒ viewport width |
| `effect_height` | `float` | `0.0` | Field height; `0` ⇒ viewport height |

**Per-star state:** parallel arrays `_positions`, `_speeds`, `_sizes`, `_colors`, `_types`
(each `_types[i]` is `randi() % 3` mapped to `StarType`).

- `_ready()`: calls `super._ready()`; if `effect_width`/`effect_height` are `<= 0.0`, falls
  back to `get_viewport_rect().size`; then seeds all arrays with random positions, speeds,
  sizes, colors, and types.
- `_process(delta)`: integrates `_positions[i] += _speeds[i] * delta`; wraps vertically
  (when `y > effect_height`, reset `y = 0` and randomize `x`) and horizontally (when
  `x > effect_width`, reset `x = 0` and randomize `y`); then `queue_redraw()`.
- `_draw()`: per star, `match type`:
  - `CIRCLE` → `draw_circle(pos, size/2, color)`;
  - `FOUR_POINT` → `_draw_star_shape(pos, size/2, 4, color)`;
  - `SIX_POINT` → `_draw_star_shape(pos, size/2, 6, color)`;
  - fallback → `draw_circle`.
- `_draw_star_shape(center, radius, points, color)`: builds a star polygon with
  `inner_radius = radius * 0.4`, alternating outer/inner vertices starting at `-PI/2`,
  then `draw_colored_polygon`.

---

### `tractor_cone_effect.gd` — `TractorConeEffect`

A tractor-beam visual: spawns small star particles at the wide end of a cone and vacuums
them toward the origin. Unlike the auto-freeing effects, this one is designed to be **toggled
on/off by a parent component** (e.g. a Face component).

```gdscript
extends CDEffect
class_name TractorConeEffect
```

> Header note: *"Set lifetime to 0 in the inspector if spawned/despawned manually by a Face
> component."* With `lifetime = 0`, the inherited timer is skipped (see `CDEffect` above).

| Export | Type | Default | Purpose |
|---|---|---|---|
| `star_count` | `int` | `40` | Max active stars maintained during vacuum |
| `cone_length` | `float` | `100.0` | Distance from origin to the wide end of the cone |
| `cone_width` | `float` | `75.0` | Total width of the cone's wide end |
| `vacuum_speed` | `float` | `250.0` | How fast stars are sucked into the origin |
| `star_size` | `float` | `1.0` | Size of drawn stars in pixels |

**Internal state:** `_is_vacuuming` (bool), parallel arrays `_stars_pos`, `_stars_vel`,
`_star_colors`.

- `_ready()`: calls `super._ready()`, then `set_process(false)` (idle until `start_vacuum()`).
- `start_vacuum()`: sets `_is_vacuuming = true`, `set_process(true)`.
- `stop_vacuum()`: sets `_is_vacuuming = false`. Existing stars finish their journey unless
  cleared — the effect keeps processing so they can complete.
- `_spawn_star()`: spawns at the wide end — center `= (cone_length, 0)`, picks a point within
  radius `cone_width/2` at a random angle in `-PI/2 .. PI/2`, velocity points exactly back to
  the origin with speed in `vacuum_speed * 0.7 .. vacuum_speed`.
- `_process(delta)`:
  - while vacuuming and below `star_count`, calls `_spawn_star()`;
  - integrates each star's position;
  - removes a star when it reaches the origin (`x <= 0.0` or `length() < 5.0`), removing from
    all three arrays in lockstep;
  - `queue_redraw()`.
- `_draw()`: draws each star as a `star_size × star_size` `Rect2` via `draw_rect`.

> The cone shape itself (the outline) is **not** drawn here — only the vacuuming particles.

---

### `twinkling_stars_effect.gd` — `CDTwinklingStarsEffect`

A non-scrolling starfield background where each star twinkles in alpha. Configurable size,
density, shape, and twinkle speed.

```gdscript
class_name CDTwinklingStarsEffect extends CDEffect
```

```gdscript
enum StarType { CIRCLE, FOUR_POINT, SIX_POINT }
```

| Export | Type | Default | Purpose |
|---|---|---|---|
| `star_count` | `int` | `100` | Number of stars |
| `min_size` | `float` | `1.0` | Minimum star radius |
| `max_size` | `float` | `4.0` | Maximum star radius |
| `min_alpha` | `float` | `0.2` | Minimum twinkle alpha |
| `max_alpha` | `float` | `1.0` | Maximum twinkle alpha |
| `twinkle_speed` | `float` | `2.0` | Twinkle frequency multiplier |
| `star_colors` | `Array[Color]` | white/red/blue/orange/green | Palette |
| `effect_width` | `float` | `0.0` | Field width; `0` ⇒ viewport width |
| `effect_height` | `float` | `0.0` | Field height; `0` ⇒ viewport height |

**Per-star state:** parallel arrays `_positions`, `_sizes`, `_base_colors`, `_types`,
`_phases` (random `0..TAU` so stars don't twinkle in sync).

- `_ready()`: calls `super._ready()`; viewport fallback for size; seeds arrays with random
  positions, sizes, colors, types, and a random phase per star.
- `_process(_delta)`: only `queue_redraw()` (twinkle is driven by real time inside `_draw`).
- `_draw()`: computes `time = Time.get_ticks_msec() / 1000.0`; per star, alpha is
  `lerpf(min_alpha, max_alpha, sin(time * twinkle_speed + phase) * 0.5 + 0.5)`, applied to a
  copy of the base color; then `match type` like the scrolling starfield:
  - `CIRCLE` → `draw_circle`;
  - `FOUR_POINT` / `SIX_POINT` → `_draw_star_shape`;
  - fallback → `draw_circle`.
- `_draw_star_shape(center, radius, points, color)`: identical implementation to
  `CDScrollingStarsEffect._draw_star_shape` (star polygon, `inner_radius = radius * 0.4`).

---

## How to use these effects

1. These are `Node2D` scripts. Attach them to a `Node2D` (or instantiate the scene that has
   the script) wherever you want the effect to appear.
2. For self-freeing effects (`BrokenShipEffect`, `DeathParticleEffect`,
   `CDScrollingStarsEffect`, `CDTwinklingStarsEffect`), set `lifetime` to control how long
   they persist. They will `queue_free()` themselves automatically.
3. For `TractorConeEffect`, set `lifetime = 0` and call `start_vacuum()` / `stop_vacuum()`
   from the parent component; free it manually when done.
4. For `LassoEffect`, parent it to a `CDEntity` whose blackboard contains the `captor_key`
   and `target_key`, and ensure the expected event-bus signals (`lasso_end`, and the game's
   `player_captured`) are available — otherwise it will error out in `_ready()`.
5. Customize the palette via the inherited `colors` array; effects pick colors with
   `get_random_color()` (falls back to white when empty).

---

## How to create a new effect of this type

To add a new self-drawing effect:

1. **Create the file** in this folder, e.g. `my_effect.gd`.
2. **Extend the base class** and declare a `class_name`:
   ```gdscript
   ## MyEffect
   ## one-line description of what it does

   class_name MyEffect extends CDEffect
   ```
3. **Add `@export` tunables** at the top for anything designers should tweak (counts,
   speeds, sizes). Reuse the inherited `colors` array for the palette rather than adding
   your own.
4. **Override `_ready()`** and **call `super._ready()` first** — this arms the lifetime
   auto-free timer. Seed any per-element arrays here using `get_random_color()` for colors.
5. **Pick the right update loop:**
   - Use `_physics_process(delta)` for motion that should be frame-rate independent and tied
     to physics (`BrokenShipEffect`, `DeathParticleEffect`).
   - Use `_process(delta)` for pure visuals / real-time-driven animation
     (`CDScrollingStarsEffect`, `CDTwinklingStarsEffect`, `TractorConeEffect`,
     `LassoEffect`).
   - In either case, call `queue_redraw()` each tick so `_draw()` re-runs.
6. **Override `_draw()`** to paint with the Godot 2D draw API (`draw_line`, `draw_circle`,
   `draw_rect`, `draw_polyline`, `draw_colored_polygon`, etc.).
7. **Store per-element state in parallel arrays** (this is the established pattern in this
   folder: one array per attribute, indexed in lockstep). Keep `_draw()` a pure function of
   that state.
8. If your effect is **toggled** rather than self-freeing, follow the `TractorConeEffect`
   pattern: set `lifetime = 0`, call `set_process(false)` in `_ready()`, and expose
   `start_*()` / `stop_*()` methods that flip processing on/off.
9. If your effect needs to **read runtime data**, follow the `LassoEffect` pattern: parent it
   to a `CDEntity`, read from its `blackboard`, and connect to event-bus signals via
   `bus_connect`. Guard with `is_instance_valid(...)` before using node endpoints.

> Keep these scripts self-contained and drawing-only. Business logic and state belong in
> components/entities, not in effects.