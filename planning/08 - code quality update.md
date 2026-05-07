# 08 — Code Quality Update

Full review of all scripts in `Godot/Scripts/`, organized by issue category.

---

## The Gold Standard

These files demonstrate the documentation convention the project should follow:

- **Bodies:** `ball.gd`, `brick.gd`, `paddle.gd`, `asteroid.gd`, `triangle_ship.gd`, `ufo.gd`
- **Brains:** `player_control.gd`, `interceptor_ai.gd`, `aim_ai.gd`, `patrol_ai.gd`, `shoot_ai.gd`
- **Arms:** `gun_simple.gd`, `damage_on_hit.gd`, `damage_on_joust.gd`
- **Components:** `health.gd`, `death_effect.gd`, `screen_wrap.gd`, `split_on_death.gd`, `angled_deflector.gd`, `paddle_ball_acceleration.gd`
- **Rules:** `group_monitor.gd`, `timer.gd`, `lives_counter.gd`

Each has: a top-of-file description, section headers for variable blocks, and comments on every function.

---

## 1. Excessive Comments (per-line commenting on every export/var)

These files comment every single export/variable instead of using section headers:

### `Legs/direct_movement.gd` (lines 5–11)
```gdscript
@export var speed: int = 600 # Pixels per second
@export var mouse_enabled: bool = true # Allow mouse following
@export var use_physics: bool = false # Use collision detection
var input: Vector2 # Movement direction from keyboard/joystick
var target: Vector2 # Mouse target position
var using_mouse: bool = false # Track input mode
```
**Fix:** Replace with section headers like `# Movement configuration` and `# Runtime state`. Variable names are already self-explanatory.

### `Legs/direct_acceleration.gd` (lines 5–10)
Same pattern — every line individually commented.

### `Legs/engine_simple.gd` (lines 5–10)
Same pattern.

### `Legs/friction_linear.gd` (lines 5–6)
Both exports individually commented.

### `Legs/friction_static.gd` (lines 5, 7)
Both the export and `@onready` individually commented.

### `Legs/rotation_direct.gd` (lines 5, 7–8)
Every line commented.

---

## 2. Uncommented Variable Blocks (≥3 lines, similar purpose)

### Legs

| File | Lines | What's Missing |
|------|-------|---------------|
| `grid_movement.gd` | 3–13 | 11 exports, no section headers |
| `grid_movement.gd` | 15–20 | 6 runtime vars, no section header |
| `grid_rotation.gd` | 3–6 | 4 exports, no section header |
| `rotation_target.gd` | 8–12 | 5 runtime vars, no section header |
| `tetromino_formation.gd` | 5–13 | 9 exports, no section header (only `# --- State ---` at line 15) |
| `tetromino_formation.gd` | 21–28 | 8 runtime vars under `# --- State ---` but could use sub-grouping |
| `warp_space_rocks.gd` | 3–4 | 2 exports (under threshold, but whole file has no variable comments) |

### Components

| File | Lines | What's Missing |
|------|-------|---------------|
| `screen_cleanup.gd` | 3–4, 6–8 | Exports and runtime vars, no section headers |
| `vector_engine_exhaust.gd` | 3–8 | 6 exports, no section header |
| `vector_engine_exhaust.gd` | 10–14 | 5 runtime vars, no section header |

### Rules

| File | Lines | What's Missing |
|------|-------|---------------|
| `goal.gd` | 5–8 | 4 exports, no section header |
| `group_monitor.gd` | 5–9 | 5 exports, no section header |
| `group_count_multiplier.gd` | 3 | 1 export — no comment at all |
| `line_clear_monitor.gd` | 3–5 | 3 exports, no section header |
| `line_clear_monitor.gd` | 11–15 | 5 runtime vars, no section header |
| `points_monitor.gd` | 3–6 | 4 exports, no section header |
| `variable_tuner.gd` | 3–8 | 6 exports, no section header |
| `variable_tuner_global.gd` | 3–10 | 8 exports, no section header |
| `wave_director.gd` | 6–9 | 4 exports, no section header |
| `wave_spawner.gd` | 3–13 | 11 exports with no top-level section header (has sub-headers at lines 15, 20, 29) |

