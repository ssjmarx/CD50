# Plan 24: V2 Faces, Voices, Projections & Speakers

## Overview

Audio and visual components for V2. Replaces V1's `sound_synth.gd`, `SoundBank` autoload, `music_player.gd`, `crt_controller.gd`, and entity `_draw()` calls with a clean five-layer architecture:

| Layer | Scope | Bus | Components |
|-------|-------|-----|------------|
| Infrastructure | CDGame child | Game bus | CDSoundBank |
| Projections | CDGame child (visual) | Game bus | CRTProjection, CreditProjection, MenaceProjection |
| Speakers | CDGame child (audio) | Game bus | MusicSpeaker, SoundSpeaker, ContinuousSpeaker |
| Faces | CDEntity child | Entity bus | SpriteFace, VectorFace, EngineFace, ThrusterFace |
| Voices | CDEntity child | Entity bus | SoundVoice, ContinuousVoice |

**Base class split follows the V2 convention:**
- **Faces and Voices** extend `CDComponent2D` (entity children). Faces use `ComponentCategory.FACE` (Priority 60). Voices use `ComponentCategory.VOICE` (Priority 65).
- **Speakers and Projections** extend `CDStageComponent2D` (CDGame children) except where a different base is required (CreditProjection extends Control, CRTProjection extends Node2D for shader pipeline). These use `ComponentCategory.STAGE` (Priority 70).
- **CDSoundBank** extends `CDStageComponent2D` — it's a CDGame child with no entity reference.

---

## V1 Migration

| V1 | V2 | Notes |
|----|-----|-------|
| `SoundBank` autoload | `CDSoundBank` CDComponent2D | Hybrid: logic on game tree, AudioStreamPlayers at root |
| `sound_synth.gd` (CONTINUOUS) | `ContinuousVoice` or `ContinuousSpeaker` + CDSoundBank | Ultra-thin — just registers/deregisters |
| `sound_synth.gd` (ON_SIGNAL) | `SoundVoice` + CDSoundBank | Sends CDSoundDef to bank on trigger |
| `sound_synth.gd` (ON_SPAWN) | `SoundVoice` (auto-trigger) + CDSoundBank | Plays immediately on ready |
| `music_player.gd` (playback) | `MusicSpeaker` | Playlist + crossfade + loop-points |
| `music_player.gd` (credit overlay) | `CreditProjection` (Control) | Receives `"track_changed"` from MusicSpeaker |
| `music_player.gd` (speed ramping) | External controller → `MusicSpeaker.pitch_scale` | Decoupled — any component can ramp |
| `music_ramping.gd` | Controller listens to game bus, sets pitch | Simple bridge component |
| `sfx_ramping.gd` | Controller listens to game bus, sets CDSoundBank param | Simple bridge component |
| `sound_on_hit.gd` | `SoundVoice` with trigger_signal = `"collision"` | Entity bus connection |
| `crt_controller.gd` | `CRTProjection` | + `"crt_on"` / `"crt_off"` game bus signals |
| `interface.gd` | ScoreCard with `is_interface=true` (Plan 20) | Already covered |
| Entity `_draw()` calls | `SpriteFace` or `VectorFace` | Drawing moves out of body scripts |
| `vector_engine_exhaust.gd` | `EngineFace` | Single flickering triangle exhaust |
| `vector_thruster_exhaust.gd` | `ThrusterFace` | Four X-pattern maneuvering jets |
| `polybius_face` / `godot_logo` menace | `MenaceProjection` | Generalized, signal-triggerable |

---

## CDSoundBank: Hybrid Architecture

### The SubViewport Problem

In arcade mode, CDGame lives inside a SubViewport. `AudioStreamPlayer` / `AudioStreamPlayer2D` nodes inside SubViewports don't produce audio in the main output in Godot 4's Compatibility renderer. This is the fundamental reason V1's `SoundBank` is an autoload.

### Why Not AudioListener2D?

`AudioListener2D` defines *where* positional audio is heard from (panning/attenuation). It does NOT route audio out of a SubViewport. Enabling `audio_listener_enable` on a SubViewport just makes positional audio work within that viewport's coordinate space.

### Solution: CDAudioBus + CDSoundBank

