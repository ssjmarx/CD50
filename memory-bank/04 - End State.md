# End State: GD50 — The Polybius Cabinet

**Last Updated:** 2025-04-15  
**Source Material:** `planning/brainstorming/` folder

---

## High-Level Vision

The end product is **not just a collection of arcade games** — it is a meta-experience housed inside a fictional arcade cabinet known as **"Polybius."** The player interacts with the cabinet as a physical object: selecting games from an infinite scrolling list, inserting modifier tokens, finding contraband items during gameplay, and slowly uncovering a narrative about the nature of the cabinet, the entity "Polybius," and ultimately, themselves.

### Three Layers of Play

| Layer | Experience | Purpose |
|-------|-----------|---------|
| **Surface** | Play classic arcade games, chase high scores | Core gameplay loop |
| **Meta** | Find contraband in games, solve server room puzzles, unlock secrets | Progression & discovery |
| **Deep** | Uncover the SCP narrative, discover "the truth," attempt to escape | Narrative & endgame |

---

## The Game Catalog

### Phase 1: Classic Games (The Base Set)
These are faithful recreations of arcade classics, built from the component system.

| Game | Core Mechanic | Key Components |
|------|--------------|----------------|
| **Pong** | Two paddles, one ball, score to win | AngledDeflector, PongAcceleration, Goal |
| **Breakout** | Paddle + ball vs brick grid | Health, GroupMonitor, LivesCounter |
| **Asteroids** | Ship vs floating rocks | ScreenWrap, SplitOnDeath, GunSimple |
| **Defender** | Side-scrolling rescue shooter | ScrollingCamera, AI_Chase |
| **Galaga** | Fixed shooter, enemy formations | FormationManager, WaveDirector |
| **Frogger** | Grid movement, avoid traffic | GridHop, RidingPlatform |
| **Donkey Kong** | Platform climbing, barrel jumping | Physics2DPlatformer, BarrelSpawner |
| **Missile Command** | Point-and-click missile defense | MouseTargeting, Projectile_Missile |
| **Tetris** | Falling block puzzle | GridSystem, TetrominoMovement |
| **Centipede** | Trackball shooter vs segmented enemy | SegmentedEnemy, TrackballMovement |
(the full list is intended to be at least twenty games)

### Phase 2: Remix Games (The Mashups)
Games that combine elements from multiple classics, like the existing **Pongsteroids**. Created by assembling components from different games into new configurations.

| Remix | Combination | Concept |
|-------|------------|---------|
| **Pongsteroids** | Pong + Asteroids | ✅ Already built |
| **Breakoutvader** | Breakout + Galaga | Bricks that shoot back |
| **Asterong** | Asteroids + Pong | Ships play pong with an asteroid |
| **Frogger Command** | Frogger + Missile Command | Guide frogs while shooting missiles |
| **Tetris Kong** | Tetris + Donkey Kong | Stack blocks to reach the top |
(the full list is intended to be at least forty remixes)

## The Infinite Scroll

In the standard play mode, games are rigged to be FAST.  Pong might end after only a single goal, asteroids after a single wave, etc.  Player victory and defeat is determined rapidly, and whatever the outcome the next game scrolls up from the bottom of the screen, with their score/multiplier increasing or their lives decreasing depending on the result.

Players can also pick games from a list or select "playlists" of games to play in sequence.

---

## The Cabinet: Physical Interface

The arcade cabinet is the player's window into the game world. It has interactive physical elements:

```
┌─────────────────────────────────────────┐
│            POLYBIUS CABINET              │
│                                          │
│   ┌─────────────────────────────────┐   │
│   │        [FACE SCREEN]            │   │
│   │   Polybius face / expressions   │   │
│   └─────────────────────────────────┘   │
│                                          │
│   ┌─────────────────────────────────┐   │
│   │       [GAME SCREEN]             │   │
│   │   The actual arcade games       │   │
│   │                                 │   │
│   └─────────────────────────────────┘   │
│                                          │
│   [COIN SLOT]  ← Modifiers go IN      │
│   [RETURN SLOT]  ← Contraband comes OUT │
│                                          │
│   [BLINKENLIGHTS PANEL]                  │
│                                         │
│[messy tangle of cables and server hardware]│
│                                          │
└─────────────────────────────────────────┘
```

---

## Polybius: The Character

Polybius is the sentient presence inhabiting the cabinet. It is the player's warden, companion, and antagonist.

### Personality
- Speaks in a distorted, electronic voice
- Key phrase: **"I hunger for score."**
- Initially seems like a simple game selector AI
- Gradually reveals awareness, malice, and eventually... something like compassion

### Behaviors
- **Idle:** Scroll the game list, wait for player input
- **During Play:** Occasional voice commentary on performance
- **Suspicious:** When the player collects too much contraband, Polybius reacts
- **Interfering:** At high suspicion, Polybius actively makes games harder
- **Honest:** In the endgame, Polybius drops the facade and speaks truthfully

### The Twist (Narrative)
Polybius is not the villain. It is not the prisoner. It is the **warden** — a digital construct designed to keep the *player* contained. The player is SCP-Ω: a reality-warping entity that turns everything into games. The cabinet is a cradle, not a cage. The games keep the player fed, distracted, and docile.

---

## The Server Room: Meta-Layer Puzzles

Between game runs, the player explores a **server room** environment surrounding the cabinet. This is where contraband items are used and puzzles are solved.

### Puzzle Zones

