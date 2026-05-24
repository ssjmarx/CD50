# Plan 15 — Arcade Orchestrator Juice (Polybius + Renaming)

**Created:** 2026-05-06  
**Status:** Phase 1.8 in progress  
**Timeline:** Before itch export (late May)  
**Scope:** Five phases — Copyright rename pass + Copyright-safety visual changes + Web performance optimization + Polybius face/voice integration  
**Depends on:** Plan 13 (Arcade Orchestrator) complete

---

## Goal

Two deliverables that make the demo shippable:

1. **Full copyright rename** — Every trademarked game name replaced with a bootleg cabinet alternative across all files, scenes, code, and docs. Open-source safe.
2. **Copyright-safety visual changes** — Make each remake visually distinct from its inspiration beyond just the name. Formation changes, color scheme swaps, shape redesigns, and layout adjustments.
3. **Polybius character presence** — A vector CRT face that introduces runs, taunts between games, and delivers game-over commentary. Voice lines are self-recorded and bitcrushed for a Sinistar feel.

---

## Phase 1 — Copyright Rename Pass

### Rename Map

| Old Name | New Name | Rationale |
|----------|----------|-----------|
| Meteor Rally | Meteor Rally | Hybrid name, evokes space + competition |
| Rock Breaker | Rock Breaker | Hybrid name, evokes space_rocks + breaking |
| Paddle Ball | Paddle Ball | Bootleg literal, from renaming.md |
| Brick Breaker | Brick Breaker | Most obvious bootleg name in history |
| Space Rocks | Space Rocks | Literal, descriptive, zero effort |
| Block Drop | Block Drop | What every bootleg cabinet was actually called |
| Bug Blaster | Bug Blaster | Not even pretending it's not Bug Blaster |
| Dogfight | Dogfight | Original — no change |

**Order matters:** The rename script processes longest/most-specific names first (Meteor Rally before Paddle Ball) to prevent partial matches.

### What Gets Renamed

**File names:**
- Game scenes: `paddle_ball.tscn` → `paddle_ball.tscn`, etc.
- ArcadeGameEntry .tres filenames

**File contents — all text files (.tscn, .gd, .tres, .md, .txt):**
- `game_title` UGS export values
- Scene resource path references (e.g., `path="res://Scenes/Games/remakes/paddle_ball.tscn"`)
- Node names inside scenes (e.g., `[node name="BugBlaster"` → `[node name="BugBlaster"`)
- ArcadeGameEntry scene references
- Code comments and doc references

### Case-Aware Rename Script (Python)

The script generates all case variants for each rename pair and replaces them across the codebase:

| Variant | Example (Paddle Ball → Paddle Ball) |
|---------|------|
| Display (Title Case with space) | "Paddle Ball" → "Paddle Ball" |
| PascalCase (no space) | "Paddle Ball" → "PaddleBall" |
| snake_case | "paddle_ball" → "paddle_ball" |
| SCREAMING_SNAKE | "PADDLE_BALL" → "PADDLE_BALL" |
| lowercase | "paddle_ball" → "paddle ball" |
| UPPERCASE | "PADDLE_BALL" → "PADDLE BALL" |
| Filename (snake_case) | `paddle_ball.tscn` → `paddle_ball.tscn` |

**Example expansions:**

| Old | New |
|-----|-----|
| `paddle_ball` / `Paddle Ball` / `PADDLE_BALL` / `paddle_ball` | `paddle ball` / `Paddle Ball` / `PADDLE BALL` / `paddle_ball` |
| `meteor_rally` / `Meteor Rally` / `METEOR_RALLY` | `meteor rally` / `MeteorRally` / `METEOR RALLY` |
| `bug_blaster` / `BugBlaster` / `Bug Blaster` | `bug_blaster` / `BugBlaster` / `Bug Blaster` |

The script:
1. **Build variant map** — For each rename pair, generate all case variants
2. **Find-and-replace in file contents** — Process all `.tscn`, `.gd`, `.tres`, `.md`, `.txt` files. Longest matches first to avoid partial collisions.
3. **Rename files** — `mv` game scene files and .tres files to their new snake_case names
4. **Verification report** — Grep for remaining old names, print results for manual review

**Target: 90% automated.** Edge cases (e.g., a comment that says "Paddle Ball-style gameplay" where the hyphenation changes meaning) are hand-fixed.

