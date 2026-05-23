# Plan 20: V2 Stage (Cue Cards, Goals, Interface)

## Overview

First consumers of CDGame's game bus. Stage components track game state (Cue Cards), trigger game transitions when conditions are met (Goals), and detect spatial events via trigger zones (Marks). No gameplay components are built — this update proves the game bus works end-to-end with a complete game flow: start → score → win/lose.

---

## V2 Convention: Configurable Signal Emissions

All non-infrastructure components have configurable signal emissions via array exports. The method determines the **data shape** (what arguments are passed). The export determines the **signal name** (what it's called on the bus). Defaults match the spec, but every game can rewire without code changes.

```gdscript
# LivesCard example (game bus = Dictionary-based, entity bus = native signals):
@export_group("Signal Emissions")
@export var on_lives_changed: Array[StringName] = [&"lives_changed"]
@export var on_lives_depleted: Array[StringName] = [&"lives_depleted"]

func _on_life_lost():
    current_lives -= 1
    for sig in on_lives_changed:
        game.bus_emit(sig, [current_lives])  # Dictionary bus: args as Array
    if current_lives <= 0:
        for sig in on_lives_depleted:
            game.bus_emit(sig)  # No args = empty Array default
```

This applies to ALL non-infrastructure components going forward, not just Stage.

---

## Changes to Plan 19 (Core Infrastructure)

All of the following changes are **already reflected in Plan 19**. Listed here for reference:

### CDGroupRegistry — `group_count_changed` Signal (Priority 5)
CDGroupRegistry proactively re-queries dirty groups and emits `group_count_changed(group_name: StringName, count: int)` when count actually changed. Empty `_process` when no groups are dirty — zero cost. Runs at Priority 5, before any gameplay logic.

This makes GroupCountCard unnecessary (see below). CDGroupRegistry is now the single source of truth for group counts, emitting on change instead of requiring polling.

### CDEnums — `GameResult` and `CountComparison`
Already included in Plan 19's CDEnums spec:

| Enum | Values | Used By |
|------|--------|---------|
| `GameResult` | `VICTORY`, `DEFEAT`, `DRAW` | CDGame.end_game(), Goals |
| `CountComparison` | `LESS_THAN`, `EQUAL_TO`, `GREATER_THAN`, `LESS_OR_EQUAL`, `GREATER_OR_EQUAL` | GroupCountGoal |

### CDGame — `end_game(result: GameResult)` and `reset_game()`
- `end_game()` now takes `GameResult` instead of `bool`. Emits `"game_over"` with `[result]` on the game bus.
- `reset_game()` emits `"game_reset"` on the game bus. All Cue Cards listen and reset internal state. Fully signal-driven — no method calls from CDGame to Cue Cards.

### CDComponent2D — Two-Phase Lifecycle
Components register signals in `_ready()` (Phase 1) and connect to signals in `_on_initialize()` (Phase 2, deferred). All Stage components follow this pattern.

---

## What Gets Built

### 0. CDCueCard (Base Class)
**Type:** Extends Control
**Purpose:** Shared base for all Cue Cards. Handles game bus access, label creation, reset signal connection, and priority setup.

```gdscript
class_name CDCueCard extends Control

@export var is_interface: bool = false

@onready var game: CDGame = CDGame.find_ancestor(self)

var _label: Label

func _ready():
    process_physics_priority = 70  # STAGE
    game.bus_connect(&"game_reset", _on_reset)
    if is_interface:
        _create_label()

func _create_label():
    _label = Label.new()
    add_child(_label)

func _update_label(text: String):
    if _label:
        _label.text = text

func _on_reset():
    push_warning("CDCueCard._on_reset() not overridden by %s" % name)
```

Each Cue Card overrides `_on_reset()` and calls `_update_label()` when state changes.

### 1. ScoreCard
**Type:** Extends CDCueCard
**Purpose:** Tracks score. Optionally applies multiplier from a MultiplierCard. Multiple ScoreCards can coexist for complex scoring setups.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `starting_score` | `int` | `0` | Score at game start / reset |
| `multiplier_card_path` | `NodePath` | `""` | Optional path to a MultiplierCard. Empty = raw score only. |
| `on_score_changed` | `Array[StringName]` | `[&"score_changed"]` | Signals emitted when score updates |

**Signal connections (Game Bus):**
- Listens: `"score_gained(amount: int)"` (default, configurable)

**Behavior:**
- On `"score_gained"`: if `multiplier_card_path` is set, reads `multiplier_card.current_multiplier` and applies it. Otherwise adds raw amount.
- Emits configured `on_score_changed` signals with `(new_score: int)`.
- On `"game_reset"`: resets to `starting_score`.

### 2. MultiplierCard
**Type:** Extends CDCueCard
**Purpose:** Tracks current score multiplier. ScoreCard reads this when applying points.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `starting_multiplier` | `float` | `1.0` | Multiplier at game start / reset |
| `on_multiplier_changed` | `Array[StringName]` | `[&"multiplier_changed"]` | Signals emitted when multiplier updates |

**Signal connections (Game Bus):**
- Listens: `"multiplier_set(mult: float)"` (default, configurable)

**Behavior:**
- On `"multiplier_set"`: updates `current_multiplier`, emits configured signals with `(new_mult: float)`.
- On `"game_reset"`: resets to `starting_multiplier`.
- Other components (e.g., controllers) can listen to `group_registry.group_count_changed` and emit `"multiplier_set"` to create dynamic multipliers — no direct dependency needed.

### 3. LivesCard
**Type:** Extends CDCueCard
**Purpose:** Tracks player lives.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `starting_lives` | `int` | `3` | Lives at game start / reset |
| `on_lives_changed` | `Array[StringName]` | `[&"lives_changed"]` | Signals emitted when count changes |
| `on_lives_depleted` | `Array[StringName]` | `[&"lives_depleted"]` | Signals emitted when count reaches 0 |

**Signal connections (Game Bus):**
- Listens: `"life_lost"`, `"life_gained"` (default, configurable)

**Behavior:**
- On `"life_lost"`: decrements. If 0, emits `on_lives_depleted`.
- On `"life_gained"`: increments.
- Always emits `on_lives_changed` with `(new_count: int)`.
- On `"game_reset"`: resets to `starting_lives`.

### 4. TimerCard
**Type:** Extends CDCueCard
**Purpose:** Tracks time counting up or down.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `mode` | `Enum { COUNT_UP, COUNT_DOWN }` | `COUNT_DOWN` | Direction |
| `starting_time` | `float` | `60.0` | Time at game start / reset |
| `tick_interval` | `float` | `1.0` | Seconds between `"timer_tick"` emissions |
| `on_timer_tick` | `Array[StringName]` | `[&"timer_tick"]` | Signals emitted at each interval |
| `on_timer_expired` | `Array[StringName]` | `[&"timer_expired"]` | Signals emitted when COUNT_DOWN reaches 0 |

**Signal connections (Game Bus):**
- Listens: `"timer_pause"`, `"timer_resume"`, `"timer_reset"` (default, configurable)

**Behavior:**
- Counts time in `_physics_process`. Emits `on_timer_tick` at `tick_interval` with `(current_time: float)`.
- If COUNT_DOWN reaches 0: emits `on_timer_expired`.
- Pause/resume toggles `_processing`.
- On `"game_reset"`: resets to `starting_time`.

### 5. WaveCard
**Type:** Extends CDCueCard
**Purpose:** Tracks current wave/level number. Acts as a **signal relay** — receives game events and re-emits wave-numbered signals for CDStageSpawner consumption. See Plan 23 (V2 Spawners) for the full relay pattern.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `starting_wave` | `int` | `1` | Wave at game start / reset |
| `advance_signal` | `StringName` | `&"wave_cleared"` | Game bus signal that advances the wave |
| `start_signal` | `StringName` | `&"game_play"` | Game bus signal that starts the first wave |
| `on_wave_start` | `Array[StringName]` | `[&"wave_start"]` | Emitted when a new wave begins (advances counter first). Args: `(wave_number: int)` |
| `on_wave_changed` | `Array[StringName]` | `[&"wave_changed"]` | Emitted whenever wave number changes. Args: `(new_wave: int)` |

**Signal connections (Game Bus):**
- Listens: `start_signal` (default `"game_play"`), `advance_signal` (default `"wave_cleared"`), `"wave_reset"`, `"game_reset"`

**Behavior:**
- On `start_signal` (e.g., `"game_play"`): increments `current_wave`, emits `on_wave_start` with `(current_wave)`, emits `on_wave_changed` with `(current_wave)`.
- On `advance_signal` (e.g., `"wave_cleared"` from GroupCountGoal): increments `current_wave`, emits `on_wave_start` with `(current_wave)`, emits `on_wave_changed` with `(current_wave)`.
- On `"wave_reset"`: resets to `starting_wave`.
- On `"game_reset"`: resets to `starting_wave`.

**Relay pattern (Plan 23 integration):**
```
CDGame emits "game_play" → WaveCard hears it → emits "wave_start(1)" → Spawners fire
GroupCountGoal emits "wave_cleared" → WaveCard hears it → emits "wave_start(2)" → Spawners fire again
```

**Independent wave cycles:** Multiple WaveCards with different signal names. WaveCard_A uses `on_wave_start = [&"asteroid_wave"]`, WaveCard_B uses `on_wave_start = [&"ufo_wave"]`. Each spawner subscribes to the relevant signal via its `trigger_signal` export.

---

### Goals (4)

Goals extend CDComponent2D (not CDCueCard — they're not data holders and they don't display). All have `component_category = STAGE` (Priority 70). All have configurable signal emissions. Goals contain **no persistent state** — pure condition checks that emit signals when met.

### 6. GroupCountGoal
**Type:** Extends CDComponent2D
**Purpose:** Triggers when group count matches a condition. Generalized from the old "GroupClearedGoal" — that's just `comparison = EQUAL_TO, target_count = 0`.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `target_groups` | `Array[StringName]` | `[&"enemies"]` | Which groups to watch |
| `comparison` | `CountComparison` | `EQUAL_TO` | How to compare observed count to target |
| `target_count` | `int` | `0` | Count to compare against |
| `require_all_groups` | `bool` | `true` | True = ALL groups must match. False = ANY group matches. |
| `on_condition_met` | `Array[StringName]` | `[&"game_end_victory"]` | Signals emitted on game bus when condition is met |

**Signal connections:**
- Listens: `game.group_registry.group_count_changed(group_name, count)` directly

**Behavior:**
- On group count change: check if `target_groups` match `comparison` against `target_count`.
- If `require_all_groups`: ALL target groups must satisfy the comparison.
- If not: ANY target group satisfying the comparison triggers.
- On match: emit all `on_condition_met` signals.
- Example uses: victory when enemies = 0, spawn reinforcements when enemies < 3, escalate when asteroids > 20.

### 7. ScoreThresholdGoal
**Type:** Extends CDComponent2D
**Purpose:** Triggers when score crosses a threshold.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `threshold` | `int` | `10000` | Score to compare against |
| `comparison` | `CountComparison` | `GREATER_OR_EQUAL` | How to compare |
| `on_condition_met` | `Array[StringName]` | `[&"game_end_victory"]` | Signals emitted when condition is met |

**Signal connections (Game Bus):**
- Listens: `"score_changed(new_score: int)"` (default, configurable)

**Behavior:**
- On score change: compare against threshold using `comparison`. On match, emit `on_condition_met`.

### 8. LivesDepletedGoal
**Type:** Extends CDComponent2D
**Purpose:** Triggers when lives reach 0. Pure relay.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `on_condition_met` | `Array[StringName]` | `[&"game_end_defeat"]` | Signals emitted when lives depleted |

**Signal connections (Game Bus):**
- Listens: `"lives_depleted"` (default, configurable)

**Behavior:**
- Direct relay. Hears `"lives_depleted"`, emits `on_condition_met`.

### 9. TimerExpiredGoal
**Type:** Extends CDComponent2D
**Purpose:** Triggers when timer expires.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `on_condition_met` | `Array[StringName]` | `[&"game_end_defeat"]` | Signals emitted when timer expires |

**Signal connections (Game Bus):**
- Listens: `"timer_expired"` (default, configurable)

**Behavior:**
- Direct relay. Hears `"timer_expired"`, emits `on_condition_met`.

---

### Marks (4)

Marks are spatial trigger zones that detect bodies and emit on the game bus. They fill the gap between physics collisions (CDEntity ↔ CDEntity via CollisionBuffer) and game state events (Cue Cards). Marks use Godot's native Area2D `body_entered`/`body_exited` signals — no collision buffer needed, since Area2D triggers are not physics-driven.

### 10. CDMark (Base Class)
**Type:** Extends Area2D
**Purpose:** Static trigger zone. Emits configurable signals on the game bus when bodies enter or exit.

```gdscript
class_name CDMark extends Area2D

@export_group("Configuration")
@export var shape_size: Vector2 = Vector2(32, 32)  # Auto-creates rect if no CollisionShape2D child
@export var filter_groups: Array[StringName] = []   # Empty = all bodies pass

@export_group("Signal Emissions")
@export var on_entered: Array[StringName] = [&"body_entered"]
@export var on_exited: Array[StringName] = []

@onready var game: CDGame = CDGame.find_ancestor(self)

func _ready():
    _ensure_collision_shape()
    body_entered.connect(_on_entered)
    body_exited.connect(_on_exited)

func _ensure_collision_shape():
    # Skip if editor-placed CollisionShape2D children exist
    for child in get_children():
        if child is CollisionShape2D:
            return
    var shape = CollisionShape2D.new()
    shape.shape = RectangleShape2D.new()
    shape.shape.size = shape_size
    add_child(shape)

func _on_entered(body):
    if _passes_filter(body):
        for sig in on_entered:
            game.bus_emit(sig, [body])

func _on_exited(body):
    if _passes_filter(body):
        for sig in on_exited:
            game.bus_emit(sig, [body])

func _passes_filter(body) -> bool:
    if filter_groups.is_empty():
        return true
    for g in filter_groups:
        if body.is_in_group(g):
            return true
    return false
```

**Shape configuration (two modes):**
- **Quick:** Set `shape_size` export → CDMark auto-creates a RectangleShape2D
- **Precise:** Place CollisionShape2D children in editor → any shape (circle, polygon, capsule). Auto-creation skipped.

**Collision filtering (two layers):**
- **Physics layer mask** (efficient, configured in editor): Area2D's `collision_mask` determines which physics layers the Mark detects
- **Group filter** (logical, configured as export): `filter_groups` provides additional filtering by entity group when multiple groups share a physics layer

**Example uses:**
- Pong left goal: `on_entered = [&"p2_scored"]`, mask = balls layer, full-height strip at left edge
- Pong right goal: `on_entered = [&"p1_scored"]`, mask = balls layer, full-height strip at right edge
- Bug Blaster bottom line: `on_entered = [&"invaders_reached_bottom"]`, mask = invaders layer
- Brick Breaker floor: `on_entered = [&"ball_lost"]`, mask = balls layer

**Note:** CDMark extends Area2D (not CDComponent2D) and does not participate in the two-phase lifecycle. It connects to the game bus directly in `_ready()` — no ordering issues since it only emits, never listens to other components' signals.

### 11. MobileMark
**Type:** Extends CDMark
**Purpose:** Mark that follows a target CDEntity. All CDMark emission behavior inherited — adds movement logic only.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `target_entity_path` | `NodePath` | `""` | Follow a specific entity by NodePath |
| `target_group` | `StringName` | `&""` | Follow nearest entity in this group |
| `follow_offset` | `Vector2` | `Vector2.ZERO` | Offset from target position |
| `lerp_speed` | `float` | `10.0` | Smoothing speed (0 = snap, higher = smoother) |

**Behavior:**
- `_physics_process`: resolves target, lerps toward `target.global_position + follow_offset`
- Two targeting modes (NodePath takes priority, group is fallback):
  - **NodePath:** Follows a specific entity (e.g., Pong: follow paddle_cannon_p1 for a moving goal)
  - **Group + nearest:** Follows closest entity in group (e.g., dynamic capture zone that tracks nearest player)
- If no target resolved, stays at current position (no movement)

**Example uses:**
- Moving goalposts that follow paddle entities
- Capture zone that tracks the leading player
- Kill barrier that follows a boss entity

### 12. CountMark
**Type:** Extends CDMark
**Purpose:** Emits after N distinct bodies have entered. Tracks unique bodies — a body entering, exiting, and re-entering only counts once. Resets on `"game_reset"`.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `target_count` | `int` | `3` | Number of unique bodies required to trigger |
| `on_count_changed` | `Array[StringName]` | `[&"mark_count_changed"]` | Signals emitted when unique count changes (args: `[current_count]`) |
| `on_count_reached` | `Array[StringName]` | `[&"mark_count_reached"]` | Signals emitted when target_count is reached (args: `[bodies_array]`) |

**Behavior:**
- Maintains internal `Array[CDEntity]` of unique bodies that have entered
- On `body_entered`: if body not already tracked, add to array. Emit `on_count_changed`. If count reaches `target_count`, emit `on_count_reached`.
- On `body_exited`: no effect on count (bodies remain tracked). Override this in subclass if exit-removal is desired.
- On `"game_reset"`: clear tracked bodies array.
- Inherits `filter_groups` and shape configuration from CDMark.

**Example uses:**
- "3 balls in zone → bonus round" (Brick Breaker variant)
- "5 enemies reach extraction point → wave complete" (Defender)
- "All targets tagged → mission complete" (Missile Command variant)

### 13. TimedMark
**Type:** Extends CDMark
**Purpose:** Emits while a body remains inside the zone for a configured duration. Tracks time per-body. Emits progress signals during occupation and a completion signal when duration is met.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `hold_duration` | `float` | `3.0` | Seconds a body must remain inside to trigger |
| `tick_interval` | `float` | `0.5` | Seconds between progress emissions |
| `on_occupy` | `Array[StringName]` | `[&"mark_occupied"]` | Emitted when first body enters (args: `[body]`) |
| `on_progress` | `Array[StringName]` | `[&"mark_progress"]` | Emitted at tick_interval while body inside (args: `[body, elapsed_fraction]`) |
| `on_complete` | `Array[StringName]` | `[&"mark_complete"]` | Emitted when a body has been inside for `hold_duration` (args: `[body]`) |
| `on_vacate` | `Array[StringName]` | `[&"mark_vacated"]` | Emitted when all bodies have exited (args: `[]`) |

**Behavior:**
- Maintains internal `Dictionary[CDEntity, float]` mapping each body inside to its elapsed time
- `_physics_process`: increments elapsed time for each tracked body. At each `tick_interval`, emits `on_progress` with `(body, elapsed / hold_duration)`. When `elapsed >= hold_duration`, emits `on_complete` and stops tracking that body.
- On `body_entered`: add to tracking dict. If first body, emit `on_occupy`.
- On `body_exited`: remove from tracking dict. If dict now empty, emit `on_vacate`.
- On `"game_reset"`: clear all tracking.
- Inherits `filter_groups` and shape configuration from CDMark.

**Example uses:**
- "Stand in zone for 3s to capture" (territory control)
- "Hold position to charge super attack" (Berzerk variant)
- "Dwell time detonator" — bomb explodes after entity stands on it (Bomberman variant)

---

## Implementation Order

All Plan 19 changes (CDEnums, CDGroupRegistry, CDGame, CDComponent2D two-phase lifecycle) are already implemented in Plan 19. This list covers only the new Stage components:

1. **CDCueCard** — Base class
2. **ScoreCard** — Simplest Cue Card with optional multiplier
3. **MultiplierCard** — Needed by ScoreCard tests
4. **LivesCard** — Same pattern, trivial
5. **WaveCard** — Signal relay with configurable advance/start signals (feeds CDStageSpawner in Plan 23)
6. **TimerCard** — Only Cue Card with `_physics_process` work
7. **CDMark** — Base class for all Marks (Area2D trigger zone)
8. **MobileMark** — Extends CDMark with entity-following
9. **CountMark** — Extends CDMark with unique body counting
10. **TimedMark** — Extends CDMark with dwell-time tracking
11. **GroupCountGoal** — Needed for proof test, exercises CDGroupRegistry signal
12. **LivesDepletedGoal** — Pure relay, trivial
13. **ScoreThresholdGoal** — Threshold comparison
14. **TimerExpiredGoal** — Pure relay

---

## Proof / Testing

### Test 1: Enemy Kill Flow (Game Bus + Goals)
A test scene proving complete game flow via Cue Cards + Goals:

- **CDGame** (root) with CDCollisionBuffer, CDGroupRegistry, CDCollisionMatrix
- **3 enemy CDEntities** in group `"enemies"` with Health
- **1 player CDEntity** with a gun that fires bullets
- **ScoreCard** (is_interface=true) tracking points per kill
- **MultiplierCard** set to 2.0× for testing
- **GroupCountGoal** watching `"enemies"` with `comparison=EQUAL_TO, target_count=0`
- **LivesCard** (is_interface=true) starting at 3

Flow: game starts → player shoots enemies → ScoreCard increments (×2) → last enemy dies → CDGroupRegistry emits count=0 → GroupCountGoal fires → game ends in victory → Interface shows final score.

### Test 2: Pong Goal Flow (CDMark + ScoreThresholdGoal)
A test scene proving spatial trigger → score → victory:

- **CDGame** (root) with CDCollisionBuffer, CDGroupRegistry, CDCollisionMatrix
- **CDMark_LeftGoal** at left edge: `on_entered = [&"p2_scored"]`, mask = balls layer
- **CDMark_RightGoal** at right edge: `on_entered = [&"p1_scored"]`, mask = balls layer
- **ScoreCard_P1** listening to `"p1_scored"` (is_interface=true)
- **ScoreCard_P2** listening to `"p2_scored"` (is_interface=true)
- **ScoreThresholdGoal_P1**: `threshold = 3, on_condition_met = [&"game_end_victory"]`
- **Ball CDEntity** that bounces between paddles

Flow: ball passes left goal → CDMark_LeftGoal emits `"p2_scored"` → ScoreCard_P2 increments → reaches threshold → ScoreThresholdGoal fires → game ends.

### Test 3: TimerCard Countdown
Secondary test: TimerCard counting down with TimerExpiredGoal triggering defeat.

---

## File Structure

```
Godot/Scripts/
├── Core/
│   ├── cdenums.gd               # Updated: GameResult, CountComparison
│   ├── cdgroupregistry.gd       # Updated: _process dirty flush, signal emission
│   └── cdgame.gd                # Updated: "game_reset" signal
├── Stage/
│   ├── cdcard.gd                # CDCueCard — base class for Cue Cards
│   ├── cdmark.gd                # CDMark — base class for Marks (Area2D trigger zones)
│   ├── score_card.gd            # ScoreCard
│   ├── multiplier_card.gd       # MultiplierCard
│   ├── lives_card.gd            # LivesCard
│   ├── timer_card.gd            # TimerCard
│   ├── wave_card.gd             # WaveCard
│   ├── mobile_mark.gd           # MobileMark — entity-following Mark
│   ├── count_mark.gd            # CountMark — N-body threshold Mark
│   ├── timed_mark.gd            # TimedMark — dwell-time Mark
│   ├── group_count_goal.gd      # GroupCountGoal
│   ├── score_threshold_goal.gd  # ScoreThresholdGoal
│   ├── lives_depleted_goal.gd   # LivesDepletedGoal
│   └── timer_expired_goal.gd    # TimerExpiredGoal
```

---

## Deferred to Later Updates

| Component | Deferred To | Reason |
|-----------|-------------|--------|
| GroupPropertyController | Update 3 (Spawners + Brains) | Modifies entity properties, needs entity component context |
| SwarmMovementController | Update 3 (Spawners + Brains) | Drives entity group movement, closely tied to spawning |
| SwarmShootingController | Update 3 (Spawners + Brains) | Selects entities to fire, needs formation/spawner context |
| MusicPlayer | Update 6 (Faces + Voices + Speakers) | Audio pipeline |
| MusicRampingController | Update 6 (Faces + Voices + Speakers) | Audio pipeline |
| CRTController | Update 6 (Faces + Voices + Speakers) | Visual pipeline |

---

## Risks & Open Questions

1. **TimerCard accuracy:** `_physics_process` timing depends on frame rate. For COUNT_DOWN games, a fixed timestep or `Engine.get_physics_frames()` counter may be more accurate. This can be refined during implementation.

2. **CDCueCard label styling:** Default labels will be bare. Per-game font/color customization can be done via Theme overrides on the Cue Card Control, or by replacing `_label` with a custom scene. This is a polish concern, not an architecture concern.

3. **Multiple ScoreCards:** The plan supports multiple ScoreCards (e.g., P1 score + P2 score in Pong). Each ScoreCard would listen to different signal names (`"p1_score_gained"` vs `"p2_score_gained"`), configured via array exports. The game bus naturally supports this since signal names are strings.