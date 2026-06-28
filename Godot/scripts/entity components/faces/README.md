# Faces — Entity Visual Components

`Faces` are `CDEntityComponent` scripts that handle an entity's **presentation** — what it looks like and what transient visuals it spawns. A face either **draws** (via Godot's `_draw()` / a child `Sprite2D`) or **spawns/despawns effect scenes** in response to entity signals.

This folder is **flat** (no subfolders). The 8 scripts fall into four functional groups, documented below.

Every script here extends `CDEntityComponent` (see `Godot/scripts/core/base classes/cd_entity_component.gd`). The faces that override `_ready()` set `component_category = CDEnums.ComponentCategory.VISUAL`.

---

## Base class contract (`CDEntityComponent`)

Faces rely on the following members provided by the base class. These are real, not assumed:

| Member | Provided by base | Notes |
|---|---|---|
| `entity: CDEntity` | cached ref | The parent entity. Resolved in `_ready()`; safe to use from `_on_initialize()` onward. |
| `game: CDGame` | cached ref | The ancestor game node. Resolved in `_ready()`. |
| `_on_initialize()` | virtual | Override to connect listen-signals, set the default frame, and create child nodes. Called once during activation. |
| `_on_entity_deactivating()` | virtual | Override to disconnect signals and free spawned effects. Base implementation calls `set_physics_process(false)`. |
| `_on_entity_activated()` | virtual | Override to re-enable processing when recycled from a pool. |
| `bus_connect(signal_name, callable)` | helper | Adds the user signal to `entity` if missing, connects it, and tracks the connection (for `CDBody` sleep/wake). |
| `bus_disconnect(signal_name, callable)` | helper | Disconnects and untracks. |
| `component_category` | export | Set to `VISUAL` by faces that override `_ready()`. |

The lifecycle is two-phase:
1. `_ready()` resolves `entity`/`game` refs, then `call_deferred("_initialize")`. (It returns early in the editor — `@tool` preview code lives in `_process()`/`_draw()` instead.)
2. `_initialize()` connects `entity_deactivating` / `entity_activated`, then calls `_on_initialize()`.

---

## At a glance

| File | Class | Extends | Group | Draws? | Input source |
|---|---|---|---|---|---|
| `vector_face.gd` | `VectorFace` | `CDEntityComponent` | Shape-drawing | `_draw()` polyline | `CDShape` frames + `CDFaceBinding` + blackboard `shape_key` |
| `polygon_face.gd` | `PolygonFace` | `CDEntityComponent` | Shape-drawing | `_draw()` filled polygon | `CDShape` frames + `CDFaceBinding` + blackboard `shape_key` |
| `menacing_vector_face.gd` | `MenacingVectorFace` | `VectorFace` | Shape-drawing | `_draw()` polyline + CRT FX | Inherits `VectorFace` + signal-triggered FX |
| `sprite_face.gd` | `SpriteFace` | `CDEntityComponent` | Texture-swap | Child `Sprite2D` | `Texture2D` frames + `CDFaceBinding` |
| `vector_engine_face.gd` | `VectorEngineFace` | `CDEntityComponent` | Flame | `_draw()` single flame | `thrust` / `thrust_end` signals |
| `vector_thruster_face.gd` | `VectorThrusterFace` | `CDEntityComponent` | Flame | `_draw()` 4 diagonal flames | blackboard `move_key` |
| `death_effect_face.gd` | `DeathEffectFace` | `CDEntityComponent` | Effect-spawning | No | death signals (`zero_health`, etc.) |
| `tractor_beam_face.gd` | `TractorBeamFace` | `CDEntityComponent` | Effect-spawning | No | `tractor_beam_windup` / `capture_missed` / `tractor_beam_complete` |

---

## Shape-drawing faces

### `VectorFace` — polyline from `CDShape`

Base class for vector-art entities. Draws an open or closed polyline from a `CDShape` resource.

| Feature | Details |
|---|---|
| `shapes: Array[CDShape]` | Frame list. Each `CDShape` has `points: PackedVector2Array` and `closed: bool` (`Godot/scripts/core/resources/behavior/cd_shape.gd`). |
| `default_frame: int` | Frame shown at rest and after a binding's restore timer. |
| `bindings: Array[CDFaceBinding]` | Signal → frame triggers (see *CDFaceBinding* below). |
| `color`, `width` | Line color and thickness in pixels. |
| `shape_key: StringName` (`"shape_points"`) | Blackboard key polled each frame; if the value differs from `_current_points`, it becomes the live geometry (forced `closed = true`). Lets other components morph the shape at runtime. |
| Editor preview | `@tool`; `_process()` calls `queue_redraw()` in editor; export setters call `queue_redraw()`. |

