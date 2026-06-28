# Entity Components — Voices

This folder contains `CDEntityComponent` scripts that produce audio. A "voice" attaches to
an entity and routes procedural sound through a shared `CDSoundBank` node instead of playing
`AudioStreamPlayer`s directly.

Both scripts are `@tool` scripts so their output can be previewed from the editor inspector.

## Files

| File              | Class             | Purpose                                                          |
| ----------------- | ----------------- | ---------------------------------------------------------------- |
| `continuous_voice.gd` | `ContinuousVoice` | Sustained, looping oscillator tone (e.g. engine hums, drones).   |
| `sound_voice.gd`     | `SoundVoice`      | One-shot procedural sound or jingle (e.g. blips, fanfares).      |

---

## Shared architecture (as implemented in these files)

The two scripts are not subclasses of each other; they are siblings that follow the same
conventions. Everything below is taken directly from the code in this folder.

### Base class
Both extend `CDEntityComponent` and rely on two members it provides:

- `entity` — the owning entity node (used for signals, `global_position`, `get_instance_id()`).
- `game`  — the game node, used to look up the sound bank.

They override two lifecycle hooks:

- `_on_initialize()` — runs at initialization; used to find the bank and wire up signals.
- `_on_entity_deactivating()` — runs when the entity deactivates; both call `super._on_entity_deactivating()` first, then do their own cleanup.

> The full semantics of `CDEntityComponent` live in its own file (outside this folder). These
> notes only describe how the voice scripts use it.

### Locating the audio backend
Both find the bank the same way inside `_on_initialize()`:

```gdscript
_bank = game.sound_bank
```

This reads the typed `game.sound_bank` property, which `CDGame` resolves once (by name) to a
`CDSoundBank` node anywhere under the game. There is no autoload and the component does no lookup
of its own. If no sound bank is present, `game.sound_bank` (and therefore `_bank`) is `null` and
playback calls silently no-op (both scripts null-guard before touching `_bank`).

### Editor preview system
Both expose an identical `Preview` inspector group:

```gdscript
@export_group("Preview")
enum PreviewAction { NONE, PLAY, STOP }
@export var preview_action: PreviewAction = PreviewAction.NONE:
    set(v):
        preview_action = PreviewAction.NONE
        if not Engine.is_editor_hint():
            return
        if v == PreviewAction.PLAY:  _preview_play()
        elif v == PreviewAction.STOP: _preview_stop()
```

The setter resets to `NONE` immediately, so in the inspector it behaves like a button: pick
`PLAY`, it fires once and snaps back. The actual audio is generated procedurally with an
`AudioStreamGenerator` / `AudioStreamGeneratorPlayback` owned by the component, using these
`CDUtilities` helpers:

- `CDUtilities.MIX_RATE` — sample rate for the generated stream.
- `CDUtilities.freq_from_note(note)` — semitone → frequency.
- `CDUtilities.apply_freq_effect(freq, t, effect)` — frequency modulation over time.
- `CDUtilities.wave_sample(phase, wave_shape)` — raw oscillator sample.
- `CDUtilities.apply_amp_effect(sample, t, progress, effect)` — amplitude envelope/modulation.

---

## `continuous_voice.gd` — `ContinuousVoice`

Plays an **ongoing** procedural oscillator tone. Per the file's own header comment, multiple
entities that produce the same signature are intended to blend into a single audio stream
(the actual blending is performed by `CDSoundBank`, which lives outside this folder).

### Exports

| Export              | Type                | Default        | Meaning                                                                                  |
| ------------------- | ------------------- | -------------- | ---------------------------------------------------------------------------------------- |
| `wave_shape`        | `CDEnums.WaveShape` | `SQUARE`       | Oscillator waveform.                                                                     |
| `effect`            | `CDEnums.Effect`    | `NONE`         | Frequency/amplitude modulation effect.                                                   |
| `note`              | `CDEnums.Semitone`  | `C4`           | Base pitch as a semitone constant.                                                       |
| `volume`            | `float`             | `0.2`          | Output volume (intended range 0.0–1.0).                                                  |
| `start_signal`      | `StringName`        | `&""`          | Entity signal name that starts playback. Empty = no auto-start wiring.                   |
| `stop_signal`       | `StringName`        | `&""`          | Entity signal name that stops playback.                                                  |
| `gameplay_only`     | `bool`              | `false`        | If true, pauses the tone whenever `game.current_state != CDEnums.GameState.PLAYING`.     |
| `start_on_spawn`    | `bool`              | `false`        | Register with the bank immediately during `_on_initialize()`.                            |
| `stop_on_deactivate`| `bool`              | `true`         | Deregister from the bank when the entity deactivates.                                    |
| `positional`        | `bool`              | `true`         | Push the entity's `global_position` to the bank for positional audio each physics frame. |

Preview group: `preview_action` (described above) and `preview_duration: float = 0.5` (length
of the preview tone in seconds).

