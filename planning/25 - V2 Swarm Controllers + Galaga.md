# Plan 25: V2 Swarm Controllers + Galaga

## Overview

**Status: ✅ COMPLETE — 0 new scripts needed**

All swarm control components proposed in this plan were built during Plans 21–24 under different names, or deemed redundant with existing components. This document serves as the architectural reference for how these components compose to produce Galaga-style swarm behavior.

The only remaining deliverable is the **Galaga proof-of-concept game scene** — assembling existing components into a playable game to prove the architecture works end-to-end.

**Depends on:** Plan 19 (Core Infrastructure), Plan 19.5 (Object Pools), Plan 20 (Stage), Plan 21 (Brains + Legs), Plan 22 (Arms + Guts), Plan 23 (Spawners), Plan 24 (Faces, Voices, Projections & Speakers)

---

## Component Mapping

### Implemented Under Different Names (10 components)

| Plan 25 Proposed Name | Actual Name | Script File | Built In | Category |
|---|---|---|---|---|
| CDSwarmStateMachine | **StateDirector** | `state_director.gd` | Plan 24 | Director |
| SwoopController | **SwoopDirector** | `swoop_director.gd` | Plan 24 | Director |
| FormationController | **FormationDirector** | `formation_director.gd` | Plan 24 | Director |
| SwarmShootingController | **SwarmShootingDirector** | `swarm_shooting_director.gd` | Plan 24 | Director |
| CaptureMonitor | **StageDirector** | `stage_director.gd` | Plan 24 | Director |
| CDCaptureRule | **CDDirectorRule** | `cd_director_rule.gd` | Plan 24 | Resource |
| CDBusBridge | **AnnouncerGuts** | `announcer_guts.gd` | Plan 24 | Guts |
| ShootIntervalBrain | **AIRepeatActionBrain** | `ai_repeat_action_brain.gd` | Plan 21 | Brain |
| TractorBeamBrain | **AITractorBeamBrain** | `ai_tractor_beam_brain.gd` | Plan 24 | Brain |
| DiveBombBrain | **AIDiveBombBrain** | `ai_dive_bomb_brain.gd` | Plan 21 | Brain |

### Also Used (pre-existing, no rename)

| Component | Script File | Built In | Category |
|---|---|---|---|
| TractorBeamArm | `tractor_beam_arm.gd` | Plan 24 | Arm |
| PowerUpDeliveryArm | `powerup_delivery_arm.gd` | Plan 24 | Arm |
| PowerupWingmanArm | `powerup_wingman_arm.gd` | Plan 24 | Arm |
| SpawnOnDeathArm | `spawn_on_death_arm.gd` | Plan 23 | Arm |
| AIFormationBrain | `ai_formation_brain.gd` | Plan 21 | Brain |
| AIChaseBrain | `ai_chase_brain.gd` | Plan 21 | Brain |

### Deemed Redundant (2 components)

| Plan 25 Proposed | Redundant With | Rationale |
|---|---|---|
| ReturnController | **FormationDirector** | After a dive, entities transition directly back to the formation group. FormationDirector already broadcasts `move_to` for every entity in the group — no separate return path needed. Entities wrap to top of screen and FormationDirector handles the rest. |
| FollowerAI | **AIChaseBrain** | Homing/chase behavior is identical to AIChaseBrain's target-group pursuit. |
| CompanionOffsetGuts | **AIFormationBrain** | Follow-the-leader offset tracking is the same pattern as AIFormationBrain's leader-offset behavior. |

### Supporting Resources (all from Plan 24)

CDTransition, CDTrigger (+ 4 concrete triggers), CDSelector (+ 4 concrete selectors), CDCurve (+ 11 concrete curves), CDDirectorRule, CDShape — all implemented and in the catalogue.

---

## Core Patterns Established

### Pattern 1: Controller Pattern (now "Director Pattern")

A **Stage component** (Director) that queries a group via `CDGroupRegistry` and broadcasts signals on each entity's entity bus. Directors don't own entities — they command whoever is in their group.

