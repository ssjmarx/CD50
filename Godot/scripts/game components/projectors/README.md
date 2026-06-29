# Projectors — Visual Overlay Components

`Projectors` listen for game-bus signals and render content on top of the running game. They build their visual output **dynamically at runtime** as child nodes rather than from a pre-authored scene tree.

## Files

| File | Class | Base | Pattern |
|------|-------|------|---------|
| `cd_game_control.gd` | `CDGameControl` | `Control` | Base for `Control`-rooted game nodes — the `Control` twin of `CDGameComponent` (cached `game`, two-phase lifecycle, tracked bus connections) |
| `credit_projection.gd` | `CreditProjection` | `CDGameControl` | Floating "now playing" credit overlay (track title/artist) that fades in/out |
| `crt_projector.gd` | `CRTProjector` | `CDGameComponent` | Full-screen CRT post-processing pipeline (phosphor persistence, warp, scanlines, noise) |

---

## Patterns

### 1. Pick the base by node type
- **`CDGameControl`** (`Control`-rooted) — UI-space overlays (use when you need layout anchors/offsets or a UI child). See `CreditProjection`.
- **`CDGameComponent`** (`Node2D`-rooted) — world-space overlays. See `CRTProjector`.

Both bases give the same contract: cached `game`, two-phase lifecycle, tracked bus API.

### 2. The shared lifecycle (from the base)
1. **`_ready()`** — editor guard (`if Engine.is_editor_hint(): return`), set `process_physics_priority = 70`, `call_deferred("_on_initialize")`.
2. **`_on_initialize()`** — base resolves `game = CDGame.find_ancestor(self)` (and `push_warning` on `CDGameControl` if absent). Subclasses override, call `super._on_initialize()` first, then build nodes / connect signals.
3. **`_exit_tree()`** — base **auto-disconnects every tracked bus connection**. Subclasses don't implement `_exit_tree` for bus teardown.

### 3. The shared bus API (from the base)
- `bus_connect(signal_name, callable)` — connect to `game`, track for auto-disconnect.
- `bus_disconnect(signal_name, callable)` — disconnect and untrack.
- `connect_all(signals: Array[StringName], callable)` — connect every signal in an array (tracked).
- `disconnect_all(signals, callable)` — disconnect every signal in an array.

Because cleanup is centralized, **neither projector implements `_exit_tree`** for signal teardown.

### 4. Listen, then build dynamically
- Listen for **zero-arg game-bus signals** via `connect_all(...)` and react by showing/hiding/updating visuals.
- Build content dynamically (`_show_credit` creates `Label` nodes; `_build_nodes` creates `BackBufferCopy` / `SubViewport` / `ColorRect` / `TextureRect`).
- Clean up your own nodes/tweens (kill tweens, `queue_free()` runtime containers) — bus cleanup is the base's job.

### 5. Dirty-flag parameter push (`CRTProjector`)
When many tunable visual parameters feed a shader, give each export a property setter that sets `var _params_dirty: bool = true`. In `_process`, push params to the shader only when dirty.

---

## How to create a new projector

```gdscript
## MyProjector
## <one-line description>

class_name MyProjector extends CDGameControl   # or CDGameComponent

@export_group("Listen Signals")
@export var on_show: Array[StringName] = [&"my_projector_show"]

func _on_initialize() -> void:
    super._on_initialize()                     # game resolved by base
    _build_nodes()
    connect_all(on_show, _on_show)             # tracked — no _exit_tree needed

func _on_show() -> void:
    visible = true

func _build_nodes() -> void:
    pass   # create child nodes that render your content
```

> The only difference between the two bases is the `extends` line — the lifecycle and bus API are identical.

### Checklist

- [ ] Pick the base by node type: `CDGameControl` (`Control`) for UI overlays, `CDGameComponent` (`Node2D`) for world-space overlays.
- [ ] Declare a `class_name`.
- [ ] Override `_on_initialize()`, call `super._on_initialize()` first, then `connect_all(signals, handler)`.
- [ ] Do **not** write `_ready()` or `_exit_tree()` for bus teardown — the base handles both.
- [ ] Build content dynamically in a `_build_nodes()` / `_show_*()` method.
- [ ] Clean up your own nodes/tweens; leave bus disconnection to the base.
- [ ] For many shader parameters, use property setters + a `_params_dirty` flag (see `CRTProjector`).
- [ ] Document each export with a leading `##` comment.