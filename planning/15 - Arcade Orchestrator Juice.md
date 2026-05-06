# Plan 15 — Arcade Orchestrator Juice (Polybius + Renaming)

**Created:** 2026-05-06  
**Status:** Not started  
**Timeline:** Before itch export (late May)  
**Scope:** Three phases — Copyright rename pass + Copyright-safety visual changes + Polybius face/voice integration  
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
| Pongsteroids | Meteor Rally | Hybrid name, evokes space + competition |
| Breaksteroids | Rock Breaker | Hybrid name, evokes asteroids + breaking |
| Pong | Paddle Ball | Bootleg literal, from renaming.md |
| Breakout | Brick Breaker | Most obvious bootleg name in history |
| Asteroids | Space Rocks | Literal, descriptive, zero effort |
| Tetris | Block Drop | What every bootleg cabinet was actually called |
| Space Invaders | Bug Blaster | Not even pretending it's not Space Invaders |
| Dogfight | Dogfight | Original — no change |

**Order matters:** The rename script processes longest/most-specific names first (Pongsteroids before Pong) to prevent partial matches.

### What Gets Renamed

**File names:**
- Game scenes: `pong.tscn` → `paddle_ball.tscn`, etc.
- ArcadeGameEntry .tres filenames

**File contents — all text files (.tscn, .gd, .tres, .md, .txt):**
- `game_title` UGS export values
- Scene resource path references (e.g., `path="res://Scenes/Games/remakes/pong.tscn"`)
- Node names inside scenes (e.g., `[node name="SpaceInvaders"` → `[node name="BugBlaster"`)
- ArcadeGameEntry scene references
- Code comments and doc references

### Case-Aware Rename Script (Python)

The script generates all case variants for each rename pair and replaces them across the codebase:

| Variant | Example (Pong → Paddle Ball) |
|---------|------|
| Display (Title Case with space) | "Pong" → "Paddle Ball" |
| PascalCase (no space) | "Pong" → "PaddleBall" |
| snake_case | "pong" → "paddle_ball" |
| SCREAMING_SNAKE | "PONG" → "PADDLE_BALL" |
| lowercase | "pong" → "paddle ball" |
| UPPERCASE | "PONG" → "PADDLE BALL" |
| Filename (snake_case) | `pong.tscn` → `paddle_ball.tscn` |

**Example expansions:**

| Old | New |
|-----|-----|
| `pong` / `Pong` / `PONG` / `pong` | `paddle ball` / `Paddle Ball` / `PADDLE BALL` / `paddle_ball` |
| `pongsteroids` / `Pongsteroids` / `PONGSTEROIDS` | `meteor rally` / `MeteorRally` / `METEOR RALLY` |
| `space_invaders` / `SpaceInvaders` / `Space Invaders` | `bug_blaster` / `BugBlaster` / `Bug Blaster` |

The script:
1. **Git commit** — Ensure clean state before rename
2. **Build variant map** — For each rename pair, generate all case variants
3. **Find-and-replace in file contents** — Process all `.tscn`, `.gd`, `.tres`, `.md`, `.txt` files. Longest matches first to avoid partial collisions.
4. **Rename files** — `mv` game scene files and .tres files to their new snake_case names
5. **Verification report** — Grep for remaining old names, print results for manual review

**Target: 90% automated.** Edge cases (e.g., a comment that says "Pong-style gameplay" where the hyphenation changes meaning) are hand-fixed.

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

#### 1. Bug Blaster (Space Invaders) — Formation Change
- **Current:** Classic narrow 5×11 grid, small step-down
- **New:** Wider formation (fewer rows, more columns), keep ~55 total invaders, increase step-down distance per edge hit
- **Why:** The classic Space Invaders formation is iconic and recognizable. A wider, shallower grid with bigger step-downs feels different immediately.

