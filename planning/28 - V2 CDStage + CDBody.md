# Plan 28: V2 CDStage + CDBody — Container Components

## Overview

**Status: 🔲 Planning**

CDStage and CDBody are **container nodes** that organize and sleep/wake groups of components. CDStage manages game-level components (directors, trapdoors, goals, cards). CDBody manages entity-level components (brains, legs, arms, guts, faces, voices). Neither touches entities directly — sleeping entities is the pool's job.

**Motivation:** Bug Blaster 2's multi-level design is too complex for simple WaveCard advancement. Each level has its own spawn choreography, entry curves, formations, and directors. CDStage lets each level be a self-contained group of stage components that can be activated/deactivated with a single signal. This same pattern enables dynamic remix content — a "SpaceRocksStage" or "BlockDropStage" can be woken mid-game to inject asteroids or tetrominos into any game.

CDBody enables runtime entity modification — powerup components, alternate control paradigms, and cross-game abilities can be pre-wired but asleep, then woken on signal.

**Depends on:** Plan 19 (Core Infrastructure), Plan 27 (Blackboard Architecture)

---

## Core Concept

| Container | Manages | Bus | Example Children |
|-----------|---------|-----|------------------|
| **CDStage** | `CDGameComponent` descendants | Game bus | Directors, Trapdoors, Goals, Cards, SequenceDirectors, Marks |
| **CDBody** | `CDEntityComponent` descendants | Entity bus | Brains, Legs, Arms, Guts, Faces, Voices |

**Sleep = freeze in place:**
- Disconnect all tracked bus connections
- Disable collision shapes under each component
- Stop physics processing on each component
- State, blackboard, groups all preserved

**Wake = resume from freeze:**
- Reconnect all tracked bus connections
- Re-enable collision shapes under each component
- Resume physics processing on each component

**What sleep is NOT:**

| Pool (deactivate) | Sleep (CDStage/CDBody) |
|---|---|
| Removes from groups | Groups untouched |
| Clears blackboard | Blackboard untouched |
| Returns to pool or frees | Stays in scene tree |
| Entity is gone | Component is frozen |
| Collision shapes disabled | Collision shapes disabled ✓ |
| Physics processing off | Physics processing off ✓ |

Entities are never managed by CDStage/CDBody. Entity lifecycle is the pool's job.

---

## Processing Order

CDStage and CDBody are themselves components (`CDGameComponent` and `CDEntityComponent` respectively). They evaluate at Priority 90 via CDUpdater, alongside group transitions.

**CDUpdater flush order at Priority 90:**

```
1. Group transitions (existing _pending array)
2. Sleep operations (_pending_sleep)
3. Wake operations (_pending_wake)
4. Clear _signal_emitters
```

Sleep before wake means "sleep Level1 + wake Level2" from the same signal on the same frame works correctly — the old stage freezes before the new stage activates.

---

## Bus Connection Tracking

### Problem

CDStage/CDBody need to disconnect/reconnect bus connections for their child components. But components currently connect to the bus in `_on_initialize()` with no tracking.

### Solution

Add `_bus_connections: Array[Dictionary]` to both base classes. Every `bus_connect()` call is auto-tracked. Every `bus_disconnect()` call is auto-untracked. CDStage/CDBody read this array during sleep/wake.

**This requires zero changes to any existing component.** All 165 components automatically get tracked connections.

### CDEntityComponent (enhanced)

```gdscript
var _bus_connections: Array[Dictionary] = []  # [{"signal_name": StringName, "callable": Callable}]

func bus_connect(signal_name: StringName, callable: Callable) -> void:
    if not entity.has_signal(signal_name):
        entity.add_user_signal(signal_name)
    entity.connect(signal_name, callable)
    _bus_connections.append({"signal_name": signal_name, "callable": callable})

func bus_disconnect(signal_name: StringName, callable: Callable) -> void:
    if entity.has_signal(signal_name) and entity.is_connected(signal_name, callable):
        entity.disconnect(signal_name, callable)
    for i in range(_bus_connections.size() - 1, -1, -1):
        if _bus_connections[i]["signal_name"] == signal_name and _bus_connections[i]["callable"] == callable:
            _bus_connections.remove_at(i)
```

