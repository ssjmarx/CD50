# Current Goal: Componentize Remaining Games

**Planning Document:** `planning/05 - Componentized Breakout, Asteroids, and Pongsteroids.md`  
**Status:** 🔄 Planning Complete — Ready to Implement  
**Previous Goal:** Component Pong ✅ (completed 2026-04-16)

---

## Objective

Eliminate the last three monolithic game scripts (`breakout.gd`, `asteroids.gd`, `pongsteroids.gd`). All games become pure `UniversalGameScript` scene assemblies with zero game-specific code.

---

## Scope

- **Breakout:** 3 new components (LifeLossZone, ScoreMultiplier, BallServer) + GRID spawn pattern + DamageOnHit + ScoreOnDeath
- **Asteroids:** 2 new components (GroupCountMultiplier, Respawner) + GroupMonitor extension + DamageOnHit + ScoreOnDeath
- **Pongsteroids:** Copy pong.tscn + add asteroid spawners + collision groups. The remix test.

**Out of Scope:** Attract modes, AI swap mechanics, control scheme selection.

---

## New Components (7 total)

| Component | Category | Used By | Complexity |
|-----------|----------|---------|------------|
| `DamageOnHit` | Component | All three | Low |
| `ScoreOnDeath` | Rule | Breakout, Asteroids | Medium |
| `LifeLossZone` | Rule | Breakout | Low |
| `ScoreMultiplier` | Rule | Breakout | Medium |
| `BallServer` | Flow | Breakout | Low |
| `GroupCountMultiplier` | Rule | Asteroids | Low |
| `Respawner` | Flow | Asteroids | High |

## Extensions (2 existing)

| Component | Change |
|-----------|--------|
| `GroupMonitor` | Add `lose_life_on_clear: bool` |
| `WaveSpawner` | Implement GRID pattern, add `max_alive: int` |

## Deletions (3 scripts)

- `Scripts/Games/breakout.gd`
- `Scripts/Games/asteroids.gd`
- `Scripts/Games/pongsteroids.gd`

---

## Implementation Order

1. **Phase A:** Cross-cutting components (DamageOnHit, ScoreOnDeath, GroupMonitor extension, GRID pattern)
2. **Phase B:** Component Breakout (LifeLossZone, ScoreMultiplier, BallServer, assemble, test, delete)
3. **Phase C:** Component Asteroids (GroupCountMultiplier, Respawner, assemble, test, delete)
4. **Phase D:** Component Pongsteroids (WaveSpawner max_alive, asteroid variant, copy pong + remix, test, delete)

---

## Success Criteria

- [ ] `breakout.gd` is deleted — Breakout runs as pure scene assembly
- [ ] `asteroids.gd` is deleted — Asteroids runs as pure scene assembly
- [ ] `pongsteroids.gd` is deleted — Pongsteroids runs as pure scene assembly
- [ ] All four games use UGS root with zero game-specific scripts
- [ ] Pongsteroids demonstrates remix ease (pong.tscn copy + asteroid additions)

---

## Deferred Items

- **Attract Mode AI swap:** Mechanism to swap PlayerControl ↔ InterceptorAI based on game state
- **Control scheme selection:** Original vs Modern Asteroids controls (pick one for now)
- **Asteroids win condition:** Game is traditionally endless — decide on score threshold or wave limit
- **Hub/Menu System:** Game selection interface