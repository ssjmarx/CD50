# Plan 29: V2 Cleanup — Architectural Consistency & Pattern Refactors

## Overview

**Status: 🔲 Planning**

This plan captures the findings of an architectural review of the V2 codebase against `COMBINED_READMES.md`. The review surfaced two classes of issues: **inconsistencies** (scripts that break their category's pattern) and **inefficient patterns** (established patterns worth refactoring). Several of these are openly admitted in the READMEs — "documented" does not mean "good," and the cleanup formalizes the fixes.

**Motivation:** The V2 architecture is component-heavy (165+ components across marks, projectors, speakers, managers, directors, trapdoors, etc.). Inconsistencies in how base-class contracts are honored create silent drift and a maintenance trap as the component count grows. Centralizing the repetitive boilerplate (connect/disconnect loops, per-frame gating) reduces both bugs and per-frame cost.

**Depends on:** Plan 28 (CDStage + CDBody — introduces `_bus_connections` tracking on base classes, which this plan builds on)

---

## Findings Catalog

Findings are grouped A (inconsistencies) and B (inefficient patterns). Each maps to one or more work items in the File Manifest.

### A. Inconsistencies

| # | Finding | Category | Priority |
|---|---------|----------|----------|
| A1 | Marks `super()` / replication split | game components/marks | High |
| A2 | Projectors use two incompatible base classes | game components/projectors | High |
| A3 | `MusicSpeaker` hardcodes trigger signals | game components/speakers | Medium |
| A4 | `MusicSpeaker` dead exports (`idle_volume_db`, `fade_in_duration`) | game components/speakers | Low |
| A5 | `GridTrapdoor` rewrites the whole `_on_trigger()` lifecycle | game components/trapdoors | High |
| A6 | `ScoreManager` is the only manager without `reset()` | game components/managers | Medium |

### B. Inefficient Patterns

| # | Finding | Category | Priority |
|---|---------|----------|----------|
| B1 | Blackboard key-collision coordination is manual | core + all consumers | Architectural |
| B2 | Trigger connect/disconnect boilerplate duplicated everywhere | core + all consumers | High |
| B3 | Managers spin `_physics_process` every frame; only `SignalManager` gates idle | game components/managers | Medium |
| B4 | Bus signals are all zero-arg → write-before-emit coupling is undocumented | core | Low |
| B5 | Cleanup contract (`_exit_tree` disconnect) is uneven and unenforced | core + all consumers | High |

---

## A1: Marks `super()` / replication split

### Problem

`CDMark` subclasses have three different relationships to `_on_body_entered`/`_on_body_exited`:
- `CountMark`, `TimedMark` — **replicate** base enter/exit behavior (copy-paste blackboard write + `on_entered` emit) without calling `super()`.
- `OccupancyMark`, `SafeZoneMark` — **replace** it entirely (emit only their own signals).
- `MobileMark` — does not override detection.

"Replicate without super" means the base contract is duplicated by hand. If `CDMark` ever changes its enter semantics, `CountMark`/`TimedMark` silently drift.

### Solution

Split the base enter/exit into shared work + a hook subclasses override, and expose explicit helpers so subclasses declare intent rather than copy-pasting.

**File:** `game components/marks/cd_mark.gd` — modified

```gdscript
## Shared enter handling. Calls filter, blackboard write, and game-bus/entity-bus
## emissions. Subclasses should call this (or _emit_enter) rather than duplicate it.
func _on_body_entered(body: Node2D) -> void:
    if not _passes_filter(body):
        return
    _handle_body_entered(body)

## Override point for subclasses. Default does the shared work.
func _handle_body_entered(body: Node2D) -> void:
    game.blackboard[entered_body_key] = body
    _emit_enter(body)

## Emit-only helpers, callable from subclass overrides.
func _emit_enter(body: Node2D) -> void:
    for sig in on_entered:
        game.bus_emit(sig)
    if body is CDEntity:
        for sig in on_entered_entity:
            (body as CDEntity).bus_emit(sig)

func _emit_exit(body: Node2D) -> void:
    for sig in on_exited:
        game.bus_emit(sig)
    if body is CDEntity:
        for sig in on_exited_entity:
            (body as CDEntity).bus_emit(sig)
```

Symmetric `_handle_body_exited` / `_emit_exit` for the exit path.

### Migration

- `CountMark`, `TimedMark` — replace their replicated blocks with `_emit_enter(body)` / `_emit_exit(body)` calls.
- `OccupancyMark`, `SafeZoneMark` — override `_handle_body_entered` without calling super; they already emit only their own signals.
- `MobileMark` — no change (doesn't override detection).
- Each subclass gets a header comment documenting whether base enter/exit emissions fire.

---

## A2: Projectors use two incompatible base classes

### Problem

- `CRTProjector` extends `CDGameComponent` → inherits `game`, `bus_connect`, `_on_initialize()`.
- `CreditProjection` extends `Control` → manually re-resolves `CDGame.find_ancestor(self)` into `_game`, hand-rolls `Engine.is_editor_hint()` guard, `call_deferred("_on_initialize")`, and `_game.bus_connect(...)`.

`CreditProjection` reinvents the `CDGameComponent` lifecycle because it needs to be a `Control`.

### Solution

Introduce a `CDGameControl` base that mirrors the `CDGameComponent` contract for `Control`-rooted nodes.

**File:** `game components/projectors/cd_game_control.gd` — **New**

```gdscript
class_name CDGameControl
extends Control

var game: CDGame
var _bus_connections: Array[Dictionary] = []

func _ready() -> void:
    if Engine.is_editor_hint():
        return
    process_physics_priority = 70
    call_deferred("_on_initialize")

func _on_initialize() -> void:
    game = CDGame.find_ancestor(self)
    if not game:
        push_warning("CDGameControl '%s' has no CDGame ancestor." % name)
        return
    ## subclass init here

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

### Migration

- `credit_projection.gd` — change `extends Control` → `extends CDGameControl`; drop the manual `_game`/`_ready`/`_on_initialize` ancestor code; use inherited `game` and `bus_connect`.

---

## A3: `MusicSpeaker` hardcodes trigger signals

### Problem

`ContinuousSpeaker` and `SoundSpeaker` expose configurable `StringName` trigger exports. `MusicSpeaker` hardcodes `bus_connect("game_play", …)` / `bus_connect("game_over", …)` with no exports, breaking the folder's contract and making it unusable for any other trigger pair.

### Solution

**File:** `game components/speakers/music_speaker.gd` — modified

Add configurable trigger exports mirroring the sibling speakers:

```gdscript
@export_group("Trigger Signals")
@export var start_signal: StringName = &"game_play"
@export var stop_signal: StringName = &"game_over"

func _on_initialize() -> void:
    _ensure_players()
    bus_connect(start_signal, _on_game_play)
    bus_connect(stop_signal, _on_game_over)
```

Existing scenes using the defaults (`game_play` / `game_over`) require **no changes** — behavior is preserved.

---

## A4: `MusicSpeaker` dead exports

### Problem

`idle_volume_db` and `fade_in_duration` are exported to the inspector but not driven by the script body. Exposing controls that silently do nothing is misleading.

### Solution

**File:** `game components/speakers/music_speaker.gd` — modified

- Wire `fade_in_duration` into `_play_next()`'s initial volume tween (currently hard-coded to a tween to `volume_db` with no fade-in parameter).
- Wire `idle_volume_db` as the resting level the non-active player holds between tracks, or remove it if the dual-player crossfade never actually idles a player.

Decision required from review: **implement or remove.** Default recommendation: implement `fade_in_duration` (cheap, matches doc intent), remove `idle_volume_db` unless a use case is identified.

---

## A5: `GridTrapdoor` rewrites the whole lifecycle

### Problem

`EdgeTrapdoor` and `PointTrapdoor` cleanly override only the three virtuals (`_get_spawn_count/_position/_scene`). `GridTrapdoor` overrides `_on_trigger()` **entirely** (no `super()`) and hand-replicates: the GAME_OVER guard, reading `wave_number` from the blackboard, populating `_spawn_queue`, resetting `_spawn_timer`, and `set_physics_process(true)`.

### Solution

Extract the queue-population step into a virtual on the base class so `GridTrapdoor` injects its Mode A/B logic without touching the lifecycle.

**File:** `core/base classes/cd_stage_trapdoor.gd` — modified

```gdscript
## Override to populate _spawn_queue with indices for this wave.
## Default: fills 0 .. count-1 where count = _get_spawn_count(wave_number).
func _populate_spawn_queue(wave_number: int) -> void:
    var total := _get_spawn_count(wave_number)
    _spawn_queue.clear()
    for i in total:
        _spawn_queue.append(i)

func _on_trigger() -> void:
    if game.current_state == CDEnums.GameState.GAME_OVER:
        return
    var wave_number: int = game.blackboard.get(wave_key, 0)
    _populate_spawn_queue(wave_number)
    _spawn_timer = 0.0
    set_physics_process(true)
```

### Migration

**File:** `game components/trapdoors/grid_trapdoor.gd` — modified

- Delete the overridden `_on_trigger()`.
- Move Mode A/B logic into `_populate_spawn_queue(wave_number)`.
- Keep `_get_spawn_position`, `_get_spawn_scene` overrides as-is.

`EdgeTrapdoor` and `PointTrapdoor` require **no changes** — they inherit the default `_populate_spawn_queue`.

---

## A6: `ScoreManager` missing `reset()`

### Problem

The README explicitly notes "all managers here except `ScoreManager` do this." It's ambiguous whether this is intentional (score persists across restart) or an oversight.

### Solution

**File:** `game components/managers/score_manager.gd` — modified

Decision required from review:
- **If score should reset on restart:** add a `reset()` that clears accumulated score state and calls `reset()` on any data resources, mirroring the sibling managers.
- **If score should persist:** add an explicit comment documenting the intentional omission, so the next reader isn't left guessing.

Default recommendation: **add `reset()`** for consistency; if a game wants persistent score, it can opt out by not calling it or by re-reading from a save resource. Confirm with the reviewer.

---

## B1: Blackboard key-collision coordination is manual (architectural)

### Problem

Every mark defaults to shared keys (`&"mark_entered_body"`, `&"mark_count"`, etc.). The README's mitigation is "change the keys to avoid collisions." This pushes global coordination onto every scene author.

### Solution

Two options, presented as a decision for the reviewer:

**Option B1-i — Auto-namespacing (default-safe, opt-out):**
Marks derive their default blackboard keys from a stable per-node prefix (e.g., node name or index) unless a key is explicitly set. Collision-free by default; explicit keys remain available for cross-node coordination.

**Option B2-ii — Typed key resources:**
Introduce a `CDBlackboardKey` resource that authors assign in the inspector. Collisions surface at authoring time (duplicate resource assignment is visible) rather than runtime.

**Recommendation:** Defer this to a follow-up plan. It is the largest scope change (touches every blackboard consumer) and deserves its own design pass. **Filed as Future Work in this plan** — no implementation in Plan 29.

---

## B2 + B5: Trigger connect/disconnect boilerplate + uneven cleanup contract

### Problem (combined — same root cause)

Across marks, projectors, speakers, and managers there's a recurring loop:
```gdscript
for sig in some_signals:
    game.bus_connect(sig, _handler)
```
…plus a mirror disconnect loop in `_exit_tree()`. This is duplicated everywhere. The cleanup contract (`_exit_tree` disconnect) is uneven — `CRTProjector` guards with `if game:`, `CreditProjection`'s path is described loosely, speakers guard inconsistently.

### Solution

Add `connect_all` / `disconnect_all` helpers to the base classes (which already track `_bus_connections` per Plan 28), and a base-managed `_exit_tree` auto-disconnect so the contract is automatic.

**Files:**
- `core/base classes/cd_game_component.gd` — modified
- `core/base classes/cd_entity_component.gd` — modified
- `game components/projectors/cd_game_control.gd` — (from A2)

```gdscript
## Connect to every signal in the array; tracked for auto-disconnect on _exit_tree.
func connect_all(signals: Array[StringName], callable: Callable) -> void:
    for sig in signals:
        bus_connect(sig, callable)

## Disconnect from every signal in the array.
func disconnect_all(signals: Array[StringName], callable: Callable) -> void:
    for sig in signals:
        bus_disconnect(sig, callable)

## Auto-disconnect all tracked connections when leaving the tree.
func _exit_tree() -> void:
    if game:
        for entry in _bus_connections.duplicate():
            game.bus_disconnect(entry["signal_name"], entry["callable"])
    if entity:
        for entry in _bus_connections.duplicate():
            entity.bus_disconnect(entry["signal_name"], entry["callable"])
```

> ⚠️ If a base class already implements `_exit_tree`, subclasses that currently override it must call `super._exit_tree()` (or the auto-disconnect is skipped). This is a migration step per file.

### Migration

Replace the connect/disconnect loops in every component with `connect_all`/`disconnect_all`. This is a mechanical sweep — see File Manifest for the full list.

---

## B3: Managers spin `_physics_process` every frame

### Problem

`StateManager`, `StageManager`, and others run `_physics_process` every frame evaluating resource triggers. Only `SignalManager` toggles `set_physics_process(false)` when idle. The others spin every frame even when nothing can fire.

### Solution

Apply `SignalManager`'s idle-gating pattern to all managers whose triggers are signal/timer-based (not continuous-condition). When all resources are waiting on a signal or timer, disable physics processing; re-enable on the triggering signal.

**Files:**
- `game components/managers/state_manager.gd` — modified
- `game components/managers/stage_manager.gd` — modified

Pattern (mirroring `SignalManager`):
```gdscript
func _on_initialize() -> void:
    super._on_initialize()
    set_physics_process(false)
    for transition in transitions:
        transition.fired.connect(_on_transition_fired)  # re-enable physics

func _on_transition_fired() -> void:
    set_physics_process(true)
```

**Caveat:** Managers whose triggers are continuous-condition (evaluated every frame by design) must keep physics processing on. Audit each manager before applying.

---

## B4: Bus signals all zero-arg → write-before-emit coupling

### Problem

The architecture routes all event data through the blackboard (write key, *then* emit zero-arg signal). This creates temporal coupling: a listener reading the blackboard assumes the writer just set it.

### Solution

This is low-risk and primarily a documentation fix in this plan:

- Add the "write-before-emit" contract as a hard rule to `CONVENTIONS.md`.
- File the larger question (optional typed bus payloads for genuinely local event data) as Future Work.

**File:** `CONVENTIONS.md` — modified (add Bus Signals section)

---

## File Manifest

### New Files

| File | Source finding | Summary |
|------|---------------|---------|
| `game components/projectors/cd_game_control.gd` | A2, B2 | `CDGameControl` base — Control-rooted nodes get the `CDGameComponent` contract + tracked connections |

### Modified Files

| File | Source findings | Summary |
|------|----------------|---------|
| `game components/marks/cd_mark.gd` | A1 | Split `_on_body_entered` into `_handle_body_entered` + `_emit_enter`/`_emit_exit` helpers |
| `game components/marks/count_mark.gd` | A1, B2 | Use `_emit_enter`/`_emit_exit`; replace loops with `connect_all` |
| `game components/marks/timed_mark.gd` | A1, B2 | Use `_emit_enter`/`_emit_exit`; replace loops with `connect_all` |
| `game components/marks/occupancy_mark.gd` | A1, B2 | Override `_handle_body_entered`; replace loops with `connect_all` |
| `game components/marks/safe_zone_mark.gd` | A1, B2 | Override `_handle_body_entered`; replace loops with `connect_all` |
| `game components/marks/mobile_mark.gd` | B2 | Replace loops with `connect_all` |
| `game components/projectors/credit_projection.gd` | A2, B2 | Extend `CDGameControl`; drop manual ancestor/lifecycle code |
| `game components/projectors/crt_projector.gd` | B2 | Replace loops with `connect_all`; call `super._exit_tree()` |
| `game components/speakers/music_speaker.gd` | A3, A4, B2 | Configurable trigger signals; wire/remove dead exports; `connect_all` |
| `game components/speakers/continuous_speaker.gd` | B2 | `connect_all` |
| `game components/speakers/sound_speaker.gd` | B2 | `connect_all` |
| `core/base classes/cd_stage_trapdoor.gd` | A5 | Add `_populate_spawn_queue` virtual; simplify `_on_trigger` |
| `game components/trapdoors/grid_trapdoor.gd` | A5 | Delete `_on_trigger` override; move logic to `_populate_spawn_queue` |
| `game components/managers/score_manager.gd` | A6 | Add (or explicitly document) `reset()` |
| `game components/managers/state_manager.gd` | B2, B3 | `connect_all`; idle physics gating |
| `game components/managers/stage_manager.gd` | B2, B3 | `connect_all`; idle physics gating |
| `game components/managers/signal_manager.gd` | B2 | `connect_all` (already gates physics — reference pattern) |
| `core/base classes/cd_game_component.gd` | B2, B5 | `connect_all`/`disconnect_all`; `_exit_tree` auto-disconnect |
| `core/base classes/cd_entity_component.gd` | B2, B5 | `connect_all`/`disconnect_all`; `_exit_tree` auto-disconnect |
| `CONVENTIONS.md` | B4 | Document write-before-emit bus contract |

**Total: 1 new script, 19 modified scripts/docs**

---

## Validation Checklist

### ✅ A1 — Marks
- [ ] `CountMark` enter path fires base `on_entered` + `entered_body_key` via `_emit_enter`, not duplicated code
- [ ] `TimedMark` enter/exit path same
- [ ] `OccupancyMark` enter fires only `on_occupancy_changed` (no base `on_entered`)
- [ ] `SafeZoneMark` enter fires only `on_zone_unsafe`/`on_zone_safe`
- [ ] All four subclasses have header comments documenting their emit behavior
- [ ] Changing `CDMark._handle_body_entered` propagates to all subclasses

### ✅ A2 — Projectors
- [ ] `CreditProjection` extends `CDGameControl` and no longer references `CDGame.find_ancestor` or `_game` directly
- [ ] `CreditProjection` uses inherited `game` and `bus_connect`
- [ ] `_on_track_changed` still fires on the configured `track_changed_signals`

### ✅ A3 — MusicSpeaker triggers
- [ ] `MusicSpeaker` exposes `start_signal` / `stop_signal` exports
- [ ] Existing scenes using defaults (`game_play`/`game_over`) work unchanged
- [ ] A scene wiring custom signals (e.g. `round_start`/`round_end`) drives playback correctly

### ✅ A4 — MusicSpeaker dead exports
- [ ] `fade_in_duration` drives the initial volume tween in `_play_next`
- [ ] `idle_volume_db` is either wired or removed (per review decision)

### ✅ A5 — GridTrapdoor lifecycle
- [ ] `GridTrapdoor` no longer overrides `_on_trigger`
- [ ] `GridTrapdoor._populate_spawn_queue` handles Mode A (layout) and Mode B (equation)
- [ ] GAME_OVER guard still applies (inherited from base)
- [ ] `on_spawning_complete` still fires when the queue empties
- [ ] `EdgeTrapdoor` and `PointTrapdoor` spawn behavior unchanged

### ✅ A6 — ScoreManager reset
- [ ] `ScoreManager.reset()` exists and clears accumulated score (or omission is documented as intentional)
- [ ] Game restart calls `reset()` on all managers uniformly

### ✅ B2 + B5 — connect_all / auto-disconnect
- [ ] Every mark, projector, speaker, manager uses `connect_all` instead of manual loops
- [ ] Removing a component from the tree leaves zero dangling bus connections (verified via connection count before/after)
- [ ] Subclass `_exit_tree` overrides call `super._exit_tree()`

### ✅ B3 — Manager idle gating
- [ ] `StateManager` disables physics when no transition can fire
- [ ] `StageManager` same
- [ ] A signal-driven transition re-enables physics for the frame it needs
- [ ] Continuous-condition managers (if any) are left untouched

### ✅ B4 — Bus contract docs
- [ ] `CONVENTIONS.md` has a "Bus Signals" section stating the write-before-emit rule

---

## Risks & Open Questions

1. **Marks API change is breaking for any external consumer.** Splitting `_on_body_entered` changes the override surface. **Mitigation:** `_on_body_entered` itself stays public and still calls the shared work; only the internal `_handle_body_entered` hook is new. External subclasses written against the old pattern still work but should migrate.

2. **`CDGameControl` vs `CDGameComponent` overlap.** Both now track `_bus_connections` and offer `connect_all`. Any future base-class change must be applied to both. **Mitigation:** Keep the two in lockstep; consider whether `CDGameControl` could be merged into the `CDGameComponent` hierarchy via a shared mixin if Godot's class constraints allow.

3. **`connect_all` + manual `bus_connect` mixes.** Components that mix `connect_all` with direct `bus_connect` calls will have some tracked and some untracked connections. The auto-disconnect in `_exit_tree` only handles tracked ones. **Mitigation:** Document that `connect_all` is the preferred entry point; direct `bus_connect` is for single-connection cases.

4. **Idle gating can miss the first-frame edge case.** If a manager disables physics in `_on_initialize` and a trigger signal fires in the same frame before any connection is live, the manager won't wake. **Mitigation:** Wire wake-on-signal connections *before* disabling physics; verify ordering in each manager's `_on_initialize`.

5. **B1 (blackboard key collisions) is deferred.** This is the largest scope change and is filed as Future Work. Plan 29 ships the smaller wins; a dedicated plan should handle auto-namespacing or typed keys.

6. **A6 is a decision point, not a mechanical change.** Whether `ScoreManager` should reset on restart depends on game-design intent. Needs reviewer confirmation before implementation.

---

## Future Work

- **B1 — Blackboard key auto-namespacing or typed key resources.** Largest scope; deserves its own plan. Affects every blackboard consumer.
- **B4 — Optional typed bus payloads.** Allow non-zero-arg bus signals for genuinely local event data (e.g. body-entered with the body as arg), reserving the blackboard for cross-system shared state. Requires a bus API extension.
- **`CDGameControl` / `CDGameComponent` convergence.** If Godot permits, unify the shared connection-tracking + lifecycle code into a single mixin or intermediate base to avoid lockstep maintenance.
- **Component sweep for direct `entity.bus_connect()` / `game.bus_connect()` calls.** Plan 28 flagged these as untracked; a follow-up migration to `self.bus_connect()` would make all components trackable by CDBody/CDStage sleep.