```
Director (Stage, Priority 70):
  _physics_process:
    entities = CDGroupRegistry.query("some_group")
    for entity in entities:
      entity.entity_bus.emit(signal_name, args)
```

Directors calculate positions, generate paths, and emit movement commands. Entities execute those commands via their own Legs. The director never sets `entity.velocity` directly.

### Pattern 2: Group-as-State

An entity's "behavior state" = which group it's in. Moving between groups = changing behavior. Entities can be in multiple groups simultaneously: a persistent category group (`"enemies"`) AND a state group (`"formation"`).

- `"enemies"` = collision/category group (always present, used by DamageOnHitArm, SwarmShootingDirector)
- `"formation"` = state group (present when in formation, used by FormationDirector)
- `"diving"` = state group (present when dive-bombing, used by AIDiveBombBrain)
- `"capturing"` = state group (present when Boss is running tractor beam)

Directors broadcast to state groups. When StateDirector transitions an entity from `"formation"` to `"diving"`, the entity naturally stops receiving formation movement commands and starts receiving dive commands.

### Pattern 3: Entity-Owned Power-Ups

**RULE: Entities must be wired for their own power-ups.**

Player entities have power-up Arms that listen for named signals on their own entity bus. Power-up entities deliver those signals via collision. The power-up entity doesn't know what it does — the player entity decides.

```
PowerUp entity:
  PowerUpDeliveryArm: on collision → emits "wingman_powerup" on collider's bus
  Deactivates self

Player entity:
  PowerupWingmanArm: hears "wingman_powerup" on own bus → spawns companion
```

This means player entities are heavier to compose, but in 99% of arcade games there's only one player entity, and each power-up can be configured precisely.

### Pattern 4: Capture-and-Replace

A generic stage pattern via **StageDirector**: when an entity is "captured," it is deactivated and replaced by a different entity (the replacement is parented to the captor). This is not Galaga-specific — any game where an entity can be hijacked, converted, or possessed uses this pattern.

```
StageDirector (Stage):
  Listens for "captured(entity, captor)" on game bus
  Looks up CDDirectorRule by entity's group
  Deactivates entity, spawns replacement, parents to captor
```

### Pattern 5: Bus Bridge (AnnouncerGuts)

Entities communicate with the game bus through **AnnouncerGuts**, which rebroadcasts signals from one bus to another. This eliminates per-signal announcer components.

```
AnnouncerGuts:
  listen_signal → rebroadcast_signal on game bus
  Optional qualifying_groups filter
  Self-reference as argument
```

### Pattern 6: Dynamic Args Pattern

When a CDTransition must emit dynamic data (player position, nearest enemy, etc.), set `emit_signal` to a zero-arg signal like `"begin_dive"`. The receiving Brain queries the required context from CDGroupRegistry. Brains that need dynamic context must document which groups they query.

Example: AIDiveBombBrain receives `"begin_dive"` (no args), then independently queries the `"players"` group via CDGroupRegistry to find the player position for path generation.

---

## Processing Order Convention

**State machine transitions run before directors query groups.**

| Role | Component | Priority | Why |
|------|-----------|----------|-----|
| State transitions | StateDirector | **65** | Transitions first — entities are in correct groups before directors query |
| All other directors | SwoopDirector, FormationDirector, SwarmShootingDirector, StageDirector | **70** | Query groups after state machine has updated membership |

Within Priority 70, director processing order is undefined. This is acceptable because directors broadcast to different state groups and don't depend on each other's output within the same frame.

---

## The Galaga Lifecycle (Full Signal Flow)

This section shows how all components compose to produce Galaga's complete enemy lifecycle. Every arrow is a signal.

