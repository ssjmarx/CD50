# Projectors

Visual overlay components that render content on top of the running game. A "projector" listens for game bus signals and dynamically builds its visual output as child nodes at runtime.

## Contents

| File | Class | Base | Purpose |
|------|-------|------|---------|
| `credit_projection.gd` | `CreditProjection` | `Control` | Floating "now playing" credit overlay showing track title/artist |
| `crt_projector.gd` | `CRTProjector` | `CDGameComponent` | Full-screen CRT post-processing pipeline (phosphor persistence, warp, scanlines, noise) |

---

## Shared patterns

These two scripts demonstrate the projector contract used in this folder. They differ in their base class, so read carefully — they are **not** identical in how they wire up.

### Both scripts

- Listen for **zero-arg game bus signals** via `bus_connect(...)` and react by showing/hiding/updating their visuals.
- **Build their content dynamically** at runtime rather than from a pre-authored scene tree (`_show_credit` creates `Label` nodes; `_build_nodes` creates `BackBufferCopy`, `SubViewport`, `ColorRect`, and `TextureRect` nodes).
- Provide an `_on_initialize()` method used as the setup hook.
- Clean up after themselves — killing tweens / freeing containers, and disconnecting bus signals on exit.

### Where they differ

| Concern | `CreditProjection` | `CRTProjector` |
|--------|--------------------|----------------|
| Base class | `extends Control` | `extends CDGameComponent` |
| Game access | Calls `CDGame.find_ancestor(self)` and stores it in `_game` | Uses the inherited `game` property from `CDGameComponent` |
| Bus wiring | `_game.bus_connect(sig, callable)` | Bare `bus_connect(sig, callable)` (inherited) |
| Init trigger | `_ready()` → `call_deferred("_on_initialize")`, guarded by `Engine.is_editor_hint()` | `_on_initialize()` (invoked by the base class lifecycle) |
| Edit-time behavior | Explicitly skips processing in editor | Uses `PROCESS_MODE_ALWAYS`; sets `z_index` at init |

---

## `credit_projection.gd` — `CreditProjection`

Floating overlay that shows the currently-playing music track's title and artist, then fades out.

### Declaration

```gdscript
class_name CreditProjection
extends Control
```

### Exports

**General**
- `display_time: float = 5.0` — how long the credit stays fully visible before fading out.
- `font: Font` — font used for the title and artist labels.

**Blackboard Keys** (`@export_group("Blackboard Keys")`)
- `track_key: StringName = &"current_track"` — blackboard key to read the current `CDMusicTrack`.

**Listen Signals** (`@export_group("Listen Signals")`)
- `track_changed_signals: Array[StringName] = [&"track_changed"]` — zero-arg game bus signals that trigger the credit.

### Lifecycle

1. `_ready()` — bails out under `Engine.is_editor_hint()`; sets `process_physics_priority = 70`; defers `_on_initialize()`.
2. `_on_initialize()` — resolves the ancestor game via `CDGame.find_ancestor(self)`; if found, connects each signal in `track_changed_signals` to `_on_track_changed` using `_game.bus_connect(...)`.

### Behavior

- `_on_track_changed()` — clears any existing credit, reads `_game.blackboard.get(track_key, null)` as a `CDMusicTrack`, and if the track has a title or artist, calls `_show_credit(track)`.
- `_show_credit(track)` — builds a `Control` container, optionally adds a `TitleLabel` and `ArtistLabel` (each with a generated `LabelSettings` using the exported font, size 24, white text, black outline), and runs a Tween sequence:
  1. fade in (`modulate:a` → 1.0, 0.8s, `EASE_IN`)
  2. hold for `display_time`
  3. fade out (`modulate:a` → 0.0, 1.0s, `EASE_OUT`)
  4. callback to `_clear_credit`
- `_clear_credit()` — kills the active tween if valid, frees the container if it's valid, and nulls both references.

### Layout notes

Labels are positioned with `offset_left/top/right/bottom` using a `left_margin` of 16, `top_margin` starting at 16, and `line_height` of 20; `top_margin` advances after the title so the artist sits below it.

