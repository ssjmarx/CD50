# Projectors

Visual overlay components that render content on top of the running game. A "projector" listens for game bus signals and dynamically builds its visual output as child nodes at runtime.

## Contents

| File | Class | Base | Purpose |
|------|-------|------|---------|
| `cd_game_control.gd` | `CDGameControl` | `Control` | Base class for game-attached `Control`-rooted nodes — the `Control`-side twin of `CDGameComponent` (cached `game`, two-phase lifecycle, tracked bus connections) |
| `credit_projection.gd` | `CreditProjection` | `CDGameControl` | Floating "now playing" credit overlay showing track title/artist |
| `crt_projector.gd` | `CRTProjector` | `CDGameComponent` | Full-screen CRT post-processing pipeline (phosphor persistence, warp, scanlines, noise) |

---

## Shared patterns

All three scripts share a common contract for game-attached nodes, even though one extends `Control` and the other two reach it through different bases (`CDGameControl` extends `Control`; `CDGameComponent` extends `Node2D`). The contract comes from their base classes.

### The common lifecycle (from the bases)

Both `CDGameControl` and `CDGameComponent` provide the same shape:

1. **`_ready()`** — guard against the editor (`if Engine.is_editor_hint(): return`), set `process_physics_priority = 70`, and `call_deferred("_on_initialize")`.
2. **`_on_initialize()`** — the base resolves `game = CDGame.find_ancestor(self)` (and `push_warning` on `CDGameControl` if absent). Subclasses override this, call `super._on_initialize()` first, then do their setup.
3. **`_exit_tree()`** — the base **auto-disconnects every tracked bus connection** so subclasses don't need their own `_exit_tree` for bus cleanup.

### The common bus API (from the bases)

Both bases expose identical signal-tracking helpers:

- `bus_connect(signal_name, callable)` — connect to `game` and track it for auto-disconnect.
- `bus_disconnect(signal_name, callable)` — disconnect and untrack.
- `connect_all(signals: Array[StringName], callable)` — connect to every signal in the array (tracked).
- `disconnect_all(signals, callable)` — disconnect every signal in the array.

Because cleanup is centralized, **neither projector implements `_exit_tree`** for signal teardown — the base handles it. (`CRTProjector` explicitly notes this in a comment.)

### What projectors do on top of that

- **Listen for zero-arg game bus signals** via `connect_all(...)` and react by showing/hiding/updating their visuals.
- **Build their content dynamically** at runtime rather than from a pre-authored scene tree (`_show_credit` creates `Label` nodes; `_build_nodes` creates `BackBufferCopy`, `SubViewport`, `ColorRect`, and `TextureRect` nodes).
- **Clean up their own nodes/tweens** (kill tweens, `queue_free()` containers) — but bus cleanup is left to the base.

### Where the two projectors differ

| Concern | `CreditProjection` | `CRTProjector` |
|--------|--------------------|----------------|
| Base class | `extends CDGameControl` (→ `Control`) | `extends CDGameComponent` (→ `Node2D`) |
| `game` ref | Inherited from `CDGameControl` | Inherited from `CDGameComponent` |
| Bus wiring | Inherited `connect_all(track_changed_signals, _on_track_changed)` | Inherited `connect_all(on_crt_on, _on_crt_on)` / `connect_all(on_crt_off, _on_crt_off)` |
| `_exit_tree` | None needed (base auto-disconnects) | None needed (base auto-disconnects; noted in a comment) |
| Extra lifecycle | `_on_initialize` connects signals only | `_on_initialize` builds nodes, caches materials, connects signals, pushes params |

---

## `cd_game_control.gd` — `CDGameControl`

Base class for V2 game-attached nodes that **must extend `Control`** (UI overlays, projections). It mirrors the `CDGameComponent` contract — cached `game` reference, two-phase lifecycle, and tracked bus connections with auto-disconnect — so `Control`-rooted nodes get the same ergonomics as `Node2D`-rooted components.

```gdscript
class_name CDGameControl
extends Control
```

### Members

| Member | Type | Purpose |
|--------|------|---------|
| `game` | `CDGame` | Cached ancestor game node, resolved in `_on_initialize()`. |
| `_bus_connections` | `Array[Dictionary]` | Tracked connections (`{"signal_name", "callable"}`) for auto-disconnect. |

### Methods