### CDGameComponent (enhanced)

```gdscript
var _bus_connections: Array[Dictionary] = []  # [{"signal_name": StringName, "callable": Callable}]

func bus_connect(signal_name: StringName, callable: Callable) -> void:
    if not game.has_signal(signal_name):
        game.add_user_signal(signal_name)
    game.connect(signal_name, callable)
    _bus_connections.append({"signal_name": signal_name, "callable": callable})

func bus_disconnect(signal_name: StringName, callable: Callable) -> void:
    if game.has_signal(signal_name) and game.is_connected(signal_name, callable):
        game.disconnect(signal_name, callable)
    for i in range(_bus_connections.size() - 1, -1, -1):
        if _bus_connections[i]["signal_name"] == signal_name and _bus_connections[i]["callable"] == callable:
            _bus_connections.remove_at(i)
```

**Note:** CDEntity and CDGame already have their own `bus_connect()`/`bus_disconnect()` methods. These base class additions are on the **component** side — they wrap calls to `entity.bus_connect()`/`game.bus_connect()` and track the result. Components currently call `entity.bus_connect()` directly — they'll need to call `self.bus_connect()` instead for auto-tracking. Components that call `entity.bus_connect()` directly won't be tracked (acceptable for components that never sleep).

### Migration Path

Components that should be trackable by CDBody need to switch from:
```gdscript
entity.bus_connect("shoot", _on_shoot)  # NOT tracked
```
to:
```gdscript
bus_connect("shoot", _on_shoot)  # Tracked via self
```

This is a search-and-replace migration within CDBody-managed components only.

---

## Sleep/Wake Virtual Methods

### CDEntityComponent (additions)

```gdscript
## Override to customize sleep behavior (clear timers, reset state, etc.)
## Default: disable physics processing.
func _on_sleep() -> void:
    set_physics_process(false)

## Override to customize wake behavior (restart timers, re-query state, etc.)
## Default: enable physics processing.
func _on_wake() -> void:
    set_physics_process(true)
```

### CDGameComponent (additions)

```gdscript
## Override to customize sleep behavior.
## Default: disable physics processing.
func _on_sleep() -> void:
    set_physics_process(false)

## Override to customize wake behavior.
## Default: enable physics processing.
func _on_wake() -> void:
    set_physics_process(true)
```

---

## CDStage

**File:** `scripts/core/infrastructure/cd_stage.gd`  
**Class:** `CDStage extends CDGameComponent`

### Exports

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `pause_signals` | `Array[StringName]` | `[]` | Game bus signals that trigger sleep |
| `resume_signals` | `Array[StringName]` | `[]` | Game bus signals that trigger wake |
| `initial_awake` | `bool` | `true` | Whether the stage starts awake or asleep |

### Internal State

```gdscript
var _is_awake: bool = true
var _child_components: Array[CDGameComponent] = []
```

### Lifecycle

```gdscript
func _on_initialize() -> void:
    component_category = CDEnums.ComponentCategory.UPDATE
    process_physics_priority = 90
    _is_awake = initial_awake
    _collect_children()

    ## wire pause/resume signals to game bus
    for sig in pause_signals:
        game.bus_connect(sig, _on_pause_signal)
    for sig in resume_signals:
        game.bus_connect(sig, _on_resume_signal)

    ## immediately sleep if starts asleep
    if not _is_awake:
        _apply_sleep()
```

### Signal Handlers

```gdscript
func _on_pause_signal() -> void:
    if _is_awake:
        game.update.queue_stage_sleep(self)

func _on_resume_signal() -> void:
    if not _is_awake:
        game.update.queue_stage_wake(self)
```

### Sleep/Wake Implementation

```gdscript
func apply_sleep() -> void:
    _is_awake = false
    _apply_sleep()

func apply_wake() -> void:
    _is_awake = true
    _apply_wake()

func _apply_sleep() -> void:
    for comp in _child_components:
        ## disconnect all tracked game bus connections
        for entry in comp._bus_connections:
            game.bus_disconnect(entry.signal_name, entry.callable)
        ## disable collision shapes under this component
        CDEntity.set_subtree_collisions(comp, false)
        ## call virtual sleep
        comp._on_sleep()

func _apply_wake() -> void:
    for comp in _child_components:
        ## reconnect all tracked game bus connections
        for entry in comp._bus_connections:
            game.bus_connect(entry.signal_name, entry.callable)
        ## re-enable collision shapes under this component
        CDEntity.set_subtree_collisions(comp, true)
        ## call virtual wake
        comp._on_wake()

func _collect_children() -> void:
    for child in find_children("*", "CDGameComponent"):
        if child != self:
            _child_components.append(child)
```