---

## `crt_projector.gd` — `CRTProjector`

Full-screen CRT post-processing pipeline. Constructs a node hierarchy at runtime that produces phosphor persistence, barrel warp, chromatic aberration, vignette, bloom, a rolling hum bar, flicker, brightness/gamma, plus tiled scanline and noise overlays.

### Declaration

```gdscript
class_name CRTProjector
extends CDGameComponent
```

### Constants

- `OVERLAY_Z: int = 4096` — z-index used for all overlay rendering so the CRT stack draws on top.

### Exports

All visual-effect exports use property setters that set `var _params_dirty: bool = true`, so changes are pushed to the shader on the next frame.

**CRT Effects** (`@export_group("CRT Effects")`)
- `warp: float` (0.0–0.3, default 0.1) — barrel distortion.
- `aberration: float` (0.0–10.0, default 0.75) — chromatic aberration offset.
- `vignette: float` (0.0–4.0, default 0.15) — edge darkening.
- `bloom_amount: float` (0.0–2.0, default 0.2) — bloom spread.
- `bloom_threshold: float` (0.0–2.0, default 0.5) — brightness threshold for bloom.
- `roll_brightness: float` (0.0–0.5, default 0.05) — rolling hum bar brightness.
- `flicker: float` (0.0–0.1, default 0.0025) — random brightness flicker.
- `brightness: float` (0.5–2.0, default 1.0) — overall brightness multiplier.
- `gamma: float` (0.5–3.0, default 1.2) — gamma correction curve.

**Persistence (Phosphor Decay)** (`@export_group("Persistence (Phosphor Decay)")`)
- `persistence_decay: float` (0.0–0.98, default 0.66) — phosphor trail fade rate (higher = longer trails).
- `persistence_blend: float` (0.0–1.0, default 0.22) — how much phosphor blends into the main image.

**Overlay Opacity** (`@export_group("Overlay Opacity")`)
- `scanline_overlay_opacity: float` (0.0–1.0, default 0.3) — scanline texture transparency.
- `noise_overlay_opacity: float` (0.0–1.0, default 0.1) — noise texture transparency.

**Animation** (`@export_group("Animation")`)
- `roll_speed: float = 0.02` — speed of the rolling hum bar.

**Listen Signals** (`@export_group("Listen Signals")`)
- `on_crt_on: Array[StringName] = [&"crt_on"]` — show the overlay.
- `on_crt_off: Array[StringName] = [&"crt_off"]` — hide the overlay.

### State (private)

- `_color_rect` — full-screen `ColorRect` with the CRT shader.
- `_scanlines_rect`, `_noise_rect` — tiled `TextureRect` overlays.
- `_material` — main CRT `ShaderMaterial`.
- `_persistence_vp` — `SubViewport` that accumulates previous frames for phosphor trails.
- `_persistence_rect` / `_persistence_mat` — `ColorRect` + `ShaderMaterial` inside the persistence viewport.
- `_params_dirty: bool` — flags that shader params need to be re-pushed.

### Lifecycle

1. `_on_initialize()` — sets `process_mode = PROCESS_MODE_ALWAYS`, `z_index = OVERLAY_Z` (relative off), calls `_build_nodes()`, caches the materials, connects `on_crt_on` → `_on_crt_on` and `on_crt_off` → `_on_crt_off` via inherited `bus_connect(...)`, and pushes params if dirty.
2. `_exit_tree()` — if `game` exists, disconnects every `on_crt_on` / `on_crt_off` signal via `game.bus_disconnect(...)`.
3. `_process(delta)` — if `_material` is missing, returns; otherwise pushes params if dirty; advances the `roll_y` shader parameter by `roll_speed * delta` (wrapped with `fmod`); and scrolls the noise overlay (x by `delta * 30`, y by `delta * 15`, both wrapped at 64).

### Runtime node hierarchy

`_build_nodes()` reads the viewport size from `get_viewport().get_visible_rect().size` and constructs, in order:

