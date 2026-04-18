# Current Goal: Asteroids Polish and More Remix Games

**Planning Document:** `planning/06 - Asteroids Polish and More Remix Games.md`  
**Status:** 🔄 In Progress — Dogfight complete, Asteroids polish + remixes remaining  
**Previous Goal:** Componentize Breakout, Asteroids, and Pongsteroids ✅ (completed 2026-04-17)

---

## Objective

Full Asteroids recreation (death effects, UFO, warp, reactive music), input system refactor for remappable buttons, and three new remix games.

---

## Completed So Far

- [x] **Dogfight** — Player vs AI triangle ships with escalating waves + asteroids (pure scene assembly)
- [x] **ShootAi** — Vision cone AI brain for auto-firing at targets
- [x] **DamageOnJoust** — Velocity-comparison collision damage (faster body wins)
- [x] **Bodies Purification** — All body scripts now contain drawing code only, zero functional logic
- [x] **triangle_ship_modern** — Pre-composed body with modern twin-stick controls

---

## Remaining Scope

### Input Refactor
- `action`/`end_action` signals pass `InputEvent` argument so components can filter by action name
- Enables remappable buttons through Godot's Input Map

### Asteroids Polish (4 new components)
- **Death effects:** `death_effect` component + 2 effect scenes (particles, ship debris)
- **UFO enemy:** `patrol_ai` brain follows Curve2D paths, UFO assembled from components
- **Warp:** `asteroids_warp` leg — teleport with intangibility on button_3
- **Reactive music:** `music_ramping` rule — loop sound with pitch scaling as group count → 0

### Remix Games (3)
- **Pongout:** Pong where goals are shielded by breakout bricks, one goal ends the game
- **Asterout:** Modern controls, UFO dogfighting with stationary brick shields
- **Breaksteroids:** Paddle + ball vs asteroid grid, asteroids have health and split

---

## New Components Needed (4-5)

| Component | Category | Purpose |
|-----------|----------|---------|
| `death_effect` | Component | Spawn visual effect scenes on parent death |
| `patrol_ai` | Brain | Curve2D path following + random path generation |
| `asteroids_warp` | Leg | Emergency teleport with intangibility |
| `music_ramping` | Rule | Loop sound with pitch scaling based on group count |
| `health_color` (optional) | Component | Color parent based on Health HP |

## Modified Components

| Component | Change |
|-----------|--------|
| `universal_body` | `action`/`end_action` signals pass InputEvent |
| Components listening to `action`/`end_action` | Accept InputEvent parameter |

## New Scenes & Folder

- `Scenes/Effects/` — new folder for visual effects (self-destructing + persistent)
- `death_effect_particles.tscn`, `death_effect_ship_debris.tscn`, `engine_flame.tscn`
- `pongout.tscn`, `asterout.tscn`, `breaksteroids.tscn`

## No Game Scripts

All games are pure UGS scene assemblies.

---

## Implementation Phases

1. ~~**A: Input Refactor** — Update universal_body signals, verify existing games~~
2. **B: Death Effects** — death_effect component + particle/debris effect scenes
3. **C: UFO + Polish** — patrol_ai, asteroids_warp, music_ramping, UFO assembly, update asteroids.tscn
4. **D: Pongout** — assemble and test
5. **E: Asterout** — assemble and test
6. **F: Breaksteroids** — assemble and test

---

## Success Criteria

- [ ] `action`/`end_action` pass InputEvent — components can filter by action name
- [ ] Asteroids explode with particle burst, ship with particles + debris lines
- [ ] UFO enemy patrols and shoots in Asteroids
- [ ] Ship can warp (button_3) with intangibility
- [ ] Reactive music speeds up as asteroid count decreases
- [ ] Pongout, Asterout, Breaksteroids all playable
- [x] Dogfight playable (pure scene assembly)
- [x] All games are pure UGS scene assemblies, zero game scripts