```
SPAWN:
  EdgeTrapdoor creates enemies in "swooping" + "enemies" groups
  SwoopDirector queries "swooping", generates bezier curves
    → emits follow_curve(curve, speed) on each entity bus

ENTRY:
  PathFollowerLeg follows curve → emits path_finished on entity bus
  AnnouncerGuts("path_finished" → "request_formation_slot" on game bus)
  StateDirector: CDSignalTrigger("request_formation_slot")
    → transition "swooping" → "formation"
    → exit_signal "exit_swooping" on entity bus
    → emit_signal "enter_formation" on entity bus
  FormationDirector assigns slot, broadcasts move_to(slot_position) every frame

FORMATION:
  FormationDirector: every frame calculates slot positions
    (base + sine breathing + lateral step)
    → emits move_to(slot_pos) on each "formation" entity's bus
  SmoothToLeg chases moving target
  SwarmShootingDirector: timer fires
    → picks random from "enemies" → emits "shoot" on entity bus

DIVE:
  StateDirector: CDTimerTrigger(4s, variance 2s) + CDSelectRandomN(1)
    → transition "formation" → "diving"
    → exit_signal "exit_formation" (SmoothToLeg clears target)
    → emit_signal "begin_dive" on entity bus (no args — Brain queries players group)
  AIDiveBombBrain: queries "players" group, generates sine-wave attack curve → emits follow_curve
  AIRepeatActionBrain: starts on "begin_dive", emits "shoot" at intervals
  PathFollowerLeg follows attack curve

DIVE MISS:
  PathFollowerLeg finishes curve (entity off-screen bottom)
  AnnouncerGuts("path_finished" → "request_formation_slot" on game bus, qualifying: "diving")
  StateDirector: transition "diving" → "formation"
    → exit_signal "exit_diving" (AIRepeatActionBrain stops)
    → emit_signal "enter_formation"
  Entity wraps to top of screen (via ScreenWrapLeg or position reset)
  FormationDirector picks up entity, broadcasts move_to for slot assignment
  Entity rejoins formation with new slot (row-major, first available)

BOSS CAPTURE:
  StateDirector: CDTimerTrigger(15s) + CDSelectN(1)
    → transition "formation" → "diving"
    → emit_signal "begin_dive" on entity bus
  AITractorBeamBrain: detects Y threshold during dive
    → emits "capture_phase_started(self)" on game bus
  StateDirector: CDSignalTrigger("capture_phase_started")
    → transition "diving" → "capturing"
    → exit_signal "exit_diving" (AIRepeatActionBrain stops)
    → emit_signal "enter_capturing" (TractorBeamArm activates)
  TractorBeamArm: Area2D detects player collision
    → emits "captured(player_entity, self)" on game bus
  StageDirector: looks up "players" → CDDirectorRule → replacement = CapturedShip.tscn
    → deactivates player, spawns CapturedShip parented to Boss
  After beam_duration: AITractorBeamBrain emits "capture_phase_ended(self)" on game bus
  StateDirector: CDSignalTrigger("capture_phase_ended")
    → transition "capturing" → "formation"
    → exit_signal "exit_capturing" (TractorBeamArm deactivates)
    → emit_signal "enter_formation"
  Boss returns to formation, CapturedShip follows as child

RESCUE (Boss killed while holding captive):
  Boss dies → DieAtZeroHealthGuts emits "died(boss)" on game bus (synchronous)
  CapturedPlayerShip is child of Boss → receives cleanup signal
  CapturedPlayerShip's SpawnOnDeathArm fires (synchronous, before deferred queue_free)
    → spawns RescuedPlayerShip at CapturedPlayerShip's last position
  RescuedPlayerShip has AIChaseBrain:
    queries "players" group each frame → moves toward player at chase speed
  RescuedPlayerShip collides with player (via CDCollisionBuffer)
    → PowerUpDeliveryArm emits "wingman_powerup" on player's entity bus
    → PowerUpDeliveryArm emits "request_deactivate" on own entity bus (self-cleanup)
  Player's PowerupWingmanArm: spawns WingmanShip companion entity
  WingmanShip: PlayerControlBrain(same player_id), GunArm, AIFormationBrain

DEATH:
  LivesCard monitors "players" group
  When ENTIRE "players" group is empty (player + wingman all dead)
    → subtracts life, respawns player entity
```

---

## Galaga State Machine Configuration

