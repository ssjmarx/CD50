# Visual Resources

1 resource class for face component sprite animation bindings.

---

## CDFaceBinding — Signal-to-Frame Binding

Pairs a signal name with a sprite frame index so face components can automatically switch frames in response to entity signals. Used by face components to build signal→frame lookup tables.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `signal_name` | `StringName` | &"" | Entity signal that triggers the frame change |
| `frame_index` | `int` | 0 | Sprite frame to switch to |
| `restore_after` | `float` | 0.0 | Seconds before reverting to default frame (0 = no restore) |

### Must-Includes

- Set `signal_name` to match an entity bus signal
- Set `frame_index` to the desired sprite frame
- Use `restore_after` for temporary expressions (hit flash, etc.), leave at 0 for permanent switches