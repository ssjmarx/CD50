# Plan 25: V2 Swarm Controllers + Galaga

## Overview

Build the V2 swarm control system: a resource-driven state machine, formation controllers, and entity-level behavior components. This plan establishes core architectural patterns and uses Galaga as the proving ground.

**No gameplay is built.** The goal is a complete, tested catalog of reusable swarm control components.

**Depends on:** Plan 19 (Core Infrastructure), Plan 19.5 (Object Pools), Plan 20 (Stage), Plan 21 (Brains + Legs), Plan 22 (Arms + Guts), Plan 23 (Spawners)

---

## Core Patterns Established

### Pattern 1: Controller Pattern

A **Stage component** that queries a group via `CDGroupRegistry` and broadcasts signals on each entity's entity bus. Controllers don't own entities — they command whoever is in their group.

```
Controller (Stage, Priority 70):
  _physics_process:
    entities = CDGroupRegistry.query("some_group")
    for entity in entities:
      entity.entity_bus.emit(signal_name, args)
```

Controllers calculate positions, generate paths, and emit movement commands. Entities execute those commands via their own Legs. The controller never sets `entity.velocity` directly.

### Pattern 2: Group-as-State

An entity's "behavior state" = which group it's in. Moving between groups = changing behavior. Entities can be in multiple groups simultaneously: a persistent category group (`"enemies"`) AND a state group (`"formation"`).

- `"enemies"` = collision/category group (always present, used by DamageOnHitArm, SwarmShootingController)
- `"formation"` = state group (present when in formation, used by FormationController)
- `"diving"` = state group (present when dive-bombing, used by DiveBombBrain)
- `"capturing"` = state group (present when Boss is running tractor beam)

Controllers broadcast to state groups. When CDSwarmStateMachine transitions an entity from `"formation"` to `"diving"`, the entity naturally stops receiving formation movement commands and starts receiving dive commands.

### Pattern 3: Entity-Owned Power-Ups

**RULE: Entities must be wired for their own power-ups.**

Player entities have power-up Arms that listen for named signals on their own entity bus. Power-up entities deliver those signals via collision. The power-up entity doesn't know what it does — the player entity decides.

```
PowerUp entity:
  PowerUpDeliveryArm: on collision → emits "wingman_powerup" on collider's bus
  Deactivates self

Player entity:
  WingmanPowerupArm: hears "wingman_powerup" on own bus → spawns companion
```

This means player entities are heavier to compose, but in 99% of arcade games there's only one player entity, and each power-up can be configured precisely.

### Pattern 4: Capture-and-Replace

A generic stage pattern: when an entity is "captured," it is deactivated and replaced by a different entity (the replacement is parented to the captor). This is not Galaga-specific — any game where an entity can be hijacked, converted, or possessed uses this pattern.

```
CaptureMonitor (Stage):
  Listens for "captured(entity, captor)" on game bus
  Looks up capture rules by entity's group
  Deactivates entity, spawns replacement, parents to captor
```

### Pattern 5: Bus Bridge

Entities communicate with the game bus through a generic `CDBusBridge` component that rebroadcasts signals from one bus to another. This eliminates per-signal announcer components.

```
CDBusBridge:
  listen_signal → rebroadcast_signal on target bus
  Optional qualifying_groups filter
  Optional self-reference as argument
```

### Pattern 6: Dynamic Args Pattern

When a CDTransition must emit dynamic data (player position, nearest enemy, etc.), set `emit_signal` to a zero-arg signal like `"begin_dive"`. The receiving Brain queries the required context from CDGroupRegistry. Brains that need dynamic context must document which groups they query.

Example: DiveBombBrain receives `"begin_dive"` (no args), then independently queries the `"players"` group via CDGroupRegistry to find the player position for path generation.

---

## Processing Order Convention

**State machine transitions run before controllers query groups.**

| Role | Priority | Why |
|------|----------|-----|
| CDSwarmStateMachine | 65 | Transitions first — entities are in correct groups before controllers query |
| All other controllers | 70 | Query groups after state machine has updated membership |

Within Priority 70, controller processing order is undefined. This is acceptable because controllers broadcast to different state groups and don't depend on each other's output within the same frame.

---

## The Galaga Lifecycle (Full Signal Flow)

This section shows how all components compose to produce Galaga's complete enemy lifecycle. Every arrow is a signal.