### Flow

| File | Lines | What's Missing |
|------|-------|---------------|
| `beep.gd` | 3–4, 6–9 | 2 exports + 4 runtime vars, no section headers |
| `grid_basic.gd` | 3–5 | 3 exports, no section header |
| `music_ramping.gd` | 3–5 | 3 exports, no section header |
| `music_ramping.gd` | 7–13 | 7 runtime vars, no section header |
| `sfx_ramping.gd` | 3–11 | 9 exports, no section header |
| `sound_synth.gd` | 3–13 | 11 exports, no section header |
| `sound_synth.gd` | 31–36 | 6 runtime vars, no section header |
| `swarm_controller.gd` | 3–11 | 9 exports, no section header |
| `swarm_controller.gd` | 16–19 | 4 runtime vars, no section header |
| `tetromino_spawner.gd` | 3–6 | 4 exports, no section header |
| `tetromino_spawner.gd` | 18–21 | 4 runtime vars, no section header |

### Effects

| File | Lines | What's Missing |
|------|-------|---------------|
| `death_broken_triangle_ship.gd` | 3–7 | 5 exports, no section header |
| `death_broken_triangle_ship.gd` | 9–15 | 7 runtime vars, no section header |
| `death_particles.gd` | 3–5 | 3 exports, no section header |

---

## 3. Missing Top-of-File Descriptions

~23 files have no description comment before `extends`:

- `Legs/grid_movement.gd`
- `Legs/grid_rotation.gd`
- `Legs/warp_space_rocks.gd`
- `Components/screen_cleanup.gd`
- `Components/vector_engine_exhaust.gd`
- `Rules/group_count_multiplier.gd`
- `Rules/points_monitor.gd`
- `Rules/variable_tuner.gd`
- `Rules/variable_tuner_global.gd`
- `Rules/line_clear_monitor.gd`
- `Rules/wave_spawner.gd`
- `Flow/grid_basic.gd`
- `Flow/swarm_controller.gd`
- `Flow/tetromino_spawner.gd`
- `Flow/music_ramping.gd`
- `Flow/sfx_ramping.gd`
- `Flow/sound_synth.gd`
- `Flow/beep.gd`
- `Effects/death_broken_triangle_ship.gd`
- `Effects/death_particles.gd`
- `Legs/tetromino_formation.gd` — has `# Leg component, non-spatial` tacked onto `extends` line; should be a proper standalone comment

### Files with filename-only or boilerplate descriptions (not real descriptions):

- `Core/collision_group.gd` — says `# collision_group_resource.gd` (filename, also wrong filename)
- `Core/property_override.gd` — says `# property_override.gd` (just a filename)

### Files with too-minimal descriptions:

- `Flow/sound_on_hit.gd` — `# plays a sound on a hit` (lowercase, one-liner that doesn't explain signals listened)
- `Rules/wave_director.gd` — lowercase run-on sentence, inconsistent style

---

## 4. Missing Function-Level Comments

### Legs

| File | Undocumented Functions |
|------|----------------------|
| `grid_movement.gd` | All ~15 functions undocumented |
| `grid_rotation.gd` | All 4 functions undocumented |
| `tetromino_formation.gd` | Has section headers (`# --- Movement ---`, `# --- Rotation ---`, etc.) but individual functions lack comments |

### Components

| File | Undocumented Functions |
|------|----------------------|
| `screen_cleanup.gd` | 1 function undocumented |
| `vector_engine_exhaust.gd` | All 5 functions undocumented |

### Rules

| File | Undocumented Functions |
|------|----------------------|
| `group_count_multiplier.gd` | 1 function undocumented |
| `line_clear_monitor.gd` | All 6 functions undocumented |
| `points_monitor.gd` | All 3 functions undocumented |
| `variable_tuner.gd` | 1 function has boilerplate comment only (`# Called when the node enters the scene tree...`) |
| `variable_tuner_global.gd` | All 2 functions undocumented |
| `wave_spawner.gd` | All 4 functions undocumented |
| `goal.gd` | All 2 functions undocumented |

### Flow

| File | Undocumented Functions |
|------|----------------------|
| `beep.gd` | All 3 functions undocumented |
| `grid_basic.gd` | All ~12 functions undocumented |
| `music_ramping.gd` | All 3 functions undocumented |
| `sfx_ramping.gd` | All 3 functions undocumented |
| `sound_synth.gd` | Most functions undocumented (has some inline comments) |
| `swarm_controller.gd` | All 6 functions undocumented |
| `tetromino_spawner.gd` | All 9 functions undocumented |

### Effects

| File | Undocumented Functions |
|------|----------------------|
| `death_broken_triangle_ship.gd` | All 5 functions undocumented |
| `death_particles.gd` | All 4 functions undocumented |

---

## 5. Outdated / Misleading Comments

| File | Line | Issue |
|------|------|-------|
| `Core/collision_group.gd` | 1 | Says `# collision_group_resource.gd` but filename is `collision_group.gd` |
| `Core/property_override.gd` | 1 | Says `# property_override.gd` — just a filename, not documentation |
| `Rules/variable_tuner.gd` | 10 | `# Called when the node enters the scene tree for the first time.` — Godot boilerplate, not meaningful |
| `Flow/sound_on_hit.gd` | 7 | Same Godot boilerplate comment |
| `Flow/interface.gd` | 75 | `#i'll add this later` — informal TODO, should be `# TODO: implement timer display` |
| `Components/ring_spawner.gd` | 9 | `@export var brick_size` / `brick_health` — uses "brick" terminology but this is a generic ring spawner |

---

## 6. Uncommented Code Blocks (≥3 lines, similar purpose)

| File | Lines | Block Purpose |
|------|-------|--------------|
| `Rules/wave_spawner.gd` | 116–138 | Component attachment, property overrides, group assignment (~22 lines) |
| `Legs/grid_movement.gd` | 54–66 | `_try_step()` validation chain |
| `Legs/grid_movement.gd` | 118–129 | `_direction_to_step()` direction mapping |
| `Flow/grid_basic.gd` | 26–32 | Grid initialization loop |
| `Flow/swarm_controller.gd` | 62–68 | Edge detection loop |
| `Flow/swarm_controller.gd` | 70–73 | Bottom detection loop |
| `Flow/tetromino_spawner.gd` | 43–55 | Piece spawning and component attachment |
| `Flow/tetromino_spawner.gd` | 76–93 | Post-lock checks and defeat conditions |
| `Flow/sound_synth.gd` | 38–63 | Setup and player creation |
| `Flow/sound_synth.gd` | 65–86 | Process loop with dual modes |
| `Effects/death_broken_triangle_ship.gd` | 22–38 | Fragment initialization loop |
| `Rules/line_clear_monitor.gd` | 87–111 | Row collapse and shift logic |
| `Rules/goal.gd` | 13–28 | Score awarding + life effects |
| `Rules/variable_tuner_global.gd` | 19–30 | Group iteration and property adjustment |
| `Flow/sfx_ramping.gd` | 23–39 | Value mapping and synth update |

---

## 7. Format Issues

### Missing type hints on variables

| File | Line(s) | Issue |
|------|---------|-------|
| `Rules/wave_spawner.gd` | 21–25 | `grid_width`, `grid_height`, `grid_columns`, `grid_rows`, `grid_spacing` — all missing `: int` |
| `Effects/death_broken_triangle_ship.gd` | 15 | `var elapsed_time = 0.0` — missing `: float` |

### Missing type hints on function params/returns

| File | Function | Missing |
|------|----------|---------|
| `Legs/direct_acceleration.gd` | `_physics_process(delta)` | Missing `: float` |
| `Legs/engine_simple.gd` | `_physics_process(delta)` | Missing `: float` |
| `Legs/engine_complex.gd` | `_physics_process(delta)` | Missing `: float` |
| `Legs/friction_linear.gd` | `_physics_process(delta)` | Missing `: float` |
| `Legs/friction_static.gd` | `_physics_process(delta)` | Missing `: float` |
| `Legs/tetromino_formation.gd` | `_process(delta)` | Missing `: float` |
| `Legs/tetromino_formation.gd` | `_ready()`, `_on_move()`, `_on_thrust()`, `_on_shoot()` | Missing `-> void` |
| `Legs/grid_movement.gd` | `_ready()` | Missing `-> void` |
| `Legs/grid_rotation.gd` | All functions | Missing `-> void` |
| `Flow/grid_basic.gd` | `_ready()` | Missing `-> void` |
| `Rules/goal.gd` | `_ready()`, `_on_body_entered(_body)` | Missing return type and param type |
| `Flow/tetromino_spawner.gd` | `_spawn_next()` | Missing `-> void` |

### Declaration order

| File | Line(s) | Issue |
|------|---------|-------|
| `Arms/damage_on_joust.gd` | 8, 10–13 | `@export var tie_breaker: Tie` uses `Tie` enum before it's declared on line 10. Enum should come before exports. |
| `Legs/tetromino_formation.gd` | 1 | `# Leg component, non-spatial` comment on `extends` line instead of separate top description |

### Inconsistent base class usage

| File | Issue |
|------|-------|
| `Legs/friction_static.gd` | `extends Node2D` instead of `extends UniversalComponent`. Manually does `@onready var parent = get_parent()` instead of inheriting `parent`. Every other component uses UniversalComponent or UniversalComponent2D. |

### Commented-out debug code (should be removed)

| File | Lines | Count |
|------|-------|-------|
| `Legs/tetromino_formation.gd` | 146, 153, 158, 162, 169, 172, 176, 183, 190, 193 | **10** `#print()` lines |
| `Rules/wave_director.gd` | 28, 37, 43 | **3** `#print()` lines |
| `Rules/wave_spawner.gd` | 47, 69, 139 | **3** `#print()` lines |
| `Rules/timer.gd` | 28, 53, 64 | **3** `#print()` lines |
| `Components/screen_cleanup.gd` | 17 | **1** `#print()` line |
| `Flow/music_ramping.gd` | 50, 52 | **2** `#print()` lines |

**Total: ~22 commented-out debug prints** across 6 files. Remove entirely, or replace with `push_warning()` behind a debug flag if logging is needed.

### Style nits

| File | Line | Issue |
|------|------|-------|
| `Flow/beep.gd` | 3 | `@export var f: float = 160.0` — terrible variable name; should be `frequency` |
| `Effects/death_broken_triangle_ship.gd` | 6–7 | `spin_speed: float = 1` and `lifetime: float = 1` — should be `1.0` for float consistency |
| `Flow/interface.gd` | 75 | `#i'll add this later` — should be `# TODO: implement timer display` |
| `Rules/wave_spawner.gd` | 37 | `var expression: Expression` — should be `_expression` (private naming convention) |

---

## Scripts Needing the Most Work

Priority order by volume of issues:

1. **`Rules/wave_spawner.gd`** — No description, no section headers on exports, no function comments, 5 missing type hints, 3 debug prints (~156 lines)
2. **`Legs/tetromino_formation.gd`** — Weak description, 10 debug prints, missing type hints, no individual function comments (~261 lines)
3. **`Flow/grid_basic.gd`** — No description, no comments on any of ~12 public API functions (~100 lines)
4. **`Flow/swarm_controller.gd`** — No description, no variable headers, no function comments (~74 lines)
5. **`Flow/tetromino_spawner.gd`** — No description, no variable headers, no function comments (~106 lines)
6. **`Flow/sound_synth.gd`** — No description, no variable headers, no function comments (~157 lines)
7. **`Effects/death_broken_triangle_ship.gd`** — No description, no variable headers, no function comments, 1 missing type hint (~59 lines)
8. **`Legs/grid_movement.gd`** — No description, no section headers, no function comments (~164 lines)
9. **`Rules/line_clear_monitor.gd`** — No description, no section headers, no function comments (~112 lines)