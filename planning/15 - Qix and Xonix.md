# Plan 15 — Qix and Xonix

**Created:** 2026-05-03  
**Status:** Pending (after Plan 14)  
**Scope:** 2 new remakes (Qix, Xonix) — shared core components (`territory_grid`, `line_drawer`, `area_filler`)

---

## Why These Two Together

Qix and Xonix are mechanical siblings — both are **territory claiming games** where the player draws lines to capture regions of a playing field. The shared core is identical:

- A boolean bitmap tracking claimed vs. unclaimed territory
- A line-drawing state machine (safe on border, vulnerable while drawing)
- A flood-fill algorithm that claims the correct region when a line completes

Xonix is essentially "Qix with a ship" — the player moves freely like in Asteroids rather than being constrained to the border like a cursor. The territory system is identical; only the player's movement model differs.

---

## Shared Territory System

Both games depend on three new components that form the territory engine:

### `territory_grid` (Components)
- 640×360 boolean bitmap (~230KB)
- Core API: `get(x,y)`, `set(x,y,claimed)`, `flood_fill(seed_point, avoid_point) → int` (returns claimed count)
- `get_claimed_percent() → float`
- `get_border_pixels() → Array[Vector2i]` (pixels adjacent to both claimed and unclaimed)
- `is_border(x,y) → bool`
- Emits `territory_changed(percent)`
- Configurable win threshold — when percent exceeds threshold, emits `territory_victory`

### `line_drawer` (Components)
- Tracks player's drawing state: `SAFE` (on border) or `DRAWING` (in open space)
- On entering unclaimed space: starts recording pixel path, spawns collision trail segments
- On reconnection to border: emits `line_completed(path)` to area_filler
- Player is flagged vulnerable while drawing (other components can check `is_drawing`)
- Emits `drawing_started`, `drawing_completed(path)`, `drawing_failed` (killed while drawing)

### `area_filler` (Components)
- On `drawing_completed(path)`: determines which side of the line to claim
- Strategy: flood fill from both sides of the completed line. Check which side contains the Qix. Claim the **other** side (or the smaller side if ambiguous)
- Calls `territory_grid.flood_fill()` for the chosen region
- Emits `area_claimed(pixel_count, percent)`

---

## Game 1 — Qix

### Game Design
- Rectangular playing field, 640×360 pixels
- Territory is a boolean bitmap: each pixel is either **claimed** or **unclaimed**
- Player moves along the **border** between claimed/unclaimed (slow, safe)
- Player can **draw** into unclaimed space (fast, vulnerable)
- When drawing line reconnects to border: the smaller region (or region without Qix) is **claimed**
- **Qix** — main enemy, bounces randomly inside unclaimed territory
- **Sparx** — follow border lines, kill player on contact
- Player dies if touched by Qix while drawing, or by Sparx anytime
- Win condition: claim 75% of territory
- Lives: 3 per game

### Player Movement
- **Border mode:** Player can only move along the claimed/unclaimed boundary. Think of it as sliding along the edge.
- **Drawing mode:** Player presses a direction into open space. Line_drawer records the path. Speed is faster while drawing (original Qix quirk: slow on border, fast while drawing)
- **Reconnection:** When the player's drawn path reaches a border pixel, the line is completed and area_filler runs

### Reusable Components

| Component | Role |
|-----------|------|
| `player_control` | Player directional input |
| `direct_movement` | Player movement (border + drawing) |
| `die_on_hit` | Death on Qix/Sparx contact |
| `health` | Player lives (3) |
| `points_monitor` | Score tracking (% claimed × speed bonus) |
| `timer` | Optional time pressure |
| `lives_counter` | Lives across rounds |
| `interface` | UI |
| `sound_synth` | Audio |

### New Components (Qix-Specific)

| Component | Category | Description |
|-----------|----------|-------------|
| `qix_ai` | Brains | Random walk within unclaimed territory. Queries `territory_grid` to stay in open space. Changes direction periodically. Speed increases over time. Configurable: base speed, direction change frequency. |
| `sparx_ai` | Brains | Traces along claimed/unclaimed border pixels. Queries `territory_grid.get_border_pixels()` or walks adjacent border pixels. Reverses at endpoints or randomly. |

### New Bodies

| Body | Description |
|------|-------------|
| `qix_body` | Drawing: animated spinning lines/shape. Pure `_draw()` — no logic. |
| `sparx_body` | Drawing: small diamond. Pure `_draw()` — no logic. |

### Assembly Sketch

