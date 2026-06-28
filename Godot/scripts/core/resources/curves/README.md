# `curves/` — Procedural Path Curve Resources

This folder contains `CDCurve` and its subclasses: reusable `Resource` objects that
generate `Curve2D` paths between a `start` and `end` point. Each subclass produces a
different procedural shape (arc, sine wave, spiral, zigzag, etc.). Because they are
`Resource`s, they are configured in the inspector, and every editable property calls
`emit_changed()` from its setter so consumers redraw live in the editor.

All scripts are marked `@tool`.

---

## Base class: `CDCurve`

File: `cd_curve.gd` — abstract base class. Do not instantiate directly; calling
`generate_curve()` on it pushes an error and returns `null`.

### Shared exports (inherited by every subclass)

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `resolution` | `int` | `100` | Number of sample points along the generated curve. |
| `curve_seed` | `int` | `0` | Phase-offset seed. Non-zero adds per-instance variation via a golden-ratio phase (`curve_seed * 0.618 * TAU`). |
| `offset` | `Vector2` | `Vector2.ZERO` | Global position offset added to every generated point (post-processing). |
| `reverse` | `bool` | `false` | Reverses the point order of the generated curve (post-processing). |

Each setter calls `emit_changed()`, so any consumer listening to the resource's
`changed` signal redraws immediately.

### Abstract interface

```gdscript
func generate_curve(start: Vector2, end: Vector2) -> Curve2D
```

Subclasses override this to build and return a `Curve2D`. The base implementation
pushes `push_error(...)` and returns `null`.

### Post-processing helpers (intended for subclasses to call internally)

- `_apply_offset(curve)` — shifts all points by `offset`; no-op if offset is zero.
- `_reverse_curve(curve)` — reverses point order; no-op if `reverse` is `false`.
- `_finalize(curve)` — convenience that applies `_apply_offset` then `_reverse_curve`.
  Every concrete `generate_curve()` in this folder ends with `return _finalize(curve)`.

### Utilities for subclasses

- `_get_phase() -> float` — returns `0.0` when `curve_seed == 0`, otherwise
  `curve_seed * 0.618 * TAU`. Used by subclasses to add seed-based variation.
- `_base_position(start, end, t) -> Vector2` — interpolated position along `start→end`
  using a `sin(PI * t)` depth factor, so the base path bows and peaks at the midpoint.

### Reset hook

```gdscript
func reset() -> void
```

Virtual no-op in the base. Override only when a subclass holds mutable runtime state
(only `CDSequenceCurve` currently does).

---

## Subclasses

All subclasses share the same structure: `@tool`, `class_name CD...Curve extends CDCurve`,
shape-specific `@export` properties with `emit_changed()` setters, and an override of
`generate_curve()` that builds a `Curve2D` and returns `_finalize(curve)`.

### `CDArcCurve` — `cd_arc_curve.gd`

Arc / semicircle bulging perpendicular to the travel direction.

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `height` | `float` | `150.0` | Peak height of the arc perpendicular to travel (scaled by seed). |
| `bulge_direction` | `int` | `1` | Which side the arc bulges toward (`1` or `-1`). |

Computes a perpendicular axis from the travel direction and uses a `sin(angle)` arc with
a `-cos(angle)` forward component. Seed adds a small height multiplier.

### `CDCircleCurve` — `cd_circle_curve.gd`

Circle / ellipse centered on the `end` point.

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `radius_x` | `float` | `100.0` | Horizontal radius. Unequal to `radius_y` produces an ellipse. |
| `radius_y` | `float` | `100.0` | Vertical radius. |
| `loops` | `int` | `1` | Number of full rotations. |

The initial angle is derived from the direction of `start` relative to `end` (the center).

### `CDHelixCurve` — `cd_helix_curve.gd`

Helix / corkscrew oscillating around the base path.

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `radius` | `float` | `100.0` | Helix radius perpendicular to travel. |
| `turns` | `int` | `3` | Number of corkscrew rotations. |