### ⚠️ Risk: Godot UIDs

Godot `.tscn` files reference resources by UID first, path second. Renaming files without updating UIDs should work (Godot falls back to path), BUT the safest approach is:
1. Run the rename script
2. Open the project in the Godot editor
3. Let it re-save any affected scenes to update internal path references
4. Test that all 8 games still load and play

### Implementation Steps

| Step | What | Depends On |
|------|------|-----------|
| 1a | Write case-aware Python rename script with the map above | — |
| 1b | Run script on a clean git state, review verification report | 1a |
| 1c | Hand-fix any edge cases from the report | 1b |
| 1d | Open in Godot editor, re-save affected scenes | 1c |
| 1e | Playtest all 8 games + full arcade run | 1d |
| 1f | Fix any broken references | 1e |
| 1g | Update memory bank + remaining planning docs with new names | 1f |

---

## Phase 1.5 — Copyright-Safety Visual Changes

Renaming isn't enough — the games also need to **look** distinct from their inspirations. These are targeted visual/mechanical tweaks, not rewrites.

### Change List

#### 1. Bug Blaster (Bug Blaster) — Formation Change
- **Current:** Classic narrow 5×11 grid, small step-down
- **New:** Wider formation (fewer rows, more columns), keep ~55 total invaders, increase step-down distance per edge hit
- **Why:** The classic Bug Blaster formation is iconic and recognizable. A wider, shallower grid with bigger step-downs feels different immediately.

#### 2. Block Drop (Block Drop) — Color Scheme + Juice Rework
- **Current:** NES-Block Drop-inspired color scheme, NES-style blink animation on line clear, standard next/held piece previews
- **New:**
  - **Color scheme:** Active (falling) blocks use cool colors (blues, teals, purples). Settled (locked) blocks shift to warm colors (oranges, reds, yellows). Gives instant visual feedback on state.
  - **Line clear juice:** Replace NES-blink with something custom — consider: row dissolve into particles, row flash + collapse, row shatter into fragments, or row "burn away" effect. NOT the iconic blink.
  - **Next/held piece previews:** Rethink the presentation. Options: ghost overlay showing where piece will land, animated piece rotation in preview box, or a different layout for the preview panel entirely.
- **Why:** The NES Block Drop color palette and blink-on-clear are deeply associated with the original. Cool/warm state colors are a clear visual signature.

#### 3. Brick Breaker (Brick Breaker) — Color Scheme + Layout Change
- **Current:** Standard Brick Breaker brick colors, standard narrow playfield
- **New:**
  - **Color scheme:** All bricks start white. A custom component colors bricks via `modulate` into different flag colors (e.g., rainbow gradient, or themed palettes — pirate flags, naval signals, etc.). The "flags" concept gives it personality.
  - **Layout:** Widen the brick layout AND widen the playfield proportionally. More bricks per row, wider paddle area.
- **Why:** The rows-of-colored-bricks layout is Brick Breaker's signature. White bricks + flag-coloring component makes it visually unique.

#### 4. Space Rocks (Space Rocks) — Ship + UFO Shape Redesign
- **Current:** Classic Space Rocks chevron ship, classic saucer UFO
- **New:**
  - **Ship shape:** More pronounced wings, flat nose. Still roughly chevron-shaped but clearly distinct — think "stealth bomber" vs "arrowhead." The wing tips should extend further and the nose should be blunted/flat.
  - **UFO shape:** Still saucer-like but with different sections (e.g., a raised center dome with antenna, asymmetric panels, or a more detailed silhouette). **Also:** use this redesign to make the visual shape more closely match its actual hitbox (which has been an annoyance).
- **Why:** The Space Rocks ship outline is one of the most recognizable shapes in gaming. It needs to be clearly different at a glance.

#### 5. Paddle Ball (Paddle Ball) — Center Line Change
- **Current:** Classic dashed line down center (Paddle Ball signature)
- **New:** Thin checkerboard pattern with 3 columns in the center zone. Gives a clearer visual distinction from Paddle Ball's iconic dotted line while still communicating "divided field."
- **Why:** The dashed center line IS Paddle Ball. A checkerboard center zone reads as "retro arcade" without being a direct copy.

### Implementation Steps

