# Projectors — Visual Display Components

2 projector components that handle visual overlays and post-processing. These are game-level UI/visual components — they don't live on entities but provide screen-level presentation.

---

## Common Projector Pattern

Projectors differ from other game components in that they're primarily visual:
- They extend `CDGameComponent` or `Control` directly
- They use `_process()` (not `_physics_process()`) since they drive visual effects
- They connect to the game bus for state-driven visibility changes
- They manage their own node hierarchy for rendering

### Must-Includes When Creating Projectors

1. Decide base class: `CDGameComponent` for shader/Node2D effects, `Control` for UI overlays
2. Use `_process()` for visual animations (hum bars, scrolling, fading)
3. Use `_physics_process()` only if physics timing is needed
4. Connect game bus signals in `_on_initialize()` for state changes
5. Clean up tweens and dynamic nodes in `_exit_tree()`
6. Use `process_physics_priority` to control update order if needed

---

## Components

### CreditProjection — Music Track Credit Overlay

A `Control`-based overlay that displays floating "Now Playing" credits when music tracks change. Fades in, holds, then fades out using a Tween sequence.

| Feature | Details |
|---------|---------|
| **Base class** | `Control` (not CDGameComponent) |
| **Trigger** | `track_changed` game bus signal with `CDMusicTrack` arg |
| **Display** | Title + artist labels with outline, built dynamically |
| **Animation** | Tween: fade in → hold → fade out → cleanup |
| **Lifecycle** | `_show_credit()` creates nodes, `_clear_credit()` kills tween and frees nodes |
| **Process priority** | `process_physics_priority = 70` |

### CRTProjector — CRT Post-Processing Pipeline

Full-screen CRT television simulation built from a node hierarchy: BackBufferCopy → Persistence SubViewport → CRT shader ColorRect → scanlines overlay → noise overlay. Driven by two custom shaders (`crt_light.gdshader` and `persistence.gdshader`).

| Feature | Details |
|---------|---------|
| **Base class** | `CDGameComponent` |
| **Pipeline** | BackBufferCopy → Persistence VP (phosphor decay) → CRT shader (warp, aberration, bloom, etc.) → scanlines → noise |
| **Shaders** | `res://shaders/crt_light.gdshader` (main CRT), `res://shaders/persistence.gdshader` (phosphor trails) |
| **Dirty flag** | All export setters mark `_params_dirty`, pushed once per frame in `_process()` |
| **Animation** | Hum bar scroll (shader `roll_y`), noise texture position scroll |
| **Visibility** | `crt_on` / `crt_off` game bus signals toggle visibility |
| **Z-index** | `OVERLAY_Z = 4096` ensures rendering on top of everything |

#### CRT Shader Parameters

| Parameter | Range | Effect |
|-----------|-------|--------|
| `warp` | 0.0–0.3 | Screen barrel distortion |
| `aberration` | 0.0–10.0 | Chromatic aberration offset |
| `vignette` | 0.0–4.0 | Edge darkening intensity |
| `bloom_amount` | 0.0–2.0 | Bloom spread |
| `bloom_threshold` | 0.0–2.0 | Brightness threshold for bloom |
| `roll_brightness` | 0.0–0.5 | Hum bar brightness |
| `flicker` | 0.0–0.1 | Random brightness variation |
| `brightness` | 0.5–2.0 | Overall brightness multiplier |
| `gamma` | 0.5–3.0 | Gamma correction |
| `persistence_decay` | 0.0–0.98 | Phosphor trail fade rate |
| `persistence_blend` | 0.0–1.0 | How much phosphor blends into main image |