Drawing rule: if the current shape `closed == true`, the first point is appended to close the loop before `draw_polyline()`. Requires ≥ 2 points to draw.

### `PolygonFace` — filled polygon from `CDShape`

Mirror of `VectorFace` but draws a **filled** polygon (`draw_colored_polygon()`). Same exports (`shapes`, `default_frame`, `bindings`, `color`, `shape_key`) and the same binding/restore/blackboard-poll machinery.

Differences from `VectorFace`:
- No `width` export (filled, not stroked).
- No `closed` handling (polygons are always closed).
- Blackboard `shape_key` poll writes `_current_points` only (no `_current_closed`).
- Requires ≥ 3 points to draw.

### `MenacingVectorFace` — CRT menace effects

Extends `VectorFace` and overrides `_draw()` to add five independent, randomly-firing CRT-style effects **on top of the inherited polyline**:

| Effect | Toggles | What it does |
|---|---|---|
| Glitch | `glitch_enabled`, `glitch_chance`, `glitch_intensity`, `glitch_band_height` | Random horizontal band displacement — per-frame chance to activate, generates 1–4 horizontal slices; points inside a slice get an x-offset. |
| Static | `static_enabled`, `static_chance`, `static_density`, `static_size` | Random bright-pixel noise rectangles scattered across a 640×360 area. |
| Glow | `glow_enabled`, `glow_passes`, `glow_base_width`, `glow_intensity`, `glow_pulse_speed`, `glow_pulse_amount` | Multi-pass semi-transparent bloom around the polyline, pulsing on a sine wave. |
| Scan | `scan_enabled`, `scan_chance`, `scan_thickness`, `scan_brightness` | A horizontal sweep line that travels downward at 800 px/s once triggered. |
| Corrupt | `corrupt_enabled`, `corrupt_chance`, `corrupt_displacement` | Seeded vertex displacement + RGB channel swap (`Color(g, r, b*0.5, a)`). |

Signal-triggered flashes (`trigger_glitch`, `trigger_corrupt`, `trigger_static` — each `Array[StringName]`) force an immediate burst of the named effect via `_force_glitch()` / `_force_corrupt()` / `_force_static()`. These are connected in `_on_initialize()` (after `super._on_initialize()`) and disconnected in `_on_entity_deactivating()` (before `super`).

> Note: the static/scan effects assume a fixed 640×360 coordinate space (hardcoded in `_generate_static_particles()` and the scan-line rect).

---

## Texture-swap face

### `SpriteFace` — `Texture2D` frames via child `Sprite2D`

Creates a `Sprite2D` child in `_ready()` and swaps its `texture` between frames.

| Feature | Details |
|---|---|
| `frames: Array[Texture2D]` | Texture list. |
| `default_frame: int` | Frame shown at rest and after restore. |
| `bindings: Array[CDFaceBinding]` | Signal → frame triggers (see *CDFaceBinding* below). |
| `_sprite: Sprite2D` | Child node created in `_ready()`; texture set via `_show_frame(index)`. |
| Editor preview | `@tool`; export setters call `_show_frame(default_frame)` to refresh. |

`_show_frame()` guards against null `_sprite` and out-of-range indices.

---

## Flame faces

Both draw V-shaped flames using `draw_polyline()` and flicker the flame tip on a timer. Neither uses `CDFaceBinding` or `CDShape`.

### `VectorEngineFace` — single exhaust flame (signal-driven)

A single flame drawn behind the entity (pointing down the local +Y axis). Only draws while thrusting.

| Feature | Details |
|---|---|
| `flame_size`, `flame_width`, `flame_offset`, `color`, `line_width` | Geometry/style; all have `queue_redraw()` setters. |
| `flicker_speed`, `flicker_size` | Timer interval and max random tip-length variation. |
| `thrust_signal` (`"thrust"`), `end_thrust_signal` (`"thrust_end"`) | Connected in `_on_initialize()`; `_on_thrust()` sets `_is_thrusting = true` and `set_process(true)`; `_on_end_thrust()` reverses both. |
| Processing | `set_process(false)` until the first thrust; in editor, `_process()` calls `queue_redraw()` for preview. |