| Step | What | Depends On |
|------|------|-----------|
| 1.5a | Bug Blaster: adjust formation parameters in scene/spawner (wider grid, bigger step-down) | Phase 1 rename |
| 1.5b | Block Drop: implement cool/warm color shift for active vs settled blocks | Phase 1 rename |
| 1.5c | Block Drop: replace line-clear blink with custom juice effect | 1.5b |
| 1.5d | Block Drop: redesign next/held piece preview presentation | 1.5b |
| 1.5e | Brick Breaker: create flag-coloring component + apply to bricks | Phase 1 rename |
| 1.5f | Brick Breaker: widen layout + playfield dimensions | Phase 1 rename |
| 1.5g | Space Rocks: redraw ship vector (pronounced wings, flat nose) | Phase 1 rename |
| 1.5h | Space Rocks: redesign UFO shape + align visual to hitbox | Phase 1 rename |
| 1.5i | Paddle Ball: replace center line with 3-column checkerboard | Phase 1 rename |
| 1.5j | Playtest all 5 remakes — verify they feel distinct from originals | all above |

---

## Phase 1.8 — Web Performance Optimization

Target: **ThinkPad T480 running in a browser** (Intel UHD 620, WebGL). Optimize the synth-heavy audio pipeline and CRT rendering for smooth 60fps on integrated graphics.

### Background

The SoundSynth system (AudioStreamGenerator) does per-sample math in GDScript for up to 16 simultaneous voices. On a browser with no thread support, all audio processing runs on the main thread, competing with physics and rendering. The CRT shader does 7 texture samples per pixel at 640×360 (~1.6M samples/frame). Combined, these are the two largest frame-time consumers.

### Optimization Targets

| # | Optimization | File | Approach | Impact |
|---|-------------|------|----------|--------|
| 1 | Cap `max_fps=60` for web export | `export_presets.cfg` | Export preset override — 120fps is wasteful for a pixel art CRT game in a vsync'd browser | **High** — halves render workload |
| 2 | Reduce `MAX_VOICES` 16→8 | `sound_synth.gd` | Lower the hard cap. Sounds were getting lost at 6; try 8 as a middle ground | **High** — 50% fewer active synths |
| 3 | Cache `_get_frequency()` | `sound_synth.gd` | Pre-compute `440 * pow(2, (note-69)/12)` once per note change instead of per-sample (was called 256× per frame per voice) | **Medium** — eliminates pow() in hot loop |
| 4 | Fix NOISE dead code | `sound_synth.gd` | Line 308 computes `sample = randf()*2-1` which is immediately overwritten by line 311's lerp. Remove the dead `randf()` call | **Low-Medium** — saves randf() in hot path |
| 5 | Lower `MIX_RATE` 22050→11025 | `sound_synth.gd` | 11025 Hz is arcade-accurate (matches TI SN76489 / AY-3-8910 effective rates). Highest note B5 (987 Hz) is well within Nyquist. Halves all sample generation | **Medium** — 50% fewer samples to generate |
| 6 | Signal-based continuous dedup | `sound_synth.gd` | Blocked continuous synths currently poll `WeakRef.get_ref()` every frame. Instead: connect to the blocking synth's `tree_exiting` signal, then `set_process(false)` until the slot frees up. 54 blocked UFOs go from 54 wasted `_process` calls/frame to zero | **Medium** — eliminates wasted processing |
| 7 | Dirty-flag CRT shader params | `crt_controller.gd` | `_process()` pushes ~20 `set_shader_parameter()` calls every frame. In production, push once on mode switch only. Use a `_params_dirty` flag | **Medium** — eliminates 20+ WASM bridge calls/frame |
| 8 | Disable persistence VP in raster | `crt_controller.gd` | Persistence SubViewport runs `UPDATE_ALWAYS` even in raster mode (just outputs black). Set `UPDATE_DISABLED` when not in vector mode | **Medium** — eliminates wasted full-screen shader pass |
| 9 | Enable thread support in export | `export_presets.cfg` | Set `variant/thread_support=true`. Moves audio processing to a Web Worker. Progressive enhancement — game works without it, but browsers that support SharedArrayBuffer (all modern desktop browsers in 2026) get audio off the main thread | **Bonus** — offloads audio entirely |

### Implementation Details

#### 1. Web Export Preset Override (`export_presets.cfg`)
Add to `[preset.0.options]`:
```
application/run/max_fps=60
```
This overrides `project.godot`'s `max_fps=120` for the web build only. Desktop builds stay at 120.