### Internal state

- `_bank: CDSoundBank` — cached bank reference.
- `_signature: String` — `"{wave_shape}_{effect}_{note}"` (see `_build_signature()`). This is the
  key the bank uses to identify this sound combination.
- `_is_registered: bool` — whether this voice currently has an active entry in the bank.
- `_preview_player: AudioStreamPlayer` — editor-only preview stream.

### Runtime flow

1. **`_on_initialize()`**
   - Finds `_bank`.
   - Builds `_signature`.
   - If `start_signal` is set, calls `entity.ensure_signal(start_signal)` and
     `entity.connect(start_signal, _on_start)`.
   - If `stop_signal` is set, does the same wiring to `_on_stop`.
   - If `start_on_spawn`, calls `_register()` immediately.
   - Calls `set_physics_process(true)`.

2. **Signal-driven control**
   - `_on_start()` → `_register()`.
   - `_on_stop()`  → `_deregister()`.

3. **`_physics_process(_delta)`** (only runs while registered; the delta argument is unused)
   - If `gameplay_only` and the state is not `PLAYING`: calls
     `_bank.pause_continuous(_signature, entity.get_instance_id())` and returns.
   - Otherwise calls `_bank.resume_continuous(...)` (still inside the `gameplay_only` branch).
   - If `positional`: calls
     `_bank.update_continuous_position(_signature, entity.get_instance_id(), entity.global_position)`.

4. **Bank registration**
   - `_register()` — guards on null bank / already registered, then:
     ```gdscript
     _is_registered = _bank.start_continuous(_signature, wave_shape, effect,
         note, volume, entity.get_instance_id(),
         entity.global_position, positional)
     ```
   - `_deregister()` — guards, then `_bank.stop_continuous(_signature, entity.get_instance_id())`
     and sets `_is_registered = false`.

5. **Cleanup**
   - `_on_entity_deactivating()` calls `super`, then if `stop_on_deactivate` calls `_deregister()`.
   - `_exit_tree()` **always** calls `_deregister()`, regardless of `stop_on_deactivate`.

> Note: `ContinuousVoice` does **not** explicitly disconnect its `start_signal`/`stop_signal`
> callbacks in `_on_entity_deactivating()`; it only deregisters from the bank there. Compare
> with `SoundVoice`, which does explicitly disconnect.

### How to use (typical setup)
1. Add a `ContinuousVoice` node as a child of an entity that extends the project's entity base.
2. Pick `wave_shape`, `effect`, `note`, and `volume`.
3. Either enable `start_on_spawn`, or set `start_signal`/`stop_signal` to entity signal names
   the rest of the entity will emit.
4. Leave `positional = true` for world-space sources; disable it for UI/global drones.
5. Use the `Preview ▸ preview_action` dropdown in the editor to audition the tone.

---

## `sound_voice.gd` — `SoundVoice`

Plays a **one-shot** procedural sound or jingle described by a `CDSoundDef` resource. It is
triggered by a bus signal and can optionally prevent overlapping copies of itself.

### Exports

| Export           | Type          | Default | Meaning                                                                              |
| ---------------- | ------------- | ------- | ------------------------------------------------------------------------------------ |
| `sound`          | `CDSoundDef`  | —       | Sound definition resource (holds the notes, wave shape, effect, and volume).         |
| `trigger_signal` | `StringName`  | `&""`   | Bus signal name that triggers a play. Empty = no auto-trigger wiring.                |
| `play_on_spawn`  | `bool`        | `false` | Play once during `_on_initialize()`.                                                 |
| `positional`     | `bool`        | `true`  | Pass the entity's `global_position` to the bank for positional audio.                |
| `exclusive`      | `bool`        | `false` | Prevent overlapping instances of the same sound (forwarded to the bank).             |
| `gameplay_only`  | `bool`        | `false` | Suppress playback when `game.current_state != CDEnums.GameState.PLAYING`.            |

Preview group: `preview_action` only (same enum/setter pattern as `ContinuousVoice`).

### Internal state

- `_bank: CDSoundBank` — cached bank reference.
- `_preview_player: AudioStreamPlayer` — editor-only preview stream.

### Runtime flow