#### 2. Block Drop (Tetris) — Color Scheme + Juice Rework
- **Current:** NES-Tetris-inspired color scheme, NES-style blink animation on line clear, standard next/held piece previews
- **New:**
  - **Color scheme:** Active (falling) blocks use cool colors (blues, teals, purples). Settled (locked) blocks shift to warm colors (oranges, reds, yellows). Gives instant visual feedback on state.
  - **Line clear juice:** Replace NES-blink with something custom — consider: row dissolve into particles, row flash + collapse, row shatter into fragments, or row "burn away" effect. NOT the iconic blink.
  - **Next/held piece previews:** Rethink the presentation. Options: ghost overlay showing where piece will land, animated piece rotation in preview box, or a different layout for the preview panel entirely.
- **Why:** The NES Tetris color palette and blink-on-clear are deeply associated with the original. Cool/warm state colors are a clear visual signature.

#### 3. Brick Breaker (Breakout) — Color Scheme + Layout Change
- **Current:** Standard Breakout brick colors, standard narrow playfield
- **New:**
  - **Color scheme:** All bricks start white. A custom component colors bricks via `modulate` into different flag colors (e.g., rainbow gradient, or themed palettes — pirate flags, naval signals, etc.). The "flags" concept gives it personality.
  - **Layout:** Widen the brick layout AND widen the playfield proportionally. More bricks per row, wider paddle area.
- **Why:** The rows-of-colored-bricks layout is Breakout's signature. White bricks + flag-coloring component makes it visually unique.

#### 4. Space Rocks (Asteroids) — Ship + UFO Shape Redesign
- **Current:** Classic Asteroids chevron ship, classic saucer UFO
- **New:**
  - **Ship shape:** More pronounced wings, flat nose. Still roughly chevron-shaped but clearly distinct — think "stealth bomber" vs "arrowhead." The wing tips should extend further and the nose should be blunted/flat.
  - **UFO shape:** Still saucer-like but with different sections (e.g., a raised center dome with antenna, asymmetric panels, or a more detailed silhouette). **Also:** use this redesign to make the visual shape more closely match its actual hitbox (which has been an annoyance).
- **Why:** The Asteroids ship outline is one of the most recognizable shapes in gaming. It needs to be clearly different at a glance.

#### 5. Paddle Ball (Pong) — Center Line Change
- **Current:** Classic dashed line down center (Pong signature)
- **New:** Thin checkerboard pattern with 3 columns in the center zone. Gives a clearer visual distinction from Pong's iconic dotted line while still communicating "divided field."
- **Why:** The dashed center line IS Pong. A checkerboard center zone reads as "retro arcade" without being a direct copy.

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

## Phase 2 — Polybius Character

### What Polybius Is (In This Phase)

A **vector CRT face** that appears:
- **Run start:** Rolls up, delivers intro line ("I hunger for score."), rolls down → first game begins
- **Between games:** Quick flash — 1-2 word commentary ("More.", "Wasted.", "Again."), then gone
- **Run end (game over):** Face stays up longer, delivers 2-3 lines of judgment, then transitions to scoreboard
- **Occasional in-game taunt:** Low random chance during gameplay — face flickers briefly with a taunt line, then disappears

### Architecture

**`polybius_face.gd`** — Control node that draws a vector face:

- **Face construction:** All `_draw()` — rounded rect border, two circular eyes with pupils, mouth line, scanline overlay. Amber/green phosphor color palette.
- **Expression states:** Enum — `IDLE`, `SPEAKING`, `PLEASED`, `DISPLEASED`, `NEUTRAL`. Each state adjusts eye size/position and mouth shape.
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
| `polybius_face.tscn` | `Scenes/Hub/` | Face scene (Control + script) |
| `polybius_face.gd` | `Scripts/Hub/` | Vector face drawing, expressions, typewriter, animations |
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
| **2** | Polybius character | 2a–2j | 3–4 |

---

## Risks & Considerations

1. **Rename script false positives** — The script replaces longest matches first (Pongsteroids → Meteor Rally before Pong → Paddle Ball). But edge cases like variable names or comments that happen to contain substrings may need hand-fixing. The 90% target is realistic.

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