### Nesting

CDStage supports nesting — `find_children("*", "CDGameComponent")` naturally recurses. A CDStage inside another CDStage will be collected as a child and will sleep/wake with its parent. The inner CDStage's own children will be handled by the inner CDStage when it processes its own sleep/wake.

---

## CDBody

**File:** `scripts/core/infrastructure/cd_body.gd`  
**Class:** `CDBody extends CDEntityComponent`

### Exports

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `sleep_signals` | `Array[StringName]` | `[]` | Entity bus signals that trigger sleep |
| `wake_signals` | `Array[StringName]` | `[]` | Entity bus signals that trigger wake |
| `initial_awake` | `bool` | `true` | Whether the body starts awake or asleep |

### Internal State

```gdscript
var _is_awake: bool = true
var _child_components: Array[CDEntityComponent] = []
```

### Lifecycle

```gdscript
func _on_initialize() -> void:
    _is_awake = initial_awake
    _collect_children()

    ## wire sleep/wake signals to entity bus
    for sig in sleep_signals:
        entity.bus_connect(sig, _on_sleep_signal)
    for sig in wake_signals:
        entity.bus_connect(sig, _on_wake_signal)

    ## immediately sleep if starts asleep
    if not _is_awake:
        _apply_sleep()
```

### Signal Handlers

```gdscript
func _on_sleep_signal() -> void:
    if _is_awake:
        entity.game.update.queue_body_sleep(self)

func _on_wake_signal() -> void:
    if not _is_awake:
        entity.game.update.queue_body_wake(self)
```

### Sleep/Wake Implementation

```gdscript
func apply_sleep() -> void:
    _is_awake = false
    _apply_sleep()

func apply_wake() -> void:
    _is_awake = true
    _apply_wake()

func _apply_sleep() -> void:
    for comp in _child_components:
        ## disconnect all tracked entity bus connections
        for entry in comp._bus_connections:
            entity.bus_disconnect(entry.signal_name, entry.callable)
        ## disable collision shapes under this component
        CDEntity.set_subtree_collisions(comp, false)
        ## call virtual sleep
        comp._on_sleep()

func _apply_wake() -> void:
    for comp in _child_components:
        ## reconnect all tracked entity bus connections
        for entry in comp._bus_connections:
            entity.bus_connect(entry.signal_name, entry.callable)
        ## re-enable collision shapes under this component
        CDEntity.set_subtree_collisions(comp, true)
        ## call virtual wake
        comp._on_wake()

func _collect_children() -> void:
    for child in find_children("*", "CDEntityComponent"):
        if child != self:
            _child_components.append(child)
```

### Nesting

Same as CDStage — `find_children("*", "CDEntityComponent")` recurses. Nested CDBodies cascade with their parent.

---

## Collision Shape Helper

### CDEntity Addition

**File:** `scripts/core/infrastructure/cd_entity.gd` — modified

Add a static helper that scans a node's children for collision shapes and enables/disables them. Refactor existing `activate()` and `_complete_deactivation()` to use it.

```gdscript
## Enable or disable all collision shapes in a node's direct children.
## Used by activate/deactivate, CDStage sleep/wake, and CDBody sleep/wake.
static func set_subtree_collisions(node: Node, enabled: bool) -> void:
    for child in node.get_children():
        if child is CollisionShape2D:
            child.set_deferred("disabled", not enabled)
        elif child is CollisionPolygon2D:
            child.set_deferred("disabled", not enabled)
```

### Refactored CDEntity.activate()

