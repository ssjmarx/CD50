# Core Infrastructure

10 infrastructure scripts that every game and entity depends on. These are not components — they provide the runtime that components plug into.

---

## The Priority Cascade

Infrastructure nodes use `process_physics_priority` to guarantee a deterministic execution order every frame:

```
 5  CDGroupRegistry   — refresh dirty group caches
10  Components (BRAIN) — generate intent
20  Components (LEG)   — execute movement
30  CDEntity           — resolve velocity, run physics, detect collisions
35  CDCollisionBuffer  — flush pending collisions (after all entities moved)
40+ Components (ARM/GUTS/FACE/VOICE/RULES)
99  CDEntity           — deferred deactivation cleanup
```

Lower number = runs earlier. This eliminates frame-ordering bugs.

---

## CDEntity — The Physical Entity

**Extends:** `CharacterBody2D`  
**Priority:** 30 (PHYSICS)

Every physical thing in the game is a CDEntity. It does one job: **accumulate movement requests from components, resolve them through physics, and emit collision signals.**

### The Velocity API

Components never set `velocity` directly. They call request methods, and the entity resolves them in `_physics_process`:

| Method | Accumulator | Wins Against |
|--------|-------------|-------------|
| `request_velocity_add(v)` | `_accumulated_velocity_add` | — |
| `request_velocity_set(v)` | `_velocity_set_pending` | `add` |
| `request_angular_add(a)` | `_accumulated_angular_add` | — |
| `request_angular_set(a)` | `_angular_set_pending` | `add` |
| `request_position_set(p)` | `_position_set_pending` | physics result |
| `request_position_add(p)` | `_position_add_pending` | physics result |
| `request_rotation_set(r)` | `_rotation_set_pending` | physics result |
| `request_rotation_add(r)` | `_rotation_add_pending` | physics result |

**Resolution order:** add accumulates from all components → set overrides (last setter wins) → physics moves → teleport/snap → clamp to bounds.

### Collision Handler Registry

Guts components can register custom collision responses that override the default (SLIDE/BOUNCE/STOP):

```gdscript
# in a Guts component's _on_initialize():
entity.register_collision_handler([&"paddles"], _on_bounce_off_paddle)
entity.register_collision_handler([], _on_any_collision)  # catch-all
```

Handlers are checked specific-first, then catch-all. Match is by collision layer bitmask resolved from group names.

### Entity Blackboard

Every CDEntity has a `blackboard: Dictionary` that components use for per-frame data sharing. Brains write intent, legs poll intent, arms write results — all through keyed dictionary access with sensible defaults.

```gdscript
# Brain writes intent every frame
entity.blackboard[move_key] = direction

# Leg reads with default (absent key = no input)
var direction = entity.blackboard.get(move_key, Vector2.ZERO)
```

The blackboard is **not** cleared automatically — components overwrite keys each frame. Pool-returned entities should clear their blackboard in `_on_entity_deactivating()`.

### Entity Bus Signals

CDEntity defines these signals at runtime via `add_user_signal`:

| Signal | Emitted When | Args |
|--------|-------------|------|
| `collision` | This entity hit something | `collider: CDEntity, normal: Vector2` |
| `collided_by` | Something hit this entity | `source: CDEntity, normal: Vector2` |
| `request_deactivate` | External request to kill this entity | (none) |
| `entity_deactivating` | This entity is dying (pool return or free) | (none) |
| `entity_activated` | This entity recycled from pool | (none) |

Components can also create custom signals via `entity.ensure_signal(name)`.

### Two Communication Modes

Entity components use one of two patterns to communicate:

| Mode | Pattern | When to Use |
|------|---------|-------------|
| **Blackboard polling** | Writer sets `entity.blackboard[key]`, reader polls with `.get(key, default)` | Continuous per-frame data (movement, aiming, health) |
| **Signal + blackboard** | Writer sets blackboard data, then emits zero-arg signal | Intermittent events (shoot, take_damage, collision response) |

The signal+blackboard pattern lets the writer push data and notify the reader in one step, while keeping the signal contract simple (zero args). The reader checks the blackboard for event-specific data.

### Lifecycle

```
_ready()              → create collision shape, register groups, find game
_physics_process()    → resolve velocity, move_and_collide, queue collisions
deactivate()          → mark DEACTIVATING, disable physics, defer cleanup
_complete_deactivation() → disable collisions, emit deactivating, free/pool
activate()            → mark ACTIVE, enable collisions, register groups
```

### Must-Includes When Assembling Entities

