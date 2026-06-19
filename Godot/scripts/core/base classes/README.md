# Core Base Classes

Four base classes that every V2 component extends. These are not game components — they define the lifecycle, reference resolution, and processing priority that all components inherit.

| Base Class | Extends | Attached To | Has Entity Ref | Has Game Ref |
|------------|---------|-------------|----------------|--------------|
| `CDEntityComponent` | Node2D | CDEntity | Yes | Yes |
| `CDGameComponent` | Node2D | CDGame | No | Yes |
| `CDCueCard` | Control | CDGame | No | Yes |
| `CDStageTrapdoor` | CDGameComponent | CDGame | No | Yes |

---

## CDEntityComponent — Entity Components

**Use when:** Your component lives as a child of a CDEntity (Brains, Legs, Arms, Guts, Faces, Voices).

### Two-Phase Lifecycle

**Phase 1 (`_ready`):** Resolves `entity` and `game` references, sets `process_physics_priority` from `component_category`. Does NOT connect signals — siblings may not exist yet.

**Phase 2 (`_on_initialize`):** Called deferred after all siblings' `_ready()` complete. This is where you connect entity bus signals, read sibling state, and start processing.

```
_ready()           → resolve refs, set priority, defer _initialize
_initialize()      → connect lifecycle signals, call _on_initialize()
_on_initialize()   → YOUR CODE HERE: connect signals, read siblings
```

### Virtual Methods

| Method | When It Fires | Override For |
|--------|--------------|--------------|
| `_on_initialize()` | After all `_ready()` calls complete | Connect signals, read sibling components |
| `_on_entity_deactivating()` | Entity is dying (pool return or free) | Reset state, disconnect from game bus |
| `_on_entity_activated()` | Entity recycled from pool | Re-enable processing, reconnect signals |

### Available References

- `entity: CDEntity` — parent entity (velocity API, bus signals, lifecycle)
- `game: CDGame` — ancestor game (game bus, group registry, collision matrix)

### Component Boilerplate

When creating a new entity component, use this template to ensure lifecycle and signal bus rules are followed. 

```gdscript
extends CDEntityComponent
class_name MyCustomGuts

# 1. Use export groups for configurable signals
@export_group("Listen Signals")
@export var listen_signals: Array[StringName] = []

@export_group("Emit Signals")
@export var emit_signals: Array[StringName] = []

# 2. Set the category (determines execution priority)
func _ready() -> void:
	# Brains(10), Legs(20), Arms(40), Guts(50), Faces(60), Voices(65)
	component_category = CDUtilities.ComponentCategory.GUTS
	super._ready()

# 3. Connect to buses in _on_initialize()
func _on_initialize() -> void:
	for sig in listen_signals:
		entity.bus_connect(sig, _on_signal_received)

# 4. Read from blackboard in signal callbacks
func _on_signal_received() -> void:
	var target_value = entity.blackboard.get("my_key", default_value)
	# ... process intent/state ...

# 5. ALWAYS reset state on deactivation to prevent the "Leaky Pool" anti-pattern
func _on_entity_deactivating() -> void:
	# Reset variables to default here
	super._on_entity_deactivating()
```

---

## CDGameComponent — Game Components

**Use when:** Your component lives as a child of CDGame (Directors, Goals, Speakers, Projectors).

Same two-phase lifecycle as CDEntityComponent but simpler:
- No `entity` reference (game components aren't attached to entities)
- No pool lifecycle hooks (game components persist for the game's lifetime)
- `_on_initialize()` is your one override point

### Component Boilerplate

```gdscript
extends CDGameComponent
class_name MyCustomDirector

# Game components commonly listen to the game bus and emit entity bus signals
@export_group("Listen Signals")
@export var listen_signals: Array[StringName] = []

func _ready() -> void:
	component_category = CDUtilities.ComponentCategory.STAGE # STAGE = 70
	super._ready()

func _on_initialize() -> void:
	# Connect to game bus signals
	for sig in listen_signals:
		game.bus_connect(sig, _on_game_signal)

	# Directors can force entities to act by emitting on their buses:
	# target_entity.bus_emit("move_to")

func _on_game_signal() -> void:
	# Read from game.blackboard
	var wave = game.blackboard.get("wave", 0)
```

---

## CDCueCard — UI Display Components

**Use when:** Your component displays game state as text (ScoreCard, LivesCard, TimerCard, WaveCard).

Extends **Control**, not Node2D — cue cards live in the UI layer, not the physics world. Fixed priority 70 (RULES).

### The Interface Pattern

Set `is_interface = true` to auto-create a child Label. Call `_update_label(text)` whenever state changes. The label is created programmatically — no scene setup needed.

### Component Boilerplate

```gdscript
extends CDCueCard
class_name MyCustomCard

@export var prefix: String = "Score: "

func _ready() -> void:
	# Fixed priority 70
	super._ready()
	
	# Cards can connect in _ready() safely, bypassing two-phase init,
	# because the game bus is Dictionary-based.
	game.bus_connect("score_gained", _on_score_gained)
	
	# Trigger initial draw
	_update_label("0")

func _on_score_gained() -> void:
	var current_score = game.blackboard.get("score", 0)
	_update_label(str(current_score))
```

---

## CDStageTrapdoor — Stage Spawners

**Use when:** You need to spawn entities into the game world (PointTrapdoor, EdgeTrapdoor, GridTrapdoor).

Extends CDGameComponent with a complete Trigger → Queue → Stagger → Spawn lifecycle. Start with this, override three virtuals.

### The Spawn Lifecycle

```
Game bus signal (e.g. "wave_start")
  → _on_trigger() queues N spawn indices
  → _physics_process() drains queue with stagger delay
  → _spawn_one() per index: acquire from pool or instantiate
  → "spawning_complete" emitted when queue empty
```

### Virtual Methods to Override

| Method | Returns | Purpose |
|--------|---------|---------|
| `_get_spawn_count(wave_number)` | `int` | How many entities to spawn this wave |
| `_get_spawn_position(index, total)` | `Vector2` | Where to place entity #index |
| `_get_spawn_scene(index, total)` | `PackedScene` | Which scene to spawn for index (null = skip) |

### Key Exports

| Export | Default | Purpose |
|--------|---------|---------|
| `pool` | null | Set to CDObjectPool for pooled spawning, null for fresh instantiate |
| `spawn_context` | null | CDSpawnContext resource for velocity/rotation on spawn |
| `telefrag` | false | Kill overlapping entities at spawn point before spawning |
| `stagger_delay` | 0.1 | Seconds between each entity spawn |

### Safe Zone Pattern

Trapdoors listen for `"zone_safe"` / `"zone_unsafe"` signals from SafeZoneMark components. When unsafe, spawning pauses (queue holds) until the zone clears. Prevents entities spawning on top of each other.
