# Speakers — Game Audio Components

`Speakers` are game-level audio components that emit sound during a game session. Each extends `CDGameComponent`, is added as a child of a game node, and fires on **game-bus signals**. They are not standalone nodes — they depend on a parent `game` object and (for synthesized audio) a sibling `CDSoundBank`.

## Files

| File | Class | Audio Source | Pattern |
|------|-------|--------------|---------|
| `continuous_speaker.gd` | `ContinuousSpeaker` | `CDSoundBank` continuous registration | Sustained synthesized tone (drone, hum, alarm) between start/stop signals; `@tool` preview |
| `music_speaker.gd` | `MusicSpeaker` | `CDMusicTrack` resources on `AudioStreamPlayer`s | Shuffled playlist with crossfades + loop-point support |
| `sound_speaker.gd` | `SoundSpeaker` | `CDSoundBank` one-shot playback | One-shot/jingle synthesized sound from a `CDSoundDef`; `@tool` preview |

---

## Patterns

### 1. Base class
`CDGameComponent` provides:
- a `game` reference to the owning game node,
- `bus_connect(signal_name, callable)` (tracked) + `connect_all(signals, callable)` for arrays,
- `game.bus_emit` / `game.bus_disconnect` for manual use,
- an `_on_initialize()` virtual that runs once `game` is ready,
- an `_exit_tree()` that **auto-disconnects every tracked bus connection**.

### 2. Lifecycle hooks
- **`_on_initialize()`** — locate dependencies (e.g. `_bank = game.sound_bank`) and `bus_connect` to the trigger signals. Connections made via `bus_connect` are tracked and torn down by the base `_exit_tree()`.
- **`_exit_tree()`** — only override when you own a resource to release. `ContinuousSpeaker` overrides it to `_deregister()` from the bank, then calls `super._exit_tree()` so the base still auto-disconnects tracked signals. `MusicSpeaker` and `SoundSpeaker` have no `_exit_tree` override.

### 3. Trigger-driven audio
Speakers never play themselves directly. They connect to a **named game-bus signal** chosen in the inspector (e.g. `game_play`, `game_over`) and react when it fires. Signal names are exported as `StringName`.

### 4. Two audio paths
- **`CDSoundBank`** for one-shots and continuous tones — do not spawn raw `AudioStreamPlayer`s for synthesized game audio.
- **`AudioStreamPlayer`s** for streamed music assets (`MusicSpeaker` is the documented exception).

### 5. Guard async work
Guard timers/awaits behind an `_is_playing` (or equivalent) flag so async paths no-op after the game ends. Re-check the flag after every `await`.

### 6. Editor preview (@tool)
`ContinuousSpeaker` and `SoundSpeaker` are `@tool`. The shared `Preview` group uses a self-resetting `preview_action` enum (`NONE`/`PLAY`/`STOP`), a `_preview_player` (`AudioStreamPlayer` + `AudioStreamGenerator`), and `_ensure_preview_player()` to create/reuse it on the `Master` bus. Every preview path is gated with `Engine.is_editor_hint()`.

Synthesis uses `CDUtilities` helpers (`MIX_RATE`, `freq_from_note`, `apply_freq_effect`, `wave_sample`, `apply_amp_effect`).

---

## How to create a new speaker

```gdscript
@tool   # only if you ship an editor preview
## MyNewSpeaker
## <one-line description>

class_name MyNewSpeaker extends CDGameComponent

@export var my_sound: CDSoundDef
@export var trigger_signal: StringName = &""
@export var gameplay_only: bool = false

@export_group("Preview")
enum PreviewAction { NONE, PLAY, STOP }
@export var preview_action: PreviewAction = PreviewAction.NONE:
    set(v):
        preview_action = PreviewAction.NONE
        if not Engine.is_editor_hint():
            return
        if v == PreviewAction.PLAY:
            _preview_play()

var _bank: CDSoundBank

func _on_initialize() -> void:
    _bank = game.sound_bank
    if trigger_signal != &"":
        bus_connect(trigger_signal, _on_trigger)   # tracked

func _on_trigger() -> void:
    if my_sound == null or _bank == null:
        return
    if gameplay_only and game.current_state != CDEnums.GameState.PLAYING:
        return
    _bank.play_one_shot(my_sound, game.global_position, false, false, get_instance_id())

# Only override _exit_tree if you own a resource to release.
# func _exit_tree() -> void:
#     _deregister_my_resource()
#     super._exit_tree()
```

### Checklist

- [ ] `class_name …Speaker extends CDGameComponent`; live as a child of a game node.
- [ ] Add `@tool` only if you ship an editor preview.
- [ ] Read the bank from the typed ref: `_bank = game.sound_bank`; null-guard every bank call.
- [ ] Expose trigger signals as `StringName` exports; connect in `_on_initialize()` via tracked `bus_connect(...)`.
- [ ] Play synthesized audio through `CDSoundBank` (one-shot or continuous). Reserve raw `AudioStreamPlayer`s for streamed music.
- [ ] Guard async work behind an `_is_playing`-style flag; re-check after every `await`.
- [ ] Override `_exit_tree()` only when you own a resource to release (e.g. deregister from the bank); always call `super._exit_tree()` after your cleanup.
- [ ] For an editor preview, copy the `Preview` group + `_ensure_preview_player()` pattern; gate every preview path with `Engine.is_editor_hint()`.
- [ ] Document every `@export` with a `##` comment.