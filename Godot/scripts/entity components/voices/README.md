# Voices — Entity Audio Components

`Voices` are `@tool` `CDEntityComponent` scripts (category `AUDIO`) that produce entity-level audio. They route procedural sound through the shared `CDSoundBank` node instead of playing `AudioStreamPlayer`s directly.

## Files

| File | Class | Pattern |
|------|-------|---------|
| `continuous_voice.gd` | `ContinuousVoice` | Sustained looping oscillator tone (engine hums, drones), start/stop signals + optional positional updates each physics frame |
| `sound_voice.gd` | `SoundVoice` | One-shot procedural sound or jingle from a `CDSoundDef`, triggered by a bus signal |

---

## Patterns

### 1. Audio category
Both set `component_category = CDEnums.ComponentCategory.AUDIO` in `_ready()`.

### 2. Find the bank once in `_on_initialize()`
```gdscript
_bank = game.sound_bank
```
`game.sound_bank` is a typed property resolved once by `CDGame`. No autoload, no per-component lookup. Both scripts null-guard `_bank` before every bank call.

### 3. Two trigger conventions
- **Entity signal** (used by `ContinuousVoice`): `entity.ensure_signal(name)` then `entity.connect(name, _handler)`.
- **Bus signal** (used by `SoundVoice`): `self.bus_connect(name, _handler)`.

### 4. `gameplay_only` gating
Both expose `gameplay_only: bool`. When true, playback is suppressed unless `game.current_state == CDEnums.GameState.PLAYING`.

### 5. Cleanup in `_on_entity_deactivating()`
Always `super._on_entity_deactivating()` first, then:
- `ContinuousVoice`: deregisters from the bank (if `stop_on_deactivate`).
- `SoundVoice`: disconnects the trigger signal.

`ContinuousVoice` additionally overrides `_exit_tree()` to deregister unconditionally.

### 6. Editor preview group
Both ship an identical self-resetting `Preview` group:

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

Preview audio is synthesized with `AudioStreamGenerator` using `CDUtilities` helpers (`MIX_RATE`, `freq_from_note`, `apply_freq_effect`, `wave_sample`, `apply_amp_effect`).

### 7. Bank-only audio path
Both reuse the bank's existing API (`start_continuous` / `stop_continuous` / `pause_continuous` / `resume_continuous` / `update_continuous_position` / `play_one_shot`). New behavior belongs in `CDSoundBank`, not here.

---

## How to create a new voice

```gdscript
@tool
## MyNewVoice
## <one-line description>

class_name MyNewVoice extends CDEntityComponent

@export var sound: CDSoundDef
@export var trigger_signal: StringName = &""
@export var gameplay_only: bool = false
@export var positional: bool = true

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
var _preview_player: AudioStreamPlayer

func _ready() -> void:
    component_category = CDEnums.ComponentCategory.AUDIO
    super._ready()

func _on_initialize() -> void:
    _bank = game.sound_bank
    if trigger_signal != &"":
        self.bus_connect(trigger_signal, _on_trigger)

func _on_trigger() -> void:
    if sound == null or _bank == null:
        return
    if gameplay_only and game.current_state != CDEnums.GameState.PLAYING:
        return
    _bank.play_one_shot(sound, entity.global_position, positional, false, get_instance_id())

func _on_entity_deactivating() -> void:
    super._on_entity_deactivating()
    if trigger_signal != &"" and entity.has_signal(trigger_signal):
        entity.disconnect(trigger_signal, _on_trigger)

func _preview_play() -> void:
    if not Engine.is_editor_hint():
        return
    _ensure_preview_player()
    # synthesize sound.notes into _preview_player via AudioStreamGenerator + CDUtilities

func _ensure_preview_player() -> void:
    pass  # create/reuse an AudioStreamGenerator-backed AudioStreamPlayer on Master
```

### Checklist

- [ ] Declare `@tool` and extend `CDEntityComponent`.
- [ ] Set `component_category = CDEnums.ComponentCategory.AUDIO` in `_ready()` (then `super._ready()`).
- [ ] Find `_bank = game.sound_bank` in `_on_initialize()` and null-guard every bank call.
- [ ] Pick the trigger convention (`entity.connect` for entity signals, `self.bus_connect` for bus signals).
- [ ] Override `_on_entity_deactivating()`, call `super` first, then disconnect/deregister.
- [ ] If you hold a continuous bank registration, also override `_exit_tree()` to deregister.
- [ ] Copy the `Preview` group + `_ensure_preview_player()` pattern for an editor audition button.
- [ ] Keep it a pure audio component: react to signals, report position — never move the entity or change game state.