# Marks

Marks are trigger zones built on `Area2D` that detect bodies entering/exiting and communicate
with the rest of the game through the **game bus** (zero-arg signals) and the **game blackboard**
(a `Dictionary` of shared state). They are the primary way a scene reacts to entities touching a
region of space.

All files in this folder are GDScript classes registered with `class_name`, so they appear in
Godot's "Add Node" dialog and can be subclassed directly.

| File | Class | Extends | Purpose |
| --- | --- | --- | --- |
| `cd_mark.gd` | `CDMark` | `Area2D` | Base mark. Detects enter/exit, emits signals on the game bus **and** the touching entity's bus, filters by group, auto-creates a collision shape, and can swap its shape at runtime. |
| `count_mark.gd` | `CountMark` | `CDMark` | Counts **unique** bodies and fires when a target count is reached. |
| `mobile_mark.gd` | `MobileMark` | `CDMark` | Follows a target entity via lerp (explicit `NodePath` or nearest-in-group). |
| `occupancy_mark.gd` | `OccupancyMark` | `CDMark` | Maintains a per-group occupancy counter and emits on every change. |
| `safe_zone_mark.gd` | `SafeZoneMark` | `CDMark` | Reports safe/unsafe state transitions for "is this region clear?" checks. |
| `timed_mark.gd` | `TimedMark` | `CDMark` | Times how long bodies stay inside; emits progress ticks and a completion signal. |

---

## Shared architecture (`CDMark`)

Every other mark extends `CDMark`, so understanding it first is essential.

### Ancestor lookup
On `_ready()`, a mark resolves its owning game controller:

```gdscript
@onready var game: CDGame = CDGame.find_ancestor(self)
```

A mark therefore **must** be a descendant of a `CDGame` node. All bus/blackboard access goes
through this `game` reference:

- `game.bus_emit(signal_name)` — fire a zero-arg signal on the game bus.
- `game.bus_connect(signal_name, callable)` — subscribe to a game-bus signal.
- `game.blackboard[key]` — read/write shared state (a `Dictionary`).
- `game.collision_matrix.configure(self)` — applied if `game.collision_matrix` is set.
- `game.group_registry.get_nearest(group, position)` — used by `MobileMark`.

### Collision shape
`_ensure_collision_shape()` runs in `_ready()`:
1. If the mark already has a `CollisionShape2D` child, that child is reused.
2. Otherwise a `CollisionShape2D` with a `CircleShape2D` (radius `shape_size`) is created and added automatically.

The chosen shape is stored in `_auto_shape` and can be swapped at runtime by listening for
signals (see "Listen Signals" below).

### The enter/exit flow — filter, then dispatch to an overrideable hook

`CDMark._ready()` connects Godot's `body_entered` / `body_exited` Area2D signals to
`_on_body_entered` / `_on_body_exited`, then (deferred) calls `_on_initialize()`.

The base handlers `_on_body_entered` / `_on_body_exited` are **final** in practice: they run the
group filter (`_passes_filter`) and then dispatch to the **overrideable** hooks
`_handle_body_entered(body)` / `_handle_body_exited(body)`:

```gdscript
func _on_body_entered(body: Node2D) -> void:
    if not _passes_filter(body):
        return
    _handle_body_entered(body)
```

The default `_handle_body_entered(body)` is where the base behavior lives:
1. Writes the body to `game.blackboard[entered_body_key]`.
2. Calls `_emit_enter(body)`.

`_emit_enter(body)` is an **emit-only helper** (no blackboard write) that fires every signal in
`on_entered` on the game bus and, if the body is a `CDEntity`, every signal in
`on_entered_entity` on **that entity's** bus. `_emit_exit(body)` mirrors it for the exit path.

> **Subclasses override `_handle_body_*`, not `_on_body_*`.** This is the key convention. A
> subclass picks one of three strategies:
>
> 1. **Replace base behavior** — override `_handle_body_entered` without calling `super`, and
>    don't call `_emit_enter`. Only your own signals fire (`OccupancyMark`, `SafeZoneMark`).
> 2. **Reuse base behavior via `super`** — override `_handle_body_entered` and call
>    `super._handle_body_entered(body)` first, then add your own logic (`CountMark`, `TimedMark`).
> 3. **Reuse base behavior via the emit helper** — override `_handle_body_entered` without
>    calling `super`, but do the blackboard write yourself and call `_emit_enter(body)` so the
>    base signals still fire (no current mark uses this; kept as a documented option).
>
> Because filtering is centralized in `_on_body_entered`, every override receives an
> already-filtered body and does **not** need to call `_passes_filter` itself.