```
UniversalGameScript (Qix)
├── Interface
├── PointsMonitor
├── LivesCounter
├── Timer
├── TerritoryGrid (win_threshold=0.75)
├── AreaFiller
├── Player Cursor (UniversalBody)
│   ├── player_control
│   ├── direct_movement
│   ├── line_drawer
│   ├── die_on_hit (Qix + Sparx groups)
│   └── paddle (drawing — repurposed as cursor)
├── Qix (UniversalBody)
│   ├── qix_ai
│   ├── direct_movement
│   └── qix_body (drawing)
├── Sparx (UniversalBody) × 2
│   ├── sparx_ai
│   ├── direct_movement
│   └── sparx_body (drawing)
└── SoundSynth instances
```

### Deliverable
Playable Qix: player draws lines to claim territory. Qix bounces in open space. Sparx patrol borders. Claim 75% to win. 3 lives. Flood fill correctly claims the non-Qix side.

---

## Game 2 — Xonix

### Game Design
- Rectangular playing field, 640×360 pixels (same territory system as Qix)
- Player controls a **ship** that moves freely in the already-claimed zone (safe) or draws into unclaimed zone (vulnerable)
- The ship has **inertia** — it doesn't stop instantly (unlike Qix's cursor)
- When the ship's drawn trail reconnects to claimed territory: the region is claimed
- **Qix-type enemies** bounce in unclaimed space
- **Sparx-type enemies** patrol the borders
- Additional **mine** enemies that sit on the border and expand over time
- Win condition: claim X% of territory
- Lives: 3 per game

### Key Differences from Qix
| Aspect | Qix | Xonix |
|--------|-----|-------|
| Player entity | Cursor (point) | Ship (has rotation, inertia) |
| Movement | Grid-constrained on border | Free movement in claimed zone |
| Drawing speed | Faster than border speed | Same speed, but inertia makes it risky |
| Enemies | Qix + Sparx | Qix + Sparx + Mines |
| Feel | Precise, methodical | Fast, action-oriented |

### Player Movement
- **Claimed zone:** Ship moves freely with slight inertia. Safe from Qix.
- **Drawing zone:** Ship enters unclaimed space, trail records behind it. Vulnerable to Qix contact.
- **Reconnection:** When ship re-enters claimed territory, trail completes and area_filler runs.
- **Key difference:** In Xonix, the ship can move freely in claimed space and start drawing from ANY edge of claimed territory, not just the outer border.

### Reusable Components

| Component | Role |
|-----------|------|
| `player_control` | Player input |
| `engine_simple` | Ship movement with inertia |
| `rotation_direct` | Ship rotation |
| `die_on_hit` | Death on enemy contact |
| `health` | Player lives |
| `points_monitor` | Score |
| `lives_counter` | Lives |
| `interface` | UI |
| `sound_synth` | Audio |
| **territory_grid** | Shared territory bitmap |
| **line_drawer** | Shared drawing state machine |
| **area_filler** | Shared flood fill |

### New Components (Xonix-Specific)

| Component | Category | Description |
|-----------|----------|-------------|
| `mine_ai` | Brains | Sits on a border pixel. Periodically claims adjacent pixels, slowly expanding into unclaimed space. Kills player on contact. Queries `territory_grid` for border positions. |

### New Bodies

| Body | Description |
|------|-------------|
| `mine_body` | Drawing: small circle/X. Pure `_draw()` — no logic. |

### Assembly Sketch

```
UniversalGameScript (Xonix)
├── Interface
├── PointsMonitor
├── LivesCounter
├── TerritoryGrid (win_threshold=0.75)
├── AreaFiller
├── Player Ship (UniversalBody)
│   ├── player_control
│   ├── engine_simple
│   ├── rotation_direct
│   ├── line_drawer
│   ├── die_on_hit (Qix + Sparx + Mine groups)
│   └── triangle_ship (drawing — repurposed as Xonix ship)
├── Qix (UniversalBody)
│   ├── qix_ai
│   ├── direct_movement
│   └── qix_body (drawing)
├── Sparx (UniversalBody) × 2
│   ├── sparx_ai
│   ├── direct_movement
│   └── sparx_body (drawing)
├── Mine (UniversalBody) × 3
│   ├── mine_ai
│   └── mine_body (drawing)
└── SoundSynth instances
```

### Deliverable
Playable Xonix: ship moves freely in claimed zone, draws into unclaimed zone. Enemies bounce/patrol/mine. Claim 75% to win. Inertia-based movement gives a different feel from Qix.

---

## New Component Summary (Both Games)

