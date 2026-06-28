# Speakers

Game-level audio components that emit sound during a game session. Each script extends `CDGameComponent`, is added as a child of a game node, and is wired to fire on **game bus signals**. They are not standalone nodes — they depend on a parent `game` object and (for synthesized audio) a sibling `CDSoundBank`.

Three speakers live here:

| Script | Purpose | Audio Source |
| --- | --- | --- |
| `continuous_speaker.gd` | Sustained synthesized tone (drone, hum, alarm) | `CDSoundBank` continuous registration |
| `music_speaker.gd` | Shuffled playlist of music tracks with crossfades | `CDMusicTrack` resources on `AudioStreamPlayer`s |
| `sound_speaker.gd` | One-shot or jingle synthesized sound | `CDSoundBank` one-shot playback |

---

## Shared patterns (read this first)

All three scripts follow the same shape. Understanding these conventions is required before adding a new speaker.

### Base class

```gdscript
class_name <Name> extends CDGameComponent
```

`CDGameComponent` provides:
- a `game` reference to the owning game node,
- a `bus_connect(signal_name, callable)` helper that **tracks** the connection for auto-disconnect, plus `connect_all(signals, callable)` for arrays,
- `game.bus_disconnect` / `game.bus_emit` for manual use,
- an `_on_initialize()` virtual that runs once the `game` reference is ready,
- an `_exit_tree()` that **auto-disconnects every tracked bus connection**, so subclasses only need to clean up their own resources (deregister, free nodes, etc.).

### Lifecycle hooks used

- `_on_initialize()` — locate dependencies (e.g. read the typed `game.sound_bank` ref) and `bus_connect` to the trigger signals. Connections made via `bus_connect` are **tracked** and torn down automatically by the base `_exit_tree()`.
- `_exit_tree()` — only used when the subclass has its own resources to release. `ContinuousSpeaker` overrides it to `_deregister()` from the sound bank and then calls `super._exit_tree()` so the base still auto-disconnects the tracked bus signals. `MusicSpeaker` and `SoundSpeaker` have no `_exit_tree` override — the base handles signal cleanup, and they own no bank slot to deregister.

### Triggering audio

Speakers never play themselves directly. They connect to a **named game bus signal** chosen in the inspector and react when that signal fires (e.g. `game_play`, `game_over`). The relevant signal name(s) are exported as `StringName` properties.

### Editor preview (@tool)

`continuous_speaker.gd` and `sound_speaker.gd` are `@tool` scripts. They expose a `Preview` export group with a `preview_action` enum that resets to `NONE` after firing, plus a `_preview_player` (`AudioStreamPlayer` + `AudioStreamGenerator`) that synthesizes samples directly into the buffer for in-editor auditioning. The preview is gated by `Engine.is_editor_hint()` and only runs in the editor.

---

## continuous_speaker.gd

`class_name ContinuousSpeaker extends CDGameComponent` · `@tool`

A sustained synthesized tone driven by `CDSoundBank`. Designed for drones, hums, and alarms that run continuously between a start and stop event.

### Exports

| Property | Type | Default | Notes |
| --- | --- | --- | --- |
| `wave_shape` | `CDEnums.WaveShape` | `SINE` | Oscillator waveform |
| `effect` | `CDEnums.Effect` | `NONE` | Frequency/amplitude modulation effect |
| `note` | `CDEnums.Semitone` | `C4` | Base pitch |
| `volume` | `float` | `0.1` | Linear output level |
| `start_signal` | `StringName` | `&"game_play"` | Bus signal that starts the tone |
| `stop_signal` | `StringName` | `&"game_over"` | Bus signal that stops the tone |
| `preview_action` | `PreviewAction` | `NONE` | Editor-only: `PLAY` / `STOP` (resets to `NONE`) |
| `preview_duration` | `float` | `0.5` | Length of the editor preview in seconds |

### State

- `_bank: CDSoundBank` — the central sound bank, read from the typed `game.sound_bank` property (resolved once by `CDGame`).
- `_signature: String` — `"{wave}_{effect}_{note}"`, the key used for bank registration.
- `_is_registered: bool` — tracks whether this speaker currently holds a bank slot.
- `_preview_player: AudioStreamPlayer` — editor-only preview voice.

### Behavior