### Signal / blackboard conventions used everywhere
- Every "emit" export is an `Array[StringName]`. Listing multiple signals fires all of them for
  the same event.
- All emitted bus signals are **zero-argument**. Data associated with an event is delivered
  through the blackboard, written immediately before emitting.
- Every blackboard key is an `@export StringName` with a sensible default, so a mark works
  out-of-the-box but can be repointed to avoid key collisions.

---

## `CDMark` reference (`cd_mark.gd`)

### Exports

| Export | Type | Default | Group | Meaning |
| --- | --- | --- | --- | --- |
| `groups` | `Array[StringName]` | `[]` | — | Godot groups the mark itself is added to in `_ready()`. |
| `shape_size` | `float` | `16.0` | — | Radius of the auto-created `CircleShape2D`. |
| `filter_groups` | `Array[StringName]` | `[]` | — | Body whitelist; empty means "allow all bodies." |
| `entered_body_key` | `StringName` | `&"mark_entered_body"` | Blackboard Keys | Key the entering body is written to. |
| `exited_body_key` | `StringName` | `&"mark_exited_body"` | Blackboard Keys | Key the exiting body is written to. |
| `shape_key` | `StringName` | `&"mark_shape"` | Blackboard Keys | Key read for runtime shape swaps. |
| `on_entered` | `Array[StringName]` | `[&"body_entered"]` | Emit Game Bus Signals | Game-bus signals fired on body enter. |
| `on_exited` | `Array[StringName]` | `[]` | Emit Game Bus Signals | Game-bus signals fired on body exit. |
| `on_entered_entity` | `Array[StringName]` | `[]` | Emit Entity Bus Signals | Signals fired on the entering entity's own bus. |
| `on_exited_entity` | `Array[StringName]` | `[]` | Emit Entity Bus Signals | Signals fired on the exiting entity's own bus. |
| `on_set_shape` | `Array[StringName]` | `[]` | Listen Signals | Game-bus signals that trigger a shape swap. |

### Runtime shape swap
In `_on_initialize()`, each signal in `on_set_shape` is connected to `_on_change_shape`, which
reads `game.blackboard[shape_key]` (expected to be a `Shape2D`) and assigns it to `_auto_shape`
when non-null.

### Helper functions subclasses use
- `_passes_filter(body) -> bool` — true if `filter_groups` is empty or `body` is in one of them.
- `_emit_enter(body)` / `_emit_exit(body)` — fire the game-bus and entity-bus signals only (no
  blackboard writes). Call these from an override that does its own blackboard write.
- `super._handle_body_entered(body)` / `super._handle_body_exited(body)` — run the full base
  behavior (blackboard write + emit helper).

---

## `CountMark` (`count_mark.gd`)

Counts **unique** bodies that enter; each body is counted at most once regardless of re-entry.
Useful for "collect N things" objectives.

### Exports

| Export | Type | Default | Group | Meaning |
| --- | --- | --- | --- | --- |
| `target_count` | `int` | `3` | — | Unique-body count required to fire completion. |
| `count_key` | `StringName` | `&"mark_count"` | Blackboard Keys | Current unique count. |
| `bodies_key` | `StringName` | `&"mark_bodies"` | Blackboard Keys | Array of tracked bodies, written when target reached. |
| `on_count_changed` | `Array[StringName]` | `[&"mark_count_changed"]` | Emit Signals | Fired on each new unique body. |
| `on_count_reached` | `Array[StringName]` | `[&"mark_count_reached"]` | Emit Signals | Fired once when `target_count` is met/exceeded. |

Inherits `CDMark`'s other exports (`filter_groups`, `on_entered`, `on_exited`, etc.).

### Behavior (strategy 2 — reuse base via super)
- `_handle_body_entered` **calls `super._handle_body_entered(body)`** first (so `entered_body_key`,
  `on_entered`, and `on_entered_entity` all fire), then dedups the body into `_tracked_bodies`,
  writes `count_key`, emits `on_count_changed`, and when the count crosses `target_count` it
  writes `bodies_key` (a duplicate of the tracked array) and emits `on_count_reached`.
- `_handle_body_exited` **calls `super._handle_body_exited(body)`** (base exit behavior fires)
  but **does not decrement the count** — once counted, a body stays counted.

---

## `MobileMark` (`mobile_mark.gd`)

A mark that moves to follow a target entity each physics frame. It does **not** override the
detection hooks, so it inherits `CDMark`'s full enter/exit behavior unchanged.

### Exports