1. Set `groups` export (used by collision matrix + group registry)
2. Set `collision_radius` (default circle shape) or override with `set_collision_polygon`/`set_collision_rect`
3. Set `collision_response` (SLIDE, BOUNCE, or STOP)
4. Set `lock_x` / `lock_y` for constrained entities (paddles, walls)
5. Set `clamp_to_bounds` + `bounds_margin` for entities that shouldn't leave the screen

---

## CDGame — The Game Root

**Extends:** `Node2D`

Every game scene has exactly one CDGame at the root. It provides:

1. **State machine** — ATTRACT → PLAYING → PAUSED → GAME_OVER
2. **Game bus** — Godot signal-based event router for game-level notifications (zero-arg signals)
3. **Game blackboard** — `Dictionary` for game-level data sharing (scores, wave numbers, etc.)
4. **Emitter tracking** — `_signal_emitters` registry for "who fired this signal" queries
5. **Required child refs** — `collision_buffer`, `group_registry`, `collision_matrix`, `input_router`, `updater`

### Game Blackboard

The game blackboard (`game.blackboard: Dictionary`) stores game-level data that components need to share. Like the entity blackboard, it uses simple key-value access:

```gdscript
# Writer (e.g., arm writes score)
game.blackboard[&"score_delta"] = points
game.bus_emit(&"score_gained")

# Reader (e.g., card reads delta)
func _on_score_gained():
    var delta = game.blackboard.get(&"score_delta", 0)
    _update_label(str(current_score + delta))
```

### Game Bus API

The game bus uses Godot signals internally. All bus signals are **zero-argument** — event-specific data goes on the `game.blackboard` before emitting.

```gdscript
# connect to a named event (auto-creates signal if needed)
game.bus_connect(&"score_gained", _on_score)

# emit a zero-arg event (no-op if nobody is listening)
game.bus_emit(&"score_gained")

# emit with emitter tracking (for CDSelectSignalEmitter)
game.bus_emit_from(&"score_gained", entity)

# disconnect on cleanup
game.bus_disconnect(&"score_gained", _on_score)
```

### Emitter Tracking

`bus_emit_from(signal_name, emitter)` records which entity emitted a signal in `_signal_emitters[signal_name]`. This enables `CDSelectSignalEmitter` to filter candidates to only the entities that caused a signal. The registry is cleared every frame by `CDUpdater`.

### Game Bus Events (conventions)

All events are zero-arg. Data is stored on `game.blackboard` before emitting.

| Event | Emitted By | Consumed By | Blackboard Key |
|-------|-----------|-------------|----------------|
| `"game_play"` | CDGame.start_game() | Stage components | — |
| `"game_over"` | CDGame.end_game() | Stage components | — |
| `"game_state_changed"` | CDGame setter | UI components | — |
| `"score_gained"` | ScoreOnCollisionArm | ScoreCard | `"score_delta"` |
| `"lives_changed"` | LivesCounterGoal | LivesCard | `"lives_delta"` |
| `"wave_start"` | WaveDirector | Trapdoors | — |
| `"wave_cleared"` | GroupCountGoal | Directors | — |

### Must-Includes When Assembling Games

1. Add required children: `CDCollisionBuffer`, `CDGroupRegistry`, `CDCollisionMatrix`, `CDInputRouter`, `CDUpdater`
2. Set `game_bounds` Rect2 to define the play area
3. Configure `CDCollisionMatrix` with `CDCollisionGroup` resources
4. Configure `CDInputRouter` with `tracked_actions`

---

## CDCollisionBuffer — Deferred Collision Flush

**Extends:** `Node`  
**Priority:** 35 (right after entity physics at 30)

Collisions are detected during `CDEntity._physics_process()` (priority 30) but NOT emitted until `CDCollisionBuffer._physics_process()` (priority 35). This guarantees all entities have finished moving before any Arm/Guts reacts to collisions.

### Pattern

1. Entity detects collision → appends to `_pending_collisions`
2. Entity registers itself with the collision buffer
3. Buffer iterates all registered entities, calls `flush_collisions()`
4. `flush_collisions()` emits `collision` + `collided_by` on each entity

---

## CDCollisionMatrix — Physics Layer Auto-Config

**Extends:** `Node`

Maps group names to Godot physics layer bitmasks so components never touch layers directly.

### Setup (in editor)

1. Create `CDCollisionGroup` resources (one per collision group)
2. Assign to `collision_groups` array on the matrix node
3. Each group gets bit `1 << index` as its layer
4. `collides_with` array defines which groups each group can detect

### Runtime

The matrix configures every CDEntity's `collision_layer` and `collision_mask` from its `groups` export. If an entity's group list changes, the matrix is re-consulted.