#### 2. MAX_VOICES (`sound_synth.gd` line 46)
```gdscript
const MAX_VOICES: int = 8
```
Try 8 and playtest. If sounds are still getting lost, bump to 10. If still smooth on T480, try going down to 6.

#### 3. Cached frequency (`sound_synth.gd`)
Add a cached frequency variable, pre-computed when `note` changes or at play start:
```gdscript
var _cached_freq: float = 0.0

func _update_cached_freq() -> void:
    _cached_freq = 440.0 * pow(2.0, (note - 69) / 12.0)
```
Call `_update_cached_freq()` in `_ready()` and `play_one_shot()`. In `_get_sample()`, use `_cached_freq` instead of calling `_get_frequency()`.

#### 4. NOISE fix (`sound_synth.gd` lines 308-311)
Replace:
```gdscript
sample = randf() * 2.0 - 1.0
var noise = randf() * 2.0 - 1.0
var tone = sin(TAU * _phase)
sample = lerp(tone, noise, 0.5)
```
With:
```gdscript
var noise = randf() * 2.0 - 1.0
var tone = sin(TAU * _phase)
sample = lerp(tone, noise, 0.5)
```

#### 5. MIX_RATE (`sound_synth.gd` line 45)
```gdscript
const MIX_RATE: int = 11025
```
11025 Hz is the most commonly used rate for retro audio emulation. All notes C3-B5 (130-987 Hz) are well within Nyquist (5512 Hz).

#### 6. Signal-based continuous dedup (`sound_synth.gd`)
In `_try_claim_continuous()`, when a synth is blocked:
```gdscript
var blocking = ref.get_ref() as Node
if blocking and blocking.has_signal("tree_exiting"):
    blocking.tree_exiting.connect(_on_slot_freed)
    set_process(false)  # No polling needed
```
New method:
```gdscript
func _on_slot_freed() -> void:
    _try_claim_continuous()
    if _voice_active:
        set_process(true)
```
In `_exit_tree()`, disconnect if we were blocked:
```gdscript
# Clean up: disconnect from blocking synth if we were waiting
var ref = _continuous_registry.get(_signature)
if ref:
    var blocking = ref.get_ref() as Node
    if blocking and blocking.tree_exiting.is_connected(_on_slot_freed):
        blocking.tree_exiting.disconnect(_on_slot_freed)
```

#### 7. Dirty-flag CRT params (`crt_controller.gd`)
Add a `_params_dirty: bool = true` flag. In `_process()`, only push params when dirty:
```gdscript
if _params_dirty:
    _push_params()
    _params_dirty = false
```
Set `_params_dirty = true` in `set_vector_mode()`. In production builds, params only need pushing on mode switch. Inspector live-tweaking can set the dirty flag via property setters.

#### 8. Persistence VP in raster (`crt_controller.gd`)
In `set_vector_mode()`:
```gdscript
if _persistence_vp:
    _persistence_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
```

#### 9. Thread support (`export_presets.cfg`)
Set `variant/thread_support=true`. Note: requires itch.io to serve COOP/COEP headers. If the itch wrapper breaks, disable for itch export only — the other 8 optimizations make the game fast enough single-threaded.

### Implementation Steps

| Step | What | Depends On |
|------|------|-----------|
| 1.8a | Cap max_fps=60 in web export preset | — |
| 1.8b | Reduce MAX_VOICES to 8 | — |
| 1.8c | Cache `_get_frequency()` + fix NOISE dead code | — |
| 1.8d | Lower MIX_RATE to 11025 | — |
| 1.8e | Signal-based continuous dedup (tree_exiting) | — |
| 1.8f | Dirty-flag CRT params | — |
| 1.8g | Disable persistence VP in raster mode | — |
| 1.8h | Enable thread support in export preset | — |
| 1.8i | Playtest all 8 games — verify audio sounds correct at 11025 Hz with 8 voices | 1.8b–1.8d |
| 1.8j | Test on target (T480 browser) — measure frame time improvement | 1.8a–1.8h |

### Files Modified

| File | Changes |
|------|---------|
| `Scripts/Flow/sound_synth.gd` | Cached freq, NOISE fix, MIX_RATE→11025, MAX_VOICES→8, signal-based continuous dedup |
| `Scripts/Flow/crt_controller.gd` | Dirty-flag params, persistence VP disable in raster |
| `export_presets.cfg` | max_fps=60 override, thread_support=true |

