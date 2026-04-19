# Current Goal: Next Steps

**Status:** 🔄 Plan 06 largely complete — deciding next direction  
**Previous Goal:** Asteroids Polish and More Remix Games ✅ (mostly completed 2026-04-18)

---

## Plan 06 Completion Status

### ✅ Completed
- [x] **Input Refactor** — `action`/`end_action` signals pass InputEvent
- [x] **Death Effects** — death_effect component + particle/debris effect scenes
- [x] **UFO Enemy** — patrol_ai brain, UFO assembled from components, integrated into Asteroids
- [x] **Visual Polish** — VectorEngineExhaust on ships, DeathEffect on asteroids/ships
- [x] **Reactive Music** — MusicRamping with SoundSynth procedural audio
- [x] **Procedural Audio System** — SoundSynth, SFXRamping, Beep (complete audio pipeline)
- [x] **Dogfight** — Player vs AI triangle ships with escalating waves
- [x] **Pongout** — Pong + Breakout hybrid (brick shields on goals)
- [x] **Breaksteroids** — Breakout + Asteroids hybrid (paddle vs asteroid grid)
- [x] **GroupMonitor enhancement** — `group_member_removed` signal for per-death tracking

### ⚠️ Needs Rework
- [ ] **Asterout** — Asteroids + Breakout hybrid (shielded UFOs). Current version has a RingSpawner collision bug and doesn't play well. Needs full remake with:
  - RingSpawner fix: parent bricks to game root instead of UFO body (CollisionMatrix blindspot)
  - Manual position tracking in `_process()` to follow UFO movement
  - Rethink the game concept — may need a different approach than brick shields on UFOs

### 🔲 Skipped / Future
- **Asteroids Warp** — emergency teleport with intangibility (not yet built)

---

## Potential Next Directions

### Option A: Fix Asterout + Move On
- Remake Asterout with RingSpawner fix
- Close out Plan 06 entirely

### Option B: New Base Games
- Build 1-2 new base games (Defender, Galaga, Frogger, etc.)
- Each new game tests and expands the component library

### Option C: Hub/Menu System
- Build the cabinet interface for game selection
- Required for the "infinite scroll" rapid-fire game experience

### Option D: Polish & Juice
- Screen shake, hit flash, combo systems, more visual effects
- Make existing games feel better before expanding

---

## Known Bugs to Fix

- `patrol_ai.gd`: Start position bug — UFO may not begin at the correct path position
- `ufo_shielded.tscn`: UFO drawing scale may need adjustment
- `ring_spawner.gd`: Bricks parented to non-root bodies bypass CollisionMatrix — needs architectural fix or workaround

---

## Component Catalog: 62 Components

| Category | Count |
|----------|-------|
| Core | 7 |
| Bodies | 9 |
| Brains | 5 |
| Legs | 8 |
| Arms | 3 |
| Components | 14 |
| Rules | 7 |
| Flow | 7 |
| Effects | 2 |

## Game Catalog: 8 Games (7 working, 1 needs remake)

| Game | Status |
|------|--------|
| Pong | ✅ Working |
| Breakout | ✅ Working |
| Asteroids | ✅ Working (polished) |
| Pongsteroids | ✅ Working |
| Dogfight | ✅ Working |
| Pongout | ✅ Working |
| Breaksteroids | ✅ Working |
| Asterout | ⚠️ Needs remake |