```
StateDirector on GalagaGame (Priority 65):

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
   emit_signal: "begin_dive"      (AIDiveBombBrain generates path)

3. diving → capturing
   Trigger: CDSignalTrigger("capture_phase_started")
   Selector: CDSelectAll()
   exit_signal: "exit_diving"     (AIRepeatActionBrain stops)
   emit_signal: "enter_capturing" (TractorBeamArm activates)

4. capturing → formation
   Trigger: CDSignalTrigger("capture_phase_ended")
   Selector: CDSelectAll()
   exit_signal: "exit_capturing"  (TractorBeamArm deactivates)
   emit_signal: "enter_formation" (FormationDirector picks up)

5. diving → formation
   Trigger: CDSignalTrigger("request_formation_slot")
   Selector: CDSelectAll()
   exit_signal: "exit_diving"
   emit_signal: "enter_formation"

6. formation → diving (Boss capture dive)
   Trigger: CDCompositeTrigger(require_all=true):
     CDTimerTrigger(15.0, variance=5.0) AND
     CDGroupCountTrigger("bosses", GREATER, 0)
   Selector: CDSelectN(1)
   exit_signal: "exit_formation"
   emit_signal: "begin_dive"
   Note: from_group set to "bosses" for Boss-specific targeting
```

---

## Galaga Entity Compositions

### Player Entity

```
GalagaPlayer.tscn (CDEntity):
  - PlayerMoveBrain — listens to input, emits "move"
  - PlayerActionBrain — listens to input, emits "shoot" on action
  - DirectMovementLeg — horizontal movement from input
  - GunArm — fires bullets on "shoot"
  - PowerupWingmanArm — listens for "wingman_powerup", spawns companion
  - HealthpoolGuts(1) — one hit kill
  - DieAtZeroHealthGuts — deactivate on death
  - SpriteFace or VectorFace — visual
  - SoundVoice — shoot sound
  Groups: "players", "player_ship"
```

### Boss Entity

```
GalagaBoss.tscn (CDEntity):
  - AITractorBeamBrain — detects Y threshold, emits capture signals
  - TractorBeamArm — enables tractor beam hitbox
  - AIDiveBombBrain — generates dive curves on "begin_dive"
  - AIRepeatActionBrain — fires during dives (start/stop via signals)
  - PathFollowerLeg — follows curves
  - SmoothToLeg — chases formation positions
  - AnnouncerGuts(path_finished → request_formation_slot) — "FormationAnnouncer"
  - HealthpoolGuts — boss health
  - DieAtZeroHealthGuts — deactivate on death
  - PointsGuts — score value
  Groups: "enemies", "bosses"
```

### Captured Player Ship

```
CapturedPlayerShip.tscn (CDEntity, child of Boss):
  - SpriteFace — same visual as player ship
  - SpawnOnDeathArm(companion_scene = RescuedPlayerShip.tscn) — spawns rescue ship on death
  - NO Legs, no Brain — purely visual, position determined by Boss parent transform
  Groups: "captured_ships" (identification only)
```

### Rescued Player Ship

```
RescuedPlayerShip.tscn (CDEntity, spawned by CapturedPlayerShip's SpawnOnDeathArm):
  - AIChaseBrain(target_group = &"players") — homes toward player
  - PowerUpDeliveryArm(target_group = &"players", power_signal = &"wingman_powerup")
  - SpriteFace — same visual as player ship
  - CollisionShape2D — for PowerUpDeliveryArm collision detection
  Groups: "power_ups"
```

### Wingman Ship

```
WingmanShip.tscn (CDEntity, spawned by PowerupWingmanArm):
  - PlayerMoveBrain (same player_id — responds to same inputs)
  - PlayerActionBrain (same player_id)
  - DirectMovementLeg — horizontal movement
  - GunArm — fires independently
  - AIFormationBrain — follows player at offset (leader entity from "players" group)
  Groups: "players", "companion"
```

---

## Player Capture Flow