---

## CDGroupRegistry — Frame-Cached Group Queries

**Extends:** `Node`  
**Priority:** 5 (first thing every frame)

Provides typed `Array[CDEntity]` access to Godot groups, with dirty-marking to avoid refreshing every group every frame.

### API

```gdscript
# get all entities in a group (auto-refreshes if dirty)
registry.get_group(&"enemies")  → Array[CDEntity]

# get count
registry.get_count(&"enemies")  → int

# find nearest entity to a position
registry.get_nearest(&"enemies", global_position)  → CDEntity
```

### Dirty-Mark Pattern

- `mark_dirty(group_name)` called when entities join/leave groups
- Registry refreshes dirty groups at priority 5 (before anything else reads them)
- Emits `group_count_changed` signal when count actually changes

---

## CDObjectPool — Entity Pooling

**Extends:** `Node`

Pre-warms a pool of CDEntity instances to avoid runtime allocation. Used for bullets, asteroids, and any entity spawned frequently.

### Lifecycle

```
_ready()       → pre-warm initial_size entities (invisible, physics disabled)
acquire()      → pop from available, push to active, return to caller
CDEntity.deactivate() → push back to available, remove from active
```

### Must-Includes

1. Set `scene` export to the entity's PackedScene
2. Set `initial_size` to expected max active count
3. Entity's `pool` ref is auto-set by the pool — no manual wiring

---

## CDInputRouter — Signal-Driven Input

**Extends:** `Node`  
**Process mode:** ALWAYS (runs even when paused — needed for start/restart)

Converts Godot Input actions into signals that Brains connect to.

### Signals

| Signal | When | Args |
|--------|------|------|
| `input_move` | Every frame | `player_id: int, direction: Vector2` |
| `input_aim` | Every frame (when aiming) | `player_id: int, direction: Vector2` |
| `input_action_pressed` | Action just pressed | `player_id: int, action: StringName` |
| `input_action_released` | Action just released | `player_id: int, action: StringName` |
| `start_pressed` | Start button | (none) |
| `restart_pressed` | Restart button | (none) |
| `quit_pressed` | Quit button | (none) |

### Multi-Player

Set `player_count > 1` to enable prefixed input actions (`p1_move_left`, `p2_move_left`, etc.). Single player uses unprefixed actions.

---

## CDUpdater — Deferred Group Transitions & Emitter Cleanup

**Extends:** `Node`  
**Priority:** UPDATE (runs after all gameplay components)

Performs two end-of-frame tasks:
1. **Flushes queued group transitions** — preventing mid-frame group inconsistencies
2. **Clears `_signal_emitters`** — resetting the per-frame emitter tracking registry

### Group Transition Pattern

```gdscript
# in a Guts component:
game.updater.queue_transition(entity, &"alive", &"dying", &"exit_alive", &"enter_dying")
```

This removes the entity from `"alive"`, adds to `"dying"`, emits both signals, and marks both groups dirty in the registry — all at the end of the frame.

### Emitter Registry Clear

After flushing transitions, CDUpdater calls `game._signal_emitters.clear()`. This ensures `CDSelectSignalEmitter` only sees emitters from the current frame, not accumulated stale data.

---

## CDEffect — Self-Destructing Visuals

**Extends:** `Node2D`

Trivially simple: spawns, plays for `lifetime` seconds, then `queue_free()`. Used for death particles, explosions, etc.

---

## CDSoundBank — Procedural Audio Engine

**Extends:** `CDGameComponent`

Generates all sound effects at runtime using `AudioStreamGenerator`. No audio files needed for SFX.

### Two Voice Pools

| Pool | Size | Purpose |
|------|------|---------|
| One-shot (`_voices`) | 8 | Short sounds: pew, boom, bounce |
| Continuous (`_continuous_pool`) | 4 | Looped sounds: engine hum, alarm |

### One-Shot Pattern

```gdscript
# in a Voice component:
game.sound_bank.play_one_shot(sound_def, global_position, positional, exclusive, get_instance_id())
```

- `exclusive: true` → skip if this caller already has an active voice
- Supports jingles (multi-note sequences via `CDSoundDef.notes`)

### Continuous Pattern

```gdscript
# start a looped sound
var sig = game.sound_bank.start_continuous("engine", wave, effect, note, vol, id, pos, positional)

# pause/resume when needed
game.sound_bank.pause_continuous("engine", id)
game.sound_bank.resume_continuous("engine", id)

# stop when done
game.sound_bank.stop_continuous("engine", id)
```

Multiple sources can share a continuous voice (ref-counted). When only one source remains, it becomes positional again.
