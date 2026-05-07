# Plan 14 — Arcade Juice (CRT Visual System)

**Created:** 2026-05-05  
**Updated:** 2026-05-06  
**Status:** COMPLETE  
**Scope:** Phase 1 only (CRT Visual System)  
**Source:** `planning/brainstorming/attract mode.md` + `planning/brainstorming/arcade juice.md`  
**Implementation notes:** Phosphor trails implemented via shader-based persistence (SubViewport + `persistence.gdshader`) instead of per-body `PhosphorTrail` component. Body `_draw()` methods were NOT modified — vector glow is handled by CRT shader bloom parameters. See `memory-bank/02 - Recent Progress.md` for full details.

---

## Goal

Build a lightweight CRT visual system that makes every game look like it's running on a real monitor, with distinct raster and vector aesthetics. This is the essential visual polish layer needed before the itch.io export.

All changes must run at 60fps in WebGL compatibility mode. The project's zero-asset, procedural architecture makes this naturally lightweight — the CRT system builds on that advantage.

---

## Phase 1 — CRT Visual System

### Why a Custom System

The existing CRT addon (`addons/crt/`) is a high-quality but heavy shader: multi-tap Gaussian filtering (27+ texture samples per pixel for scanlines + aberration), per-pixel noise math, and rolling line computation. This is overkill for 640×360 procedural graphics running in a browser.

**The performance problem is sample count, not SCREEN_TEXTURE.** The original shader's expense comes from 27+ multi-tap Gaussian samples per pixel. A replacement using SCREEN_TEXTURE with exactly 3 samples (for chromatic aberration) is ~10x cheaper and runs without issue on any WebGL GPU.

The replacement uses a **layered approach**: tiny PNG overlays for static effects + a minimal shader for dynamic distortion + body-level `_draw()` for vector glow and phosphor trails.

### 1A. Lightweight CRT Shader

**Replace:** `addons/crt/crt.gdshader` (delete entire addon when new system is accepted)

**New:** `Shaders/crt_light.gdshader` — a minimal canvas_item shader using SCREEN_TEXTURE with exactly 3 samples total:

```
Effects in shader:
- Barrel distortion (screen bulge) — UV warp, zero extra samples
- Chromatic aberration (R/G/B offset) — 3 samples total (one per channel)
- Vignette (math, not texture) — pow() falloff, zero extra samples
- Bloom boost (brightness threshold) — dot() + max(), zero extra samples
- Rolling hum bar (scrolling bright band) — smoothstep, zero extra samples
```

Approximately 35–40 lines of GLSL. No Gaussian multi-tap. No per-pixel noise. Each pixel: 1 UV warp + 3 texture samples (R/G/B offset for aberration) + vignette calculation + bloom threshold + hum bar smoothstep. This runs in single-digit microseconds per frame on any GPU.

**Shader uniform inputs:**
- `resolution` — base resolution for pixel grid calculations
- `warp_amount` — barrel distortion strength
- `aberration_amount` — chromatic aberration offset distance
- `vignette_intensity` — edge darkening strength
- `bloom_threshold` — brightness cutoff for bloom
- `bloom_amount` — bloom intensity multiplier
- `roll_y` — current Y position of the hum bar (updated by script each frame)
- `roll_brightness` — hum bar intensity

### 1B. PNG Texture Overlays

Two `TextureRect` nodes added to the AO scene (or CRT controller node), drawn on top of the game view. A third optional noise overlay provides subtle "alive" texture.

| Overlay | Size | Content | Mode | Required? |
|---------|------|---------|------|-----------|
| Scanlines | 1×2 px | Top pixel transparent, bottom pixel semi-transparent black | `TILE`, `NEAREST` | Yes |
| Phosphor grid | 3×3 px | Repeating RGB sub-pixel aperture grille pattern | `TILE`, `NEAREST` | Yes |
| Noise | 64×64 px | Pre-generated tileable greyscale noise, scrolled slowly via script | `TILE`, `NEAREST` | Optional |

Scanlines and phosphor grid are generated as tiny PNGs (scanlines = 8 bytes, phosphor = 18 bytes). The GPU composites them for free — no math, just alpha blending.

The noise overlay scrolls slowly downward via script (`position.y += delta * scroll_speed`) at very low alpha (0.02–0.04). This provides subtle "living screen" texture without per-pixel shader noise computation. ~4KB PNG.

**Vignette is NOT a PNG** — it's computed in the shader as math (5 lines of GLSL, follows barrel distortion naturally, saves ~50KB texture, identical visual result to the original shader).