```
SPAWN:
  EdgeSpawner creates enemies in "swooping" + "enemies" groups
  SwoopController queries "swooping", generates bezier curves
    → emits follow_curve(curve, speed) on each entity bus

ENTRY:
  PathFollowerLeg (Plan 21) follows curve → emits path_finished on entity bus
  CDBusBridge("path_finished" → "request_formation_slot" on game bus)
  CDSwarmStateMachine: CDSignalTrigger("request_formation_slot")
    → transition "swooping" → "formation"
    → exit_signal "exit_swooping" on entity bus
    → emit_signal "enter_formation" on entity bus
  FormationController assigns slot, broadcasts move_to(slot_position) every frame

FORMATION:
  FormationController: every frame calculates slot positions
    (base + sine breathing + lateral step)
    → emits move_to(slot_pos) on each "formation" entity's bus
  SmoothToLeg (Plan 21) chases moving target
  SwarmShootingController: timer fires
    → picks random from "enemies" → emits "shoot" on entity bus

DIVE:
  CDSwarmStateMachine: CDTimerTrigger(4s, variance 2s) + CDSelectRandomN(1)
    → transition "formation" → "diving"
    → exit_signal "exit_formation" (SmoothToLeg clears target)
    → emit_signal "begin_dive" on entity bus (no args — Brain queries players group)
  DiveBombBrain: queries "players" group, generates sine-wave attack curve → emits follow_curve
  ShootIntervalBrain: starts on "begin_dive", emits "shoot" at intervals
  PathFollowerLeg follows attack curve

DIVE MISS:
  PathFollowerLeg finishes curve (entity off-screen bottom)
  CDBusBridge("path_finished" → "request_return_path" on game bus, qualifying: "diving")
  CDSwarmStateMachine: transition "diving" → "returning"
    → exit_signal "exit_diving" (ShootIntervalBrain stops)
  ReturnController: wraps to top, calculates return bezier
    → emits follow_curve on entity bus
  PathFollowerLeg follows return curve → path_finished
  CDBusBridge("path_finished" → "request_formation_slot" on game bus)
  CDSwarmStateMachine: transition "returning" → "formation"

BOSS CAPTURE:
  CDSwarmStateMachine: CDTimerTrigger(15s) + CDSelectN(1)
    → transition "formation" → "diving"
    → emit_signal "begin_dive" on entity bus
  TractorBeamBrain: detects Y threshold during dive
    → emits "capture_phase_started(self)" on game bus
  CDSwarmStateMachine: CDSignalTrigger("capture_phase_started")
    → transition "diving" → "capturing"
    → exit_signal "exit_diving" (ShootIntervalBrain stops)
    → emit_signal "enter_capturing" (TractorBeamArm activates)
  TractorBeamArm: Area2D detects player collision
    → emits "captured(player_entity, self)" on game bus
  CaptureMonitor: looks up "players" → replacement = CapturedShip.tscn
    → deactivates player, spawns CapturedShip parented to Boss
  After beam_duration: TractorBeamBrain emits "capture_phase_ended(self)" on game bus
  CDSwarmStateMachine: CDSignalTrigger("capture_phase_ended")
    → transition "capturing" → "returning"
    → exit_signal "exit_capturing" (TractorBeamArm deactivates)
    → emit_signal "request_return_path" (ReturnController picks up)
  ReturnController handles return → entity rejoins formation
  CapturedShip follows Boss into formation (parented, no Legs)

RESCUE (Boss killed while holding captive):
  Boss dies → DieAtZeroHealthGuts emits "died(boss)" on game bus (synchronous)
  CapturedPlayerShip is child of Boss → receives cleanup signal
  CapturedPlayerShip's SpawnOnDeathArm fires (synchronous, before deferred queue_free)
    → spawns RescuedPlayerShip at CapturedPlayerShip's last position
  RescuedPlayerShip has FollowerAI:
    queries "players" group each frame → moves toward player at follow_speed
  RescuedPlayerShip collides with player (via CDCollisionBuffer, Plan 22)
    → PowerUpDeliveryArm emits "wingman_powerup" on player's entity bus
    → PowerUpDeliveryArm emits "request_deactivate" on own entity bus (self-cleanup)
  Player's WingmanPowerupArm: spawns WingmanShip companion entity
  WingmanShip: PlayerControlBrain(same player_id), GunArm, CompanionOffsetGuts

DEATH:
  LivesTracker monitors "players" group
  When ENTIRE "players" group is empty (player + wingman all dead)
    → subtracts life, respawns player entity
```

---

## State Machine Resources (9)

### CDTransition
**Type:** Custom Resource (extends Resource)
**Purpose:** One transition rule. Defines when and how entities move between groups.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `from_group` | `StringName` | `&""` | Source group (entities must be in this group to transition) |
| `to_group` | `StringName` | `&""` | Destination group (entities are moved here on transition) |
| `trigger` | `CDTrigger` | `null` | What causes this transition to evaluate |
| `selector` | `CDSelector` | `null` | Which entities from `from_group` transition |
| `cooldown` | `float` | `0.0` | Minimum seconds between fires for this transition |
| `emit_signal` | `StringName` | `&""` | Emitted on each transitioning entity's bus after group change |
| `exit_signal` | `StringName` | `&""` | Emitted on each transitioning entity's bus before leaving `from_group` |
| `signal_args` | `Dictionary` | `{}` | Arguments for `emit_signal` (static values only — see Dynamic Args Pattern) |

