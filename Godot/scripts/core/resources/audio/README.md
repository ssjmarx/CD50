# Audio Resources

3 data-only resource classes that configure CDSoundBank and MusicSpeaker. No logic — just exported properties.

---

## CDNote — A Single Note

Defines one note in a sequence. Used inside `CDSoundDef.notes`.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `note` | `CDEnums.Semitone` | C4 | Which semitone to play |
| `duration` | `float` | 0.15 | Seconds this note lasts |

### Must-Includes

- Set `note` to the desired pitch (CDEnums.Semitone enum covers C2→B6)
- Set `duration` — 0.15s is a good default for arcade sounds

---

## CDSoundDef — A Sound Effect Definition

Defines a complete sound effect (one-shot or jingle). Passed to `CDSoundBank.play_one_shot()`.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `wave_shape` | `CDEnums.WaveShape` | SQUARE | Oscillator type |
| `effect` | `CDEnums.Effect` | NONE | Frequency/amplitude modulation |
| `volume` | `float` | 0.2 | Linear volume (0.0–1.0) |
| `notes` | `Array[CDNote]` | [] | Note sequence (1 note = one-shot, 2+ = jingle) |

### Must-Includes

1. Set `wave_shape` — SQUARE for retro, SINE for smooth, NOISE for percussion
2. Add at least one `CDNote` to `notes`
3. Adjust `volume` — 0.2 is a safe baseline, louder sounds can clip

### Jingle Pattern

Multi-note sounds are played sequentially by CDSoundBank's fill loop. Each note gets its own duration and pitch. The bank handles phase resets between notes automatically.

```
notes = [
    CDNote(note=C4, duration=0.1),   # first note
    CDNote(note=E4, duration=0.1),   # second note
    CDNote(note=G4, duration=0.15),  # final note
]
```

---

## CDMusicTrack — A Music Track

Defines a music track for MusicSpeaker playlists. Supports loop points and crossfade.

| Export | Type | Default | Purpose |
|--------|------|---------|---------|
| `stream` | `AudioStream` | null | The audio file (OGG recommended) |
| `title` | `String` | "" | Display name |
| `artist` | `String` | "" | Artist credit |
| `loop_start` | `float` | 0.0 | Loop point start (seconds) |
| `loop_end` | `float` | 0.0 | Loop point end (seconds, 0 = end of file) |
| `loopfade_duration` | `float` | 1.0 | Crossfade duration for seamless loops |

### Must-Includes

1. Set `stream` to an AudioStream (OGG with loop import settings)
2. Set `loop_start`/`loop_end` if the track has a loop section
3. Set `loopfade_duration` to avoid clicks at loop boundaries
