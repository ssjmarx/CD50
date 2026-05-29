# Voices — Entity Audio Components

2 voice components that play procedural sounds through the `CDSoundBank`. All extend `CDEntityComponent` and are `@tool` scripts with editor preview support.

---

## Common Voice Pattern

```
@tool
_ready()                   → (nothing — voices initialize late)
_on_initialize()           → find CDSoundBank, connect trigger signals
_on_trigger(args)          → optionally filter by arg value, then play
_on_entity_deactivating()  → disconnect signals, stop playback
_exit_tree()               → deregister from sound bank
```

### Must-Includes When Creating Voices

1. Extend `CDEntityComponent` with `@tool` annotation
2. Find `CDSoundBank` via `game.find_child("CDSoundBank")` in `_on_initialize()`
3. Use `entity.ensure_signal()` before connecting trigger signals
4. Disconnect in `_on_entity_deactivating()` with validity guards
5. Deregister from sound bank on deactivation / exit tree
6. Include preview infrastructure (PreviewAction enum, `_preview_play`, `_preview_stop`, `_ensure_preview_player`) for editor testing

### Key Dependencies

| Dependency | Purpose |
|------------|---------|
| `CDSoundBank` | Central audio manager — handles continuous streams and one-shot playback |
| `CDSoundDef` | Resource defining a sequence of `CDNote`s with wave shape, effect, volume |
| `CDUtilities` | Static helpers: `freq_from_note()`, `wave_sample()`, `apply_freq_effect()`, `apply_amp_effect()` |
| `CDEnums.WaveShape` | Oscillator waveform (SINE, SQUARE, SAW, TRIANGLE, NOISE) |
| `CDEnums.Effect` | Frequency/amplitude modulation effects |
| `CDEnums.Semitone` | Note constants (C4, D4, etc.) for pitch definition |

---

## Components

### ContinuousVoice — Ongoing Sound

Plays a procedural oscillator tone that persists until explicitly stopped. The sound bank manages multiple listeners sharing the same signature (wave + effect + note combo).

| Feature | Details |
|---------|---------|
| **Trigger** | `start_signal` / `stop_signal` on entity bus |
| **Audio API** | `_bank.start_continuous()` / `_bank.stop_continuous()` |
| **Position tracking** | Updates positional audio each physics frame via `_bank.update_continuous_position()` |
| **Gameplay lock** | `gameplay_only` pauses sound when game state ≠ PLAYING |
| **Auto-start** | `start_on_spawn` registers immediately on initialize |
| **Filter** | `filter_value` matches against signal arg to selectively respond |

**Signature system:** Sounds are identified by `"{wave_shape}_{effect}_{note}"`. Multiple entities playing the same signature share one audio stream — the bank tracks instance IDs for positional mixing.

### SoundVoice — One-Shot / Jingle

Plays a defined sound (sequence of notes from a `CDSoundDef` resource) once when triggered. Good for hit sounds, pickups, alerts, and short jingles.

| Feature | Details |
|---------|---------|
| **Trigger** | `trigger_signal` on entity bus |
| **Audio API** | `_bank.play_one_shot(sound_def, position, ...)` |
| **Sound definition** | `CDSoundDef` resource with array of `CDNote`s |
| **Exclusive** | `exclusive` flag prevents overlapping instances of the same sound |
| **Gameplay lock** | `gameplay_only` suppresses playback when game state ≠ PLAYING |
| **Filter** | `filter_value` matches against first signal arg |
| **Auto-play** | `play_on_spawn` fires immediately on initialize |

---

## Preview System (Shared)

Both voices include identical editor preview infrastructure:

| Component | Description |
|-----------|-------------|
| `PreviewAction` enum | NONE / PLAY / STOP — resets immediately so the inspector button can be re-clicked |
| `preview_action` export | Setter triggers `_preview_play()` or `_preview_stop()` only in editor |
| `_ensure_preview_player()` | Creates an `AudioStreamGenerator` + `AudioStreamPlayer` pair in the editor |
| `_preview_fill()` | Generates PCM audio frames procedurally using `CDUtilities` |
| `_preview_stop()` | Stops the preview player |

The preview plays directly through an `AudioStreamPlayer` in the scene tree, bypassing `CDSoundBank` entirely. This allows testing sounds without running the game.