| Export | Type | Default | Group | Meaning |
| --- | --- | --- | --- | --- |
| `follow_offset` | `Vector2` | `Vector2.ZERO` | — | Offset added to the target's global position. |
| `lerp_speed` | `float` | `10.0` | — | Lerp coefficient (higher = tighter follow). |
| `target_entity_path` | `NodePath` | `""` | Target | Explicit target node (must be a `CDEntity`). |
| `target_groups` | `Array[StringName]` | `[]` | Target | Groups to auto-acquire the nearest entity from. |

### Behavior
- `_on_initialize` calls `super._on_initialize()` and, if `target_entity_path` is set and points
  to a `CDEntity`, stores it in `_target`.
- `_physics_process` invalidates a freed `_target`, auto-acquires a new one via
  `game.group_registry.get_nearest(group, global_position)` (first non-null candidate across
  `target_groups`), and lerps `global_position` toward `target.global_position + follow_offset`
  using `lerp_speed * delta`.

---

## `OccupancyMark` (`occupancy_mark.gd`)

Keeps a running per-group body count and emits whenever any tracked group's count changes. Use
this to answer "how many of each kind of thing are in this region?"

### Exports

| Export | Type | Default | Group | Meaning |
| --- | --- | --- | --- | --- |
| `tracked_groups` | `Array[StringName]` | `[]` | — | Groups to count. Each gets its own counter. |
| `changed_group_key` | `StringName` | `&"mark_changed_group"` | Blackboard Keys | Name of the group whose count changed. |
| `changed_count_key` | `StringName` | `&"mark_changed_count"` | Blackboard Keys | New count for that group. |
| `on_occupancy_changed` | `Array[StringName]` | `[&"occupancy_changed"]` | Emit Signals | Fired on any tracked group's enter/exit. |

### Behavior (strategy 1 — replace base behavior)
- `_ready` calls `super._ready()` and pre-initializes `_counts[group] = 0` for every tracked group.
- `_handle_body_entered` / `_handle_body_exited` **do not call `super`** and **do not** fire the
  base `entered_body_key` / `on_entered` behavior — they only update counters. For each tracked
  group the body belongs to they bump the count (enter) or clamp-decrement it (exit, never below
  0), write `changed_group_key` + `changed_count_key`, and emit `on_occupancy_changed`.
- Public query: `get_count(group: StringName) -> int`.

---

## `SafeZoneMark` (`safe_zone_mark.gd`)

A boolean-ish "is this region clear?" sensor. It tracks a count of "unsafe" bodies and emits
only on **state transitions** (safe → unsafe, unsafe → safe). Designed for things like
trapdoor-spawn clearance checks.

### Exports

| Export | Type | Default | Group | Meaning |
| --- | --- | --- | --- | --- |
| `unsafe_groups` | `Array[StringName]` | `[&"enemies"]` | — | Groups whose presence makes the zone unsafe. |
| `on_zone_safe` | `Array[StringName]` | `[&"zone_safe"]` | Emit Signals | Fired on the unsafe → safe transition. |
| `on_zone_unsafe` | `Array[StringName]` | `[&"zone_unsafe"]` | Emit Signals | Fired on the safe → unsafe transition. |

### Behavior (strategy 1 — replace base behavior)
- `_handle_body_entered` / `_handle_body_exited` **do not call `super`** and **do not** fire base
  behavior. They only manage `_unsafe_count`.
- On enter: for the first matching unsafe group it captures `was_safe` (`_unsafe_count == 0`),
  increments `_unsafe_count`, emits `on_zone_unsafe` if it just transitioned from safe, and
  returns after the first matching group.
- On exit: decrements per matching group; when the count reaches `<= 0` it clamps to 0 and emits
  `on_zone_safe`.

---

## `TimedMark` (`timed_mark.gd`)

Measures how long bodies remain inside. Emits periodic progress ticks while occupied and a
completion signal once a configurable `hold_duration` is reached per body.

### Exports

| Export | Type | Default | Group | Meaning |
| --- | --- | --- | --- | --- |
| `hold_duration` | `float` | `3.0` | — | Seconds a body must stay inside to complete. |
| `tick_interval` | `float` | `0.5` | — | Seconds between progress signals (0 disables ticks). |
| `active_body_key` | `StringName` | `&"mark_active_body"` | Blackboard Keys | Body associated with the latest progress/complete/occupy. |
| `progress_fraction_key` | `StringName` | `&"mark_progress_fraction"` | Blackboard Keys | Fraction `elapsed / hold_duration` (0.0–1.0+). |
| `on_occupy` | `Array[StringName]` | `[&"mark_occupied"]` | Emit Signals | Fired when the first body enters an empty zone. |
| `on_progress` | `Array[StringName]` | `[&"mark_progress"]` | Emit Signals | Fired every `tick_interval` per body. |
| `on_complete` | `Array[StringName]` | `[&"mark_complete"]` | Emit Signals | Fired when a body's elapsed time reaches `hold_duration`. |
| `on_vacate` | `Array[StringName]` | `[&"mark_vacated"]` | Emit Signals | Fired when the last body leaves. |