```
Boss captures player:
  TractorBeamArm emits "captured(player, boss)" on game bus
  StageDirector: CDDirectorRule for "players" → spawn CapturedPlayerShip, parent to Boss
  CapturedPlayerShip has NO Legs — position determined by Boss parent transform
  CapturedPlayerShip is purely visual + carries SpawnOnDeathArm

Boss killed while holding captive:
  Boss's DieAtZeroHealthGuts emits "died(boss)" on game bus (synchronous)
  CapturedPlayerShip receives cleanup signal → SpawnOnDeathArm fires (synchronous)
    → spawns RescuedPlayerShip at CapturedPlayerShip's last known position
  Boss and CapturedPlayerShip are queue_free()'d (deferred cleanup)
  RescuedPlayerShip activates:
    AIChaseBrain queries "players" group → moves toward player
    Visual: captured ship flies toward the active player
  RescuedPlayerShip collides with player:
    PowerUpDeliveryArm emits "wingman_powerup" on player's entity bus
    PowerUpDeliveryArm emits "request_deactivate" on own entity bus (self-cleanup)
  Player's PowerupWingmanArm: spawns WingmanShip
  WingmanShip responds to same inputs, AIFormationBrain keeps at offset
  Both in "players" group → LivesCard waits for both to die

Death:
  LivesCard: queries "players" group
  Only subtracts a life when ENTIRE "players" group is empty
  Both player and wingman must die → then respawn
```

**Spawn timing constraint:** SpawnOnDeathArm must use synchronous `add_child()`, not `call_deferred()`. Death signal processing is synchronous — spawns resolve before the deferred `queue_free()` cleanup executes. Object pooling (Plan 19.5) avoids this concern entirely since pool activation is synchronous.

---

## Validation Checklist

### ✅ Test 1: State Machine — Timer Transition
- 5 entities in `"group_a"`
- StateDirector: CDTimerTrigger(1.0s) + CDSelectRandomN(1), transition `"group_a"` → `"group_b"`
- After 1s: 1 entity moves to `"group_b"`, 4 remain in `"group_a"`
- After 2s: another moves, etc.

### ✅ Test 2: State Machine — Signal Transition
- Entity finishes path, AnnouncerGuts fires `"request_formation_slot(entity)"`
- StateDirector: CDSignalTrigger + CDSelectAll, `"swooping"` → `"formation"`
- Entity removed from `"swooping"`, added to `"formation"`
- `exit_signal` fired on entity bus, `emit_signal` fired on entity bus

### ✅ Test 3: State Machine — No Double Transition
- 5 entities in `"formation"`
- Two transitions with `from_group = "formation"`, both triggered by same timer
- Verify: each entity transitions at most once per frame
- Verify: first transition in array wins

### ✅ Test 4: Formation Breathing
- FormationDirector: 5×3 grid, breathing_amplitude=5, breathing_frequency=2
- 15 entities in `"formation"` with SmoothToLeg
- Entities visibly oscillate vertically while maintaining grid positions

### ✅ Test 5: Swoop Entry
- 10 enemies spawned in `"swooping"` group at screen edge
- SwoopDirector generates 10 unique bezier curves
- Each entity receives `follow_curve` and follows its curve

### ✅ Test 6: Full Dive Cycle
- Entity in `"formation"` → StateDirector transitions to `"diving"`, emits `"begin_dive"`
- `exit_signal "exit_formation"` fires → SmoothToLeg clears target
- AIDiveBombBrain generates sine-wave curve → `follow_curve`
- AIRepeatActionBrain starts on `"begin_dive"`, fires during dive
- Path finishes → AnnouncerGuts fires `"request_formation_slot"`
- StateDirector transitions `"diving"` → `"formation"`, `exit_signal "exit_diving"` stops AIRepeatActionBrain
- FormationDirector picks up entity, broadcasts move_to for new slot

### ✅ Test 7: Boss Capture (Routed Through StateDirector)
- Boss entity with AITractorBeamBrain in `"diving"` group
- Entity reaches Y threshold → AITractorBeamBrain emits `"capture_phase_started(entity)"` on game bus
- StateDirector: CDSignalTrigger → transition `"diving"` → `"capturing"`
  - `exit_signal "exit_diving"` → AIRepeatActionBrain stops
  - `emit_signal "enter_capturing"` → AITractorBeamBrain activates beam
