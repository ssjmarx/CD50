# Audio Resources

Data-only `Resource` classes that define audio content for the CD audio system. No logic — each script only declares a `class_name`, extends `Resource`, exports a handful of fields, and documents its role in a header comment.

## Files

| Class | Purpose | Consumed by |
|-------|---------|-------------|
| `CDNote` | A single note in a sound sequence — pitch + duration | `CDSoundDef.notes` arrays |
| `CDSoundDef` | A complete sound effect definition — wave shape, effects, volume, note sequence | `CDSoundBank.play_one_shot()` |
| `CDMusicTrack` | A music track definition supporting loop points and crossfade | `MusicSpeaker` playlists |

> This folder contains no playback logic — only data definitions.

---

## Patterns

### 1. Data-only
Every audio resource is a pure data container: `class_name CD<Name> extends Resource`, exported fields, no methods beyond what `Resource` provides. Playback logic lives in the consuming audio systems (`CDSoundBank`, `MusicSpeaker`).

### 2. Header doc comments
Each script starts with two `##` lines: the class name, then a one-line purpose that names the consumer.

### 3. Per-field doc comments
Every `@export` is preceded by a `##` comment describing its meaning, type, and units.

### 4. Sensible defaults
Match existing conventions (e.g. `0.2` volume, `0.15` note duration, `1.0` fade).

### 5. Note sequence duality (`CDSoundDef.notes`)
A single `CDNote` entry is a one-shot; two or more entries form a jingle played sequentially. Each entry carries its own pitch/duration/glide.

### 6. Loop convention (`CDMusicTrack`)
When both `loop_start` and `loop_end` are `0.0`, the track plays once with no loop.

---

## How to create a new audio resource

```gdscript
## CDMyAudioResource
## <one-line purpose, naming the consumer>

class_name CDMyAudioResource extends Resource

## <field description with type, units, and meaning>
@export var field_name: FieldType = default_value
```

### Checklist

- [ ] `class_name CD<Name> extends Resource`.
- [ ] Two-line `##` header: class name + one-line purpose naming the consumer.
- [ ] Every `@export` has a preceding `##` comment (type, units, meaning).
- [ ] Sensible defaults matching existing conventions.
- [ ] No playback logic, signal connections, or node references — data only.