1. On `_on_initialize()`: finds the bank, builds `_signature`, and connects `start_signal` → `_on_start` and `stop_signal` → `_on_stop` (both tracked for auto-disconnect).
2. `_on_start()` computes a sound position (center of `game.game_bounds`, or `Vector2.ZERO` if it has no area) and calls `_bank.start_continuous(...)`, tagged with `game.get_instance_id()`.
3. `_on_stop()` → `_deregister()` calls `_bank.stop_continuous(_signature, owner_id)`.
4. `_exit_tree()` calls `_deregister()` to release the bank slot, then `super._exit_tree()` so the base auto-disconnects the tracked `start_signal`/`stop_signal` connections.

The editor preview generates `preview_duration` seconds of samples using `CDUtilities.freq_from_note`, `apply_freq_effect`, `wave_sample`, and `apply_amp_effect`, pushing stereo frames into an `AudioStreamGeneratorPlayback`.

---

## music_speaker.gd

`class_name MusicSpeaker extends CDGameComponent`

A dual-player playlist system with shuffled ordering, crossfades, and loop-point support. Emits `track_changed` on the game bus and writes the current `CDMusicTrack` to the game blackboard.

> Not a `@tool` script — no editor preview.

### Exports

| Property | Type | Default | Group | Notes |
| --- | --- | --- | --- | --- |
| `playlist` | `Array[CDMusicTrack]` | `[]` | — | Ordered list of tracks |
| `loop` | `bool` | `false` | — | Re-shuffle and continue after the last track |
| `volume_db` | `float` | `-6.0` | — | Target playback volume (dB) |
| `fade_in_duration` | `float` | `1.0` | — | Used to tween the new player up to `volume_db` |
| `fade_out_duration` | `float` | `0.5` | — | Used by `_fade_out_and_stop` |
| `crossfade_duration` | `float` | `1.0` | — | Fade-out duration for the outgoing player during a crossfade |
| `start_signal` | `StringName` | `&"game_play"` | Trigger Signals | Bus signal that starts the playlist |
| `stop_signal` | `StringName` | `&"game_over"` | Trigger Signals | Bus signal that stops the playlist |
| `track_key` | `StringName` | `&"current_track"` | Blackboard Keys | Blackboard key for the current `CDMusicTrack` |

### State

- `_player_a`, `_player_b`, `_active_player` — two `AudioStreamPlayer`s on the `CD_Audio` bus; `_active_player` flips between them per track for seamless crossfades.
- `_queue: Array[int]` — shuffled index queue.
- `_current_index: int` — index into `playlist` of the playing track (`-1` before first play).
- `_is_playing: bool` — master gate; every async path re-checks it.
- `_pitch_scale: float` — exposed via the `pitch_scale` property which applies to both players live.

### Signal wiring

`MusicSpeaker` connects its configurable `start_signal` / `stop_signal` in `_on_initialize()` (tracked for auto-disconnect):

```gdscript
bus_connect(start_signal, _on_game_play)
bus_connect(stop_signal, _on_game_over)
```

It has no `_exit_tree` override — the base auto-disconnects both.

### Behavior

- `_on_game_play()` → `_start_playlist()`: shuffles `range(playlist.size())`, then `_play_next()`.
- `_play_next()`:
  - reshuffles (if `loop`) or stops (`_is_playing = false`) when the queue empties,
  - pops the next index, swaps `_active_player` to the other voice,
  - starts the new stream at `-60.0` dB and tweens it to `volume_db` over `fade_in_duration` while the previous player tweens to `-60.0` over `crossfade_duration` and then `stop`s,
  - writes `game.blackboard[track_key] = track` and emits `track_changed`,
  - if `track.loop_end > 0.0` calls `_schedule_loop_crossfade(track)`, otherwise `_schedule_next_on_finish()`.
- `_schedule_loop_crossfade(track)` `await`s a timer for `loop_end - loopfade_duration`, then jumps the active player to `loop_start` and reschedules itself recursively. Re-checks `_is_playing` after each await.
- `_schedule_next_on_finish()` `await`s the stream length, then calls `_play_next()`. Re-checks `_is_playing`.
- `_on_game_over()` → `_fade_out_and_stop()`: sets `_is_playing = false`, tweens `_active_player` to `-60.0` dB over `fade_out_duration`, then stops it.