- Player enters beam → `"captured(player, boss)"` on game bus
- StageDirector: deactivates player, spawns CapturedShip parented to Boss
- Beam timer expires → AITractorBeamBrain emits `"capture_phase_ended(entity)"` on game bus
- StateDirector: transition `"capturing"` → `"formation"`
  - `exit_signal "exit_capturing"` → TractorBeamArm deactivates
  - `emit_signal "enter_formation"` → FormationDirector picks up
- Boss returns to formation with CapturedShip attached

### ✅ Test 8: Rescue + Double Ship
- Boss killed → CapturedPlayerShip's SpawnOnDeathArm spawns RescuedPlayerShip (synchronous)
- RescuedPlayerShip's AIChaseBrain homes toward player
- RescuedPlayerShip collides with player → PowerUpDeliveryArm emits `"wingman_powerup"` on player bus
- RescuedPlayerShip deactivates (PowerUpDeliveryArm self-cleanup)
- PowerupWingmanArm spawns WingmanShip
- WingmanShip responds to same inputs, AIFormationBrain keeps at offset
- Both in `"players"` group → LivesCard waits for both to die

### ✅ Test 9: SwarmShootingDirector
- 20 entities in `"enemies"` group, each with GunArm
- SwarmShootingDirector: interval=1.5s, shoot_count=2, RANDOM
- Every 1.5s, 2 random enemies fire

### ✅ Test 10: Composite Trigger (Event + Evaluative)
- StateDirector: CDCompositeTrigger(require_all=true) with:
  - CDTimerTrigger(5.0) — event trigger
  - CDGroupCountTrigger("formation", GREATER, 0) — evaluative guard
- Timer fires → check if formation count > 0 → only then transition
- Kill all formation entities → timer still fires but guard prevents transition

---

## Risks & Open Questions

1. **StateDirector performance with many transitions:** Each `_physics_process` evaluates timer triggers. With 5–10 transitions, trivial. Timer triggers only evaluate on their interval. **Mitigation:** Guard rule prevents per-frame evaluation except for timer ticks.

2. **FormationDirector slot release timing:** When StateDirector removes entity from `"formation"`, FormationDirector detects on next frame. **Mitigation:** Verify `is_instance_valid()` and group membership before emitting `move_to`. Clean up invalid slots immediately.

3. **PowerUpDeliveryArm and entity bus access:** Power-up entity emits on collider's bus. **Mitigation:** Same guard pattern as DamageOnHitArm (Plan 22) — `is_instance_valid()` + signal existence check.

4. **AIFormationBrain lead entity identification:** Need to distinguish lead from companion within the same group. **Mitigation:** Use `"lead_player"` sub-group on the main player entity, or check `"companion"` sub-group to exclude companions. Small groups make this cheap.

5. **AIDiveBombBrain curve generation:** Sine-wave path smoothness depends on intermediate point count. **Mitigation:** Start with ~20 points per curve.

6. **StageDirector and entity parenting:** Parented replacements should not have movement components. **Mitigation:** Document in CDDirectorRule. Galaga's CapturedPlayerShip has no Legs.

7. **Signal name typos:** Dynamic `emit_signal()` calls have zero type safety. **Mitigation:** StateDirector validates all signal names on `_on_initialize()` via `push_warning()`. Future: cross-cutting signal constants file.

8. **SpawnOnDeathArm spawn timing:** Spawns must be synchronous (`add_child()`, not `call_deferred()`) to resolve before the deferred `queue_free()` cleanup of the dying parent entity. **Mitigation:** Document in SpawnOnDeathArm. Object pooling (Plan 19.5) eliminates this concern since pool activation is synchronous.

---

## Future Work

**SwarmShootingDirector BOTTOM_ROW mode:** Deferred until Space Invaders.

**CDSelectFilteredN selector:** A selector that filters by an additional group. Eliminates the need for a separate Boss capture transition.

**Power-up modification pattern:** For power-ups that modify the player (speed boost, spread shot), a runtime component injection pattern may be needed. Deferred until a game requires it.

**Signal name constants file:** Cross-cutting quality pass across all plans.

**AnimatedFace + ActionStateGuts:** Deferred from Plan 24.

**Galaga proof-of-concept scene:** Assembling all components into a playable Galaga game to prove the architecture end-to-end.