```gdscript
func activate() -> void:
    if state != CDEnums.EntityState.INACTIVE:
        return
    state = CDEnums.EntityState.ACTIVE
    blackboard.clear()
    set_subtree_collisions(self, true)  # was inline loop
    visible = true
    set_physics_process(true)
    for group_name in groups:
        add_to_group(group_name)
        if game and game.group_registry:
            game.group_registry.mark_dirty(group_name)
    emit_signal("entity_activated")
```

### Refactored CDEntity._complete_deactivation()

```gdscript
func _complete_deactivation() -> void:
    set_subtree_collisions(self, false)  # was inline loop
    emit_signal("entity_deactivating")
    for group_name in groups:
        remove_from_group(group_name)
        if game and game.group_registry:
            game.group_registry.mark_dirty(group_name)
    if pool != null:
        visible = false
        state = CDEnums.EntityState.INACTIVE
        pool.release(self)
    else:
        state = CDEnums.EntityState.INACTIVE
        queue_free()
```

---

## CDUpdater Integration

**File:** `scripts/core/infrastructure/cd_updater.gd` — modified

### New Queues

```gdscript
var _pending_sleep: Array = []   # Array of CDStage or CDBody
var _pending_wake: Array = Array  # Array of CDStage or CDBody
```

### New Queue API

```gdscript
func queue_stage_sleep(stage: CDStage) -> void:
    _pending_sleep.append(stage)

func queue_stage_wake(stage: CDStage) -> void:
    _pending_wake.append(stage)

func queue_body_sleep(body) -> void:  # CDBody
    _pending_sleep.append(body)

func queue_body_wake(body) -> void:  # CDBody
    _pending_wake.append(body)
```

### Updated Flush

```gdscript
func _flush() -> void:
    ## 1. Group transitions (existing)
    for op in _pending:
        # ... existing group transition logic ...

    _pending.clear()

    ## 2. Sleep operations
    for target in _pending_sleep:
        if is_instance_valid(target):
            target.apply_sleep()
    _pending_sleep.clear()

    ## 3. Wake operations
    for target in _pending_wake:
        if is_instance_valid(target):
            target.apply_wake()
    _pending_wake.clear()

    ## 4. Clear signal emitter registries
    game._signal_emitters.clear()
```

---

## Scene Tree Examples

### Bug Blaster 2 — Multi-Level

```
CDGame "BugBlaster2"
├── CDCollisionBuffer
├── CDGroupRegistry
├── CDCollisionMatrix
├── CDInputRouter
├── CDUpdater
├── TriangleShip (CDEntity — player)
├── WaveCard
├── StateDirector
│   └── transitions: formation→diving (timer), diving→formation (signal), etc.
├── CDStage "Level1" (initial_awake = true)
│   ├── pause_signals: ["level_1_cleared"]
│   ├── resume_signals: ["restart_level_1"]
│   ├── SignalSequenceDirector (Level 1 choreography)
│   ├── SwoopDirector ×4
│   ├── PointTrapdoor ×4
│   ├── FormationDirector
│   ├── ShootingDirector
│   ├── AimingDirector
│   └── GroupCountGoal → "level_1_cleared"
├── CDStage "Level2" (initial_awake = false)
│   ├── pause_signals: ["level_2_cleared"]
│   ├── resume_signals: ["restart_level_2"]
│   ├── SignalSequenceDirector (Level 2 choreography — different patterns)
│   ├── SwoopDirector ×6 (more swoopers)
│   ├── PointTrapdoor ×6
│   ├── FormationDirector (larger formation)
│   ├── ShootingDirector (faster timer)
│   ├── AimingDirector (less noise)
│   └── GroupCountGoal → "level_2_cleared"
├── CDStage "Level3" (initial_awake = false)
│   ├── pause_signals: ["level_3_cleared"]
│   └── ... (boss level with capture mechanics)
└── CdMark (dive-complete zone — always active)
```

### Player Entity — CDBody for Control Paradigms + Powerups