| Component | Category | Used By | Complexity |
|-----------|----------|---------|------------|
| `territory_grid` | Components | Qix + Xonix + future remixes | **High** — 640×360 bitmap + flood fill + border detection |
| `line_drawer` | Components | Qix + Xonix + future remixes | **High** — drawing state machine + path recording + reconnection detection |
| `area_filler` | Components | Qix + Xonix + future remixes | **Medium** — flood fill with Qix avoidance |
| `qix_ai` | Brains | Qix + Xonix | **Medium** — random walk constrained to unclaimed pixels |
| `sparx_ai` | Brains | Qix + Xonix | **Medium** — border tracing algorithm |
| `mine_ai` | Brains | Xonix only | **Low** — sit on border, slowly expand |

### New Bodies

| Body | Used By |
|------|---------|
| `qix_body` | Qix + Xonix (shared enemy) |
| `sparx_body` | Qix + Xonix (shared enemy) |
| `mine_body` | Xonix only |

---

## Implementation Order

| Step | What | Depends On | Notes |
|------|------|-----------|-------|
| 1 | Create `territory_grid` component | — | Core data structure. Test flood fill independently. |
| 2 | Create `line_drawer` component | territory_grid | Drawing state machine + reconnection. |
| 3 | Create `area_filler` component | territory_grid | Flood fill with Qix avoidance. |
| 4 | Create `qix_body` + `sparx_body` | — | Drawing-only bodies. |
| 5 | Create `qix_ai` brain | territory_grid | Random walk in unclaimed space. |
| 6 | Create `sparx_ai` brain | territory_grid | Border tracing. |
| 7 | Assemble Qix game | 1–6 | Full game assembly. |
| 8 | Playtest Qix | 7 | Territory claiming must work correctly. |
| 9 | Create `mine_body` | — | Drawing-only body. |
| 10 | Create `mine_ai` brain | territory_grid | Border expansion behavior. |
| 11 | Assemble Xonix game | 1–6, 9–10 | Reuses all territory components + Qix/Sparx. |
| 12 | Playtest Xonix | 11 | Ship inertia feel, mine behavior. |

---

## Design Considerations

1. **Territory Grid performance** — 640×360 flood fill on 230K pixels. Optimization: early-exit when Qix is found during fill (then claim the other side). Also: limit fill to bounding box of the completed path + margin.

2. **Line Drawer reconnection** — Detecting when the drawn path reconnects to existing border. Options: (a) collision-based (trail segment hits border collider), (b) pixel-check (head position is on a border pixel in territory_grid). Pixel-check against territory_grid is more reliable — `territory_grid.is_border(x,y)`.

3. **Qix AI in shrinking space** — As territory is claimed, unclaimed space shrinks. Qix AI must query territory_grid efficiently. If unclaimed space becomes very small or fragmented, Qix needs to handle dead ends (reverse direction, or teleport to largest unclaimed pocket).

4. **Border detection** — `territory_grid.is_border(x,y)` must be fast (called every frame by line_drawer and sparx_ai). Consider caching border pixels or computing on-the-fly from 4-neighbor check.

5. **Qix vs Xonix player feel** — Qix uses `direct_movement` (snappy, grid-aligned cursor). Xonix uses `engine_simple` (inertial ship). Same territory system, different movement = different game feel. This is the key design win of pairing them.

6. **Drawing speed** — Original Qix has the quirk that drawing is FASTER than border movement. This is counterintuitive but deliberate — encourages risky drawing. Xonix doesn't have this split (same speed everywhere, but inertia makes drawing naturally riskier). `line_drawer` should expose a `drawing_speed_multiplier` export for Qix to configure.

7. **Partial claims** — If the player is killed while drawing, the partial trail should be cleaned up. `line_drawer` should revert (unclaim trail pixels) on death, or simply despawn trail segments. Original Qix: partial trails are lost (no claim). Same for Xonix.

---

## Risks

1. **Flood fill is the hardest single mechanic in the project.** Getting the "which side to claim" logic right — especially with irregular line shapes — requires careful testing. Start with simple rectangles, then test curves and spirals.

2. **Pixel-level collision sync.** The territory bitmap and the physics collision bodies (trail segments, Qix body, Sparx body) must agree on what's claimed and what's border. Drift between these two representations will cause bugs.

3. **Qix AI edge cases.** If the player claims territory in a way that splits unclaimed space into two disconnected regions, and the Qix is in one of them, the AI must handle being trapped. Options: teleport to largest region, or die + respawn.

4. **Xonix mines on dynamic borders.** Mines sit on border pixels, but borders change as territory is claimed. Mines need to update their position when the border shifts underneath them.