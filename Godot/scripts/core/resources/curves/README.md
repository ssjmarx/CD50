# Curve Resources

11 resource classes that generate `Curve2D` paths for entity movement. All marked `@tool` for live editor preview.

---

## Architecture

`CDCurve` (abstract base) defines common exports and utility methods. 10 concrete curves extend it, each implementing `generate_curve(start, end) → Curve2D`.

### Base Class Exports (inherited by all)

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `resolution` | `int` | 100 | Number of sample points along the curve |
| `curve_seed` | `int` | 0 | Phase offset seed (0 = no variation) |
| `offset` | `Vector2` | ZERO | Global position offset applied after generation |
| `reverse` | `bool` | false | Reverse point order |

### Base Class Methods

| Method | Purpose |
|--------|---------|
| `generate_curve(start, end)` | **Abstract** — override in subclasses |
| `_apply_offset(curve)` | Shift all points by `offset` |
| `_reverse_curve(curve)` | Reverse point order if `reverse` is true |
| `_finalize(curve)` | Apply offset + reverse (call at end of `generate_curve`) |
| `_get_phase()` | Seed-based phase offset for variation |
| `_base_position(start, end, t)` | Interpolated position along start→end with sin depth |

### Must-Includes When Creating Curves

1. Mark as `@tool` for editor preview
2. Extend `CDCurve`
3. Add shape-specific `@export` vars with `emit_changed()` setters
4. Override `generate_curve(start, end)` → return `_finalize(curve)`

---

## Curve Types

### CDArcCurve — Arc / Semicircle

| Export | Default | Purpose |
|--------|---------|---------|
| `height` | 150.0 | Arc height perpendicular to travel direction |
| `bulge_direction` | 1 | Which side the arc bulges toward (1 or -1) |

### CDCircleCurve — Circle / Ellipse

| Export | Default | Purpose |
|--------|---------|---------|
| `radius_x` | 100.0 | Horizontal radius |
| `radius_y` | 100.0 | Vertical radius (different from radius_x = ellipse) |
| `loops` | 1 | Number of full rotations |

Centered on `end` point. `start` determines the starting angle.

### CDHelixCurve — Helix / Corkscrew

| Export | Default | Purpose |
|--------|---------|---------|
| `radius` | 100.0 | Helix radius perpendicular to travel |
| `turns` | 3 | Number of corkscrew rotations |

Oscillates around the base path between start and end.

### CDLissajousCurve — Lissajous Figure

| Export | Default | Purpose |
|--------|---------|---------|
| `amplitude_x` | 150.0 | Horizontal oscillation amplitude |
| `amplitude_y` | 200.0 | Vertical oscillation amplitude |
| `loops` | 1 | Frequency multiplier |

Classic Lissajous pattern using sin/cos with the seed phase offset.

### CDParabolaCurve — Parabolic Arc

| Export | Default | Purpose |
|--------|---------|---------|
| `amplitude` | 150.0 | Peak displacement from base path |
| `curvature` | 2.0 | Power exponent for the parabola shape |
| `direction` | 1 | Which side the parabola curves toward (1 or -1) |

### CDSawtoothWaveCurve — Sawtooth Wave

| Export | Default | Purpose |
|--------|---------|---------|
| `amplitude` | 150.0 | Peak displacement |
| `teeth` | 4 | Number of sawtooth peaks |

Sharp zigzag pattern with asymmetric rise/fall. Returns to start.

### CDSineCurve — Sine Wave

| Export | Default | Purpose |
|--------|---------|---------|
| `amplitude` | 150.0 | Peak displacement from base path |
| `frequency` | 1 | Number of full sine cycles |

Smooth sinusoidal oscillation along the travel direction.

### CDSpiralCurve — Spiral

| Export | Default | Purpose |
|--------|---------|---------|
| `max_radius` | 150.0 | Maximum spiral radius |
| `turns` | 3 | Number of spiral rotations |
| `inward` | true | Spiral inward (tighten) or outward (expand) |

Radius modulated by `sin(PI * t)` depth factor.

### CDSquareWaveCurve — Square Wave

| Export | Default | Purpose |
|--------|---------|---------|
| `amplitude` | 150.0 | Peak displacement |
| `steps` | 4 | Number of square wave steps |

Sharp 90° transitions between high/low. Returns to start.

### CDTriangleCurve — Triangle Shape

| Export | Default | Purpose |
|--------|---------|---------|
| `size` | 100.0 | Triangle side length |
| `base_angle` | 60.0 | Base angle in degrees (1–89) |

Generates a closed triangle. Apex angle is `180 - 2 * base_angle`.

### CDZigzagCurve — Zigzag

| Export | Default | Purpose |
|--------|---------|---------|
| `amplitude` | 150.0 | Peak displacement |
| `segments` | 4 | Number of zigzag peaks |

Alternating sharp peaks. Returns to start.