1. **`BackBufferCopy`** (`COPY_MODE_VIEWPORT`) — captures game content so `SCREEN_TEXTURE` is available.
2. **`PersistenceVP`** (`SubViewport`) — `CLEAR_MODE_NEVER`, `UPDATE_ALWAYS`, opaque; accumulates previous frames.
   - **`PersistenceAccumulator`** (`ColorRect`) — uses `res://shaders/persistence.gdshader`, with shader params `decay` (= `persistence_decay`) and `game_frame` (= the viewport texture).
3. **`CRTShader`** (`ColorRect`) — uses `res://shaders/crt_light.gdshader`, with shader params `resolution`, `persistence_blend`, and `persistence_tex` (the persistence viewport's texture).
4. **`ScanlinesOverlay`** (`TextureRect`) — texture `res://assets/crt/scanlines.png`, `STRETCH_TILE`, alpha = `scanline_overlay_opacity`.
5. **`NoiseOverlay`** (`TextureRect`) — texture `res://assets/crt/noise.png`, `STRETCH_TILE`, sized 704×424, alpha = `noise_overlay_opacity`; position is animated in `_process`.

Overlays are produced by `_create_overlay(...)`, which returns a fullscreen `TextureRect` at `OVERLAY_Z`, mouse-ignored, with `EXPAND_IGNORE_SIZE`.

### Parameter push

`_push_params()` writes every export to the matching shader parameter on `_material` and `_persistence_mat`, reassigns the persistence textures, and applies the overlay alphas. It is called from `_on_initialize()` and from `_process()` when `_params_dirty` is set.

---

## How to add a new projector

A projector is any component that listens for game bus signals and renders dynamic overlay content. Two valid shapes exist in this folder — pick the one that fits.

### Option A — extend `CDGameComponent` (like `CRTProjector`)

Use this when your projector is a managed game component and you want the inherited `game` reference, `bus_connect` / `bus_disconnect`, and the base `_on_initialize()` hook.

```gdscript
class_name MyProjector
extends CDGameComponent

@export_group("Listen Signals")
@export var on_show: Array[StringName] = [&"my_projector_show"]

func _on_initialize() -> void:
    z_index = OVERLAY_Z
    _build_nodes()
    for sig in on_show:
        bus_connect(sig, _on_show)

func _exit_tree() -> void:
    if game:
        for sig in on_show:
            game.bus_disconnect(sig, _on_show)

func _on_show() -> void:
    visible = true

func _build_nodes() -> void:
    # create child nodes that render your content
    pass
```

### Option B — extend `Control` directly (like `CreditProjection`)

Use this when you want a standalone `Control` that resolves its own game reference and defers initialization itself.

```gdscript
class_name MyProjector
extends Control

@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"my_projector_trigger"]

var _game: CDGame

func _ready() -> void:
    if Engine.is_editor_hint():
        return
    process_physics_priority = 70
    call_deferred("_on_initialize")

func _on_initialize() -> void:
    _game = CDGame.find_ancestor(self)
    if not _game:
        return
    for sig in trigger_signals:
        _game.bus_connect(sig, _on_triggered)

func _on_triggered() -> void:
    # read from _game.blackboard, build content, animate, etc.
    pass
```

### Checklist for a new projector

1. **Pick a base class.** `CDGameComponent` for managed components; `Control` for standalone.
2. **Declare a `class_name`.** Every projector here exposes one (`CreditProjection`, `CRTProjector`).
3. **Expose signals you react to** under an `@export_group("Listen Signals")` as `Array[StringName]`, and loop over them in `_on_initialize()` to connect.
4. **Build content dynamically.** Create child nodes in a `_build_nodes()` / `_show_*()` style method rather than relying on a pre-authored tree.
5. **Use property setters + a `_params_dirty` flag** if you have many tunable visual parameters that must be pushed to a shader (see `CRTProjector`).
6. **Clean up.** Kill tweens / `queue_free()` runtime nodes, and `bus_disconnect(...)` anything you connected in `_exit_tree()` (or equivalent).
7. **Document each export** with a leading `##` comment, matching the style used in these files.
8. **Edit-time safety.** If extending `Control` directly, guard `_ready()` with `Engine.is_editor_hint()`.