`_draw()` returns early if not thrusting and not in the editor. The flame is `[left, tip, right]` where `tip.y = flame_size + flame_offset + _tip_flicker`.

### `VectorThrusterFace` — four diagonal thrusters (blackboard-driven)

Draws an X of four flames along pre-normalized diagonals (`FLAME_DIRS`: UL, UR, LL, LR). Activates the flames **opposite** to the movement direction (push behavior).

| Feature | Details |
|---|---|
| `flame_size`, `flame_width`, `distance`, `color`, `line_width` | Geometry/style; all have `queue_redraw()` setters. |
| `flicker_speed`, `flicker_size` | Per-flame tip flicker. |
| `move_key: StringName` (`"move_direction"`) | Blackboard key polled each frame for the move direction. |
| Activation logic | Reads `_direction` from blackboard, rotates it into local space, then sets `_active[i]` per diagonal based on sign of `local_dir.x`/`local_dir.y` (threshold `0.1`). Zero direction → no flames. |
| Processing | `_on_initialize()` calls `set_process(true)`; editor preview draws all four flames. |

Each flame is `[left, tip, right]` where the base sits at `flame_dir * distance` and the tip extends further out along `flame_dir`.

---

## Effect-spawning faces

Neither of these implements `_draw()`. Both instantiate `PackedScene`s in response to signals and free them on cleanup.

### `DeathEffectFace` — spawn `CDEffect` scenes on death

| Feature | Details |
|---|---|
| `effect_scenes: Array[PackedScene]` | Effect scenes to spawn (all are instantiated on each death signal). |
| `inherit_position: bool` | Copy `entity.global_position` to each spawned effect. |
| `colors: Array[Color]` | If non-empty, overrides each effect's `.colors` palette. |
| `death_signals: Array[StringName]` (`["zero_health"]`) | Signals that trigger one spawn burst. |

On death: instantiates every scene in `effect_scenes`, optionally overrides `colors`, optionally sets `global_position`, and adds each to `game` (`game.add_child(effect)`). Cleans up by disconnecting in `_on_entity_deactivating()`.

> Assumes spawned scenes are/inherit `CDEffect` (it casts and sets `.colors` / `.global_position`).

### `TractorBeamFace` — spawn/despawn `TractorConeEffect`

Wraps a single active effect instance that lives for the duration of a tractor-beam action.

| Feature | Details |
|---|---|
| `effect_scene: PackedScene` | The cone effect scene (configured in inspector). |
| `windup_signals` (`["tractor_beam_windup"]`) | Spawn the effect and call `start_vacuum()` if present. |
| `miss_signals` (`["capture_missed"]`) / `complete_signals` (`["tractor_beam_complete"]`) | Stop the effect: call `stop_vacuum()` if present, then `queue_free()`. |

The effect is added **as a child of the face** (`add_child(_active_effect)`), not to `game`. Only one instance is live at a time (`_active_effect` guard). `_on_entity_deactivating()` frees any lingering instance before disconnecting.

> Assumes the spawned scene is/inherits `TractorConeEffect` and optionally exposes `start_vacuum()` / `stop_vacuum()`.

---

## Shared systems

### `CDFaceBinding` — signal → frame mapping

Used by `VectorFace`, `PolygonFace`, and `SpriteFace`. Resource defined at `Godot/scripts/core/resources/visuals/cd_face_binding.gd`:

```gdscript
class_name CDFaceBinding extends Resource
@export var signal_name: StringName = &""   # entity bus signal that triggers the frame change
@export var frame_index: int = 0            # frame to switch to
@export var restore_after: float = 0.0      # seconds before reverting to default (0 = permanent)
```

The three faces implement an identical binding handler:

```gdscript
func _on_initialize() -> void:
    for binding in bindings:
        self.bus_connect(binding.signal_name, _on_binding_signal.bind(binding))
    _update_frame()   # or _show_frame(default_frame) for SpriteFace
    queue_redraw()

func _on_binding_signal(binding: CDFaceBinding = null) -> void:
    if binding == null:
        return
    # switch to binding.frame_index (guarded against out-of-range)
    ...
    # schedule auto-restore if configured
    if binding.restore_after > 0.0:
        if _restore_timer != null and _restore_timer.time_left > 0.0:
            _restore_timer.timeout.disconnect(_on_restore)
        _restore_timer = get_tree().create_timer(binding.restore_after)
        _restore_timer.timeout.connect(_on_restore)

func _on_restore() -> void:
    # revert to default_frame
    ...

func _on_entity_deactivating() -> void:
    super._on_entity_deactivating()
    for binding in bindings:
        self.bus_disconnect(binding.signal_name, _on_binding_signal.bind(binding))
```

