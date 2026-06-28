# `formation/`

This folder contains `Resource` scripts used to **describe** formations and the movement orders that drive them. These are pure data/logic resources — they do not spawn nodes or move anything themselves. Other systems (e.g. the `FormationDirector` referenced in the comments of `CDFormation`) read these resources and apply them.

There are two distinct concepts here:

1. **`CDFormation`** — the static layout of a grid of slots.
2. **`CDMarchingOrder`** and its subclasses — a sequenced list of movement/breathing commands that animate a formation over time.

> Note: This documentation describes only what is actually implemented in the `.gd` files in this folder. Comments reference external systems such as `FormationDirector` and `CDEntity`, but those are **not** present here and are not part of this folder's scope.

---

## Files

| File | `class_name` | Base | `@tool` | Purpose |
|------|--------------|------|---------|---------|
| `cd_formation.gd` | `CDFormation` | `Resource` | Yes | Defines a sub-formation grid (dimensions, cell layout, offset, fill direction). |
| `cd_marching_order.gd` | `CDMarchingOrder` | `Resource` | No | Abstract base class for formation movement commands. |
| `marching_order_step.gd` | `MarchingOrderStep` | `CDMarchingOrder` | Yes | Moves the formation by a relative `offset` over `duration`. |
| `marching_order_pause.gd` | `MarchingOrderPause` | `CDMarchingOrder` | Yes | Holds the formation still for `duration` seconds. |
| `marching_order_breathe.gd` | `MarchingOrderBreathe` | `CDMarchingOrder` | Yes | Animates "breathing" (grid spacing and/or offset expansion) on a sine cycle. |
| `marching_order_repeat.gd` | `MarchingOrderRepeat` | `CDMarchingOrder` | Yes | Loops a list of sub-orders for a fixed total `duration`. |

---

## `CDFormation` — static grid layout

A `@tool` resource describing one tiered sub-formation grid. Per its header comment, it is "used by `FormationDirector` to manage multiple tiered formations in one scene."

### Exported properties

| Property | Type | Default | Notes |
|----------|------|---------|-------|
| `preferred_group` | `StringName` | `&""` | Group name for entities that should fill these slots. Empty = any unassigned entity can fill them. |
| `columns` | `int` | `10` | Grid width in cells. |
| `rows` | `int` | `5` | Grid height in cells. |
| `cell_size` | `Vector2` | `(16, 16)` | Size of each grid cell. |
| `cell_spacing` | `Vector2` | `(4, 4)` | Spacing between cells; base spacing, scaled by breathing. |
| `offset` | `Vector2` | `Vector2.ZERO` | Offset from the director's center position. |
| `fill_direction` | `Vector2` | `Vector2.ZERO` | Priority direction for slot assignment. `ZERO` = fill from the center outward by distance. |

### Runtime state

- `slots: Array` — flat array of length `columns * rows`. Each entry is `null` (empty) or an occupying entity (comments call this `CDEntity`).

### Methods

- `init_slots() -> void`
  Clears and resizes `slots` to `columns * rows`, filling every index with `null`. **Must be called before slots are used.**

- `get_slot_position(slot_index: int, center: Vector2, breathing_scale: float = 1.0) -> Vector2`
  World position of a slot, given the formation `center` and an optional breathing scale. Equals `center + offset + local_position`.

- `get_slot_position_local(slot_index: int, breathing_scale: float = 1.0) -> Vector2`
  Local position of a slot (`offset + local_position`), used for editor preview.

- `find_empty_slot() -> int`
  Returns the index of the best empty slot, or `-1` if none.
  - If `fill_direction == Vector2.ZERO`: scores slots by distance from the origin (closest first).
  - Otherwise: scores by `-pos.dot(fill_direction)` (slots furthest along the fill direction win).

### Internal layout math

`_calculate_local_position(slot_index, breathing_scale)` maps a flat index to a grid cell:

- `col = slot_index % columns`, `row = slot_index / columns`
- `step = cell_size + (cell_spacing * breathing_scale)`
- The grid is centered on the local origin, so column 0 / row 0 is at the top-left of a centered bounding box.

---

## `CDMarchingOrder` — movement command base class

The abstract base for all marching orders. It is **not** a `@tool` script (only the concrete subclasses are). It defines four methods that all return neutral defaults; subclasses override the ones they support.

### API

| Method | Default | Meaning |
|--------|---------|---------|
| `get_duration() -> float` | `0.0` | Total duration of this order, in seconds. |
| `get_offset_at_time(time: float) -> Vector2` | `Vector2.ZERO` | Absolute offset achieved at the given elapsed time. |
| `get_accumulated_offset() -> Vector2` | `Vector2.ZERO` | Final total offset when the order completes. |
| `get_breathing_values(time: float) -> Dictionary` | `{ "spacing_scale": 1.0, "offset_scale": 1.0 }` | Per-frame breathing data. Only breathing-aware subclasses override this. |

The `Dictionary` returned by `get_breathing_values` always uses these two keys:

- `"spacing_scale"` (`float`) — multiplier applied to `CDFormation.cell_spacing`.
- `"offset_scale"` (`float`) — multiplier applied to `CDFormation.offset` (distance from center).

---

## Concrete marching orders

All four subclasses are `@tool` resources so they can be edited and previewed in the inspector.

### `MarchingOrderStep`

Moves the formation by a relative offset over a duration. Motion is **linear** (clamped lerp from `0` to `offset`).

| Property | Type | Default |
|----------|------|---------|
| `offset` | `Vector2` | `Vector2.ZERO` |
| `duration` | `float` | `2.0` |

- `get_offset_at_time(time)`: returns `offset * clamp(time / duration, 0, 1)`.
- `get_accumulated_offset()`: returns `offset`.