Combines the `_base_position` path with a perpendicular `cos(angle)` displacement and a
small forward `sin(angle)` component (scaled by `0.3`).

### `CDLissajousCurve` — `cd_lissajous_curve.gd`

Lissajous figure: independent-axis `sin`/`cos` oscillation layered on the base path.

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `amplitude_x` | `float` | `150.0` | Horizontal oscillation amplitude. |
| `amplitude_y` | `float` | `200.0` | Vertical oscillation amplitude. |
| `loops` | `int` | `1` | Frequency multiplier for the pattern. |

Uses `sin(loops * TAU * t)` on X and `cos(loops * TAU * t)` on Y, both phase-shifted by
the seed.

### `CDParabolaCurve` — `cd_parabola_curve.gd`

Parabolic arc with a configurable curvature exponent.

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `amplitude` | `float` | `150.0` | Peak displacement from the base path. |
| `curvature` | `float` | `2.0` | Power exponent (`pow(sin(...), curvature)`); higher = more peaked. |
| `direction` | `int` | `1` | Which side the parabola curves toward (`1` or `-1`). |

Computed as `pow(sin(PI * t + seed_offset), curvature) * amplitude` along the perpendicular.

### `CDSawtoothWaveCurve` — `cd_sawtooth_wave_curve.gd`

Sawtooth wave of alternating sharp peaks. **Closed loop**: starts and ends at `start`.

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `amplitude` | `float` | `150.0` | Peak displacement from the base path. |
| `teeth` | `int` | `4` | Number of sawtooth peaks. |

Generates `teeth * 2` alternating peaks on each side of the path. Seed flips the starting
side via `sin(_get_phase())`.

### `CDSequenceCurve` — `cd_sequence_curve.gd`

Composites multiple `CDCurve` resources into a cycling sequence. **The only subclass with
runtime state**; it also overrides `reset()`.

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `curves` | `Array[CDCurve]` | `[]` | Ordered list of child curves to cycle through. |
| `mode` | `SequenceMode` | `SEQUENTIAL` | How the active index advances (see enum below). |
| `preview_index` | `int` | `0` | Editor-only: which child to show in the preview drawing. |

`SequenceMode` enum:

- `SEQUENTIAL` — A → B → C → A → B → C …
- `RANDOM` — random selection each call.
- `PING_PONG` — A → B → C → B → A → B → C …
- `RANDOM_NO_REPEAT` — random but never the same index twice in a row.

Behavior details actually in the script:

- On each `generate_curve(start, end)` call it delegates to `curves[idx].generate_curve(...)`,
  then finalizes the result with `_finalize(...)`.
- In the editor (`Engine.is_editor_hint()`), it uses `preview_index` and does **not**
  advance; at runtime it advances the index after each call.
- Returns `null` if `curves` is empty or the child returns `null`.
- Connects to each child's `changed` signal (in `_enter_tree` / on `curves` assignment)
  and re-emits `changed` so the composite updates when a child is edited. Disconnects in
  `_exit_tree` / before reassignment.
- `reset()` restores `_current_index = 0` and `_ping_pong_direction = 1`.

### `CDSineCurve` — `cd_sine_curve.gd`

Smooth sine wave perpendicular to the travel direction.

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `amplitude` | `float` | `150.0` | Peak displacement perpendicular to travel. |
| `frequency` | `int` | `1` | Number of full sine cycles. |

### `CDSpiralCurve` — `cd_spiral_curve.gd`

Spiral whose radius is modulated by a `sin(PI * t)` depth factor along the base path.

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `max_radius` | `float` | `150.0` | Maximum spiral radius. |
| `turns` | `int` | `3` | Number of spiral rotations. |
| `inward` | `bool` | `true` | `true` tightens inward (radius shrinks toward the middle); `false` expands outward (radius grows from the ends toward the middle). |

Uses `perp * cos(angle) * r + travel_dir * (sin(angle) * r * 0.3)` so the spiral also has a
small forward/back component.

### `CDSquareWaveCurve` — `cd_square_wave_curve.gd`

