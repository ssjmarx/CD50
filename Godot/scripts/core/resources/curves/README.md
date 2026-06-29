# Curves — Procedural Path Resources

`CDCurve` and its subclasses are reusable `@tool Resource`s that generate a `Curve2D` between a `start` and `end` point. Each subclass produces a different procedural shape (arc, sine, spiral, zigzag, etc.). They are configured in the inspector, and every editable property calls `emit_changed()` from its setter so consumers redraw live in the editor.

## Files

| Class | Shape |
|-------|-------|
| `CDCurve` | Abstract base — do not instantiate |
| `CDArcCurve` | Semicircle perpendicular to travel |
| `CDCircleCurve` | Circle/ellipse centered on `end` |
| `CDHelixCurve` | Corkscrew around the base path |
| `CDLissajousCurve` | Lissajous figure on each axis |
| `CDParabolaCurve` | Parabolic arc with curvature exponent |
| `CDSawtoothWaveCurve` | Closed sawtooth wave |
| `CDSequenceCurve` | Composites child curves into a cycling sequence (only stateful one) |
| `CDSineCurve` | Smooth sine perpendicular to travel |
| `CDSpiralCurve` | Sinusoidal radius spiral along base path |
| `CDSquareWaveCurve` | Closed square wave |
| `CDTriangleCurve` | Closed triangle from `end` |
| `CDZigzagCurve` | Closed alternating zigzag |

---

## Patterns

### 1. Base class contract
`CDCurve` is abstract. Subclasses override:
```gdscript
func generate_curve(start: Vector2, end: Vector2) -> Curve2D
```
The base implementation `push_error`s and returns `null`. `reset()` is a no-op in the base; override only when a subclass holds runtime state (`CDSequenceCurve` is the only one).

### 2. Shared exports (inherited by every subclass)
| Export | Default | Purpose |
|--------|---------|---------|
| `resolution` | `100` | Sample-point count |
| `curve_seed` | `0` | Per-instance phase variation (`curve_seed * 0.618 * TAU`); `0` = none |
| `offset` | `Vector2.ZERO` | Global position offset added post-generation |
| `reverse` | `false` | Reverses point order post-generation |

### 3. `@tool` + `emit_changed()` setters
Every curve is `@tool`. Every `@export` uses a setter that assigns the value then calls `emit_changed()` so inspector edits update consumers immediately.

### 4. Helpers (call from `generate_curve`)
- `_get_phase() -> float` — seed-based phase offset (`0.0` when `curve_seed == 0`).
- `_base_position(start, end, t) -> Vector2` — interpolated position with a `sin(PI * t)` depth bow (peaks at midpoint).
- `_finalize(curve)` — applies `offset` then `reverse`; **every** `generate_curve()` ends with `return _finalize(curve)`.

### 5. Sampling convention
Open shapes sample `range(resolution + 1)` with `t = i / resolution`. Closed loops add the `start` point as both the first and last point.

---

## How to create a new curve

```gdscript
## CDExampleCurve
## One-line description of the shape this produces.

@tool
class_name CDExampleCurve extends CDCurve

## shape-specific export; every export uses a setter that calls emit_changed()
@export var amplitude: float = 150.0:
    set(v):
        amplitude = v
        emit_changed()

func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
    var curve := Curve2D.new()
    var phase := _get_phase()
    for i in range(resolution + 1):
        var t := float(i) / float(resolution)
        var base := _base_position(start, end, t)
        # ...compute your displacement...
        curve.add_point(base)
    return _finalize(curve)
```

### Checklist

- [ ] `@tool`; `class_name CD<Something>Curve extends CDCurve`.
- [ ] Every editable property is `@export` with a setter that calls `emit_changed()`.
- [ ] Override `generate_curve(start, end) -> Curve2D`; end with `return _finalize(curve)`.
- [ ] Sample `range(resolution + 1)` with `t = i / resolution`; for closed loops add `start` as first and last point.
- [ ] Use `_get_phase()` for seed variation and `_base_position()` for the bowed base path.
- [ ] Override `reset()` only if the curve holds mutable runtime state across calls.