```
CDEntity "Player"
├── GunArm (always active — not in any body)
├── HealthpoolGuts (always active)
├── DieAtZeroHealthGuts (always active)
├── SpriteFace (always active)
├── CDBody "PlayerControls" (initial_awake = true)
│   ├── wake_signals: ["rescued"]
│   ├── PlayerMoveBrain
│   ├── PlayerActionBrain
│   └── DirectMovementLeg
├── CDBody "CapturedControls" (initial_awake = false)
│   ├── sleep_signals: ["rescued"]
│   ├── wake_signals: ["captured"]
│   └── (no brains, no legs — player is frozen while captured)
├── CDBody "WingmanAbility" (initial_awake = false)
│   ├── wake_signals: ["wingman_powerup"]
│   └── PowerupWingmanArm
└── SoundVoice (always active)
```

### Remix Example — Space Rocks + Bug Blaster Hybrid

```
CDGame "SpaceBugsRemix"
├── Infrastructure...
├── Player (CDEntity)
├── CDStage "SpaceRocksStage" (initial_awake = true)
│   ├── pause_signals: ["rocks_disabled"]
│   ├── resume_signals: ["rocks_enabled"]
│   ├── EdgeTrapdoor (spawns asteroids)
│   └── GroupCountGoal (asteroid wave management)
├── CDStage "BugBlasterStage" (initial_awake = true)
│   ├── pause_signals: ["bugs_disabled"]
│   ├── resume_signals: ["bugs_enabled"]
│   ├── FormationDirector
│   ├── SwoopDirector
│   └── ShootingDirector
└── RemixDirector (wakes/sleeps stages based on game rules)
```

---

## File Manifest

| File | Action | Summary |
|------|--------|---------|
| `scripts/core/infrastructure/cd_stage.gd` | **New** | CDStage container component — sleeps/wakes CDGameComponent children |
| `scripts/core/infrastructure/cd_body.gd` | **New** | CDBody container component — sleeps/wakes CDEntityComponent children |
| `scripts/core/base classes/cd_entity_component.gd` | **Modified** | Add `_bus_connections` tracking, `bus_connect()`/`bus_disconnect()` wrappers, `_on_sleep()`/`_on_wake()` virtuals |
| `scripts/core/base classes/cd_game_component.gd` | **Modified** | Add `_bus_connections` tracking, `bus_connect()`/`bus_disconnect()` wrappers, `_on_sleep()`/`_on_wake()` virtuals |
| `scripts/core/infrastructure/cd_entity.gd` | **Modified** | Add `set_subtree_collisions()` static helper, refactor `activate()`/`_complete_deactivation()` |
| `scripts/core/infrastructure/cd_updater.gd` | **Modified** | Add `_pending_sleep`/`_pending_wake` queues + `queue_stage_sleep/wake()` + `queue_body_sleep/wake()` + updated `_flush()` |

**Total: 2 new scripts, 4 modified scripts**

---

## Validation Checklist

### ✅ Test 1: CDStage Sleep on Signal
- CDStage with `pause_signals: ["level_cleared"]`, contains ShootingDirector + FormationDirector
- Game bus emits `"level_cleared"`
- Verify: ShootingDirector and FormationDirector both have `_physics_process = false`
- Verify: Their tracked bus connections are disconnected
- Verify: Any collision shapes under them are disabled

### ✅ Test 2: CDStage Wake on Signal
- Same CDStage asleep, `resume_signals: ["restart_level"]`
- Game bus emits `"restart_level"`
- Verify: All children reconnected to game bus
- Verify: Physics processing resumed
- Verify: Collision shapes re-enabled

### ✅ Test 3: CDStage Starting Asleep
- CDStage with `initial_awake = false`
- On `_on_initialize()`: all children immediately slept
- No processing, no bus connections, no collision shapes until explicitly woken

### ✅ Test 4: CDBody Sleep/Wake on Entity Bus
- CDBody with `sleep_signals: ["captured"]`, `wake_signals: ["rescued"]`
- Contains PlayerMoveBrain + DirectMovementLeg
- Entity bus emits `"captured"` → brain and leg stop processing
- Entity bus emits `"rescued"` → brain and leg resume processing

### ✅ Test 5: CDUpdater Flush Order
- Same frame: group transition + CDStage sleep + CDStage wake
- Verify: Group transitions execute first
- Verify: Sleep executes before wake
- Verify: Signal emitters cleared last

### ✅ Test 6: Nested CDBody
- CDBody "Outer" contains CDBody "Inner" which contains a Brain
- Outer sleeps → Inner and its Brain also sleep
- Outer wakes → Inner and its Brain also wake