**Process:** When `trigger` fires, query `from_group` via CDGroupRegistry. Apply `selector` to narrow the list. For each selected entity (that hasn't already transitioned this frame): emit `exit_signal` on entity bus, remove from `from_group`, add to `to_group`, emit `emit_signal` on entity bus.

---

### CDTrigger (Abstract)
**Type:** Abstract Custom Resource
**Purpose:** Base class for transition triggers. Triggers come in two semantic categories:

- **Event triggers** (CDTimerTrigger, CDSignalTrigger) — *fire* at a specific moment
- **Evaluative triggers** (CDGroupCountTrigger) — *evaluate* as a condition each frame

CDCompositeTrigger uses this distinction: "all event triggers have fired AND all evaluative conditions are true."

#### CDTimerTrigger (Event)
| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `interval` | `float` | `5.0` | Seconds between fires |
| `random_variance` | `float` | `0.0` | Added random delay (0 = exact interval) |

**Fires:** On interval timer. Does not carry entity context — the CDTransition's selector picks entities from `from_group`.

#### CDSignalTrigger (Event)
| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `signal_name` | `StringName` | `&""` | Game bus signal to listen for |

**Fires:** When game bus receives `signal_name`. If the signal carries an `entity: CDEntity` argument, that entity is checked against `from_group` before the selector runs. This enables entity-initiated transitions (e.g., `"capture_phase_started"` carries the requesting entity).

#### CDGroupCountTrigger (Evaluative)
| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `group_name` | `StringName` | `&""` | Group to monitor |
| `comparison` | `CompareOp` | `LESS_EQUAL` | Comparison operation |
| `threshold` | `int` | `0` | Count to compare against |

**CompareOp Enum:** `LESS`, `LESS_EQUAL`, `EQUAL`, `GREATER_EQUAL`, `GREATER`

**Semantics:** When used standalone as a transition trigger, "fires" when its condition transitions from false to true (edge detection). When used inside CDCompositeTrigger, evaluated as a guard condition — must be true for the composite to fire, but doesn't need to "fire" independently.

#### CDCompositeTrigger
| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `triggers` | `Array[CDTrigger]` | `[]` | Sub-triggers to combine |
| `require_all` | `bool` | `true` | `true` = AND, `false` = OR |

**Fires:** For `require_all = true`: all event triggers must have fired AND all evaluative conditions must be true. For `require_all = false`: any event trigger has fired OR any evaluative condition is true.

---

### CDSelector (Abstract)
**Type:** Abstract Custom Resource
**Purpose:** Determines which entities from the `from_group` are transitioned.

#### CDSelectAll
**Purpose:** Transition every entity in `from_group`.
*(No properties — all entities selected.)*

#### CDSelectN
| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `count` | `int` | `1` | Select the first N entities |

**Selection order:** CDGroupRegistry iteration order (scene tree order). Deterministic.

#### CDSelectRandomN
| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `count` | `int` | `1` | Select N random entities |

**Selection order:** Random. Each fire picks independently.

#### CDSelectNearestN
| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `count` | `int` | `1` | Select N nearest entities |
| `target_group` | `StringName` | `&"player"` | Measure distance to nearest entity in this group |

**Selection order:** Sorted by distance to nearest entity in `target_group`. Useful for "nearest enemies dive first."

---

## Stage Controllers (6)

### CDSwarmStateMachine
**Role:** Single source of truth for all group transitions in a swarm. Moves entities between groups based on a configurable transition table. This is the one node where you can see the entire state graph.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDStageComponent2D`, Category: `STAGE`, Priority **65** |
| **Consumes** | Game bus: whatever signals are referenced in CDTransition triggers |
| **Generates** | Group reassignments (remove from `from_group`, add to `to_group`). Entity bus: `exit_signal` and `emit_signal` per transition. |
| **Exports** | `transitions: Array[CDTransition]` |
| **Init** | On `_on_initialize()`: `duplicate()` all trigger resources to prevent shared-state bugs (Godot Resources are shared by reference). Validate all `emit_signal` and `exit_signal` names — `push_warning()` for signals not found on the entity bus. |
| **Process** | On `_physics_process()`: (1) Mark all entities as "not transitioned this frame." (2) Snapshot `from_group` membership for all transitions. (3) Evaluate event triggers (timers, pending signals). (4) For each fired trigger: query snapshotted `from_group`, apply selector, skip already-transitioned entities, perform group reassignment + emit signals. |
| **Guard Rules** | (1) `push_error()` if any transition has empty `from_group` or `to_group`. (2) An entity transitions **at most once per frame** — first matching transition wins. (3) Transitions are evaluated in array order — earlier transitions have higher priority. |

---

### SwoopController
**Role:** Generates bezier entry curves for entities entering the play field. Broadcasts `follow_curve` to the `"swooping"` group. Fires once per wave.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDStageComponent2D`, Category: `STAGE`, Priority 70 |
| **Consumes** | Game bus: configurable trigger signal (default `"wave_start"`) |
| **Generates** | Entity bus (per entity in `"swooping"`): `"follow_curve(curve: Curve2D, speed: float)"` |
| **Exports** | `swooping_group: StringName = &"swooping"` <br> `trigger_signal: StringName = &"wave_start"` <br> `entry_speed: float = 200.0` <br> `curve_amplitude: float = 100.0` (how wide the swoop curves) <br> `entry_point_spread: float = 50.0` (random spread of curve entry points) <br> `target_y: float = 0.0` (Y coordinate where curves end, 0 = use formation center Y) |
| **Process** | On trigger signal: query `"swooping"` group. For each entity at index `i`: calculate start position (entity's current position), end position (near formation center with horizontal offset based on index), control points (bezier with `curve_amplitude` creating the swoop). Emit `"follow_curve"` on entity's bus. Done — hands off to PathFollowerLeg. |

---

### FormationController
**Role:** Manages a grid of named slots. Every frame, calculates slot positions (base + breathing sine + lateral step) and broadcasts `move_to` to the `"formation"` group. Also handles slot assignment when entities request formation entry.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDStageComponent2D`, Category: `STAGE`, Priority 70 |
| **Consumes** | Game bus: `"request_formation_slot(entity: CDEntity)"` |
| **Generates** | Entity bus (per entity in `"formation"`): `"move_to(target: Vector2)"` every frame |
| **Exports** | `formation_group: StringName = &"formation"` <br> `columns: int = 10` <br> `rows: int = 5` <br> `cell_size: Vector2 = Vector2(16, 16)` <br> `cell_spacing: Vector2 = Vector2(4, 4)` <br> `breathing_amplitude: float = 3.0` <br> `breathing_frequency: float = 1.0` <br> `step_enabled: bool = true` <br> `step_speed: float = 20.0` <br> `step_distance: float = 30.0` |
| **Internal State** | `_slots: Array[CDEntity]` (2D array flattened to columns×rows, null = empty slot) <br> `_step_offset: float` (current lateral offset, oscillates) <br> `_breathing_offset: float` (current breathing phase) |
| **Process** | **Per frame:** Update breathing + step offsets. For each occupied slot, calculate target position. Emit `"move_to(target)"` on that entity's bus. Verify `is_instance_valid(entity)` and entity is still in `"formation"` before emitting — clean up invalid slots immediately. <br><br> **On `"request_formation_slot"`:** Find first empty slot (row-major order). Assign entity to slot. Add entity to `"formation"` group. Immediately emit `"move_to"` with current slot position. |
| **Slot reassignment:** | Returning entities get the first empty slot (row-major), NOT their original slot. This is authentic to Galaga behavior. |

---

### ReturnController
**Role:** Calculates return bezier curves for entities that need to re-enter formation after a dive. Handles screen wrapping (bottom → top) before pathing back.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDStageComponent2D`, Category: `STAGE`, Priority 70 |
| **Consumes** | Game bus: `"request_return_path(entity: CDEntity)"` |
| **Generates** | Entity bus: `"wrap_to(position: Vector2)"` (screen wrap), `"follow_curve(curve: Curve2D, speed: float)"` |
| **Exports** | `return_speed: float = 150.0` <br> `curve_amplitude: float = 80.0` |
| **Process** | On `"request_return_path"`: (1) Emit `"wrap_to"` on entity's bus to teleport to top of screen. (2) Calculate bezier curve from wrapped position to a point near the formation center. (3) Emit `"follow_curve"` on entity's bus. The entity's PathFollowerLeg handles the rest. |

---

### SwarmShootingController
**Role:** Periodically selects entities from target groups and commands them to fire. Configurable selection mode for different shooting behaviors.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDStageComponent2D`, Category: `STAGE`, Priority 70 |
| **Consumes** | Internal timer |
| **Generates** | Entity bus (on selected entities): `"shoot"` |
| **Exports** | `target_groups: Array[StringName] = [&"enemies"]` (union of all groups — deduplicates entities present in multiple groups) <br> `shoot_interval: float = 2.0` <br> `random_variance: float = 1.0` <br> `shoot_count: int = 1` (how many entities fire per interval) <br> `selection_mode: ShootSelect = RANDOM` |
| **Selection Modes** | `RANDOM` — pick N random from pool <br> `BOTTOM_ROW` — group by X proximity into columns, pick lowest Y from each column (Space Invaders) <br> `NEAREST` — pick N closest to nearest entity in `"players"` group |
| **Process** | Timer fires (interval + random variance). Query all entities in `target_groups` (union, deduplicated — entity in multiple target groups is counted once). Apply `selection_mode`. Emit `"shoot"` on each selected entity's bus. |

---

### CaptureMonitor
**Role:** Generic capture-and-replace stage component. When an entity is "captured," it is deactivated and replaced by a configured entity, which is parented to the captor.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDStageComponent2D`, Category: `STAGE`, Priority 70 |
| **Consumes** | Game bus: `"captured(entity: CDEntity, captor: CDEntity)"` |
| **Generates** | Spawns replacement entities. Deactivates captured entities. |
| **Exports** | `capture_rules: Array[CDCaptureRule]` |
| **Process** | On `"captured"`: iterate `capture_rules`. Find rule where `target_group` matches one of the captured entity's groups. If found: deactivate the captured entity. Spawn `replacement_scene`. If `parent_to_captor`, add as child of captor entity. |

**CDCaptureRule (Resource):**

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `target_group` | `StringName` | `&""` | The captured entity must be in this group for this rule to apply |
| `replacement_scene` | `PackedScene` | `null` | Scene to spawn as replacement |
| `parent_to_captor` | `bool` | `true` | Parent the replacement to the capturing entity |

**Galaga config:** `target_group = &"players"`, `replacement_scene = CapturedShip.tscn`, `parent_to_captor = true`

**Note on parented replacements:** When `parent_to_captor = true`, the replacement's transform is relative to the captor. Parented replacements should NOT have movement components (Legs) — their position is determined by the parent's transform. For Galaga's CapturedShip, the entity has no Legs; it just sits there as a child of the Boss.

---

## Entity Components (8)

### TractorBeamBrain
**Role:** Boss entity behavior. During a dive, detects when it reaches a Y threshold, announces the capture phase to the state machine (game bus signals), manages beam timing, then announces capture phase end.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDComponent2D`, Category: `BRAIN`, Priority 10 |
| **Consumes** | Entity bus: `"begin_dive"` (no args — queries "players" group via Dynamic Args Pattern), `"enter_capturing"`, `"exit_capturing"` |
| **Generates** | Entity bus: `"activate_tractor_beam"`, `"deactivate_tractor_beam"`, `"request_velocity_set(Vector2.ZERO)"` <br> Game bus: `"capture_phase_started(entity)"`, `"capture_phase_ended(entity)"` |
| **Exports** | `capture_height_ratio: float = 0.7` (fraction of screen height — when to stop and beam) <br> `beam_duration: float = 2.0` <br> `is_boss: bool = true` (only activates for boss entities) |
| **Process** | 1. On `"begin_dive"`: if `is_boss`, start monitoring Y position. <br> 2. Each frame: if entity.global_position.y >= game.game_bounds.size.y * `capture_height_ratio`: <br> &nbsp;&nbsp;&nbsp;&nbsp;a. Emit `"capture_phase_started(entity)"` on game bus (state machine transitions to `"capturing"`). <br> &nbsp;&nbsp;&nbsp;&nbsp;b. Emit `"cancel_dive"` on entity bus (PathFollowerLeg stops). <br> &nbsp;&nbsp;&nbsp;&nbsp;c. Emit `"request_velocity_set(Vector2.ZERO)"` (stop moving). <br> 3. On `"enter_capturing"` (from state machine's emit_signal): emit `"activate_tractor_beam"` on entity bus. Start `beam_duration` timer. <br> 4. On timer expiry: <br> &nbsp;&nbsp;&nbsp;&nbsp;a. Emit `"deactivate_tractor_beam"` on entity bus. <br> &nbsp;&nbsp;&nbsp;&nbsp;b. Emit `"capture_phase_ended(entity)"` on game bus (state machine transitions to `"returning"`). <br> 5. On `"exit_capturing"` (from state machine's exit_signal): cleanup. |
| **Key Design:** | The brain owns the *decision* (Y threshold, beam timing). The state machine owns the *transition* (group changes). All group membership flows through CDSwarmStateMachine. |

---

### TractorBeamArm
**Role:** Enables a collision hitbox on command. When the hitbox detects a player entity, announces capture on the game bus.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDComponent2D`, Category: `ARM`, Priority 40 |
| **Consumes** | Entity bus: `"activate_tractor_beam"`, `"deactivate_tractor_beam"` |
| **Generates** | Game bus: `"captured(entity: CDEntity, captor: CDEntity)"` |
| **Exports** | `target_group: StringName = &"players"` <br> `beam_area_path: NodePath` (path to Area2D child) |
| **Process** | On `"activate_tractor_beam"`: enable the Area2D (`monitoring = true`). On body entered: if body is in `target_group`, emit `"captured(body, entity)"` on game bus. On `"deactivate_tractor_beam"`: disable Area2D (`monitoring = false`). |

---

### CDBusBridge
**Role:** Generic bus bridge. Listens for a signal on one bus and rebroadcasts on another. Eliminates per-signal announcer components.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDComponent2D`, Category: Announcer (no priority — reactive only) |
| **Consumes** | Entity bus: configurable `listen_signal` |
| **Generates** | Game bus OR entity bus: configurable `rebroadcast_signal` |
| **Exports** | `listen_signal: StringName = &"path_finished"` <br> `rebroadcast_signal: StringName = &"request_formation_slot"` <br> `target_bus: CDBusTarget = GAME_BUS` (enum: `GAME_BUS`, `ENTITY_BUS`) <br> `qualifying_groups: Array[StringName] = []` (only fire if entity is in one of these; empty = always fire) <br> `include_self: bool = true` (pass entity as first argument) |
| **Process** | On `listen_signal`: if `qualifying_groups` is empty OR entity is in any qualifying group: emit `rebroadcast_signal` on `target_bus`, with entity as first arg if `include_self`. |

**Named scene files for readability:**
- `FormationAnnouncer.tscn` = CDBusBridge(listen=`"path_finished"`, rebroadcast=`"request_formation_slot"`, target=GAME_BUS, include_self=true, qualifying=[])
- `ReturnAnnouncer.tscn` = CDBusBridge(listen=`"path_finished"`, rebroadcast=`"request_return_path"`, target=GAME_BUS, include_self=true, qualifying=[`"diving"`])

---

### PowerUpDeliveryArm
**Role:** Generic power-up delivery. On collision with a target group, emits a configurable signal on the *collider's* entity bus, then deactivates. Used by any entity that delivers a power-up via contact (stationary pickups, homing rescue ships, etc.).

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDComponent2D`, Category: `ARM`, Priority 40 |
| **Consumes** | Entity bus: `"collision(collider, normal)"` (via CDCollisionBuffer, Plan 22) |
| **Generates** | Collider's entity bus: configurable signal <br> Own entity bus: `"request_deactivate"` |
| **Exports** | `target_group: StringName = &"players"` <br> `power_signal: StringName = &""` (signal name to emit on collider's bus) |
| **Process** | On collision: validate collider is in `target_group`. If so, emit `power_signal` on collider's entity bus. Then emit `"request_deactivate"` on own entity bus (power-up consumed). |

---

### FollowerAI
**Role:** Universally reusable Brain that moves its entity toward the nearest member of a target group. Used for homing enemies, seeker missiles, escort NPCs, rescue ships — any "chase target" behavior.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDComponent2D`, Category: `BRAIN`, Priority 10 |
| **Consumes** | CDGroupRegistry: queries `target_group` each frame |
| **Generates** | Sets entity velocity directly (or emits `"request_velocity_set(velocity)"` on entity bus) |
| **Exports** | `target_group: StringName = &"players"` <br> `follow_speed: float = 150.0` <br> `stop_distance: float = 5.0` (stop following when this close) <br> `active_signal: StringName = &""` (optional — only follow after receiving this signal; empty = always active) |
| **Process** | Each frame: query `target_group` via CDGroupRegistry. If empty, do nothing. Find nearest entity by distance. Calculate direction vector. If distance > `stop_distance`, set velocity = direction × `follow_speed`. If distance <= `stop_distance`, set velocity = `Vector2.ZERO`. |

---

### WingmanPowerupArm
**Role:** Player-side power-up. Listens for `"wingman_powerup"` on own entity bus and spawns a companion WingmanShip entity nearby.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDComponent2D`, Category: `ARM`, Priority 40 |
| **Consumes** | Entity bus: `"wingman_powerup"` |
| **Generates** | Spawns WingmanShip entity |
| **Exports** | `companion_scene: PackedScene` <br> `spawn_offset: Vector2 = Vector2(20, 0)` <br> `power_signal: StringName = &"wingman_powerup"` <br> `max_companions: int = 1` <br> `companion_group: StringName = &"players"` |
| **Process** | On `"wingman_powerup"`: count existing companions (entities in `"players"` group that aren't the main player). If count >= `max_companions`, skip. Otherwise: instantiate `companion_scene`, set position to entity position + `spawn_offset`, add to game tree, add to `"players"` group. |

---

### CompanionOffsetGuts
**Role:** Companion entity component. Each frame, reads the lead entity's position from a target group and offsets own position to match.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDComponent2D`, Category: `GUTS`, Priority 50 |
| **Consumes** | Lead entity position (via CDGroupRegistry query) |
| **Generates** | `entity.request_velocity_set(velocity)` |
| **Exports** | `lead_group: StringName = &"players"` <br> `offset: Vector2 = Vector2(20, 0)` <br> `chase_speed: float = 500.0` |
| **Process** | Each frame: query `lead_group`, find the first entity that is NOT self and is NOT in `"companion"` sub-group (or use a `"lead_player"` sub-group to avoid ordering ambiguity). Calculate target position = lead position + offset. Set own velocity toward target at `chase_speed`. |

---

### ShootIntervalBrain
**Role:** Simple entity brain that emits `"shoot"` on the entity bus at configurable intervals. Started and stopped via entity bus signals.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDComponent2D`, Category: `BRAIN`, Priority 10 |
| **Consumes** | Entity bus: configurable `start_signal` and `stop_signal` |
| **Generates** | Entity bus: `"shoot"` |
| **Exports** | `start_signal: StringName = &"begin_dive"` <br> `stop_signal: StringName = &"exit_diving"` (state machine exit_signal — consistent stop regardless of which component cancels the dive) <br> `interval: float = 1.0` <br> `random_variance: float = 0.3` |
| **Process** | On `start_signal`: begin timer. On timer fire: emit `"shoot"`. Reset timer with `interval + randf_range(-random_variance, random_variance)`. On `stop_signal`: stop timer. |
| **Note:** | `stop_signal` defaults to the state machine's `exit_signal` for the diving group (`"exit_diving"`), not a brain-specific signal. This means ShootIntervalBrain stops whenever the entity leaves the diving group, regardless of whether the exit was caused by path_finished, capture, or any other transition. |

---

## DiveBombBrain (Detailed from Plan 21)

**Role:** Entity brain. On `"begin_dive"`, queries the `"players"` group for player position (Dynamic Args Pattern), generates a sine-wave dive path, and emits `follow_curve`.

| Aspect | Detail |
|--------|--------|
| **Extends** | `CDComponent2D`, Category: `BRAIN`, Priority 10 |
| **Consumes** | Entity bus: `"begin_dive"` (no args — queries "players" group via Dynamic Args Pattern) |
| **Generates** | Entity bus: `"follow_curve(curve: Curve2D, speed: float)"` |
| **Exports** | `dive_speed: float = 250.0` <br> `sine_frequency: float = 2.0` (oscillations during dive) <br> `sine_amplitude: float = 40.0` (width of weaving) <br> `overshoot: float = 50.0` (how far past screen bottom the path extends) <br> `aim_at_player: bool = true` (curve toward player, vs straight down) <br> `target_group: StringName = &"players"` (group to query for player position) |
| **Process** | On `"begin_dive"`: <br> 1. Query `"players"` group via CDGroupRegistry. If empty, dive straight down. <br> 2. Calculate start = entity position. <br> 3. Calculate end = start + direction toward player (or straight down), extended past `game.game_bounds.end.y + overshoot`. <br> 4. Generate Curve2D with intermediate points along a sine wave perpendicular to the dive direction. <br> 5. Emit `"follow_curve(curve, dive_speed)"` on entity bus. |

---

## Galaga Player Side

### Player Entity Composition

```
GalagaPlayer.tscn (CDEntity):
  - PlayerControlBrain (Plan 21) — listens to input, emits "move" and "shoot"
  - EightWayWalk (Plan 21) or HorizontalOnly — constrains to horizontal movement
  - GunArm (Plan 23) — fires bullets
  - WingmanPowerupArm — listens for "wingman_powerup", spawns companion
  - HealthPoolGuts(1) — one hit kill
  - DieAtZeroHealthGuts — deactivate on death
  - SpriteFace or VectorFace — visual
  - SoundVoice — shoot sound
  Groups: "players", "player_ship"
```

### Boss Entity Composition

```
GalagaBoss.tscn (CDEntity):
  - TractorBeamBrain — detects Y threshold, emits capture signals
  - TractorBeamArm — enables tractor beam hitbox
  - DiveBombBrain — generates dive curves
  - ShootIntervalBrain — fires during dives
  - PathFollowerLeg — follows curves
  - SmoothToLeg — chases formation positions
  - CDBusBridge(path_finished → request_formation_slot) — "FormationAnnouncer"
  Groups: "enemies", "bosses"  ← Note: "bosses" group for CDSelectN targeting

CapturedPlayerShip.tscn (CDEntity, child of Boss):
  - SpriteFace — same visual as player ship
  - SpawnOnDeathArm(companion_scene = RescuedPlayerShip.tscn) — spawns rescue ship on death
  - NO Legs, no Brain — purely visual, position determined by Boss parent transform
  Groups: "captured_ships" (identification only)

RescuedPlayerShip.tscn (CDEntity, spawned by CapturedPlayerShip's SpawnOnDeathArm):
  - FollowerAI(target_group = &"players", follow_speed = 150.0) — homes toward player
  - PowerUpDeliveryArm(target_group = &"players", power_signal = &"wingman_powerup") — delivers power-up on collision
  - SpriteFace — same visual as player ship
  - CollisionShape2D — for PowerUpDeliveryArm collision detection (via CDCollisionBuffer)
  Groups: "power_ups"
```

### Player Capture Flow

```
Boss captures player:
  TractorBeamArm emits "captured(player, boss)" on game bus
  CaptureMonitor: rule for "players" → spawn CapturedPlayerShip, parent to Boss
  CapturedPlayerShip has NO Legs — position determined by Boss parent transform
  CapturedPlayerShip is purely visual + carries SpawnOnDeathArm

Boss killed while holding captive:
  Boss's DieAtZeroHealthGuts emits "died(boss)" on game bus (synchronous)
  CapturedPlayerShip receives cleanup signal → SpawnOnDeathArm fires (synchronous)
    → spawns RescuedPlayerShip at CapturedPlayerShip's last known position
  Boss and CapturedPlayerShip are queue_free()'d (deferred cleanup)
  RescuedPlayerShip activates:
    FollowerAI queries "players" group → moves toward player
    Visual: captured ship flies down toward the active player
  RescuedPlayerShip collides with player:
    PowerUpDeliveryArm emits "wingman_powerup" on player's entity bus
    PowerUpDeliveryArm emits "request_deactivate" on own entity bus (self-cleanup)
  Player's WingmanPowerupArm: spawns WingmanShip

WingmanShip:
  PlayerControlBrain (same player_id — responds to same inputs)
  GunArm — fires independently
  CompanionOffsetGuts — follows player at offset
  Groups: "players", "companion" (companion sub-group for identification)

Death:
  LivesTracker: queries "players" group
  Only subtracts a life when ENTIRE "players" group is empty
  Both player and wingman must die → then respawn
```

**Spawn timing constraint:** SpawnOnDeathArm must use synchronous `add_child()`, not `call_deferred()`. Death signal processing is synchronous — spawns resolve before the deferred `queue_free()` cleanup executes. Object pooling (Plan 19.5) avoids this concern entirely since pool activation is synchronous.

---

## Galaga State Machine Configuration

```
CDSwarmStateMachine on GalagaGame (Priority 65):

transitions (in priority order — first match wins per entity per frame):

1. swooping → formation
   Trigger: CDSignalTrigger("request_formation_slot")
   Selector: CDSelectAll()
   exit_signal: "exit_swooping"
   emit_signal: "enter_formation"

2. formation → diving
   Trigger: CDTimerTrigger(interval=4.0, variance=2.0)
   Selector: CDSelectRandomN(1)
   exit_signal: "exit_formation"  (SmoothToLeg clears target)
   emit_signal: "begin_dive"      (DiveBombBrain generates path)

3. diving → capturing
   Trigger: CDSignalTrigger("capture_phase_started")
   Selector: CDSelectAll()
   exit_signal: "exit_diving"     (ShootIntervalBrain stops)
   emit_signal: "enter_capturing" (TractorBeamArm activates)

4. capturing → returning
   Trigger: CDSignalTrigger("capture_phase_ended")
   Selector: CDSelectAll()
   exit_signal: "exit_capturing"  (TractorBeamArm deactivates)
   emit_signal: "request_return_path" (ReturnController picks up —
     note: this is on game bus via the signal trigger mechanism,
     ReturnController hears it directly)

5. diving → returning
   Trigger: CDSignalTrigger("request_return_path")
   Selector: CDSelectAll()
   exit_signal: "exit_diving"
   (no emit_signal — ReturnController handles independently)

6. returning → formation
   Trigger: CDSignalTrigger("request_formation_slot")
   Selector: CDSelectAll()
   exit_signal: "exit_returning"
   emit_signal: "enter_formation"

7. formation → diving (Boss capture dive)
   Trigger: CDTimerTrigger(interval=15.0, variance=5.0)
   Selector: CDSelectN(1)
   exit_signal: "exit_formation"
   emit_signal: "begin_dive"
   Note: Boss entities are tagged in "bosses" group.
   To guarantee Boss selection, use CDCompositeTrigger:
     CDTimerTrigger(15.0) AND CDGroupCountTrigger("bosses", GREATER, 0)
   with from_group set to "bosses" or use CDSelectFilteredN (Future Work).
```

---

## V1 → V2 Migration Map

| V1 Script | V2 Component(s) | Key Changes |
|-----------|-----------------|-------------|
| `swarm_ai.gd` (466 lines) | CDSwarmStateMachine + SwoopController + FormationController | Monolith → resource-driven state machine + dedicated controllers |
| `interceptor_ai.gd` | DiveBombBrain + ShootIntervalBrain | Dive logic extracted to entity brain |
| `shoot_ai.gd` | ShootIntervalBrain | Timer-based shooting during dives |
| `shoot_ai_swarm.gd` | SwarmShootingController | Entity-level → stage-level shooting director |
| `wave_spawner.gd` (swarm patterns) | SwoopController + EdgeSpawner | Entry curves extracted from spawner |
| `patrol_ai.gd` | FormationController + SmoothToLeg | Grid-based movement via controller broadcasts |
| (none) | TractorBeamBrain + TractorBeamArm | New — Boss capture sequence |
| (none) | CaptureMonitor + CDCaptureRule | New — generic capture-and-replace |
| (none) | PowerUpDeliveryArm + WingmanPowerupArm | New — entity-owned power-ups |
| (none) | FollowerAI | New — universally reusable homing/chase Brain |
| (none) | CompanionOffsetGuts | New — follow-the-leader companion |
| (none) | CDSwarmStateMachine + 9 Resources | New — resource-driven state machine |
| (none) | ReturnController | New — return path generation |
| (none) | CDBusBridge | New — generic bus bridge (replaces per-signal announcers) |

---

## Implementation Order

### Phase 1: State Machine Foundation
1. CDTransition resource — prove transition data structure (with `exit_signal`)
2. CDTimerTrigger + CDSelectRandomN — prove timer-driven group transitions
3. CDSwarmStateMachine — prove full evaluate → select → transition loop with per-frame guard

### Phase 2: Additional Triggers + Selectors
4. CDSignalTrigger — prove signal-driven transitions (entity-initiated)
5. CDGroupCountTrigger (evaluative) — prove population-based guard conditions
6. CDSelectAll, CDSelectN, CDSelectNearestN — prove selection variants
7. CDCompositeTrigger — prove AND/OR with event + evaluative trigger mixing

### Phase 3: Movement Controllers
8. SwoopController — prove bezier curve generation + broadcast
9. FormationController — prove slot assignment + breathing + stepping
10. ReturnController — prove screen wrap + return bezier

### Phase 4: Shooting
11. SwarmShootingController — prove group-based shoot commands with RANDOM mode
12. ShootIntervalBrain — prove entity-level interval shooting (start/stop via signals)

### Phase 5: Capture System
13. TractorBeamBrain — prove Y-threshold detection + game bus signal emission (no self-managed groups)
14. TractorBeamArm — prove hitbox activation + capture announcement
15. CaptureMonitor + CDCaptureRule — prove capture-and-replace pattern

### Phase 6: Power-Ups + Companions + Rescue
16. PowerUpDeliveryArm — prove generic signal delivery via collision
17. FollowerAI — prove group-query homing behavior (universally reusable)
18. WingmanPowerupArm — prove companion spawning + group assignment
19. CompanionOffsetGuts — prove follow-the-leader offset tracking

### Phase 7: Bus Bridge
20. CDBusBridge — prove generic entity→game bus translation
21. Create named scenes: FormationAnnouncer.tscn, ReturnAnnouncer.tscn

---

## Proof / Testing

### Test 1: State Machine — Timer Transition
- 5 entities in `"group_a"`
- CDSwarmStateMachine: CDTimerTrigger(1.0s) + CDSelectRandomN(1), transition `"group_a"` → `"group_b"`
- After 1s: 1 entity moves to `"group_b"`, 4 remain in `"group_a"`
- After 2s: another moves, etc.

### Test 2: State Machine — Signal Transition
- Entity finishes path, CDBusBridge fires `"request_formation_slot(entity)"`
- CDSwarmStateMachine: CDSignalTrigger + CDSelectAll, `"swooping"` → `"formation"`
- Entity removed from `"swooping"`, added to `"formation"`
- `exit_signal` fired on entity bus, `emit_signal` fired on entity bus

### Test 3: State Machine — No Double Transition
- 5 entities in `"formation"`
- Two transitions with `from_group = "formation"`, both triggered by same timer
- Verify: each entity transitions at most once per frame
- Verify: first transition in array wins

### Test 4: Formation Breathing
- FormationController: 5×3 grid, breathing_amplitude=5, breathing_frequency=2
- 15 entities in `"formation"` with SmoothToLeg
- Entities visibly oscillate vertically while maintaining grid positions

### Test 5: Swoop Entry
- 10 enemies spawned in `"swooping"` group at screen edge
- SwoopController generates 10 unique bezier curves
- Each entity receives `follow_curve` and follows its curve

### Test 6: Full Dive Cycle
- Entity in `"formation"` → state machine transitions to `"diving"`, emits `"begin_dive"`
- `exit_signal "exit_formation"` fires → SmoothToLeg clears target
- DiveBombBrain generates sine-wave curve → `follow_curve`
- ShootIntervalBrain starts on `"begin_dive"`, fires during dive
- Path finishes → CDBusBridge fires `"request_return_path"`
- State machine transitions `"diving"` → `"returning"`, `exit_signal "exit_diving"` stops ShootIntervalBrain
- ReturnController wraps to top, generates return curve
- Path finishes → CDBusBridge fires `"request_formation_slot"` → entity rejoins formation

### Test 7: Boss Capture (Routed Through State Machine)
- Boss entity with TractorBeamBrain in `"diving"` group
- Entity reaches Y threshold → TractorBeamBrain emits `"capture_phase_started(entity)"` on game bus
- State machine: CDSignalTrigger → transition `"diving"` → `"capturing"`
  - `exit_signal "exit_diving"` → ShootIntervalBrain stops
  - `emit_signal "enter_capturing"` → TractorBeamBrain activates beam
- Player enters beam → `"captured(player, boss)"` on game bus
- CaptureMonitor: deactivates player, spawns CapturedShip parented to Boss
- Beam timer expires → TractorBeamBrain emits `"capture_phase_ended(entity)"` on game bus
- State machine: transition `"capturing"` → `"returning"`
  - `exit_signal "exit_capturing"` → TractorBeamArm deactivates
- Boss returns to formation with CapturedShip attached

### Test 8: Rescue + Double Ship
- Boss killed → CapturedPlayerShip's SpawnOnDeathArm spawns RescuedPlayerShip (synchronous)
- RescuedPlayerShip's FollowerAI homes toward player
- RescuedPlayerShip collides with player → PowerUpDeliveryArm emits `"wingman_powerup"` on player bus
- RescuedPlayerShip deactivates (PowerUpDeliveryArm self-cleanup)
- WingmanPowerupArm spawns WingmanShip
- WingmanShip responds to same inputs, CompanionOffsetGuts keeps at offset
- Both in `"players"` group → LivesTracker waits for both to die

### Test 9: SwarmShootingController
- 20 entities in `"enemies"` group, each with GunArm
- SwarmShootingController: interval=1.5s, shoot_count=2, RANDOM
- Every 1.5s, 2 random enemies fire

### Test 10: Composite Trigger (Event + Evaluative)
- CDSwarmStateMachine: CDCompositeTrigger(require_all=true) with:
  - CDTimerTrigger(5.0) — event trigger
  - CDGroupCountTrigger("formation", GREATER, 0) — evaluative guard
- Timer fires → check if formation count > 0 → only then transition
- Kill all formation entities → timer still fires but guard prevents transition

---

## File Structure

```
Godot/Scripts/
├── Controllers/
│   ├── cd_swarm_state_machine.gd      # Resource-driven state machine (Priority 65)
│   ├── swoop_controller.gd            # Bezier entry curves (Priority 70)
│   ├── formation_controller.gd        # Grid + breathing + stepping (Priority 70)
│   ├── return_controller.gd           # Return bezier + screen wrap (Priority 70)
│   ├── swarm_shooting_controller.gd   # Periodic group shoot commands (Priority 70)
│   └── capture_monitor.gd             # Generic capture-and-replace (Priority 70)
├── Brains/
│   ├── tractor_beam_brain.gd          # Boss capture sequence AI
│   ├── follower_ai.gd                 # Homing/chase AI (universally reusable)
│   └── shoot_interval_brain.gd        # Timer-based shooting
├── Arms/
│   ├── tractor_beam_arm.gd            # Capture hitbox
│   ├── power_up_delivery_arm.gd       # Generic power-up delivery
│   └── wingman_powerup_arm.gd         # Companion spawning
├── Guts/
│   ├── companion_offset_guts.gd       # Follow-the-leader offset
│   └── cd_bus_bridge.gd               # Generic bus bridge (entity↔game)
├── Resources/
│   ├── cd_transition.gd               # Transition rule (with exit_signal)
│   ├── cd_trigger.gd                  # Abstract trigger + concretes
│   ├── cd_selector.gd                 # Abstract selector + concretes
│   └── cd_capture_rule.gd             # Capture-and-replace rule
```

**Note on directory structure:** `Controllers/` is a new directory. Controllers are Stage components grouped by role for discoverability.

---

## Risks & Open Questions

1. **CDSwarmStateMachine performance with many transitions:** Each `_physics_process` evaluates timer triggers. With 5–10 transitions, trivial. Timer triggers only evaluate on their interval. **Mitigation:** Guard rule prevents per-frame evaluation except for timer ticks.

2. **FormationController slot release timing:** When state machine removes entity from `"formation"`, FormationController detects on next frame. **Mitigation:** Verify `is_instance_valid()` and group membership before emitting `move_to`. Clean up invalid slots immediately.

3. **PowerUpDeliveryArm and entity bus access:** Power-up entity emits on collider's bus. **Mitigation:** Same guard pattern as DamageOnHitArm (Plan 22) — `is_instance_valid()` + signal existence check.

4. **CompanionOffsetGuts lead entity identification:** Need to distinguish lead from companion within the same group. **Mitigation:** Use `"lead_player"` sub-group on the main player entity, or check `"companion"` sub-group to exclude companions. Small groups make this cheap.

5. **DiveBombBrain curve generation:** Sine-wave path smoothness depends on intermediate point count. **Mitigation:** Start with ~20 points per curve.

6. **CaptureMonitor and entity parenting:** Parented replacements should not have movement components. **Mitigation:** Document in CDCaptureRule. Galaga's CapturedPlayerShip has no Legs.

7. **Signal name typos:** Dynamic `emit_signal()` calls have zero type safety. **Mitigation:** State machine validates all signal names on `_on_initialize()` via `push_warning()`. Future: cross-cutting signal constants file.

8. **SpawnOnDeathArm spawn timing:** Spawns must be synchronous (`add_child()`, not `call_deferred()`) to resolve before the deferred `queue_free()` cleanup of the dying parent entity. **Mitigation:** Document in SpawnOnDeathArm. Object pooling (Plan 19.5) eliminates this concern since pool activation is synchronous.

---

## Future Work

**SwarmShootingController BOTTOM_ROW mode:** Deferred until Space Invaders.

**CDSelectFilteredN selector:** A selector that filters by an additional group. Eliminates the need for a separate Boss capture transition.

**Power-up modification pattern:** For power-ups that modify the player (speed boost, spread shot), a runtime component injection pattern may be needed. Deferred until a game requires it.

**Signal name constants file:** Cross-cutting quality pass across all plans.

**AnimatedFace + ActionStateGuts:** Deferred from Plan 24.