A single `_restore_timer: SceneTreeTimer` is shared; scheduling a new binding cancels any pending restore.

### Blackboard shape polling

`VectorFace` and `PolygonFace` poll `entity.blackboard.get(shape_key)` every frame in `_process()`. When the value changes, it becomes the live geometry and triggers a redraw. This lets a sibling component (e.g. a shape-collider or deformation guts) drive the face without signals.

### `@tool` editor preview

All five draw-based faces (`VectorFace`, `PolygonFace`, `MenacingVectorFace`, `VectorEngineFace`, `VectorThrusterFace`) plus the texture-swap `SpriteFace` are `@tool`. Their preview pattern:

- `_process()` checks `Engine.is_editor_hint()` and calls `queue_redraw()` (draw-based) or `_show_frame(default_frame)` (`SpriteFace`).
- Export setters call `queue_redraw()` (or `_show_frame()`) so inspector edits update live.

`DeathEffectFace` and `TractorBeamFace` are **not** `@tool` (they only react to runtime entity signals).

---

## Common patterns observed in these files

These recur across multiple files in this folder — use them as a reference, not a prescription invented for this doc.

### 1. Export grouping & `queue_redraw()` setters

Draw-based faces expose style as exports whose setters re-draw immediately:

```gdscript
@export var color: Color = Color.WHITE:
    set(v):
        color = v
        queue_redraw()
```

Listen-signals are grouped: `@export_group("Listen Signals")` followed by `Array[StringName]` defaults.

### 2. Listen via `self.bus_connect`, clean up in `_on_entity_deactivating()`

Every signal-driven face connects with the tracked helper and disconnects on deactivation:

```gdscript
func _on_initialize() -> void:
    for sig in death_signals:
        self.bus_connect(sig, _on_death)

func _on_entity_deactivating() -> void:
    super._on_entity_deactivating()
    for sig in death_signals:
        self.bus_disconnect(sig, _on_death)
```

`TractorBeamFace` additionally frees its live effect; `MenacingVectorFace` disconnects its FX triggers (before `super`).

### 3. Two input models

- **Signal-driven** (`VectorEngineFace`, effect-spawners, binding faces): connect in `_on_initialize()`, toggle state on signal.
- **Blackboard-driven** (`VectorThrusterFace`, shape polling in `VectorFace`/`PolygonFace`): poll `entity.blackboard.get(key, default)` each frame; the default yields "do nothing".

### 4. Effect lifecycle

Effect-spawning faces own their instances and free them on deactivation:
- `DeathEffectFace`: children of `game`, one burst per death signal.
- `TractorBeamFace`: single child of self, explicitly `queue_free()`d on end/deactivate.

---

## How to create a new face

Pick the group that matches what the face does, then follow the corresponding skeleton. **Only copy what you actually need** — every face here is a slimmed-down version of these ideas.

### A. Shape- or texture-swap face (uses `CDFaceBinding`)

```gdscript
@tool
## MyNewFace
## <one-line description>

class_name MyNewFace extends CDEntityComponent

@export var frames: Array[CDShape] = []:    # or Array[Texture2D] for a sprite face
    set(v):
        frames = v
        _update_frame()
        queue_redraw()

@export var default_frame: int = 0:
    set(v):
        default_frame = v
        _update_frame()
        queue_redraw()

@export var bindings: Array[CDFaceBinding] = []
@export var color: Color = Color.WHITE:
    set(v):
        color = v
        queue_redraw()

var _current_points: PackedVector2Array = []   # or _sprite: Sprite2D for texture faces
var _restore_timer: SceneTreeTimer

func _on_initialize() -> void:
    for binding in bindings:
        self.bus_connect(binding.signal_name, _on_binding_signal.bind(binding))
    _update_frame()
    queue_redraw()

func _on_binding_signal(binding: CDFaceBinding = null) -> void:
    if binding == null:
        return
    # switch to binding.frame_index (guard range)
    if binding.restore_after > 0.0:
        if _restore_timer != null and _restore_timer.time_left > 0.0:
            _restore_timer.timeout.disconnect(_on_restore)
        _restore_timer = get_tree().create_timer(binding.restore_after)
        _restore_timer.timeout.connect(_on_restore)

func _on_restore() -> void:
    _update_frame()
    queue_redraw()

func _on_entity_deactivating() -> void:
    super._on_entity_deactivating()
    for binding in bindings:
        self.bus_disconnect(binding.signal_name, _on_binding_signal.bind(binding))

func _update_frame() -> void:
    if not frames.is_empty() and default_frame >= 0 and default_frame < frames.size():
        _current_points = frames[default_frame].points

func _draw() -> void:
    if _current_points.size() < 2:
        return
    # ...draw using _current_points + color...
```