### What's NOT Changing

- **CRT shader quality** — Deferred. The 7-sample shader is acceptable after the other optimizations reduce main-thread pressure. Can revisit with a "web quality" preset if frame time is still high post-testing.
- **Runtime `OS.has_feature("web")` checks** — Not needed. All changes are either constants that are fine globally (MIX_RATE 11025 sounds great on desktop too) or export-preset-specific (max_fps, thread support).
- **Game scripts or scenes** — Zero game behavior changes.
- `project.godot` — Desktop settings stay as-is.

---

## Phase 2 — Polybius Character

### What Polybius Is (In This Phase)

A **vector CRT face** that appears:
- **Run start:** Rolls up, delivers intro line ("I hunger for score."), rolls down → first game begins
- **Between games:** Quick flash — 1-2 word commentary ("More.", "Wasted.", "Again."), then gone
- **Run end (game over):** Face stays up longer, delivers 2-3 lines of judgment, then transitions to scoreboard
- **Occasional in-game taunt:** Low random chance during gameplay — face flickers briefly with a taunt line, then disappears

### Architecture

**Two-channel design** — Eyes and mouth are independent, allowing any expression at any mouth position for proper lip sync:

- **Eyes channel:** Face outline, eyes, pupils, eyebrows — controlled by `PolybiusEyes` resources (one per expression: neutral, displeased, etc.)
- **Mouth channel:** Mouth shape — controlled by `PolybiusMouth` resources (one per mouth position for lip sync)
- Both channels combine freely via two independent frame indices

**`polybius_eyes.gd`** — Custom Resource (`PolybiusEyes`):
- `outline`, `left_eye`, `right_eye`, `left_pupil`, `right_pupil`, `left_eyebrow`, `right_eyebrow` — all `PackedVector2Array`
- One resource per expression state, editable directly in the Godot inspector

**`polybius_mouth.gd`** — Custom Resource (`PolybiusMouth`):
- `mouth` — `PackedVector2Array`
- One resource per mouth position, editable in the inspector

**`polybius_face.gd`** — `@tool extends Control`:
- `eye_frames: Array[PolybiusEyes]` — expression frames
- `mouth_frames: Array[PolybiusMouth]` — lip sync frames
- `current_eye_frame: int` / `current_mouth_frame: int` — switch in inspector to preview combinations
- `_draw()` reads both channels and draws polylines
- `@tool` + `queue_redraw()` for live viewport preview while editing

- **Animations:** Face rolls up from below viewport, pauses, speaks, rolls back down. Quick-flash for between-game commentary.
- **Typewriter text:** Label that reveals text character-by-character. Emits `text_finished` when done.

**Voice lines:**
- **NOT procedural SoundSynth.** Self-recorded lines, bitcrushed post-production for Sinistar feel (whisper into mic → effects chain).
- Format: `.ogg` files in `Assets/Voice/`
- Playback triggered alongside typewriter text — each voice clip plays once when the face speaks

**Dialogue system:**
- Dictionary of voice line entries keyed by context
- Each entry has: text string + audio file path
- Categories: `INTRO`, `GAME_WIN`, `GAME_LOSS`, `GAME_OVER`, `TAUNT`
- Random selection within category, no-repeat tracking

### New Files

| File | Location | Purpose |
|------|----------|---------|
| `polybius_eyes.gd` | `Scripts/Hub/` | Custom Resource — eye/expression frame data (`PolybiusEyes`) |
| `polybius_mouth.gd` | `Scripts/Hub/` | Custom Resource — mouth frame data (`PolybiusMouth`) |
| `polybius_face.gd` | `Scripts/Hub/` | `@tool` Control — vector face drawing, two-channel frame system |
| `polybius_face.tscn` | `Scenes/Hub/` | Face scene (Control + script) |
| Voice line assets | `Assets/Voice/` | Self-recorded, bitcrushed .ogg files |

### Modified Files

| File | Changes |
|------|---------|
| `arcade_orchestrator.gd` | Add `INTRO` state. Integrate Polybius face into state transitions (INTRO → face appears, RESULT → quick comment, GAME_OVER → face stays, PLAYING → random taunt) |
| `arcade_orchestrator.tscn` | Add PolybiusFace node as child |