`CDMusicTrack` fields actually read by this script: `stream`, `loop_end`, `loop_start`, `loopfade_duration`.

---

## sound_speaker.gd

`class_name SoundSpeaker extends CDGameComponent` · `@tool`

Fires a one-shot (or jingle) synthesized sound through `CDSoundBank` in response to a single bus signal. The sound itself is defined by a `CDSoundDef` resource.

### Exports

| Property | Type | Default | Notes |
| --- | --- | --- | --- |
| `sound` | `CDSoundDef` | — | Sound definition (notes, wave shape, effect, volume) |
| `trigger_signal` | `StringName` | `&""` | Bus signal that fires playback; empty = not connected |
| `gameplay_only` | `bool` | `false` | If true, ignore triggers unless `game.current_state == GameState.PLAYING` |
| `preview_action` | `PreviewAction` | `NONE` | Editor-only: `PLAY` / `STOP` (resets to `NONE`) |

### State

- `_bank: CDSoundBank` — read from the typed `game.sound_bank` property (resolved once by `CDGame`).
- `_preview_player: AudioStreamPlayer` — editor-only preview voice.

### Behavior

1. `_on_initialize()` finds the bank and connects `trigger_signal` → `_on_trigger` via `bus_connect(...)` (tracked for auto-disconnect; skipped if the name is empty).
2. `_on_trigger()` bails if `sound` or `_bank` is null, or if `gameplay_only` and the state isn't `PLAYING`. Otherwise it computes a center position and calls `_bank.play_one_shot(sound, position, false, false, owner_id)`.
3. No `_exit_tree()` override — the base auto-disconnects the tracked `trigger_signal` connection. `SoundSpeaker` holds no bank slot to deregister.

### Editor preview

The preview iterates `sound.notes` (a list of `CDNote`s) and synthesizes each note into the buffer:

- `target_freq = CDUtilities.freq_from_note(cd_note.note)`
- frame count = `maxi(1, int(cd_note.duration * CDUtilities.MIX_RATE))`
- when `cd_note.glide` is true and it isn't the first note, frequency is interpolated from the previous note's frequency across the note; otherwise phase resets to `0.0` at the note boundary,
- per frame: `apply_freq_effect` → accumulate phase → `wave_sample` → `apply_amp_effect`, scaled by `sound.volume`,
- the generator buffer is sized to the total note duration (plus 0.1 s) and reused/resized on subsequent previews.

`CDSoundDef` fields actually read: `notes`, `wave_shape`, `effect`, `volume`.
`CDNote` fields actually read: `note`, `duration`, `glide`.

---

## How to add a new speaker

Mirror the conventions above. Concretely:

1. **Create the file here** (`Godot/scripts/game components/speakers/<name>_speaker.gd`) and declare:
   ```gdscript
   class_name <Name>Speaker extends CDGameComponent
   ```
   Add `@tool` only if you intend to ship an editor preview.
2. **Read the bank** (if you need synthesized audio) from the typed game ref:
   ```gdscript
   _bank = game.sound_bank
   ```
3. **Expose trigger signals as `StringName` exports** (like all three speakers here — `MusicSpeaker` now exposes configurable `start_signal`/`stop_signal` too), and connect them in `_on_initialize()` via the tracked `bus_connect(...)`.
4. **Play through `CDSoundBank`** for one-shots and continuous tones — do not spawn raw `AudioStreamPlayer`s for synthesized game audio. `MusicSpeaker` is the documented exception because it plays streamed `CDMusicTrack` assets.
5. **Guard async work** behind `_is_playing` (or an equivalent flag) so timers and awaits no-op after the game ends.
6. **Only override `_exit_tree()` when you have your own resources to release** (e.g. deregistering from the bank). Signal disconnection is handled automatically by the base `_exit_tree()`. If you do override it, call `super._exit_tree()` after your own cleanup so the base still auto-disconnects tracked connections (see `ContinuousSpeaker`).
7. **If you add an editor preview**, copy the `Preview` export group pattern: a self-resetting `preview_action` enum, an `_ensure_preview_player()` that creates/reuses an `AudioStreamGenerator`-backed `AudioStreamPlayer` on the `Master` bus, and a deferred `_preview_fill()` that pushes stereo frames. Gate every preview path with `Engine.is_editor_hint()`.
8. **Document every `@export`** with a `##` comment above it, matching the style used in these files.