### `MarchingOrderPause`

Holds the formation at its current position. Adds duration without adding motion.

| Property | Type | Default |
|----------|------|---------|
| `duration` | `float` | `1.0` |

Only overrides `get_duration()`. Offset methods inherit the base class's `Vector2.ZERO`.

### `MarchingOrderBreathe`

Animates the formation "breathing" — expanding and contracting — using a sine wave. Independent amplitudes control grid spacing vs. distance-from-center.

| Property | Type | Default | Group | Meaning |
|----------|------|---------|-------|---------|
| `spacing_amplitude` | `float` | `0.0` | "Spacing Breathing" | `0` = no breathing; `1.0` = spacing doubles at peak. |
| `spacing_duration` | `float` | `4.0` | "Spacing Breathing" | Seconds for one full breathe-in / breathe-out cycle. |
| `offset_amplitude` | `float` | `0.0` | "Offset Breathing" | Multiplier added to the `CDFormation.offset` expansion. |

- `get_duration()` returns `spacing_duration`.
- `get_breathing_values(time)`:
  - Returns neutral `{1.0, 1.0}` if `spacing_duration <= 0`.
  - Phase: `time / spacing_duration * TAU`.
  - Intensity: `(1.0 - cos(phase)) / 2.0` — a smooth `0 → 1 → 0` wave over one period.
  - `spacing_scale = 1.0 + intensity * spacing_amplitude`
  - `offset_scale = 1.0 + intensity * offset_amplitude`

### `MarchingOrderRepeat`

A **composite** order that loops through a list of sub-orders for a fixed total wall-clock `duration`. This is the pattern used for repeating movement (e.g. the classic back-and-forth march).

| Property | Type | Default |
|----------|------|---------|
| `duration` | `float` | `10.0` |
| `orders` | `Array[CDMarchingOrder]` | `[]` |

It is **loop-driven**: it computes the duration of one full pass over `orders`, then repeats that pass as many times as fit before its own `duration` expires.

- `get_duration()` returns its own `duration` (not the sum of sub-orders).
- `get_offset_at_time(time)`:
  1. Computes one loop's total duration and total offset by summing sub-orders.
  2. `loops_completed = int(time / loop_duration)`, `time_in_loop = fmod(time, loop_duration)`.
  3. Starts from `loop_offset * loops_completed`.
  4. Walks the sub-orders, adding each completed sub-order's accumulated offset, then the active sub-order's `get_offset_at_time` for the remainder.
- `get_accumulated_offset()` returns `get_offset_at_time(duration)` — i.e. wherever it ends up exactly when its own `duration` expires (which may be mid-loop).
- `get_breathing_values(time)` delegates to whichever sub-order is active at `fmod(time, loop_duration)`, returning neutral values if the list is empty.

> Because the accumulated offset is sampled at `duration`, a `Repeat` whose `duration` is not a whole multiple of its loop length will leave a partial offset behind. That is the documented/implemented behavior.

---

## How to use these resources

These resources are data objects. In practice you:

1. Create a `CDFormation` resource, set its grid dimensions / cell size / spacing / offset / fill direction, and call `init_slots()` at runtime before assigning entities.
2. Build one or more `CDMarchingOrder` resources (typically a `MarchingOrderRepeat` containing `Step` / `Pause` / `Breathe` children) to describe how the formation should move.
3. Hand both to whichever system drives formations. **That consumer is not in this folder** — `CDFormation`'s header comment names `FormationDirector`, but its implementation lives elsewhere. This folder only provides the data and the per-order evaluation math.

The evaluation helpers (`get_offset_at_time`, `get_breathing_values`, etc.) are pure functions of elapsed time, so they can be queried by any caller each frame.

---

## How to create a new marching order

The marching-order system is explicitly extensible. The base class header states: "Subclasses define specific behaviors (Step, Pause, Breathe, Repeat)."

To add a new order type:

1. **Create a new script** in this folder, e.g. `marching_order_<name>.gd`.
2. **Extend the base class**:
   ```gdscript
   @tool
   class_name MarchingOrder<Name> extends CDMarchingOrder
   ```
   Mark it `@tool` if you want it editable/previewable in the inspector (all four existing subclasses do).
3. **Add `@export` properties** for whatever parameters your order needs. Follow the existing convention of grouping related exports with `@export_group("...")` where appropriate (see `MarchingOrderBreathe`).
4. **Override the base methods your order actually supports.** You do not need to override all four — the existing orders show this:
   - `MarchingOrderPause` overrides only `get_duration()`.
   - `MarchingOrderStep` adds `get_offset_at_time` and `get_accumulated_offset`.
   - `MarchingOrderBreathe` overrides `get_duration` and `get_breathing_values`.
   - `MarchingOrderRepeat` overrides all four.
5. **Respect the method contracts** so composite orders (especially `MarchingOrderRepeat`) work correctly:
   - `get_duration()` must return the order's true length in seconds.
   - `get_offset_at_time(time)` must return the **absolute** offset at `time` (not a delta), with `time` clamped implicitly to `[0, duration]`.
   - `get_accumulated_offset()` must return the final offset at completion (normally equal to `get_offset_at_time(get_duration())`).
   - `get_breathing_values(time)` must return a `Dictionary` with exactly the keys `"spacing_scale"` and `"offset_scale"` (both `float`, `1.0` = no change). Return the neutral defaults if your order does not breathe.
6. **Handle edge cases defensively**, as the existing orders do:
   - Guard against `duration <= 0.0` before dividing.
   - Return neutral/zero values from empty states (e.g. `MarchingOrderRepeat` checks `orders.is_empty()`).

### Minimal template

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
