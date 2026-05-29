# Speakers — Audio Playback Components

3 speaker components that handle game-level audio: synthesized one-shots, continuous tones, and music playlist playback with crossfade. All extend `CDGameComponent`.

---

## Common Speaker Pattern

```
_on_initialize()   → find CDSoundBank child, connect bus signals
_on_trigger()      → delegate to CDSoundBank for playback
_exit_tree()       → disconnect bus signals, deregister from bank
```

### Must-Includes When Creating Speakers

1. Extend `CDGameComponent`
2. Find `CDSoundBank` via `game.find_child("CDSoundBank")` in `_on_initialize()`
3. Connect trigger signals via `game.bus_connect()`
4. Disconnect in `_exit_tree()` to prevent dangling callbacks
5. Use `game.get_instance_id()` as owner ID for bank registration
6. Center sound position with `game.game_bounds.get_center()`
7. For `@tool` scripts: add preview enum + `_preview_play()` / `_preview_stop()` for editor auditioning

### Key Dependencies

| Dependency | Purpose |
|------------|---------|
| `CDSoundBank` | Central audio engine — handles mixing, spatialization, and continuous voice management |
| `CDSoundDef` | Resource defining a one-shot sound (wave shape, effect, note list, volume) |
| `CDMusicTrack` | Resource defining a music track (stream, title, artist, loop points) |
| `CDUtilities` | Wave sampling, frequency calculation, effect application |
| `CDEnums.WaveShape` | Sine, square, saw, triangle, noise |
| `CDEnums.Effect` | Frequency/amplitude modulation effects |
| `CDEnums.Semitone` | Note-to-frequency mapping |

---

## Components

### ContinuousSpeaker — Sustained Synthesized Tone

Generates a continuous synthesized tone (drone, hum, alarm) via CDSoundBank. Starts and stops on game bus signals. Includes editor preview with `@tool`.

| Feature | Details |
|---------|---------|
| **Synthesis** | Delegated to CDSoundBank — wave shape, effect, note, volume |
| **Signature** | `"{wave_shape}_{effect}_{note}"` — unique key for bank registration |
| **Start/stop** | `start_signal` / `stop_signal` game bus signals |
| **Owner ID** | `game.get_instance_id()` prevents cross-game conflicts |
| **Preview** | Editor-only play/stop via `AudioStreamGenerator` |
| **Cleanup** | Deregisters from bank and disconnects signals in `_exit_tree()` |

### MusicSpeaker — Playlist Crossfade Player

Dual-player music system with shuffled playlists, crossfade transitions, and loop-point support. Emits `track_changed` on the game bus for credit overlays.

| Feature | Details |
|---------|---------|
| **Players** | Two `AudioStreamPlayer` nodes (A/B) for seamless crossfade |
| **Playlist** | Array of `CDMusicTrack` resources, shuffled on start |
| **Crossfade** | Parallel tween: fade in new player, fade out old player |
| **Looping** | `loop_end` / `loop_start` / `loopfade_duration` from CDMusicTrack |
| **Pitch** | `pitch_scale` property applies to both players |
| **Signals** | Connects `game_play` → start, `game_over` → fade out |
| **Emit** | `track_changed` with CDMusicTrack arg for CreditProjection |

### SoundSpeaker — One-Shot Synthesized Sound

Plays a `CDSoundDef` one-shot or jingle triggered by a game bus signal. Optionally gated to gameplay state only. Includes editor preview with `@tool`.

| Feature | Details |
|---------|---------|
| **Sound def** | `CDSoundDef` resource with notes, wave shape, effect, volume |
| **Trigger** | Single `trigger_signal` game bus signal |
| **Gameplay gate** | `gameplay_only` skips playback outside PLAYING state |
| **Playback** | Delegated to `CDSoundBank.play_one_shot()` |
| **Preview** | Editor-only play/stop via `AudioStreamGenerator` with auto buffer sizing |
| **Cleanup** | Disconnects signal in `_exit_tree()` |