### B. Procedural draw face (flame / decoration)

```gdscript
@tool
## MyNewFace
## <one-line description>

class_name MyNewFace extends CDEntityComponent

@export var color: Color = Color.WHITE:
    set(v):
        color = v
        queue_redraw()
@export var flicker_speed: float = 0.1
@export var flicker_size: float = 2.0

@export_group("Listen Signals")
@export var activate_signal: StringName = &"activate"
@export var deactivate_signal: StringName = &"deactivate"

var _active: bool = false
var _timer: float = 0.0
var _tip: float = 0.0

func _ready() -> void:
    component_category = CDEnums.ComponentCategory.VISUAL
    super._ready()

func _on_initialize() -> void:
    self.bus_connect(activate_signal, _on_activate)
    self.bus_connect(deactivate_signal, _on_deactivate)
    set_process(false)

func _on_activate() -> void:
    _active = true
    set_process(true)

func _on_deactivate() -> void:
    _active = false
    set_process(false)
    queue_redraw()

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        queue_redraw()
        return
    _timer += delta
    if _timer > flicker_speed:
        _tip = randf_range(0.0, flicker_size)
        _timer = 0.0
    queue_redraw()

func _on_entity_deactivating() -> void:
    super._on_entity_deactivating()
    self.bus_disconnect(activate_signal, _on_activate)
    self.bus_disconnect(deactivate_signal, _on_deactivate)
    _active = false
    set_process(false)

func _draw() -> void:
    if not _active and not Engine.is_editor_hint():
        return
    # ...draw the decoration...
```

### C. Effect-spawning face

```gdscript
## MyNewFace
## <one-line description>

class_name MyNewFace extends CDEntityComponent

@export var effect_scene: PackedScene
@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"something"]
@export var end_signals: Array[StringName] = [&"something_else"]

var _active_effect: Node = null

func _ready() -> void:
    component_category = CDEnums.ComponentCategory.VISUAL
    super._ready()

func _on_initialize() -> void:
    for sig in trigger_signals:
        self.bus_connect(sig, _on_trigger)
    for sig in end_signals:
        self.bus_connect(sig, _on_end)

func _on_trigger() -> void:
    if _active_effect or not effect_scene:
        return
    _active_effect = effect_scene.instantiate()
    add_child(_active_effect)          # or game.add_child(...) for world-space effects

func _on_end() -> void:
    if not _active_effect:
        return
    _active_effect.queue_free()
    _active_effect = null

func _on_entity_deactivating() -> void:
    super._on_entity_deactivating()
    if _active_effect:
        _active_effect.queue_free()
        _active_effect = null
    for sig in trigger_signals:
        self.bus_disconnect(sig, _on_trigger)
    for sig in end_signals:
        self.bus_disconnect(sig, _on_end)
```

### Checklist for a new face

- [ ] Extend `CDEntityComponent` (or `VectorFace` if you want to inherit its `CDShape`/binding machinery).
- [ ] If it draws, add `@tool` and an editor-preview branch in `_process()` (`if Engine.is_editor_hint(): queue_redraw()`), plus `queue_redraw()` setters on style exports.
- [ ] Set `component_category = CDEnums.ComponentCategory.VISUAL` in `_ready()` (then `super._ready()`).
- [ ] Use `@export_group("Listen Signals")` with `Array[StringName]` defaults for signal triggers.
- [ ] Connect in `_on_initialize()` with `self.bus_connect(...)`; disconnect in `_on_entity_deactivating()` (call `super`).
- [ ] If it swaps frames, use `CDFaceBinding` + the shared `_on_binding_signal` / `_on_restore` / single `_restore_timer` pattern.
- [ ] If it spawns effect scenes, own the instance(s) and `queue_free()` them in both the end-handler and `_on_entity_deactivating()`.
- [ ] If it should morph at runtime without signals, poll `entity.blackboard.get(key, default)` in `_process()` and redraw on change.