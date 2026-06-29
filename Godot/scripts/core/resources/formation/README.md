# Formation Resources

`Resource` scripts that **describe** formations and the movement orders that animate them. Pure data/logic — they spawn nothing and move nothing themselves; an external consumer (e.g. `FormationDirector`) reads them and applies them.

## Files

| Class | Base | `@tool` | Purpose |
|-------|------|---------|---------|
| `CDFormation` | `Resource` | Yes | Static tiered grid layout (dimensions, cell layout, offset, fill direction) |
| `CDMarchingOrder` | `Resource` | No | Abstract base for movement commands |
| `MarchingOrderStep` | `CDMarchingOrder` | Yes | Linear relative move over `duration` |
| `MarchingOrderPause` | `CDMarchingOrder` | Yes | Holds position for `duration` |
| `MarchingOrderBreathe` | `CDMarchingOrder` | Yes | Sine-wave "breathing" of spacing/offset |
| `MarchingOrderRepeat` | `CDMarchingOrder` | Yes | Composite loop over sub-orders for a fixed total `duration` |

---

## Patterns

### 1. Two resource concepts
- **`CDFormation`** — a static grid: `columns`/`rows`/`cell_size`/`cell_spacing`/`offset`/`fill_direction`, plus a `slots: Array` (length `columns*rows`, `null` or occupying entity). `init_slots()` must be called before use; `find_empty_slot()` picks the next slot by distance (`fill_direction == ZERO`) or by `-pos.dot(fill_direction)`.
- **`CDMarchingOrder`** — a time-sampled movement/breathing command, evaluated each frame by the consumer.

### 2. `CDMarchingOrder` contract (four methods)
All return neutral defaults in the base; subclasses override only what they support.

| Method | Default | Must return |
|--------|---------|-------------|
| `get_duration() -> float` | `0.0` | True length in seconds |
| `get_offset_at_time(time) -> Vector2` | `ZERO` | **Absolute** offset at `time` (clamped to `[0, duration]`) |
| `get_accumulated_offset() -> Vector2` | `ZERO` | Final offset at completion |
| `get_breathing_values(time) -> Dictionary` | `{ "spacing_scale": 1.0, "offset_scale": 1.0 }` | Dict with exactly those two float keys (`1.0` = no change) |

### 3. Override surface (existing orders show the pattern)
- `MarchingOrderPause` → only `get_duration()`.
- `MarchingOrderStep` → `get_duration` + `get_offset_at_time` + `get_accumulated_offset`.
- `MarchingOrderBreathe` → `get_duration` + `get_breathing_values`.
- `MarchingOrderRepeat` → all four (composite; samples active child via `fmod(time, loop_duration)`).

### 4. `@tool` concrete subclasses
Concrete marching orders are `@tool` so they can be edited/previewed in the inspector. `CDFormation` is `@tool` for the same reason.

### 5. Defensive math
Guard against `duration <= 0.0` before dividing; return neutral/zero values from empty states (e.g. `MarchingOrderRepeat` checks `orders.is_empty()`).

---

## How to create a new marching order

```gdscript
@tool
class_name MarchingOrderExample extends CDMarchingOrder

@export var duration: float = 1.0

func get_duration() -> float:
    return duration

func get_offset_at_time(time: float) -> Vector2:
    var t := 1.0
    if duration > 0.0:
        t = clamp(time / duration, 0.0, 1.0)
    # ...compute absolute offset as a function of t...
    return Vector2.ZERO

func get_accumulated_offset() -> Vector2:
    return get_offset_at_time(duration)

func get_breathing_values(_time: float) -> Dictionary:
    return { "spacing_scale": 1.0, "offset_scale": 1.0 }
```

### Checklist

- [ ] Filename `marching_order_<name>.gd`; `class_name MarchingOrder<Name> extends CDMarchingOrder`.
- [ ] Mark `@tool`.
- [ ] Add `@export` params; group related ones with `@export_group("...")`.
- [ ] Override only the base methods your order supports.
- [ ] `get_offset_at_time` returns the **absolute** offset (not a delta); `get_accumulated_offset` returns the offset at `duration`.
- [ ] `get_breathing_values` returns exactly `{"spacing_scale", "offset_scale"}`; neutral `{1.0, 1.0}` if it doesn't breathe.
- [ ] Guard `duration <= 0.0` before dividing; return neutral/zero from empty states.