Audio routing uses a dedicated **CDAudioBus** (AudioBus layout) rather than parenting individual players to `get_tree().root`. CDSoundBank is a CDStageComponent2D child of CDGame (for tree discoverability and lifecycle binding), and all its audio output routes through the CDAudioBus which is always in the main audio output.

**CDAudioBus (AudioBus Layout):**
- Created in Godot's Audio Bus editor (not via code)
- Named `"CD_Audio"` — all V2 audio routes through this bus
- Allows game-level volume control, effects, and muting without touching individual players
- Each CDGame instance could theoretically have its own bus for multi-game arcade mode (future consideration)
- The bus persists across scene reloads since it's part of the project's audio bus layout

**CDSoundBank node placement:**
- Logic lives as a CDStageComponent2D child of CDGame (tree discoverability, lifecycle binding)
- AudioStreamPlayer nodes are created as children of CDSoundBank itself
- AudioStreamPlayer nodes output to the `"CD_Audio"` bus, which always reaches the main output
- When CDGame is freed, CDSoundBank is freed with it, cleaning up all players

This gives:

1. **Tree discoverability:** `get_game().get_node("CDSoundBank")`
2. **CDGame lifecycle binding:** auto-cleanup when game freed
3. **Correct audio routing:** always audible, even in arcade mode, via the CDAudioBus
4. **No singleton:** follows V2 architecture
5. **No root-level node parenting:** cleaner than V1's approach of parenting to `get_tree().root`

---

## What Gets Built

### 1. CDSoundDef
**Type:** Custom Resource (extends Resource)
**Purpose:** Describes a sound — single note or multi-note jingle. Used by SoundVoice and SoundSpeaker.

**Modes:**
- `SINGLE`: One note. The familiar V1 pattern.
- `JINGLE`: Array of note/duration pairs played in sequence. New for V2.

| Property | Type | Description |
|----------|------|-------------|
| `mode` | `Enum { SINGLE, JINGLE }` | Single note or sequence |
| `wave_shape` | `Enum { SINE, SQUARE, SAWTOOTH, TRIANGLE, NOISE }` | Waveform |
| `effect` | `Enum { NONE, WARBLE, TREMOLO, SWEEP_DOWN, DECAY }` | Audio effect |
| `note` | `Semitone` | Note for SINGLE mode |
| `volume` | `float` | Volume (0.0–1.0) |
| `duration` | `float` | Duration for SINGLE mode |
| `jingle_notes` | `Array[JingleNote]` | Note sequence for JINGLE mode |

**JingleNote sub-resource:**

| Property | Type | Description |
|----------|------|-------------|
| `note` | `Semitone` | MIDI note number |
| `duration` | `float` | Duration in seconds |

