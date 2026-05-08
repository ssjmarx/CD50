# End State: CD50 — Arcade Cabinet

**Last Updated:** 2026-05-08

---

## Vision

CD50 is **"Balatro but with classic arcade games instead of poker."**

A collection of classic arcade games from the 70s and 80s — remade and remixed — bound together by a Balatro-inspired system of modifiers. The player plays the game as a series of "runs", which consist of 20-60 second arcade game rounds, losing a life (and instantly progressing to the next game) if they die, and ending the run when they lose all three lives.  The main goal is chasing ever-higher scores by breaking the logic of the games with combinations of modifiers. Every game is built entirely from reusable, composable components. Zero game-specific scripts exist.

The project initially ships a demo as an **itch.io arcade cabinet** with a meta-level orchestrator that runs games in sequence with fast rules, lives, and cumulative scoring. A **Steam Coming Soon** page drives wishlists toward an **October 2026 Next Fest** launch of the full game.

---

## The Arcade Cabinet

Every game runs inside a simulated CRT monitor:

- **Custom lightweight CRT shader** (~80 lines GLSL) — barrel warp, chromatic aberration, bloom, vignette, hum bar, flicker, brightness/contrast. All parameters inspector-tunable.
- **Raster mode** — Scanline overlay, milder bloom. For grid/pixel games (Paddle Ball, Brick Breaker, Bug Blaster, Block Drop, Rock Breaker).
- **Vector monitor mode** — Brighter bloom, stronger warp, phosphor dot grid overlay, SubViewport-based phosphor persistence with exponential decay. For vector-line games (Space Rocks, Dogfight, Meteor Rally). Moving objects leave glowing afterimages that fade like ghostly trails. No per-body components — shader handles everything.
- **Per-game display mode switching** via `vector_monitor` export on UGS. The arcade orchestrator toggles mode on game start.
- **Self-building CRT controller** — No `.tscn` needed. Programmatically creates BackBufferCopy, persistence SubViewport, CRT shader ColorRect, and 3 PNG overlay TextureRects. Fully portable.

---

## Game Roster

### Remakes (5/5 built)

| # | Game | Description | Status |
|---|------|-------------|--------|
| 1 | **Paddle Ball** | Two paddles, one ball, first to 11 wins | ✅ Built |
| 2 | **Brick Breaker** | Paddle + ball vs grid of breakable bricks | ✅ Built |
| 3 | **Space Rocks** | 360° ship, drifting/splitting asteroids, screen wrap | ✅ Built |
| 4 | **Bug Blaster** | Invader swarm marching downward, player shoots upward | ✅ Built |
| 5 | **Block Drop** | Modern tetromino stacking with ghost piece, hold, T-spin, combo/B2B scoring | ✅ Built |

### Remixes & Originals (3/10 built, 3 designed, 9 TBD)

| # | Game | Type | Status |
|---|------|------|--------|
| 1 | **Dogfight** | Original — survive gauntlet of enemies, death is guaranteed | ✅ Built |
| 2 | **Meteor Rally** | Paddle Ball + Space Rocks — paddle keeps ball alive while dodging asteroids | ✅ Built |
| 3 | **Rock Breaker** | Brick Breaker + Space Rocks — bricks in a bouncing asteroid field | ✅ Built |
| 4 | **Bug Drop** | Block Drop + Bug Blaster — invaders march upward, tetrominos drop downward, any complete row clears | 📐 Designed |
| 5 | **Space Bugs** | Bug Blaster + Space Rocks — invaders AND Sdrifting asteroids simultaneously | 📐 Designed |
| 6 | **Planetary Attack!** | Bug Blaster reversed — player controls the invader swarm, assaulting AI defenders | 📐 Designed |
| 7–15 | *(TBD)* | — | 🔲 Blank |

### Total: 8 playable, targeting 20 for demo (5/15 split), and 50 for launch (10/40 split)

Game target is aspirational, but entirely achievable thanks to component architecture.  While some will be "first class" remixes with custom mechanics and unique design goals, necessity demands that many will be "second tier" remixes that change only one or two variables from the base game.

### Arcade Rules

During a "run", the games are modified with "fast play" rules, balanced around 20-60 seconds per game

- Paddle Ball ends after a single score
- Brick Breaker and Block Drop give 20 seconds to get as many points as possible without dying
- Space Rocks and Bug Blaster last for a single wave
- Games with a "mystery ship" or other bonus mechanics have it limited to only a single fast appearance

During a "run", the player is awarded a "speed bonus" every time they complete a game without dying, worth 1,000 points if they complete it in 20 seconds or less, and decaying to 0 if they spend 60 seconds or more in the game

---

## The Progression System

### Modifiers — "Illegal Modifications"

Before each run, select from a locker of passive modifiers that rewrite the rules of every game:

| # | Modifier | Effect | Unlock Score |
|---|----------|--------|-------------|
| 1 | **Double Barrel** | `gun_simple` fires 2 bullets with slight spread | 100 |
| 2 | **Overclocked CPU** | All Leg components: speed × 1.25 | 1,000 |
| 3 | **Feature Creep** | All spawner components: entity_count × 2 | 10,000 |
| 4 | **Crunch Time** | Lives set to 1. All score values × 3.0 | 100,000 |
| 5 | **Scope Creep** | All CollisionShape radii × 1.20 (bigger hitboxes for everything) | 1,000,000 |

Modifiers unlock as **lifetime score** climbs. Combine freely. Break the game open.