**Visibility toggled by `vector_monitor`:**
- Raster mode (`vector_monitor = false`): Scanlines ON, Phosphor Grid ON, Noise ON
- Vector mode (`vector_monitor = true`): Scanlines OFF, Phosphor Grid OFF, Noise ON (optional, weaker alpha)

Vignette, aberration, bloom, and hum bar are always on (controlled by shader uniforms, not visibility toggles).

### 1C. `vector_monitor` Export on UGS

```gdscript
# universal_game_script.gd
@export var vector_monitor: bool = false
```

This single bool switches the CRT aesthetic. A `crt_controller` component (or logic in the Interface Takeover) reads this on ready and configures:
- Texture overlay visibility (scanlines, phosphor grid)
- Shader uniform values (aberration strength, bloom amount)
- Body draw mode (passed through `game.vector_monitor`)

**Game assignments** (case-by-case, based on historical hardware):

| Game | Mode | Rationale |
|------|------|-----------|
| Pong | Raster | Original used a standard raster CRT |
| Breakout | Raster | Standard raster display |
| Asteroids | Vector | Original used a vector monitor (XY display) |
| Pongsteroids | Vector | Asteroids-derived, vector aesthetic |
| Dogfight | Vector | Asteroids-derived, vector aesthetic |
| Space Invaders | Raster | Original used a raster CRT |
| Tetris | Raster | Standard raster display |
| Breaksteroids | Raster | Breakout-derived, raster aesthetic |

### 1D. Body Draw Updates — Vector Glow

Vector-mode bodies draw a double-stroke in `_draw()`:

```gdscript
if game and game.vector_monitor:
    # 1. Glow (wider, semi-transparent)
    var glow_color = Color(r, g, b, 0.2)
    draw_polyline(points, glow_color, 4.0, true)
    # 2. Core (sharp, bright)
    draw_polyline(points, ship_color, 1.5, true)
else:
    # Standard raster draw
    draw_polyline(points, ship_color, 2.0, true)
```

Affected bodies: `triangle_ship.gd`, `ball.gd`, `asteroid.gd`. Each checks `game.vector_monitor` and branches its draw code. Raster bodies (brick, invader, paddle, tetromino) are unaffected.

### 1E. Phosphor Trail Component

**New component:** `phosphor_trail.gd` — pure `_draw()` ghost trail for vector-mode bodies.

**How it works:**
1. Stores a ring buffer of the body's last N global positions (configurable, default 5)
2. In `_physics_process`, pushes current position if it changed since last frame
3. Body's `_draw()` calls `phosphor_trail.get_trail_data()` and draws ghost copies at previous positions with decreasing opacity
4. Ghosts use the same shape/points as the current frame, just offset and faded

```gdscript
# phosphor_trail.gd
extends UniversalComponent

@export var trail_length: int = 5
var _positions: Array[Vector2] = []

func _physics_process(_delta):
    if not parent: return
    var current = parent.global_position
    if _positions.is_empty() or current.distance_squared_to(_positions[0]) > 1.0:
        _positions.push_front(current)
        if _positions.size() > trail_length:
            _positions.pop_back()
        parent.queue_redraw()

func get_trail_data() -> Array[Vector2]:
    return _positions
```

In body `_draw()`:
```gdscript
# Draw ghosts before current frame
var trail_comp = get_node_or_null("PhosphorTrail")
if trail_comp and trail_comp.get_trail_data().size() > 0:
    for i in range(trail_comp.get_trail_data().size()):
        var ghost_pos = trail_comp.get_trail_data()[i]
        var alpha = 0.3 * (1.0 - float(i) / trail_comp.trail_length)
        var offset = ghost_pos - global_position
        draw_set_transform(offset, 0, Vector2.ONE)
        draw_polyline(PackedVector2Array(points), Color(r, g, b, alpha), 1.5, true)
    draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
# Then draw current frame (glow + core)
```

**Why this approach over SCREEN_TEXTURE:**
- Zero VRAM overhead — no backbuffer copy needed
- Zero shader complexity — trails are just extra draw calls
- Physically accurate — trails follow entity paths, static elements never ghost
- Selective — only attached to vector-mode bodies, raster games have zero cost
- Tunable per entity — fast ships get longer trails, slow rocks get shorter ones
- WebGL safe — `_draw()` calls are CPU-side canvas item updates, what Godot 2D is optimized for

**Performance:** ~5 extra `draw_polyline` calls per body per frame. At 640×360 with maybe 15 on-screen entities, this is trivial.

### 1F. CRT Controller

**New component:** `crt_controller.gd` — reads UGS `vector_monitor` and configures shader + overlays.