**Rationale:** V1 assumes single beeps for everything. Jingle support unlocks game-start stings, victory fanfares, defeat sounds, combo chimes, etc. — all without creating separate components per jingle. Not applicable to Continuous* components (continuous sounds don't have discrete note sequences).

### 2. CDSoundBank
**Type:** CDStageComponent2D child of CDGame (`ComponentCategory.STAGE`)
**Purpose:** Centralized audio generation, polyphony management, voice deduplication, buffer fill, and jingle sequencing.

**Hybrid audio routing:** Logic lives on game tree. AudioStreamPlayer nodes live at `get_tree().root`.

**Polyphony limit:** Godot supports a finite number of concurrent `AudioStreamPlayback` instances (typically 16–32 depending on platform). CDSoundBank must enforce a hard cap on simultaneous one-shots. When the cap is reached, new requests either skip silently or steal the oldest playing one-shot (configurable). Document this limit clearly — arcade games with many simultaneous sound effects (Asteroids, Robotron) will hit it.

| Method | Description |
|--------|-------------|
| `play_one_shot(def: CDSoundDef, position: Vector2, positional: bool, exclusive: bool, caller_id: int)` | Play a single note or jingle sequence |
| `start_continuous(signature: String, wave_shape, effect, note, volume, caller_id)` | Register a continuous voice |
| `stop_continuous(signature: String, caller_id)` | Deregister a continuous voice |
| `pause_continuous(signature: String, caller_id)` | Temporarily pause (gameplay gating) |
| `resume_continuous(signature: String, caller_id)` | Resume from pause |

**Internal state:**
- `_active_one_shots: Dictionary` — currently playing one-shots
- `_continuous_voices: Dictionary` — signature → { callers, AudioStreamPlayer, params }
- `_jingle_queue: Array` — pending jingle notes with timing

**Process:**
1. Fill audio buffers for all active continuous voices (same as V1 SoundBank).
2. Advance jingle sequences — push next note samples when current note duration expires.
3. Clean up finished one-shots.

**Voice deduplication (from V1):** Multiple entities requesting the same signature (wave+effect+note) share one AudioStreamPlayer. `caller_id` tracks who's registered. Voice stops when last caller deregisters.

### 3. CDShape
**Type:** Custom Resource (extends Resource)
**Purpose:** Defines a polygon shape from a set of 2D points. Shared between VectorFace (drawing) and ShapeColliderGuts (collision). Enables the "one shape, two consumers" pattern where a single CDShape is referenced by both visual and physics components.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `points` | `PackedVector2Array` | `PackedVector2Array()` | Polygon vertices |
| `closed` | `bool` | `true` | Whether the shape is a closed polygon |

**Saved as `.tres` files** for pre-authored shapes (triangle ship, paddle outline). Created at runtime for procedural shapes (asteroids).

**Cross-references:** Consumed by VectorFace (this plan) and ShapeColliderGuts (Plan 22). CDEntity's Collision Shape API (Plan 19) is the interface ShapeColliderGuts uses to apply shapes to collision nodes.

**Runtime signal contract:** When shape points are generated at runtime (e.g., by AsteroidGuts), emit `"shape_changed(points: PackedVector2Array)"` on the entity bus. Both VectorFace (this plan) and ShapeColliderGuts (Plan 22) listen for this same signal and consume the `PackedVector2Array` directly. CDShape is a convenience for static shapes authored in the editor — it is NOT passed through the signal at runtime. This keeps ShapeColliderGuts free of CDShape dependencies and uses a native Godot type as the shared contract.

### 4. CDFaceBinding
**Type:** Custom Resource (extends Resource)
**Purpose:** Pairs a signal name to a frame index. Used by SpriteFace, VectorFace, and any visual component that needs signal-to-frame mapping.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `signal_name` | `StringName` | `&""` | Entity bus signal that triggers this frame |
| `frame_index` | `int` | `0` | Index into the component's frames array |
| `restore_after` | `float` | `0.0` | Seconds before reverting to `default_frame`. 0 = permanent. |

**Rationale:** Rather than a generic `"face_changed(int)"` signal, each frame is bound to a semantic signal name. `"collision"` shows the hurt sprite, `"shoot"` shows the muzzle flash, `"entity_deactivating"` shows the death sprite. The component auto-connects to whatever signals its bindings specify. `restore_after` handles temporary states (muzzle flash reverts to idle after 0.1s).

### 5. SpriteFace
**Type:** CDComponent2D (`ComponentCategory.FACE`)
**Purpose:** Draws a single Texture2D. Swaps texture based on signal-to-frame bindings.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `frames` | `Array[Texture2D]` | `[]` | Available textures (indexed by CDFaceBinding) |
| `default_frame` | `int` | `0` | Frame shown on spawn and after restore |
| `bindings` | `Array[CDFaceBinding]` | `[]` | Signal → frame mappings |

**Consumes:** Entity bus: whatever signal names are specified in `bindings`

**Process:**
1. In `_on_initialize()`: iterate `bindings`, connect each `signal_name` on the entity bus.
2. On signal: swap to `frames[binding.frame_index]`. If `binding.restore_after > 0`, start a timer to revert to `default_frame`.
3. On spawn: display `frames[default_frame]`.

### 6. VectorFace
**Type:** CDComponent2D (`ComponentCategory.FACE`)
**Purpose:** Draws polylines/polygons from CDShape resources. Three consumption modes: static (editor-placed shapes), binding-driven (signal swaps), and dynamic (runtime shape reception). Successor to V1's inline `_draw()` calls.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `shapes` | `Array[CDShape]` | `[]` | Pre-authored CDShape resources (indexed by CDFaceBinding) |
| `default_frame` | `int` | `0` | Shape index shown on spawn and after restore |
| `bindings` | `Array[CDFaceBinding]` | `[]` | Signal → shape index mappings |
| `color` | `Color` | `Color.WHITE` | Line color |
| `width` | `float` | `1.0` | Line width |

**Consumes:**
- Entity bus: whatever signal names are specified in `bindings` (static frame swaps)
- Entity bus: `"shape_changed(points: PackedVector2Array)"` (dynamic runtime points)

**Three Consumption Modes:**

| Mode | Trigger | Use Case |
|------|---------|----------|
| **Default** | Spawn | Draws `shapes[default_frame]` on init. Simple entities with one shape. |
| **Binding** | CDFaceBinding signal | Swaps to `shapes[binding.frame_index]`. Multi-shape entities (hurt pose, death flash). |
| **Dynamic** | `"shape_changed"` signal | Draws the received CDShape directly. Runtime-generated shapes (asteroids). |

**Process:**
1. In `_on_initialize()`: iterate `bindings`, connect each `signal_name` on the entity bus. Also connect to `"shape_changed"`.
2. On binding signal: swap to `shapes[binding.frame_index]`. If `binding.restore_after > 0`, start a timer to revert to `default_frame`. `queue_redraw()`.
3. On `"shape_changed(points: PackedVector2Array)"`: store the received points as current drawing target (use `true` for closed by default in dynamic mode). `queue_redraw()`.
4. On spawn: display `shapes[default_frame]`.
5. `_draw()`: calls `draw_polyline(current_points, color, width)` on the active shape's points. If `shape.closed`, closes the polyline.

**Editor tool support:** Tool-mode script with inspector controls for creating/editing shapes point-by-point. CDShape resources can be authored in the inspector and saved as .tres files for reuse.

**V1 examples that become VectorFace instances:**
- Triangle ship polygon: CDShape with `points = [Vector2(8,0), Vector2(-6,-5), Vector2(-4.5,-2.5), Vector2(-4.5,2.5), Vector2(-6,5), Vector2(8,0)]`
- Asteroid shapes (runtime CDShape from `"shape_changed"` signal)
- Paddle outlines (CDShape resource)
- PolybiusFace line art (multiple CDShapes indexed by CDFaceBinding)

**The Asteroid Flow (end-to-end):**
```
AsteroidGuts generates random PackedVector2Array → emits "shape_changed(points)" on entity bus
  → VectorFace hears it → draws the points as a closed polyline
  → ShapeColliderGuts (Plan 22) hears it → applies points to collision via CDEntity API
```
One `PackedVector2Array`, emitted once, consumed by two independent components via the same signal.

### 7. VectorEngineFace
**Type:** CDComponent2D (`ComponentCategory.FACE`)
**Purpose:** Single flickering triangle exhaust behind entity. Direct port of V1's `vector_engine_exhaust.gd`.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `flame_size` | `float` | `6.0` | Base flame length |
| `flame_width` | `float` | `8.0` | Base flame width at base |
| `flame_offset` | `float` | `4.0` | Distance behind entity origin |
| `color` | `Color` | `Color.WHITE` | Flame color |
| `flicker_speed` | `float` | `0.1` | Seconds between flicker updates |
| `flicker_size` | `float` | `4.0` | Max random flicker addition |

**Consumes:** Entity bus: `"thrust"`, `"end_thrust"`

**Process:**
1. On `"thrust"`: set visible, begin flickering.
2. On `"end_thrust"`: set not visible, stop drawing.
3. In `_physics_process`: flicker timer updates flame tip. `queue_redraw()` if visible.
4. `_draw()`: `draw_polyline([left, tip, right], color, 2.0)` — polyline triangle.

**V1 reference:** `Godot/Scripts/Components/vector_engine_exhaust.gd` — identical behavior, V2 signal names.

### 8. VectorThrusterFace
**Type:** CDComponent2D (`ComponentCategory.FACE`)
**Purpose:** Four X-pattern maneuvering jets. Direct port of V1's `vector_thruster_exhaust.gd`. Used on TriangleShipModern for diagonal thruster flames.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `flame_size` | `float` | `4.0` | Base flame length |
| `flame_width` | `float` | `3.0` | Base flame width |
| `distance` | `float` | `6.0` | Distance from entity center |
| `color` | `Color` | `Color.WHITE` | Flame color |
| `flicker_speed` | `float` | `0.08` | Seconds between flicker updates |
| `flicker_size` | `float` | `2.0` | Max random flicker addition |
| `audio_volume` | `float` | `0.05` | Volume for thruster noise |

**Consumes:** Entity bus: `"move(dir: Vector2)"`

**Process:**
1. On `"move"`: store direction.
2. In `_physics_process`: transform direction to local space, determine which of 4 diagonal thrusters fire (opposite to movement).
3. Flicker flame tips at `flicker_speed` intervals.
4. Audio: sends noise request to CDSoundBank when any flame active, stops when none active.
5. `_draw()`: for each active thruster, draw polyline triangle along its diagonal.

**V1 reference:** `Godot/Scripts/Components/vector_thruster_exhaust.gd` — identical behavior, audio routed through CDSoundBank instead of local AudioStreamPlayer.

### 9. SoundVoice
**Type:** CDComponent2D (`ComponentCategory.VOICE`, Priority 65)
**Purpose:** One-shot or multi-note jingle triggered by entity bus signal. Sends play request to CDSoundBank.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `sound` | `CDSoundDef` | — | Sound definition (single or jingle) |
| `trigger_signal` | `StringName` | `&""` | Entity bus signal that triggers playback |
| `filter_value` | `String` | `""` | Optional filter — only plays if first signal arg matches |
| `play_on_spawn` | `bool` | `false` | Play immediately on ready (replaces V1 ON_SPAWN mode) |
| `positional` | `bool` | `true` | Use positional audio |
| `exclusive` | `bool` | `false` | Kill previous instance before playing |
| `gameplay_only` | `bool` | `false` | Only play during PLAYING state |

**Consumes:** Entity bus: configurable via `trigger_signal`

**Process:**
1. On spawn: if `play_on_spawn`, call CDSoundBank immediately.
2. On trigger signal (with optional filter): call `CDSoundBank.play_one_shot(sound, entity.position, positional, exclusive, get_instance_id())`.
3. If `gameplay_only` and game state ≠ PLAYING, skip.

Ultra-thin. All generation, polyphony, and sequencing handled by CDSoundBank.

### 10. ContinuousVoice
**Type:** CDComponent2D (`ComponentCategory.VOICE`, Priority 65)
**Purpose:** Ongoing sound (engine hum, beam drone). Registers with CDSoundBank, deregisters on stop or exit.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `wave_shape` | `WaveShape` | `SQUARE` | Waveform |
| `effect` | `Effect` | `NONE` | Audio effect |
| `note` | `Semitone` | `C4` | Note |
| `volume` | `float` | `0.2` | Volume |
| `exclusive` | `bool` | `false` | Voice dedup — only one instance of this signature |
| `gameplay_only` | `bool` | `false` | Pause when not PLAYING |
| `start_on_spawn` | `bool` | `true` | Auto-start on ready |
| `stop_on_deactivate` | `bool` | `true` | Auto-stop when entity deactivates |

**Consumes:** Entity bus: `"start"`, `"stop"`, `"entity_deactivating"`

**Process:**
1. On spawn: if `start_on_spawn`, call `CDSoundBank.start_continuous(signature, ...)`.
2. On `"start"` signal: call `CDSoundBank.start_continuous(...)`.
3. On `"stop"` signal or `"entity_deactivating"`: call `CDSoundBank.stop_continuous(...)`.
4. In `_process`: if `gameplay_only`, pause/resume via CDSoundBank based on game state.
5. On `_exit_tree`: deregister from CDSoundBank.

**Use case example:** Engine noise that starts when thrusting and stops when releasing — entity emits `"start"` on thrust begin, `"stop"` on thrust end.

### 11. MusicSpeaker
**Type:** CDStageComponent2D (`ComponentCategory.STAGE`)
**Purpose:** Playlist + dual-player crossfade + loop-point logic. Game-level audio controller.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `playlist` | `Array[MusicTrack]` | `[]` | Music tracks to play |
| `loop` | `bool` | `false` | Loop playlist |
| `volume_db` | `float` | `-6.0` | Normal playback volume |
| `idle_volume_db` | `float` | `-20.0` | Attract/idle volume |
| `fade_in_duration` | `float` | `1.0` | Fade in seconds |
| `fade_out_duration` | `float` | `0.5` | Fade out seconds |
| `crossfade_duration` | `float` | `1.0` | Loop crossfade seconds |

**Consumes:** Game bus: `"game_play"`, `"game_over"`

**Generates:** Game bus: `"track_changed(track: MusicTrack)"`

**Exposed property:** `pitch_scale: float` — settable by external controllers for speed ramping.

**Process (from V1 `music_player.gd`):**
1. On `"game_play"`: start playlist playback.
2. On `"game_over"`: fade out and stop.
3. Dual AudioStreamPlayer (A/B) for seamless loop crossfading.
4. Loop-point monitoring: when playback position reaches `loop_end - crossfade_duration`, crossfade to `loop_start`.
5. On track change: emit `"track_changed"` for CreditProjection.
6. Shuffle queue, refill when empty.

### 12. SoundSpeaker
**Type:** CDStageComponent2D (`ComponentCategory.STAGE`)
**Purpose:** Game-level one-shot or jingle triggered by game bus signal.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `sound` | `CDSoundDef` | — | Sound definition (single or jingle) |
| `trigger_signal` | `StringName` | `&""` | Game bus signal that triggers playback |
| `gameplay_only` | `bool` | `false` | Only play during PLAYING state |

**Consumes:** Game bus: configurable via `trigger_signal`

**Process:** On trigger signal, calls `CDSoundBank.play_one_shot(...)`. Same thin-wrapper pattern as SoundVoice but on the game bus.

### 13. ContinuousSpeaker
**Type:** CDStageComponent2D (`ComponentCategory.STAGE`)
**Purpose:** Game-level continuous sound (ambient hum, alarm tone).

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `wave_shape` | `WaveShape` | `SINE` | Waveform |
| `effect` | `Effect` | `NONE` | Audio effect |
| `note` | `Semitone` | `C4` | Note |
| `volume` | `float` | `0.1` | Volume |

**Consumes:** Game bus: `"game_play"`, `"game_over"`

**Process:**
1. On `"game_play"`: `CDSoundBank.start_continuous(...)`.
2. On `"game_over"`: `CDSoundBank.stop_continuous(...)`.
3. On `_exit_tree`: deregister.

### 14. CRTProjection
**Type:** Node2D (`ComponentCategory.STAGE`)
**Purpose:** CRT post-processing pipeline. Direct port of V1 `crt_controller.gd` with added signal control.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| *All V1 CRT params* | | | warp, aberration, vignette, bloom, persistence, etc. |
| `signal_controlled` | `bool` | `false` | If true, listens for bus signals |

**Consumes:** Game bus: `"crt_on"`, `"crt_off"` (only when `signal_controlled = true`)

**Process:**
1. Self-building pipeline (BackBufferCopy → Persistence SubViewport → CRT shader → scanline/noise overlays). Unchanged from V1.
2. Dirty-flag param pushing. Unchanged from V1.
3. NEW: On `"crt_on"`, show all CRT layers. On `"crt_off"`, hide all CRT layers. Allows game-level control of the CRT effect (e.g., disable during menus, enable during gameplay).

### 15. CreditProjection
**Type:** Control (`ComponentCategory.STAGE`)
**Purpose:** Floating credit overlay showing song title and credits. Extracted from V1 `music_player.gd`.

Extends `Control` because it's a UI element — it lives naturally in the UI tree and can be positioned/anchored like any other Control.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `display_time` | `float` | `5.0` | Seconds to show credits |
| `font` | `Font` | Kenney Pixel | Display font |

**Consumes:** Game bus: `"track_changed(track: MusicTrack)"`

**Process:**
1. On `"track_changed"`: build credit Labels (title, song_credit, render_credit) as children.
2. Animate: fade in (0.8s) → hold (`display_time`) → fade out (1.0s) → cleanup.

**V1 reference:** `music_player.gd` lines 192–268 (`_show_credit` / `_hide_credit`). Same Label construction and tween animation, extracted into its own component.

### 16. MenaceProjection
**Type:** CDStageComponent2D (`ComponentCategory.STAGE`)
**Purpose:** Generalized CRT menace effects. Extracted from V1's PolybiusFace and GodotLogo. All "random chance" events can be configured to listen for game bus signals, and functions are generalized to apply to any visual target.

**Effects:**

| Effect | Description | V1 Source |
|--------|-------------|-----------|
| Glitch | Horizontal displacement of drawing region | PolybiusFace, GodotLogo |
| Static | Noise overlay burst | PolybiusFace, GodotLogo |
| Glow | Brightness bloom pulse | PolybiusFace, GodotLogo |
| Scan | Horizontal scan line sweep | PolybiusFace |
| Corrupt | Color channel separation / shift | PolybiusFace |

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `glitch_chance` | `float` | `0.0` | Per-frame probability of glitch |
| `static_chance` | `float` | `0.0` | Per-frame probability of static |
| `glow_chance` | `float` | `0.0` | Per-frame probability of glow |
| `scan_chance` | `float` | `0.0` | Per-frame probability of scan |
| `corrupt_chance` | `float` | `0.0` | Per-frame probability of corrupt |
| `signal_triggers` | `Dictionary` | `{}` | Maps game bus signal names to effect names |

**Consumes:** Game bus: configurable via `signal_triggers` keys

**Process:**
1. In `_process`: roll random for each effect with `chance > 0`. If triggered, apply effect.
2. Listen for game bus signals listed in `signal_triggers`. On signal, apply the mapped effect.
3. Effects can fire from random chance AND/OR signal — both are active simultaneously.
4. Target-agnostic: effects manipulate rendering properties (modulate, offset, shader params) on whatever node the MenaceProjection is attached to.

---

## Implementation Order

1. **CDSoundDef** — Resource, no dependencies (needed by SoundBank and Voices)
2. **CDShape** — Resource, no dependencies (needed by VectorFace and ShapeColliderGuts)
3. **CDSoundBank** — Core infrastructure, all audio flows through it
4. **SoundVoice** — Needs CDSoundBank
5. **ContinuousVoice** — Needs CDSoundBank
6. **SpriteFace** — Standalone visual, no audio dependency
7. **VectorFace** — Needs CDShape. Standalone visual, includes editor tool
8. **EngineFace** — Standalone visual
9. **ThrusterFace** — Needs CDSoundBank (audio component)
9. **MusicSpeaker** — Needs CDSoundBank
10. **SoundSpeaker** — Needs CDSoundBank + CDSoundDef
11. **ContinuousSpeaker** — Needs CDSoundBank
12. **CRTProjection** — Standalone (port of V1, + signal control)
13. **CreditProjection** — Needs MusicSpeaker's `"track_changed"` signal
14. **MenaceProjection** — Standalone (generalized from V1)

---

## Proof / Testing

After all components are built, create test scenes that prove:

1. **CDSoundBank Single:** SoundVoice on an entity. Entity bus signal fires → single beep plays through CDSoundBank.
2. **CDSoundBank Jingle:** SoundVoice with jingle CDSoundDef. Signal fires → multi-note sequence plays in order.
3. **CDSoundBank Continuous:** ContinuousVoice on an entity. `"start"` → hum begins. `"stop"` → hum ends. Voice dedup: two entities with same signature share one voice.
4. **CDSoundBank Gameplay Gating:** ContinuousVoice with `gameplay_only = true`. Sound pauses on GAME_OVER, resumes on PLAYING.
5. **SpriteFace + CDFaceBinding:** Entity with SpriteFace, bindings `[{ "collision": 1 }, { "shoot": 2, restore_after: 0.1 }]`. Emit `"collision"` → hurt texture appears. Emit `"shoot"` → muzzle flash appears, reverts to default after 0.1s.
6. **VectorFace + CDFaceBinding:** Entity with VectorFace, shapes `[(idle CDShape), (hurt CDShape)]`, bindings `[{ "idle": 0 }, { "hurt": 1 }]`. Emit `"hurt"` → polyline swaps to hurt shape. Emit `"idle"` → reverts to default shape.
7. **VectorFace + Dynamic Shape:** Entity with VectorFace + ShapeColliderGuts (Plan 22). Emit `"shape_changed"` with a procedural CDShape → VectorFace draws it, ShapeColliderGuts applies it to collision. One CDShape shared by two components.
9. **EngineFace:** Entity with EngineFace. Emit `"thrust"` → flame appears and flickers. Emit `"end_thrust"` → flame disappears.
10. **ThrusterFace:** TriangleShipModern entity with ThrusterFace. Emit `"move(Vector2.RIGHT)"` → left-side thrusters fire. Audio plays through CDSoundBank.
11. **MusicSpeaker:** MusicSpeaker under CDGame with playlist. `start_game()` → music plays. Track finishes → next track. Loop-point crossfade works. `"track_changed"` emitted.
12. **CreditProjection:** CreditProjection receives `"track_changed"` → credit overlay fades in, holds, fades out.
13. **CRTProjection:** CRTProjection with `signal_controlled = true`. Emit `"crt_off"` → all layers hidden. Emit `"crt_on"` → all layers visible.
14. **MenaceProjection:** MenaceProjection with `glitch_chance = 0.5`. Random glitches visible. Then: set `signal_triggers = { "game_over": "corrupt" }`. End game → corrupt effect fires.
15. **SoundSpeaker:** SoundSpeaker under CDGame. Game bus signal fires → jingle plays at game level.
16. **Arcade Mode Audio:** Entire test inside SubViewport. All audio audible — proves hybrid routing works.

---

## File Structure

```
Godot/Scripts/
├── Core/
│   ├── cdentity.gd
│   ├── cdgame.gd
│   ├── cdcomponent2d.gd
│   ├── ...
│   └── cdsoundbank.gd          # Centralized audio engine
├── Faces/
│   ├── sprite_face.gd           # Texture2D display
│   ├── vector_face.gd           # Polyline/polygon frames
│   ├── engine_face.gd           # Single triangle exhaust
│   └── thruster_face.gd         # X-pattern maneuvering jets
├── Voices/
│   ├── sound_voice.gd           # One-shot/jingle entity audio
│   └── continuous_voice.gd      # Continuous entity audio
├── Speakers/
│   ├── music_speaker.gd         # Playlist + crossfade
│   ├── sound_speaker.gd         # Game-level one-shot/jingle
│   └── continuous_speaker.gd    # Game-level continuous audio
├── Projections/
│   ├── crt_projection.gd        # CRT post-processing pipeline
│   ├── credit_projection.gd     # Floating song credit overlay
│   └── menace_projection.gd     # Generalized CRT menace effects
├── Resources/
│   ├── cd_sound_def.gd          # CDSoundDef + JingleNote resources
│   ├── cd_shape.gd              # CDShape — polygon points resource (shared by Faces + Guts)
│   └── cd_face_binding.gd       # CDFaceBinding — signal → frame mapping
```

---

## Risks & Open Questions

1. **Root-level AudioStreamPlayer cleanup:** When CDGame is freed, CDSoundBank must clean up its root-level AudioStreamPlayer nodes. `_exit_tree()` handles this, but timing with SubViewport teardown needs testing in arcade mode.

2. **Jingle sequencing latency:** Jingles require multiple notes played in sequence. CDSoundBank must manage a note queue and transition between notes seamlessly. If the gap between notes is too large, jingles will sound staccato. May need pre-buffering of the next note.

3. **MenaceProjection target generality:** V1's menace effects are tightly coupled to specific drawing code. Generalizing them to work on any visual node may require different approaches per effect (e.g., glitch via shader param vs. position offset). The first implementation may need to be opinionated about how each effect manifests.

4. **VectorFace editor tool complexity:** Building a point-by-point editor tool that works well in the Godot inspector is non-trivial. The first pass could use a simpler approach (text-based coordinate input, or export arrays directly) with a gizmo-based editor as a future enhancement.

5. **CDSoundDef resource nesting:** `CDSoundDef` contains `Array[JingleNote]` where `JingleNote` is also a custom resource. Godot's inspector handles nested resource arrays, but the UX may be clunky. Monitor this during implementation.

---

## Future Work

**AnimatedFace + ActionStateGuts** — Multi-frame sprite animations and priority-based state arbitration are deferred to a future plan (likely alongside Plan 22: V2 Arms & Guts). The `frame perfect inputs v2` brainstorm defines:

- **ActionStateGuts** (GUT, Priority 50): Priority arbitrator. Components request states (`"idle"`, `"walk"`, `"light_attack"`, `"hitstun"`) with priorities. Highest priority wins. Emits `"action_state_changed(new_state, old_state)"`.
- **AnimatedFace** (FACE, Priority 60): Wraps `AnimatedSprite2D`. Maps `"action_state_changed"` states to named animations. Zero blend time for fighting-game snappiness.

This pattern is more complex and only needed for games with animation state machines (beat 'em ups, platformers). Plan 24's CDFaceBinding handles the simpler cases (arcade games, static frame swaps). Both patterns can coexist on different entities.