1. **`_on_initialize()`**
   - Finds `_bank`.
   - If `trigger_signal` is set, calls `self.bus_connect(trigger_signal, _on_trigger)`
     (note: this uses the component's own `bus_connect` helper, **not** `entity.connect`).
   - If `play_on_spawn`, calls `_try_play()`.

2. **Triggering**
   - `_on_trigger()` → `_try_play()`.

3. **`_try_play()`**
   - Returns early if `sound == null` or `_bank == null`.
   - Returns early if `gameplay_only` and the state is not `PLAYING`.
   - Otherwise:
     ```gdscript
     _bank.play_one_shot(sound, entity.global_position, positional,
         exclusive, get_instance_id())
     ```

4. **Cleanup**
   - `_on_entity_deactivating()` calls `super`, then if `trigger_signal` is set and
     `entity.has_signal(trigger_signal)`, calls `entity.disconnect(trigger_signal, _on_trigger)`.

> Note the wiring asymmetry: `SoundVoice` connects via `self.bus_connect(...)` but disconnects
> via `entity.disconnect(...)`. It has no `_physics_process` and no `_exit_tree` override.

### Preview details specific to `SoundVoice`
`_preview_fill()` iterates `sound.notes` (a list of `CDNote` resources). For each note it:
- Computes `total_frames = max(1, int(note.duration * MIX_RATE))`.
- Supports **glide**: if `note.glide` is true and this is not the first note, phase is *not*
  reset and the frequency is interpolated with `lerpf(prev_freq, target_freq, progress)`.
- On hard (non-glide) note boundaries, phase resets to `0.0`.
- `_ensure_preview_player()` sizes the `AudioStreamGenerator.buffer_length` to the total
  duration of all notes (`+ 0.1` seconds of headroom), reusing/resizing an existing player
  when possible.

### How to use (typical setup)
1. Create or assign a `CDSoundDef` resource to the `sound` export.
2. Either enable `play_on_spawn`, or set `trigger_signal` to a bus signal emitted elsewhere.
3. Enable `exclusive` if overlapping copies of this sound are undesirable.
4. Use the `Preview ▸ preview_action` dropdown to audition the full jingle.

---

## External types referenced (defined outside this folder)

These are the only external symbols the two scripts touch. Consult their own source for
authoritative behavior.

| Symbol | Kind | Used for |
| --- | --- | --- |
| `CDEntityComponent` | Base class | Provides `entity`, `game`, `_on_initialize()`, `_on_entity_deactivating()`, and (for `SoundVoice`) `bus_connect()`. |
| `CDSoundBank` | Node | Audio backend. Methods called: `start_continuous`, `stop_continuous`, `pause_continuous`, `resume_continuous`, `update_continuous_position`, `play_one_shot`. |
| `CDEnums.WaveShape`, `CDEnums.Effect`, `CDEnums.Semitone`, `CDEnums.GameState` | Enums | Waveform, modulation, pitch, and game-state selection. |
| `CDSoundDef`, `CDNote` | Resources | `SoundVoice`'s sound definition and the individual notes inside it (`CDNote.note`, `CDNote.duration`, `CDNote.glide`). |
| `CDUtilities` | Static helpers | `MIX_RATE`, `freq_from_note`, `apply_freq_effect`, `wave_sample`, `apply_amp_effect`. |
| `AudioStreamPlayer`, `AudioStreamGenerator`, `AudioStreamGeneratorPlayback` | Godot built-ins | Editor preview audio generation. |

---

## How to add a new voice component

Mirror the patterns already present in this folder. A minimal new voice should:

1. **Declare the class as a tool component.**
   ```gdscript
   @tool
   class_name MyVoice extends CDEntityComponent
   ```

2. **Find the bank in `_on_initialize()`.**
   ```gdscript
   func _on_initialize() -> void:
       _bank = game.sound_bank
   ```

3. **Wire triggers the way the existing voices do** — pick the matching convention:
   - For an **entity signal** (like `ContinuousVoice`): `entity.ensure_signal(name)` then
     `entity.connect(name, _handler)`.
   - For a **bus signal** (like `SoundVoice`): `self.bus_connect(name, _handler)`.

4. **Talk to the bank through its existing API.** Reuse the methods these scripts already call
   (`start_continuous`/`stop_continuous`/`pause_continuous`/`resume_continuous`/
   `update_continuous_position`/`play_one_shot`) rather than inventing new audio paths. If you
   need behavior the bank does not expose, that change belongs in `CDSoundBank`, not here.

5. **Always null-guard `_bank`** before calling it; both existing voices do.

6. **Override `_on_entity_deactivating()` and call `super` first**, then do cleanup
   (disconnect signals, deregister from the bank). If you hold a bank registration that must
   survive across activate/deactivate cycles differently, follow `ContinuousVoice`'s
   `stop_on_deactivate` toggle pattern.

7. **For continuous voices, also override `_exit_tree()`** to deregister, so the sound stops
   even if the node is removed without the entity deactivating first.

8. **Add an editor preview** by copying the `Preview` group from either file: the
   `PreviewAction` enum, the self-resetting `preview_action` setter guarded by
   `Engine.is_editor_hint()`, and `_preview_play()`/`_preview_stop()`/`_preview_fill()`/
   `_ensure_preview_player()` helpers built on `AudioStreamGenerator` and `CDUtilities`.

9. **Keep it a pure audio component.** These scripts do not move the entity, change game state,
   or read input; they only react to signals and report position to the bank. Preserve that
   separation in new voices.