Square wave with sharp 90° transitions between high and low. **Closed loop**: starts and
ends at `start`.

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `amplitude` | `float` | `150.0` | Peak displacement from the base path. |
| `steps` | `int` | `4` | Number of square-wave steps. |

Generates `steps * 2` half-steps, inserting a second point at the opposite side between
peaks to create the vertical transitions. Seed flips the starting side.

### `CDTriangleCurve` — `cd_triangle_curve.gd`

Closed three-vertex triangle built outward from the `end` point.

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `size` | `float` | `100.0` | Side length of the triangle. |
| `base_angle` | `float` | `60.0` | Base angle in degrees (clamped to `1–89`); apex angle = `180 - 2 * base_angle`. |

The triangle is built from `end` along the direction back toward `start`, rotated by the
seed phase. Adds four points to close the loop (`v0, v1, v2, v0`).

### `CDZigzagCurve` — `cd_zigzag_curve.gd`

Alternating sharp peaks on each side of the base path. **Closed loop**: starts and ends
at `start`.

| Export | Type | Default | Purpose |
| --- | --- | --- | --- |
| `amplitude` | `float` | `150.0` | Peak displacement from the base path. |
| `segments` | `int` | `4` | Number of zigzag peak segments. |

Generates `segments * 2` alternating peaks. Seed flips the starting side.

---

## How to use these curves

1. Create or assign one of these resources (e.g. in the inspector or via `load()`/`preload()`).
2. Configure its exports. Setters call `emit_changed()`, so anything connected to the
   `changed` signal updates live.
3. Call `generate_curve(start, end)` to obtain a `Curve2D`. The `start` and `end` points
   are interpreted per-subclass (see each section above — e.g. `CDCircleCurve` treats
   `end` as the center, while `CDSineCurve` travels from `start` to `end`).
4. The shared `resolution`, `curve_seed`, `offset`, and `reverse` exports behave
   identically across all subclasses.
5. For `CDSequenceCurve`, call `reset()` if you need to restart the sequence from its
   initial state.

---

## How to create a new curve of this type

Follow the pattern every file in this folder already uses. Minimal template, derived
directly from the existing scripts:

```gdscript
## CDExampleCurve
## One-line description of the shape this produces.

@tool
class_name CDExampleCurve extends CDCurve

## (shape-specific export; every export uses a setter that calls emit_changed())
@export var amplitude: float = 150.0:
	set(v):
		amplitude = v
		emit_changed()

func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()

	# typical helpers available from the base class:
	#   _get_phase()            -> seed-based phase offset (0.0 when curve_seed == 0)
	#   _base_position(s, e, t) -> bowed interpolated base position (peaks at midpoint)
	var phase := _get_phase()

	# Sample the shape from t = 0..1 across (resolution + 1) points:
	for i in range(resolution + 1):
		var t := float(i) / float(resolution)
		var base := _base_position(start, end, t)
		# ...compute your displacement...
		curve.add_point(base)

	# Always end with _finalize so the shared offset/reverse post-processing runs:
	return _finalize(curve)
```

Conventions to follow (all observed in this folder):

- Mark the script `@tool`.
- Name the class `CD<Something>Curve` and extend `CDCurve`.
- Declare every editable property with `@export` and a setter body that assigns the value
  and then calls `emit_changed()`.
- Override `generate_curve(start: Vector2, end: Vector2) -> Curve2D`.
- Sample the shape over `range(resolution + 1)` for open curves, with `t = i / resolution`.
- Return the result through `_finalize(curve)` so `offset` and `reverse` apply uniformly.
- Use `_get_phase()` for any seed-based variation and `_base_position()` when you want the
  bowed base path that the other curves use.
- Only override `reset()` if your curve holds mutable runtime state across calls (see
  `CDSequenceCurve`); otherwise leave the base no-op.
- For closed-loop shapes, explicitly add the `start` point as both the first and last
  point (see `CDSawtoothWaveCurve`, `CDSquareWaveCurve`, `CDZigzagCurve`, `CDTriangleCurve`).