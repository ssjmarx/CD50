# `resources/visuals/`

Data-only `Resource` classes that describe **visual configuration** for entity components. These scripts contain no scene-tree logic — they are pure data containers meant to be authored in the inspector and consumed by components at runtime.

## Files

### `cd_face_binding.gd` — `CDFaceBinding`

A `Resource` that pairs an **entity-bus signal** with a **sprite frame index**, plus an optional timed restore. It is the unit used to build signal→frame lookup tables on face components.

```gdscript
class_name CDFaceBinding extends Resource
```

**Exported properties**

| Property        | Type         | Default | Purpose                                                                 |
| --------------- | ------------ | ------- | ----------------------------------------------------------------------- |
| `signal_name`   | `StringName` | `&""`   | Entity-bus signal that triggers the frame change.                       |
| `frame_index`   | `int`        | `0`     | Sprite frame index to switch to when the signal is received.            |
| `restore_after` | `float`      | `0.0`   | Seconds before reverting to the default frame. `0.0` = permanent switch.|

## How it is used (observed in the codebase)

`CDFaceBinding` instances are stored as an exported array on the **face components** in `Godot/scripts/entity components/faces/`:

- `SpriteFace` (`sprite_face.gd`)
- `PolygonFace` (`polygon_face.gd`)
- `VectorFace` (`vector_face.gd`)

Each of these declares:

```gdscript
@export var bindings: Array[CDFaceBinding] = []
```

The consumption pattern (taken directly from `sprite_face.gd`) is:

1. **On initialize** — each binding's `signal_name` is connected on the entity bus, bound to the binding itself:
   ```gdscript
   func _on_initialize() -> void:
       for binding in bindings:
           self.bus_connect(binding.signal_name, _on_binding_signal.bind(binding))
   ```
2. **On signal** — the handler switches to the binding's frame and, if `restore_after > 0.0`, schedules a `SceneTreeTimer` that restores the component's `default_frame`:
   ```gdscript
   func _on_binding_signal(binding: CDFaceBinding = null):
       if binding == null:
           return
       _show_frame(binding.frame_index)
       if binding.restore_after > 0.0:
           ...
           _restore_timer = get_tree().create_timer(binding.restore_after)
           _restore_timer.timeout.connect(_on_restore)
   ```
3. **On deactivate** — the same bindings are disconnected from the bus.

So a `CDFaceBinding` is a self-contained rule: *"when this bus signal fires, show this frame, and (optionally) snap back to the default frame after N seconds."*

## How to use `CDFaceBinding`

1. Select a face component node (`SpriteFace`, `PolygonFace`, or `VectorFace`) in a scene.
2. In the inspector, locate the **Bindings** array (`bindings`).
3. Add a new element and create a **New CDFaceBinding**.
4. Fill in:
   - **Signal Name** — the exact `StringName` the entity bus emits (must match what some other component on the entity emits).
   - **Frame Index** — which entry of the component's `frames`/shape array to display.
   - **Restore After** — `0.0` for a permanent switch, or a positive number of seconds to auto-revert.

Multiple bindings can be added; each maps its own signal to its own frame.

## How to add a new `visuals` resource script

This folder is for **data resources only**. To add a new one, follow the shape of `cd_face_binding.gd`:

1. Create a new `.gd` file in this folder (`Godot/scripts/core/resources/visuals/`).
2. Declare it as a `Resource` subclass with a `class_name`:
   ```gdscript
   class_name CDYourVisualThing extends Resource
   ```
3. Expose all configurable fields as `@export` vars with sensible defaults so they can be authored purely in the inspector:
   ```gdscript
   @export var something: int = 0
   ```
4. **Do not** add `_ready()`, `_process()`, or any node/scene-tree logic. These resources are pure data; behavior belongs in the component that consumes them.
5. Keep the leading doc comment (the `##` lines at the top of the file) updated — it is the in-editor description of the resource.

The contract for anything in this folder is: *data in, data out — no side effects, no scene access.*