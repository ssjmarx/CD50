# Faces — Entity Visual Components

7 face components that define what an entity **looks like**. All extend `CDEntityComponent` with `component_category = VISUAL`. Faces handle rendering: vector shapes, sprites, engine flames, and death effects.

No subcategories — faces are a flat collection.

---

## Common Face Pattern

```
_ready()         → set component_category = VISUAL, create child nodes (SpriteFace only)
_on_initialize() → ensure signals, connect bindings, set default frame
_process()       → queue_redraw() for @tool editor preview
_draw()          → Godot 2D drawing API (vector faces) or child Sprite2D (sprite face)
_on_entity_deactivating() → disconnect signals
```

### The Binding System

`VectorFace`, `PolygonFace`, and `SpriteFace` share a binding pattern using `CDFaceBinding` resources:

| Binding Property | Purpose |
|-----------------|---------|
| `signal_name` | Entity signal that triggers the frame change |
| `frame_index` | Which shape/texture to switch to |
| `restore_after` | Seconds before reverting to `default_frame` (0 = no restore) |

This lets any entity signal (e.g., `"hit"`, `"thrust"`, `"shape_changed"`) trigger a visual state change without the face knowing why.

### Shape Resources

Vector faces use `CDShape` resources which contain:
- `points: PackedVector2Array` — the polygon/polyline vertices
- `closed: bool` — whether to close the shape (VectorFace only)

### Must-Includes When Creating Faces

1. Extend `CDEntityComponent` (or a face subclass like `VectorFace`)
2. Set `component_category = CDEnums.ComponentCategory.VISUAL` in `_ready()`
3. Add `@tool` annotation if the face should preview in the editor
4. Add setter functions on exports that call `queue_redraw()` for live preview
5. Add `_process()` that calls `queue_redraw()` when `Engine.is_editor_hint()` for editor preview
6. Ensure all entity signals exist with `entity.ensure_signal()` before connecting
7. Disconnect all connections in `_on_entity_deactivating()`

---

## Face Components

### Static Shape Faces

These draw shapes defined in `CDShape` resources. They support the binding system for frame-based animation.

| Face | Draw Method | Shape Type | Extends |
|------|------------|------------|---------|
| `VectorFace` | `draw_polyline()` | Open/closed polylines | `CDEntityComponent` |
| `PolygonFace` | `draw_colored_polygon()` | Filled polygons | `CDEntityComponent` |
| `SpriteFace` | Child `Sprite2D` | Texture frames | `CDEntityComponent` |

### Dynamic Vector Faces

These draw procedural vector graphics driven by entity state.

| Face | Visual | Driven By |
|------|--------|-----------|
| `VectorEngineFace` | Single exhaust flame | `thrust` / `end_thrust` signals |
| `VectorThrusterFace` | 4 diagonal thruster flames | `move` signal direction |

Both engine faces feature:
- Flickering tips on a configurable timer (`flicker_speed`, `flicker_size`)
- Editor preview via `@tool` + `_process()`
- Physics-process driven animation (only runs when active)

### Effect Faces

| Face | Purpose |
|------|---------|
| `DeathEffectFace` | Spawns `CDEffect` scenes at entity position on death |
| `MenacingVectorFace` | Extends `VectorFace` with CRT menace effects: glitch, static, glow, scan, corrupt |

### MenacingVectorFace CRT Effects

Extends `VectorFace` with 5 layered effects, each independently toggleable:

| Effect | Visual | Key Exports |
|--------|--------|-------------|
| Glitch | Horizontal band displacement | `glitch_chance`, `glitch_intensity`, `glitch_band_height` |
| Static | Random bright pixels | `static_chance`, `static_density`, `static_size` |
| Glow | Pulsing multi-pass bloom | `glow_passes`, `glow_base_width`, `glow_pulse_speed` |
| Scan | Bright horizontal sweep line | `scan_chance`, `scan_thickness`, `scan_brightness` |
| Corrupt | Vertex displacement + color swap | `corrupt_chance`, `corrupt_displacement` |

Effects can also be triggered by entity signals via `trigger_glitch`, `trigger_corrupt`, `trigger_static` arrays.
