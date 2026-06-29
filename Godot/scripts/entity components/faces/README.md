# Faces — Entity Visual Components

`Faces` are `CDEntityComponent` scripts (category `VISUAL`) that handle an entity's **presentation**. A face either **draws** (via `_draw()` / a child `Sprite2D`) or **spawns/despawns effect scenes** in response to entity signals.

This folder is flat — no subfolders.

## Files

| File | Class | Pattern |
|------|-------|---------|
| `vector_face.gd` | `VectorFace` | Draws a polyline from a `CDShape` resource |
| `polygon_face.gd` | `PolygonFace` | Draws a filled polygon from a `CDShape` resource |
| `menacing_vector_face.gd` | `MenacingVectorFace` | Extends `VectorFace`, overlays CRT glitch/glow effects |
| `sprite_face.gd` | `SpriteFace` | Swaps a child `Sprite2D`'s `texture` between frames |
| `vector_engine_face.gd` | `VectorEngineFace` | Procedurally draws a single flame, signal-driven |
| `vector_thruster_face.gd` | `VectorThrusterFace` | Procedurally draws four diagonal flames, blackboard-driven |
| `death_effect_face.gd` | `DeathEffectFace` | Spawns effect scenes on death signals |
| `tractor_beam_face.gd` | `TractorBeamFace` | Spawns/despawns a single effect on tractor-beam signals |

---

## Patterns

### 1. Visual category
Faces that override `_ready()` set `component_category = CDEnums.ComponentCategory.VISUAL` before calling `super._ready()`.

### 2. Export grouping
Style exports use `queue_redraw()` setters so inspector edits update live:

```gdscript
@export var color: Color = Color.WHITE:
    set(v):
        color = v
        queue_redraw()
```

Listen-signals are grouped: `@export_group("Listen Signals")` with `Array[StringName]` defaults.

### 3. Editor preview (`@tool`)
Draw-based faces and `SpriteFace` are `@tool`. Their preview pattern:

```gdscript
func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        queue_redraw()        # or _show_frame(default_frame) for SpriteFace
        return
    ...
```

Effect-spawning faces are **not** `@tool`.

### 4. Signal binding (`CDFaceBinding`)
`VectorFace`, `PolygonFace`, and `SpriteFace` share a frame-swap pattern driven by `CDFaceBinding` resources (`Godot/scripts/core/resources/visuals/cd_face_binding.gd`):

```gdscript
@export var bindings: Array[CDFaceBinding] = []
```

Connect in `_on_initialize()`, switch to `binding.frame_index` on signal, optionally restore to `default_frame` after `binding.restore_after` seconds via a single shared `_restore_timer`.

### 5. Listen via `bus_connect`, clean up on deactivation
Signal-driven faces connect with the tracked helper and disconnect on deactivation:

```gdscript
func _on_initialize() -> void:
    for sig in death_signals:
        self.bus_connect(sig, _on_death)

func _on_entity_deactivating() -> void:
    super._on_entity_deactivating()
    for sig in death_signals:
        self.bus_disconnect(sig, _on_death)
```

### 6. Two input models
- **Signal-driven** (`VectorEngineFace`, effect-spawners, binding faces): connect in `_on_initialize()`, toggle state on signal.
- **Blackboard-driven** (`VectorThrusterFace`, shape polling in `VectorFace`/`PolygonFace`): poll `entity.blackboard.get(key, default)` each frame; the default yields "do nothing".

### 7. Effect lifecycle
Effect-spawning faces own their instances and free them on deactivation:
- `DeathEffectFace`: children of `game`, one burst per death signal.
- `TractorBeamFace`: single child of self, `queue_free()`d on end/deactivate.

---

## How to create a new face

Pick the matching group and copy only what you need.

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

### Checklist

- [ ] Extend `CDEntityComponent` (or `VectorFace` to inherit its `CDShape`/binding machinery).
- [ ] If it draws, add `@tool` and an editor-preview branch in `_process()` plus `queue_redraw()` setters.
- [ ] Set `component_category = CDEnums.ComponentCategory.VISUAL` in `_ready()` (then `super._ready()`).
- [ ] Use `@export_group("Listen Signals")` with `Array[StringName]` for signal triggers.
- [ ] Connect in `_on_initialize()` with `self.bus_connect(...)`; disconnect in `_on_entity_deactivating()` (call `super`).
- [ ] If it swaps frames, use `CDFaceBinding` + the shared restore-timer pattern.
- [ ] If it spawns effect scenes, own the instance(s) and `queue_free()` them on end and deactivation.
- [ ] If it morphs at runtime without signals, poll `entity.blackboard.get(key, default)` in `_process()`.