### ✅ Test 7: Bus Connection Tracking Round-Trip
- Component calls `bus_connect("shoot", _on_shoot)` → tracked in `_bus_connections`
- CDStage sleeps → connection disconnected
- CDStage wakes → connection reconnected with same callable
- Verify: signal reaches the component after wake

### ✅ Test 8: Collision Shape Toggle
- CdMark with CollisionShape2D under CDStage
- CDStage sleeps → CdMark's CollisionShape2D disabled
- CDStage wakes → CdMark's CollisionShape2D re-enabled
- Verify: Mark stops detecting bodies while asleep

### ✅ Test 9: Bug Blaster 2 Level Transition
- Level1 CDStage awake, Level2 CDStage asleep
- GroupCountGoal fires `"level_1_cleared"`
- Level1's `pause_signals: ["level_1_cleared"]` → Level1 sleeps
- Level2's `resume_signals: ["level_1_cleared"]` → Level2 wakes (same signal wires to both)
- Verify: Level1 directors stop, Level2 directors start
- Verify: No entity is touched by either operation

### ✅ Test 10: Entity Pool Unaffected
- CDEntity in pool with state INACTIVE
- CDStage sleeps → pool entity untouched (not a CDGameComponent)
- CDBody sleeps → pool entity untouched (CDEntity itself is not a CDEntityComponent)
- Verify: Pool lifecycle is independent of CDStage/CDBody

---

## Risks & Open Questions

1. **Bus connection migration:** Components that call `entity.bus_connect()` or `game.bus_connect()` directly (bypassing the base class wrapper) won't have their connections tracked. CDStage/CDBody won't disconnect those during sleep. **Mitigation:** Document the convention: components that need to be trackable must use `self.bus_connect()`. For V1 components, this is a search-and-replace migration within CDBody-managed children only.

2. **Deferred collision shape timing:** `set_deferred("disabled", ...)` applies at end of frame. If a CDStage wakes and a component's collision shape needs to be active this same frame, there's a one-frame delay. **Mitigation:** Since sleep/wake also processes at end of frame (Priority 90), this is consistent. The collision shape change and the component wake happen in the same deferred batch.

3. **CDStage/CDBody `_collect_children()` timing:** If a child component is added dynamically after `_on_initialize()`, it won't be tracked. **Mitigation:** Plan 28 scope is static scene assemblies. Dynamic children are explicitly out of scope.

4. **Component `_on_initialize()` call during wake:** When CDStage wakes a child component, it reconnects bus connections and calls `_on_wake()`. It does NOT call `_on_initialize()` again. Components that set up internal state in `_on_initialize()` that depends on bus connections must handle re-initialization in `_on_wake()`. **Mitigation:** Default `_on_wake()` just sets `set_physics_process(true)`. Document that components needing state reset on wake should override `_on_wake()`.

5. **Signal name collisions:** Two CDStages listening to the same game bus signal will both react. This is intentional (e.g., Level1 sleeps and Level2 wakes on `"level_1_cleared"`). **Mitigation:** Document as feature, not bug. Designer wires signals deliberately.

6. **CDBody accessing entity.game.update:** CDBody needs to queue operations on CDUpdater. It accesses this via `entity.game.update` which is safe because CDEntityComponent guarantees both `entity` and `game` are resolved in `_ready()`. **Mitigation:** Standard pattern, no risk.

---

## Future Work

**Dynamic child registration:** If a CDBody needs to track components spawned at runtime (e.g., a powerup that injects a new component), add `register_child()` and `unregister_child()` methods. Deferred until a use case requires it.

**CDStage scene instancing:** Allow CDStage to load a `.tscn` file at runtime instead of requiring inline children. This would enable "drop-in" remix stages. Deferred until remix content requires it.

**Sleep/wake signals:** CDStage/CDBody could emit signals when they complete sleep/wake transitions. Not needed for current design (direct wiring is sufficient). Deferred.

**Component `_on_sleep()` overrides:** As components are migrated to use tracked bus connections, some may need custom `_on_sleep()` behavior (e.g., GunArm clearing cooldown, TimerGuts pausing its timer). These will be discovered during integration and handled case-by-case.