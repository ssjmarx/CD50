# Marks — Spatial Detection Zones

6 mark components that are Area2D-based spatial triggers. The base `CDMark` handles collision shape creation, body enter/exit detection, and group filtering. Specialized marks extend it for counting, tracking, timing, and movement.

---

## Common Mark Pattern

```
CDMark (base)
  _ready()           → _ensure_collision_shape(), connect body_entered/body_exited
  _on_initialize()   → connect listen signals to game bus
  _on_body_entered() → filter by group, emit on_entered signals
  _on_body_exited()  → filter by group, emit on_exited signals
  _passes_filter()   → check body against filter_groups (empty = allow all)
```

### Must-Includes When Creating Marks

1. Extend `CDMark` (or another mark that extends CDMark)
2. Override `_on_body_entered()` and/or `_on_body_exited()` for custom behavior
3. Call `_passes_filter(body)` before processing to respect group filtering
4. Use `@export_group("Emit Signals")` for game bus emissions
5. Emit via `game.bus_emit(sig, [args])` — always wrap args in array

### CDMark Inherited API

| API | Purpose |
|-----|---------|
| `_passes_filter(body)` | Returns true if body matches `filter_groups` (empty = allow all) |
| `_ensure_collision_shape()` | Auto-creates a CircleShape2D if no CollisionShape2D child exists |
| `on_entered` / `on_exited` | Base emit signal arrays |
| `filter_groups` | Group whitelist for body filtering |
| `shape_size` | Radius for auto-created collision shape |
| `on_set_shape` | Listen signal to swap the collision shape at runtime |

### Key Dependencies

| Dependency | Purpose |
|------------|---------|
| `CDGame` | Found via `CDGame.find_ancestor()` — provides bus and group registry |
| `CDEntity` | Bodies are typically CDEntity instances |
| `game.group_registry` | Used by MobileMark and others to find entities by group |

---

## Components

### CDMark — Base Area2D Mark

Foundation for all marks. Auto-creates a collision shape, detects body enter/exit, filters by groups, and emits signals on the game bus.

| Feature | Details |
|---------|---------|
| **Detection** | Area2D `body_entered` / `body_exited` |
| **Shape** | Auto-creates CircleShape2D if no child CollisionShape2D exists |
| **Filtering** | `filter_groups` whitelist (empty = allow all bodies) |
| **Runtime shape swap** | `on_set_shape` listen signal replaces the collision shape |

### CountMark — Unique Body Counter

Tracks unique bodies that enter the zone. Emits count changes and a signal when the target count is reached.

| Feature | Details |
|---------|---------|
| **Tracking** | Deduplicates bodies — each body counted only once |
| **Emit** | `on_count_changed(current_count)`, `on_count_reached([tracked_bodies])` |
| **Override** | Replaces CDMark's enter/exit handlers entirely |

### MobileMark — Following Mark

Follows a target entity with lerp-based smooth movement. Can lock to a specific entity via NodePath or auto-acquire the nearest entity from groups.

| Feature | Details |
|---------|---------|
| **Targeting** | NodePath (explicit) or `target_groups` (nearest auto-acquire) |
| **Movement** | Lerp toward `target.global_position + follow_offset` |
| **Reacquire** | Automatically finds new target if current becomes invalid |

### OccupancyMark — Per-Group Occupancy Counter

Maintains a running count of bodies inside the zone, broken down by tracked group. Emits on every change.

| Feature | Details |
|---------|---------|
| **Tracking** | Per-group count dictionary |
| **Emit** | `on_occupancy_changed(group_name, current_count)` |
| **API** | `get_count(group)` returns current occupancy for a group |
| **Override** | Replaces CDMark's enter/exit handlers entirely |

### SafeZoneMark — Spawn Safety Monitor

Tracks whether the zone is "safe" (no unsafe bodies inside) or "unsafe". Used by trapdoors to delay spawning until the area is clear.

| Feature | Details |
|---------|---------|
| **Unsafe groups** | Bodies in `unsafe_groups` increment the unsafe counter |
| **Emit** | `on_zone_safe` when counter drops to 0, `on_zone_unsafe` on first unsafe body |
| **Override** | Replaces CDMark's enter/exit handlers entirely |

### TimedMark — Duration-Based Trigger

Tracks how long bodies remain inside the zone. Emits progress ticks during the hold and a completion signal when the duration is met.

| Feature | Details |
|---------|---------|
| **Tracking** | Per-body elapsed time and tick accumulator |
| **Emit** | `on_occupy(body)`, `on_progress(body, fraction)`, `on_complete(body)`, `on_vacate()` |
| **Tick** | Configurable `tick_interval` for progress updates |
| **Completion** | Bodies removed from tracking after hold duration is met |