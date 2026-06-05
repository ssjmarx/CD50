# Directors — Game-Level Controllers

5 director components that orchestrate entity behavior from the game level. All extend `CDGameComponent` with `component_category = RULES`. Directors observe and command — they don't live on entities themselves but manage groups of entities through the game bus and group registry.

---

## Common Director Pattern

```
_ready()              → super._ready(), set component_category = RULES
_on_initialize()      → build lookup maps, connect game bus signals
_physics_process()    → evaluate rules/conditions, command entities
reset()               → clear all runtime state for game restart
```

### Must-Includes When Creating Directors

1. Extend `CDGameComponent`
2. Set `component_category = CDEnums.ComponentCategory.RULES` in `_ready()`
3. Connect game bus signals in `_on_initialize()`
4. Use `game.group_registry.get_group(group_name)` to find entities
5. Command entities via their own signals (`entity.ensure_signal()`, `entity.emit_signal()`)
6. Guard all entity access with `is_instance_valid()` and state checks
7. Implement `reset()` for clean game restart

### Key APIs Used by Directors

| API | Purpose |
|-----|---------|
| `game.bus_connect(sig, callable)` | Listen to zero-arg game bus signals |
| `game.bus_emit(sig)` | Broadcast zero-arg signal to game bus listeners |
| `game.bus_emit_from(sig, entity)` | Broadcast + record emitter for `CDSelectSignalEmitter` |
| `game.blackboard[key]` | Read/write game-level data |
| `game.group_registry.get_group(name)` | Get all entities in a named group |
| `entity.ensure_signal(name)` | Create signal on entity if missing |
| `entity.emit_signal(name)` | Command entity via its own signal bus (zero-arg) |
| `entity.blackboard[key]` | Write per-entity data for components to read |
| `entity.request_deactivate()` | Return entity to pool |
| `game.updater.queue_transition(...)` | Queue a group transition via CDUpdater |

---

## Components

### FormationDirector — Grid Slot Manager

Manages a rows×columns grid of named slots for formation entities (Galaga-style). Entities in the `formation_group` are auto-assigned to empty slots and commanded via `move_to` signals each frame.

| Feature | Details |
|---------|---------|
| **Slot grid** | `columns × rows`, positioned relative to director's `global_position` |
| **Animations** | Breathing (sinusoidal Y wave), stepping (horizontal oscillation) |
| **Auto-assign** | Untracked group members get first empty slot (row-major) |
| **Stale cleanup** | Invalid/departed entities are nullified each frame |
| **Position formula** | Grid base + column/row offsets + step X + breathing Y |

### StageDirector — Entity Swap Controller

Listens for game bus signals and performs entity swaps based on `CDDirectorRule` resources. Deactivates the original and spawns a replacement at the same position.

| Feature | Details |
|---------|---------|
| **Rules** | Array of `CDDirectorRule` (trigger signals, target group, swap scene, selector) |
| **Signal map** | Reverse lookup from signal name → matching rules |
| **Selection** | Optional `CDSelector` for filtering candidates |
| **Swap process** | Record position → deactivate original → instantiate replacement → activate at position |

### StateDirector — Group-as-State Machine

Transitions entities between groups (treating group membership as state). Uses `CDTransition` resources with triggers, selectors, and cooldowns. Transitions are queued via `CDUpdater` to avoid modifying groups during iteration.

| Feature | Details |
|---------|---------|
| **Transitions** | Array of `CDTransition` (from_group, to_group, trigger, selector, cooldown, exit/enter signals) |
| **Per-frame guard** | `_transitioned_this_frame: Dictionary` — each entity can only transition once per frame |
| **Signal triggers** | `CDSignalTrigger` queues pending entities for consumption |
| **Evaluation triggers** | Other triggers are evaluated each frame against group members |
| **CDUpdater queue** | All transitions deferred to avoid group mutation during iteration |
| **Cooldowns** | Per-entity cooldown tracking prevents rapid re-transitions |
| **Exit/enter signals** | Transition optionally emits signals on the entity when leaving/entering groups |

#### StateDirector Flow

```
1. _on_initialize()
   → Build lookup: transition.from_group → [transitions]
   → Connect trigger signals (CDSignalTrigger) to game bus
   → Store signal → transition mapping

2. _physics_process()
   → Clear _transitioned_this_frame
   → For each transition:
     a. Get candidates from from_group via group_registry
     b. Filter by selector (if configured)
     c. Check per-entity cooldown
     d. Evaluate trigger condition
     e. If all pass → queue transition via CDUpdater

3. CDSignalTrigger path:
   → Bus signal fires → _on_trigger_signal()
   → Record emitting entity in _pending_signal_entities
   → Next _physics_process checks _pending_signal_entities for matching transitions
```

### SwarmShootingDirector — Coordinated Fire Control

Periodically selects entities from target groups and commands them to shoot. Three selection modes for different tactical patterns.

| Feature | Details |
|---------|---------|
| **Modes** | RANDOM (pick N random), NEAREST (closest to reference group), BOTTOM_ROW (lowest entity per column) |
| **Timing** | Configurable interval with random variance |
| **Fire count** | Select N entities per fire cycle |
| **Command** | Emits `shoot` signal on selected entities |
| **Dedup** | Cross-group deduplication when using multiple target groups |

### SwoopDirector — Curve Path Mover

Generates a `Curve2D` from a `CDCurve` resource and commands entities along it via checkpoints. Entities enter in staggered sequence (line formation) and emit `swoop_complete` when finished.

| Feature | Details |
|---------|---------|
| **Curve** | `CDCurve` resource, generates `Curve2D` from origin to target |
| **Checkpoints** | Evenly-spaced baked points along the curve |
| **Line formation** | Staggered entry via `slot_spacing / entry_speed` delay per slot |
| **Movement** | Writes checkpoint position to entity blackboard, emits `begin_swoop` / checkpoint signals |
| **Completion** | Emits `swoop_complete` on game bus when entity finishes |
| **Editor preview** | `@tool` with `_draw()` showing the curve as a polyline |