### Behavior (strategy 2 — reuse base via super)
- State is two dictionaries keyed by body: `_occupants` (elapsed time) and `_tick_accumulators`.
- `_physics_process` advances each occupant's timer by `delta`:
  - Every `tick_interval` (when `tick_interval > 0`) it writes `active_body_key` and
    `progress_fraction_key` and emits `on_progress`.
  - When `elapsed >= hold_duration` it writes `active_body_key`, emits `on_complete`, and removes
    the body from tracking (so completion fires once per entry).
- `_handle_body_entered` **calls `super._handle_body_entered(body)`** (so `entered_body_key`,
  `on_entered`, and `on_entered_entity` all fire), then registers the body. If the zone was
  empty, it also writes `active_body_key` and emits `on_occupy`.
- `_handle_body_exited` **calls `super._handle_body_exited(body)`** (base exit behavior fires),
  removes the body from tracking, and emits `on_vacate` if the zone is now empty.

---

## How to use a mark in a scene

1. The mark must live somewhere under a `CDGame` node (the ancestor lookup happens in `_ready()`).
2. Add the mark node (e.g. `CountMark`) as a child where you want the trigger zone.
3. Optionally add your own `CollisionShape2D` child; otherwise one is auto-generated as a circle
   of radius `shape_size`.
4. Configure the inspector exports:
   - Use `filter_groups` to restrict which bodies count.
   - Pick which signals fire by editing the `Emit … Signals` arrays.
   - If multiple marks in a scene write the same default blackboard keys, change the keys to
     avoid collisions.
5. Have other nodes listen for the emitted game-bus signals (via `game.bus_connect`) and/or read
   the blackboard keys the mark writes.

---

## How to create a new mark

1. Create `your_mark.gd` in this folder.
2. Start from this skeleton, overriding the **`_handle_body_*` hooks** (not `_on_body_*`):

   ```gdscript
   ## YourMark
   ## One-line summary of what it detects and emits.

   class_name YourMark extends CDMark

   ## --- exports ---

   @export_group("Emit Signals")
   @export var on_your_event: Array[StringName] = [&"your_event"]

   ## --- body detection ---

   ## (describe what your override does and which base-reuse strategy you picked)
   func _handle_body_entered(body: Node2D) -> void:
       # Option A — replace base: do NOT call super, do NOT call _emit_enter.
       # Option B — reuse base via super:
       super._handle_body_entered(body)
       # Option C — reuse base via emit helper (call after your own blackboard write):
       # game.blackboard[entered_body_key] = body
       # _emit_enter(body)

       # your own logic, then emit on the game bus:
       for sig in on_your_event:
           game.bus_emit(sig)
   ```

3. Follow the existing conventions you can see in this folder:
   - Put exports in `@export_group` sections; group signal arrays under "Emit Signals" and
     blackboard keys under "Blackboard Keys".
   - Make every emitted bus signal **zero-arg**; deliver payloads through the blackboard, writing
     immediately before emitting.
   - Use `Array[StringName]` for every "signals to emit" export so one event can fire multiple.
   - Reuse `CDMark` helpers: `_emit_enter(body)` / `_emit_exit(body)`, `_passes_filter(body)` is
     already applied for you, `_auto_shape`, `game.blackboard`, `game.bus_emit(...)`.
4. **Pick a base-reuse strategy deliberately** and document it in the header comment:
   - **Replace base** (`OccupancyMark`, `SafeZoneMark`) — override `_handle_body_entered` without
     `super` and without `_emit_enter`; only your own signals fire.
   - **Reuse via `super`** (`CountMark`, `TimedMark`) — call `super._handle_body_entered(body)`
     first; base signals fire too.
   - **Reuse via emit helper** — do your own blackboard write then call `_emit_enter(body)`;
     base signals fire too. (No current mark uses this; it's a documented fallback.)
   - **Don't override detection** (`MobileMark`) — inherit the base behavior entirely.
5. Do **not** override `_on_body_entered` / `_on_body_exited` — those own the filter step and
   dispatch to your `_handle_body_*` hooks. Overriding them bypasses group filtering.
6. If you need per-frame logic, override `_physics_process(delta)` (see `MobileMark`,
   `TimedMark`); if you need deferred one-time setup, override `_on_initialize()` and call
   `super._on_initialize()` first (see `MobileMark`).
7. Register the class with `class_name` so it appears in the Add Node dialog.