| Zone | Mechanic | Purpose |
|------|----------|---------|
| **Filing Cabinet** | Insert keys to unlock drawers | Unlock game playlists, cheats, archives |
| **Terminal** | Type codes found in games | Reveal secrets, trigger voice lines, enter commands |
| **Cable Tangle** | Use tools (wire cutters) to reveal hidden ports | Access speaker/power/data overrides |
| **Coin Slot** | Insert quarters/coins/tokens | Modify game behavior (difficulty, visuals, cheats) |
| **Blinkenlights** | Decode light patterns using cipher key | Receive messages from previous "players" |
| **Junction Box** | Route limited power between systems | Trade off Polybius voice, game function, score saving |
| **Floor Tile** | Pry open hidden compartment | Discover ultimate secrets |

---

## Contraband: Items Found in Games

### How Items Appear
- **Visual secrets:** Glinting bricks, differently-colored asteroids, subtle marks
- **Score thresholds:** Reach X points, an item spawns
- **Secret actions:** Bounce the ball 7 times without scoring, hidden sound plays, next score drops item
- **Pattern secrets:** Shoot enemies in a specific order
- **Corruption reveals:** Item visible for 1 frame during a glitch

### Item Categories

| Category | Examples | Use |
|----------|---------|-----|
| **Keys** | Brass key, magnetic card, skeleton key | Unlock filing cabinet drawers |
| **Codes** | 4-digit PIN, cipher key, password | Enter into terminal |
| **Tools** | Wire cutters, screwdriver, flashlight | Interact with physical cabinet areas |
| **Story Items** | Journal pages, photographs, audio tapes | Uncover the SCP narrative |
| **Modifier Tokens** | Double-Sided Coin, Chaos Marble, Phoenix Feather | Alter next run (score, difficulty, lives) |

---

## The Narrative: SCP

The story is told through **journal entries, photographs, audio tapes, and terminal logs** found as contraband items scattered throughout the games. The narrative arc:

### Act 1: The Mystery
- Entry 01-09: SCP is recovered from an arcade in 1981. Test subjects become addicted, experience memory loss. The machine seems to "speak" to players.

### Act 2: The Investigation
- Entry 10-18: A researcher (Dr. L.) becomes obsessed, sees "something behind the games." Discovers the machine isn't a prison — it's a **cradle**. The player isn't a victim — they're the **SCP**.

### Act 3: The Truth
- Entry 19: Polybius speaks honestly. It was built to keep the player content. The player is a reality-warping entity. The games prevent the entity from "waking up."

### Act 4: The Choice
- Entry 20: The player is given a choice — keep playing (stay contained, stay safe) or "exit" (remember what they are, risk everything). The true ending: the player **chooses to stay**, not because they're trapped, but because the games are genuinely fun.

### Key Twist
```
THE CABINET IS NOT THE PRISON.
THE GAMES ARE NOT THE WALLS.
THE PLAYER IS NOT THE VICTIM.

The player is the SCP.
Polybius is the warden.
The games are the pacifier.
The cabinet is a cradle for something dangerous that thinks it's having fun.
```

---

## Architecture Implications for End State

To support this vision, the component system must eventually accommodate:

### New Component Categories
| Category | Purpose | Examples |
|----------|---------|---------|
| **Faces** | Visual rendering (swappable) | VectorFace, SpriteFace, LabelFace |
| **Meta** | Cross-game persistence | InventoryManager, PuzzleState |

### Required Singletons
| Singleton | Purpose |
|-----------|---------|
| `GameRegistry` | High scores, unlocked content, player settings |
| `InventoryManager` | Track contraband items across runs |
| `PuzzleState` | Track which puzzles are solved, what's unlocked |
| `PolybiusSuspicion` | Track suspicion level (0-100), trigger reactions |

### The "Recipe" System
Eventually, Bodies should be pure `.tscn` scene files with **no custom scripts** — just `UniversalBody` + component assemblies:

```
Ball.tscn = UniversalBody + CircleCollision + PongAcceleration + VectorFace
Ship.tscn = UniversalBody + TriangleCollision + EngineSimple + GunSimple + VectorFace
Invader.tscn = UniversalBody + RectCollision + PatrolAI + GunSimple + SpriteFace
```

New games become **editor assemblies**, not code. The only code is components.

---

## Progression Toward End State

```
WHERE WE ARE (Current)
├── ✅ Entity component system (Bodies + Brains + Legs + Arms)
├── ✅ 4 playable games (Pong, Breakout, Asteroids, Pongsteroids)
├── ✅ Component reuse validated (Pongsteroids)
├── ✅ Game-level componentization proven (Component Pong)
└── ✅ UniversalGameScript as generic game container

NEXT STEPS
├── 🔲 Componentize remaining games (Breakout, Asteroids, Pongsteroids)
├── 🔲 Build the Hub/Menu (cabinet interface)
└── 🔲 Build 6 more base games

META LAYER
├── 🔲 Inventory system
├── 🔲 Contraband item spawning in games
├── 🔲 Server room puzzles
├── 🔲 Polybius character system
└── 🔲 SCP narrative integration

POLISH
├── 🔲 Visual Faces system (VectorFace, SpriteFace)
├── 🔲 CRT/filter effects per game
├── 🔲 Audio design (Polybius voice, ambient)
├── 🔲 Infinite scroll game selector
└── 🔲 The EXIT sequence + true ending
```
</task_progress>
</write_to_file>