- `_ready()` — editor guard, sets `process_physics_priority = 70`, defers `_on_initialize()`.
- `_on_initialize()` — resolves `game` via `CDGame.find_ancestor(self)`; `push_warning` if missing. **Override and call `super._on_initialize()` first.**
- `bus_connect(signal_name, callable)` — connect to `game` (adding the user signal if absent) and track it.
- `bus_disconnect(signal_name, callable)` — disconnect and untrack.
- `connect_all(signals, callable)` — connect every signal in an array (tracked).
- `disconnect_all(signals, callable)` — disconnect every signal in an array.
- `_exit_tree()` — iterates `_bus_connections` and disconnects each via `game.bus_disconnect(...)`.

---

## `credit_projection.gd` — `CreditProjection`

Floating overlay that shows the currently-playing music track's title and artist, then fades out.

### Declaration

```gdscript
class_name CreditProjection
extends CDGameControl
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

- `_on_initialize()` — calls `super._on_initialize()` (which resolves `game`), early-outs if `game` is missing, then `connect_all(track_changed_signals, _on_track_changed)`. No `_ready()` or `_exit_tree()` override is needed — both come from `CDGameControl`.

### Behavior

- `_on_track_changed()` — clears any existing credit, reads `game.blackboard.get(track_key, null)` as a `CDMusicTrack`, and if the track has a title or artist, calls `_show_credit(track)`.
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

1. `_on_initialize()` — sets `process_mode = PROCESS_MODE_ALWAYS`, `z_index = OVERLAY_Z` (`z_as_relative = false`), calls `_build_nodes()`, caches the materials, connects visibility signals via `connect_all(on_crt_on, _on_crt_on)` and `connect_all(on_crt_off, _on_crt_off)` (tracked for auto-disconnect), and pushes params if dirty.
2. **No `_exit_tree()` override.** Tracked bus connections are auto-disconnected by `CDGameComponent._exit_tree` (the script carries a comment stating this).
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

A projector is any component that listens for game bus signals and renders dynamic overlay content. Pick the base that matches your node type:

- **`CDGameComponent`** (`Node2D`-rooted) — for world-space overlays like `CRTProjector`.
- **`CDGameControl`** (`Control`-rooted) — for UI-space overlays like `CreditProjection`. Use this when you need `Control` layout anchors/offsets or the node must be a UI child.

Both bases give you the same lifecycle (`_on_initialize()` override + deferred init) and the same tracked bus API (`connect_all` / `bus_connect` with auto-disconnect on `_exit_tree`).

### Skeleton (`CDGameControl` version)

```gdscript
class_name MyProjector
extends CDGameControl

@export_group("Listen Signals")
@export var on_show: Array[StringName] = [&"my_projector_show"]

func _on_initialize() -> void:
    super._on_initialize()
    # game is now resolved by the base
    # build any nodes you need:
    _build_nodes()
    # connect signals (tracked — no _exit_tree needed for cleanup):
    connect_all(on_show, _on_show)

func _on_show() -> void:
    visible = true

func _build_nodes() -> void:
    # create child nodes that render your content
    pass
```

> If you instead extend `CDGameComponent`, the only difference is the base class line — the lifecycle and bus API are identical. (`CDGameComponent` also provides the category/lifecycle hooks used elsewhere in the project; see its README.)

### Checklist for a new projector

1. **Pick a base class.** `CDGameControl` for `Control`-rooted overlays; `CDGameComponent` for `Node2D`-rooted overlays. Both give you `_on_initialize()`, `game`, and tracked `connect_all`/`bus_connect`.
2. **Declare a `class_name`.** Every projector here exposes one (`CDGameControl`, `CreditProjection`, `CRTProjector`).
3. **Override `_on_initialize()` and call `super._on_initialize()` first**, then `connect_all(signals, handler)` to wire inputs. Do **not** write your own `_ready()` or `_exit_tree()` for bus teardown — the base handles both.
4. **Build content dynamically.** Create child nodes in a `_build_nodes()` / `_show_*()` style method rather than relying on a pre-authored tree.
5. **Use property setters + a `_params_dirty` flag** if you have many tunable visual parameters that must be pushed to a shader (see `CRTProjector`).
6. **Clean up your own nodes/tweens** (kill tweens, `queue_free()` runtime containers). Bus disconnection is handled by the base `_exit_tree()`.
7. **Document each export** with a leading `##` comment, matching the style used in these files.