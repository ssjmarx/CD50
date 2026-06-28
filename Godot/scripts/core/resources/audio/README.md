## Audio Resources

3 data-only `Resource` classes that define audio content for the CD audio system. No logic — each script only declares a `class_name`, extends `Resource`, exports a handful of fields, and documents its role in a header comment.

| Class | Purpose (per script header) | Consumed by (per script header) |
|-------|------------------------------|---------------------------------|
| `CDNote` | A single note in a sound sequence — pitch + duration | `CDSoundDef.notes` arrays (for one-shots and jingles) |
| `CDSoundDef` | A complete sound effect definition — wave shape, effects, volume, note sequence | `CDSoundBank.play_one_shot()` (procedural audio) |
| `CDMusicTrack` | A music track definition supporting loop points and crossfade | `MusicSpeaker` playlists |

> The consumer names above (`CDSoundBank`, `MusicSpeaker`) come from the scripts' own header comments, not from any component wiring shown in these files. This folder contains no playback logic — only data definitions.

---

## CDNote — A Single Note

One note in a sequence. Lives inside `CDSoundDef.notes` arrays.

| Export | Type | Default | Purpose (per script comment) |
|--------|------|---------|-------------------------------|
| `note` | `CDEnums.Semitone` | `C4` | Which semitone to play (enum spans C2–B6 per the comment) |
| `duration` | `float` | `0.15` | How long this note lasts, in seconds |
| `glide` | `bool` | `false` | Smoothly glide from the previous note's frequency to this note's frequency |

---

## CDSoundDef — A Sound Effect Definition

A complete sound effect: waveform, modulation effect, volume, and a note sequence. Passed to `CDSoundBank.play_one_shot()` to trigger procedural audio.

| Export | Type | Default | Purpose (per script comment) |
|--------|------|---------|-------------------------------|
| `wave_shape` | `CDEnums.WaveShape` | `SQUARE` | Oscillator waveform for this sound |
| `effect` | `CDEnums.Effect` | `NONE` | Frequency/amplitude modulation effect (tremolo, vibrato, decay, etc. — per the comment) |
| `volume` | `float` | `0.2` | Linear volume level (0.0–1.0; `0.2` is a safe baseline per the comment) |
| `notes` | `Array[CDNote]` | `[]` | Note sequence — 1 note = one-shot, 2+ notes = jingle played sequentially |

### Note Sequences

The `notes` array serves double duty: a single entry is a one-shot, while two or more entries form a jingle played sequentially. Each entry is its own `CDNote` carrying independent pitch, duration, and glide settings. (These files do not contain the playback loop itself — that lives in the consumer, not here.)

---

## CDMusicTrack — A Music Track

A music track for `MusicSpeaker` playlists, supporting loop points and crossfade for seamless background music.

| Export | Type | Default | Purpose (per script comment) |
|--------|------|---------|-------------------------------|
| `stream` | `AudioStream` | — | The audio stream (OGG recommended for loop support) |
| `title` | `String` | `""` | Display metadata |
| `artist` | `String` | `""` | Display metadata |
| `loop_start` | `float` | `0.0` | Loop region start in seconds |
| `loop_end` | `float` | `0.0` | Loop region end in seconds |
| `loopfade_duration` | `float` | `1.0` | Crossfade duration for seamless loop transitions |

Per the script comment, when both `loop_start` and `loop_end` are `0.0` the track plays once with no loop.

---

## Creating a New Audio Resource

All three scripts share an identical structure. To add a new resource type to this folder, follow that same pattern:

1. **Header doc comment** — two `##` lines: the class name, then a one-line purpose that names the consumer (mirrors `CDSoundBank`, `MusicSpeaker` style).
2. **Class declaration** — `class_name CD<Name> extends Resource`.
3. **Exported fields** — each `@export` preceded by a `##` comment describing its meaning, type, and units.
4. **Sensible defaults** — match existing conventions (e.g. `0.2` volume, `0.15` note duration, `1.0` fade).

Template:

```gdscript
## CD<Name>
## <one-line purpose, naming the consumer>

class_name CD<Name> extends Resource

## <field description with type, units, and meaning>
@export var field_name: FieldType = default_value
```

This folder is data-only. Do not add playback logic, signal connections, or node references here — those belong in the consuming audio components/systems, not in these resource definitions.