Or this logic can be part of the AO's Interface Takeover, since AO already manages the child Interface. The controller would:
1. Set shader uniforms on the CRT ColorRect (aberration, bloom, vignette)
2. Toggle TextureRect visibility (scanlines, phosphor grid)
3. Update `roll_y` uniform each frame for the rolling hum bar
4. Optionally scroll the noise overlay
5. Optionally adjust per-game (e.g., stronger aberration for vector games)

```gdscript
# Rolling hum bar update (in _process)
roll_y = fmod(roll_y + delta * roll_speed, 1.0)
material.set_shader_parameter("roll_y", roll_y)
```

### New Files

| File | Location | Purpose |
|------|----------|---------|
| `crt_light.gdshader` | `Shaders/` | Lightweight CRT shader (barrel + aberration + vignette + bloom + hum bar) |
| `scanlines.png` | `Assets/CRT/` | 1×2 pixel scanline overlay |
| `phosphor_grid.png` | `Assets/CRT/` | 3×3 pixel aperture grille overlay |
| `noise.png` | `Assets/CRT/` | 64×64 tileable noise overlay (optional) |
| `phosphor_trail.tscn` | `Scenes/Components/` | Phosphor trail component scene |
| `phosphor_trail.gd` | `Scripts/Components/` | Ghost trail ring buffer + redraw trigger |
| `crt_controller.tscn` | `Scenes/Flow/` | CRT overlay controller scene |
| `crt_controller.gd` | `Scripts/Flow/` | Reads UGS vector_monitor, configures shader + overlays |

### Modified Files

| File | Changes |
|------|---------|
| `universal_game_script.gd` | Add `@export var vector_monitor: bool = false` |
| `triangle_ship.gd` | Vector glow double-stroke + ghost trail drawing |
| `ball.gd` | Vector glow double-stroke + ghost trail drawing |
| `asteroid.gd` | Vector glow double-stroke + ghost trail drawing |
| `arcade_orchestrator.tscn` | Add CRT ColorRect + texture overlay TextureRects |

### Deliverable

All games display with a CRT aesthetic. Vector games (Asteroids, Pongsteroids, Dogfight) show glow + phosphor trails + no scanlines + stronger aberration. Raster games show scanlines + phosphor grid + subtle noise. All games show barrel distortion, vignette, bloom, and the rolling hum bar. The heavy CRT addon is deleted. Runs at 60fps in WebGL.

---

## Implementation Order

| Step | What | Depends On |
|------|------|-----------|
| 1a | Create lightweight CRT shader (`crt_light.gdshader`) — barrel + aberration + vignette + bloom + hum bar | — |
| 1b | Generate PNG overlays (scanlines, phosphor, noise) | — |
| 1c | Add `vector_monitor` export to UGS | — |
| 1d | Update body `_draw()` for vector glow (triangle_ship, ball, asteroid) | 1c |
| 1e | Create `phosphor_trail` component | 1c |
| 1f | Attach phosphor_trail to vector-mode bodies, integrate ghost drawing into body `_draw()` | 1e, 1d |
| 1g | Create CRT controller (shader uniforms + overlay toggles + hum bar scroll + noise scroll) | 1a, 1b, 1c |
| 1h | Wire CRT controller into AO scene | 1g |
| 1i | Test all 8 games — verify raster vs vector aesthetics | all above |
| 1j | Delete old CRT addon | 1i |

---

## Risks & Considerations

1. **WebGL shader compatibility** — The CRT shader must use only GLSL ES 2.0 features (no `dFdx`, no integer operations, no texture arrays). Test early in a browser. The shader uses `SCREEN_TEXTURE` with exactly 3 texture samples for chromatic aberration — this is ~10x fewer than the original and well within WebGL performance budget. No Gaussian multi-tap.

2. **Phosphor trail visual quality** — Pure `_draw()` ghosts may look "choppy" at low frame rates if position changes are large between frames. Mitigation: interpolate between stored positions, or increase ring buffer size. May need tuning per game.

3. **CRT overlay z-ordering** — The texture overlays and CRT shader ColorRect must draw ABOVE all game content (including Interface) but BELOW the BootScreen/GameOverScreen overlays. Verify z-index ordering in the AO scene tree.

4. **Rolling hum bar subtlety** — The hum bar should be barely noticeable (brightness ~0.03–0.05). Too strong and it becomes distracting during gameplay. Tunable via `roll_brightness` uniform.

---

## What Doesn't Change

- **`interface.gd`** — No modifications
- **Game scenes** — No modifications (phosphor_trail is an attached component)
- **`ArcadeGameEntry` resources** — No modifications
- **AO signal declarations** — Already exist
- **AO scoring/multiplier/lives logic** — Unchanged
- **Scrolling transition mechanics** — Unchanged