**Technical approach:** `ModifierManager` node spawned by ArcadeOrchestrator. Connects to `SceneTree.node_added`. When a matching node enters the tree, applies property overrides before `_ready` finishes. No game scenes need modification.

Tergeting 5 modifiers for demo (freely selectable), and 50 for launch (score-gated random drops, progression gated number equippable, combination of "contraband" which can be equipped at any time and more powerful "tokens" which are single-use)

### Playlists

- Not implemented for demo, targeted for full release
- The player's other main form of agency in between runs is curating their own playlists of games
- Because some modifiers are better for certain games than others, they are encouraged to create powerful combinations
- Playlists must consist of at least 10 games
- In order to put a game onto a playlist, the player must collect the "floppy" containing that game

### Drops

- Not implemented for demo, targeted for full release
- Drops are awarded in game as drops to be picked up whenever the player crosses a score threshold
- Mercy rule: if the player "wins" a game and an uncollected drop is on screen and less than 5 seconds old, they get it
- Drops include modifiers, floppies, and lore files

### Semi-Random Playlist

- **Phase 1 (Warm-up):** 2 random games from remakes
- **Phase 2 (The Remix):** Random remixes/originals, no repeats until exhausted
- Games continue until meta-lives run out
- Full game will include player-buildable playlists by unlocking games from randomly dropped "floppy disks" (same score gate system as modifiers)

### Score Persistence

- `lifetime_score` persists across runs (JSON via `user://`, works on both desktop and web/IndexedDB)
- Top 10 high scores saved with initials + date
- Score gate system checks unlocks on boot
- Full game will target online high scores/achievements via Steam

### Bosses and Bug Bounties

- Not implemented for demo, targeted for full release
- Tokens are single-use powerful modifiers, the most common of which is a quarter, which gives the player an extra life
- Bosses are single games with a longer runtime (2-3 minutes) consisting of multiple phases
- During a regular run, the player will encounter a boss every 9 levels.  Completion will grant a massive score payout and multiplier increase for the run
- Bug Bounties are playlists of multiple games with challenging rules that award a large number of random tokens if completed successfully

### Glitches

- Not implemented for demo, targeted for full release
- During a run, every 8 games the player will be afflicted by a "glitch"
- Glitches are modifiers that make games harder, but don't grant a score bonus
- Glitches increase pressure on "deep" runs, where the modifier can get extremely high

### Player Progression

- The game's equivalent to an "ante" is the high score board, which lists scores from 1,000 to 1,000,000,000 on a fresh save file
- The player's progression is gated by the highest score they've achieved, with new modifier slots being unlocked at each tier
- The player's progression is also gated by their score during a single run, with rare modifier drops being granted only at higher score tiers
- A lite version of this progression is targeted for the demo (scoring from 100-1,000,000 unlocks up to 5 modifiers)

### Lore

- Not implemented for demo, targeted for full release
- Polybius is a mysterious game cabinet that was being investigated by the CIA
- This ties into the urban legend about it being a government mind control machine, however the real story is that it was [redacted]
- Because nobody in America knows the cabinet's programming language, the player is a researcher/game preservationist trying to find out its secrets by playing it
- The player finds lore documents among the drops while playing the games, and can piece together the full story of Polybius as a meta narrative while progressing

---

## Polybius

*"I hunger for score."*

Polybius is the digital jailer. He judges, mocks, and demands more. When a new high score is set, he only raises the bar. Designed as a narrator/face/voice for the arcade experience - a personality that makes the cabinet feel alive - and as a thematic anchor for the full experience, doling out lore tidbits and pushing the player to complete his challenges.

---

## Architecture

- **88 components** across 10 categories (Core, Bodies, Brains, Legs, Arms, Components, Rules, Flow, Effects, Hub)
- **Zero game scripts** — every game is a `UniversalGameScript` root with attached components
- **Signal flow:** Brains → Body → Legs/Arms → Components/Rules/Flow → Effects
- **UGS as event bus:** Components communicate through game-level signals (`hold_requested`, `t_spin_detected`, `piece_settled`)
- **Body scripts are drawing code only** — visual shape, colors, `_draw()` calls. All behavior from attached components.
- **UGS Mode enum:** STANDALONE vs ARCADE — same game scenes work standalone or under orchestrator
- **Arcade bonus passthrough:** Orchestrator pushes multiplier to UGS so in-game scoring is affected without modifying game scenes
- **Property overrides:** `ArcadeGameEntry` reuses `PropertyOverride` resource for per-game tuning
- **Interface Takeover:** AO hijacks each game's child Interface, becomes sole source of truth for displayed values
- **Physics-based grid:** Block Drop uses no grid data structure — all detection via physics queries
- **Component toggleability:** Features enabled/disabled by including/excluding component scenes

---

## Shipping Scope

| Milestone | Timeline | Status |
|-----------|----------|--------|
| Steamworks setup + itch.io pipeline | May 6–11 | In progress |
| Finalize arcade content + export to itch | May 12–31 | Upcoming |
| Vertical slice content (modifiers + scoring + new games) | June–July | Planned |
| Steamworks integration (stats, leaderboards, achievements) | August 1–17 | Planned |
| Next Fest registration + store page | August 18–31 | Planned |
| Steam demo build + press preview | September | Planned |
| Demo live + Next Fest | October 19–26 | Target |
| Full game release | Late October | Target |

**Full schedule:** `memory-bank/06 - Deadlines.md`