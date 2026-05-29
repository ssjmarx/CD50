# Effects

2 visual effect scripts that extend `CDEffect`. Both use custom `_draw()` rendering with `_physics_process()` animation, and auto-free via the base class `lifetime` export.

---

## Architecture

All effects extend `CDEffect` which provides:
- `lifetime` export (seconds before auto-free)
- `_ready()` calls `super._ready()` which starts the lifetime countdown

Effects use the Godot `_draw()` / `queue_redraw()` pattern:
1. `_ready()` — initialize particle/fragment arrays with random positions, velocities, rotations
2. `_physics_process(delta)` — update positions, call `queue_redraw()`
3. `_draw()` — render the current frame using Godot draw primitives

### Must-Includes When Creating Effects

1. Extend `CDEffect`
2. Call `super._ready()` in your `_ready()`
3. Initialize particle arrays in `_ready()`
4. Update positions in `_physics_process()` and call `queue_redraw()`
5. Render using `draw_*` primitives in `_draw()`

---

## Effect Types

### BrokenTriangleEffect — Spinning Line Fragments

Spinning line fragments that drift outward and fade. Used for ship death effects.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `fragment_length` | `float` | 12.0 | Length of each line fragment |
| `line_count` | `int` | 4 | Number of fragments |
| `spread_speed` | `float` | 12.0 | Maximum outward drift speed |
| `spin_speed` | `float` | 1.0 | Maximum rotation speed |
| `fragment_color` | `Color` | WHITE | Color of the line fragments |

### DeathParticleEffect — Single-Pixel Particle Burst

Burst of single-pixel particles that fly outward in all directions. Used for entity death explosions.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `particle_count` | `int` | 50 | Number of particles |
| `spread_speed` | `float` | 200.0 | Maximum outward speed |
| `particle_color` | `Color` | WHITE | Color of the particles |