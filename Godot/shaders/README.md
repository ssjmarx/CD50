# Shaders — CRT Post-Processing Pipeline

2 canvas_item shaders that simulate a CRT television display. Used by `CRTProjector` to build the visual pipeline: persistence accumulation → main CRT effects → PNG overlays (scanlines + noise).

---

## Pipeline Architecture

```
Game Viewport
  → BackBufferCopy (captures SCREEN_TEXTURE)
  → Persistence SubViewport (CLEAR_MODE_NEVER)
	  → persistence.gdshader (phosphor decay accumulation)
  → CRT ColorRect
	  → crt_light.gdshader (barrel warp, chroma, bloom, vignette, hum, flicker, gamma)
  → Scanlines TextureRect (PNG overlay, tiled)
  → Noise TextureRect (PNG overlay, scrolling)
```

### Must-Includes When Creating Shaders for This Project

1. Use `shader_type canvas_item` — all effects are 2D screen-space
2. Use `SCREEN_TEXTURE : hint_screen_texture, filter_nearest` for pixel-perfect sampling
3. Guard expensive operations with threshold checks (`if bloom_amount > 0.0`)
4. Clamp UV after warp to prevent out-of-bounds sampling
5. Comment each uniform with its visual effect and unit/pixel meaning
6. Keep texture samples minimal — target ~7 or fewer per pixel for performance

---

## Shaders

### crt_light.gdshader — Main CRT Post-Processing

Full-screen shader that applies: barrel distortion → chromatic aberration (3 samples) → persistence blending → vignette → bloom (4-sample cross) → rolling hum bar → flicker → brightness → gamma.

| Stage | Samples | Effect |
|-------|---------|--------|
| **Barrel warp** | 0 | UV distortion for curved glass look |
| **Chromatic aberration** | 3 | RGB channel offset for color fringing |
| **Persistence blend** | 1 | Phosphor trail overlay from SubViewport |
| **Vignette** | 0 | Edge darkening (computed, not sampled) |
| **Bloom** | 4 | Cross-pattern bright pixel bleed |
| **Hum bar** | 0 | Scrolling bright band |
| **Flicker** | 0 | Time-based brightness oscillation |
| **Brightness + Gamma** | 0 | Master controls |

**Total: ~7-8 texture samples per pixel** (3 chroma + 1 persistence + 4 bloom)

### persistence.gdshader — Phosphor Trail Accumulator

Minimal shader running inside a `CLEAR_MODE_NEVER` SubViewport. Each frame it blends the previous accumulated content (decayed) with the current game frame, keeping the brightest of both. This creates authentic phosphor afterglow trails.

| Input | Source |
|-------|--------|
| `SCREEN_TEXTURE` | Previous frame's accumulated content (SubViewport retains between frames) |
| `game_frame` | Main viewport output (current game render) |

**Formula:** `max(prev * decay, game)` — physically-motivated: phosphor fades but current frame always shows through at full brightness.

---

## Uniform Reference

### crt_light.gdshader Uniforms

| Uniform | Type | Range | Default | Purpose |
|---------|------|-------|---------|---------|
| `persistence_tex` | sampler2D | — | — | Phosphor accumulation buffer |
| `persistence_blend` | float | 0.0–1.0 | 0.0 | How much phosphor blends into image |
| `resolution` | vec2 | — | 640×360 | Base resolution for pixel calculations |
| `warp_amount` | float | 0.0–0.3 | 0.03 | Barrel distortion strength |
| `aberration_amount` | float | 0.0–10.0 | 1.5 | Chromatic aberration pixel offset |
| `vignette_intensity` | float | 0.0–4.0 | 0.8 | Edge darkening exponent |
| `bloom_threshold` | float | 0.0–2.0 | 0.8 | Brightness cutoff for bloom |
| `bloom_amount` | float | 0.0–2.0 | 0.2 | Bloom spread intensity |
| `roll_y` | float | 0.0–1.0 | 0.0 | Hum bar vertical position (animated) |
| `roll_brightness` | float | 0.0–0.5 | 0.04 | Hum band brightness |
| `flicker_amount` | float | 0.0–0.1 | 0.005 | Brightness oscillation amplitude |
| `brightness` | float | 0.5–2.0 | 1.0 | Master brightness multiplier |
| `gamma` | float | 0.5–3.0 | 1.1 | CRT phosphor power curve |

### persistence.gdshader Uniforms

| Uniform | Type | Range | Default | Purpose |
|---------|------|-------|---------|---------|
| `game_frame` | sampler2D | — | — | Current game viewport texture |
| `decay` | float | 0.0–1.0 | 0.85 | Phosphor fade rate per frame |