### AO Integration Points

The orchestrator already has state transitions. Polybius plugs into them:

| AO State | Polybius Action |
|----------|----------------|
| `BOOT` | Face hidden. "PRESS START" appears as before. |
| `INTRO` (new) | Face rolls up. Plays INTRO voice line. On `text_finished` → face rolls down → first game loads. |
| `PLAYING` | Face hidden. Low random chance (5% per minute?) → face flickers with TAUNT line, disappears after 2s. |
| `RESULT` | Quick flash. Plays GAME_WIN or GAME_LOSS line. 1-2 words, fast. |
| `GAME_OVER` | Face rolls up. Plays GAME_OVER lines (2-3). On `text_finished` → scoreboard. |

**New AO state:** `INTRO` — inserted between BOOT and the first game load. Short (~3s), just Polybius intro.

### Voice Line Set (First Pass)

| Category | Lines |
|----------|-------|
| INTRO | "I hunger for score." / "Feed me." / "Play." |
| GAME_WIN | "More." / "Acceptable." / "Again." |
| GAME_LOSS | "Wasted." / "Careless." / "Fragile." |
| GAME_OVER | "Not even on the leaderboard. How pathetic." / "You fed me nothing." / "The cabinet remains." |
| TAUNT | "Your hesitation feeds nothing." / "I am still hungry." / "Do not stop." |

### Implementation Steps

| Step | What | Depends On |
|------|------|-----------|
| 2a | Create `polybius_face.gd` — vector face drawing + expression states | — |
| 2b | Create `polybius_face.tscn` — face scene with typewriter label | 2a |
| 2c | Record voice lines + bitcrush → export as .ogg | — |
| 2d | Implement typewriter text + voice playback sync | 2b, 2c |
| 2e | Implement face animations (roll up/down, quick flash) | 2b |
| 2f | Add INTRO state to AO + face integration on run start | 2e |
| 2g | Add quick-comment integration on RESULT state | 2e |
| 2h | Add game-over integration on GAME_OVER state | 2e |
| 2i | Add random in-game taunt during PLAYING state | 2e |
| 2j | Playtest full arcade run with Polybius | all above |

---

## Implementation Order

Phase 1 (rename) should complete before Phase 2 (Polybius) so that Polybius integration references the new game names from the start.

| Phase | What | Steps | Est. Days |
|-------|------|-------|-----------|
| **1** | Copyright rename | 1a–1g | 1–2 |
| **1.5** | Copyright-safety visuals | 1.5a–1.5j | 2–3 |
| **1.8** | Web performance optimization | 1.8a–1.8j | 1–2 |
| **2** | Polybius character | 2a–2j | 3–4 |

---

## Risks & Considerations

1. **Rename script false positives** — The script replaces longest matches first (Meteor Rally → Meteor Rally before Paddle Ball → Paddle Ball). But edge cases like variable names or comments that happen to contain substrings may need hand-fixing. The 90% target is realistic.

2. **Godot UID integrity** — After renaming files, some UIDs may reference stale paths. Opening in the Godot editor and re-saving should fix this, but it's a manual verification step that must not be skipped.

3. **Voice line production pipeline** — Recording + bitcrushing is a non-code task. Could block Phase 2 if voice lines aren't ready. **Mitigation:** Build the face system with text-only (no audio) first. Add voice clips when ready. The typewriter text alone is functional.

4. **In-game taunt interruption** — If Polybius flickers during gameplay, it must not steal input focus or obscure the play area. The face should appear in an unused screen region (top corners?) or as a semi-transparent overlay that doesn't block the game.

5. **Two-word game names** — "Paddle Ball", "Brick Breaker", "Space Rocks" etc. have spaces in their display titles but not in filenames (snake_case). The `game_title` property uses display form; filenames use snake_case. The script handles this automatically.

---

## What Doesn't Change

- **Component architecture** — No new components for Polybius; it's a Hub script. Phase 1.5 adds one new component (brick flag-coloring) but doesn't change the architecture.
- **Game mechanics** — Phase 1.5 is visual/layout only. No changes to how games play (except Bug Blaster formation parameters, which affect difficulty but not rules).
- **Interface.gd** — No modifications
- **Scrolling transition mechanics** — Unchanged
- **ArcadeGameEntry structure** — Unchanged (just renamed .tres files and updated paths)