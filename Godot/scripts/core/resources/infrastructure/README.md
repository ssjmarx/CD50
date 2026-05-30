# Infrastructure Resources

3 foundational classes used across the entire V2 codebase: collision config, shared enums, and pure utility functions.

---

## CDCollisionGroup — Collision Layer Config

Simple data resource used by `CDCollisionMatrix` to auto-configure Godot collision layers from group definitions.

| Export | Type | Purpose |
|--------|------|---------|
| `group_name` | `StringName` | Name of the entity group (maps to a collision layer) |
| `collides_with` | `Array[StringName]` | Groups this one can collide with |

### Must-Includes

1. Set `group_name` — must match an entity group used in the game
2. Set `collides_with` — list all groups that should physically interact with this one

---

## CDEnums — Shared Enumerations

Data bag class (no instance needed — all enums + one static function). Defines every enum used across V2 components.

### Component Processing Priority

`ComponentCategory` defines the execution order for `CDComponent2D` and `CDStageComponent2D` via `_process_priority`. Categories marked "not intended for component use" are reserved for infrastructure internals.

| Category | Priority | Purpose |
|----------|----------|---------|
| REGISTRATION | 5 | Group cache flush |
| INPUT | 8 | Input routing |
| INTENT | 10 | Brains / controllers |
| STEERING | 20 | Legs |
| ENTITY | 30 | CDEntity core |
| COLLISION | 35 | Collision buffer flush |
| INTERACTION | 40 | Arms |
| STATE | 50 | Guts (internal entity state) |
| VISUAL | 60 | Faces / projectors |
| AUDIO | 65 | Voices / speakers |
| RULES | 70 | Directors, goals, cards, trapdoors |
| UPDATE | 90 | State mutation flush, lifecycle |

Use `CDEnums.category_to_priority(category)` to assign in `_init()` or `_ready()`.

### Entity & Game Lifecycle

| Enum | Values | Used By |
|------|--------|---------|
| EntityState | ACTIVE, DEACTIVATING, INACTIVE | CDEntity |
| GameState | ATTRACT, PLAYING, PAUSED, GAME_OVER | CDGame |
| GameResult | VICTORY, DEFEAT, DRAW | Game bus game_over signal |

### Physics & Collision

| Enum | Values | Used By |
|------|--------|---------|
| CollisionResponse | STOP, BOUNCE, SLIDE | CDEntity physics processing |
| Edge | TOP, BOTTOM, LEFT, RIGHT | Spawners |

### Logic & Comparison

| Enum | Values | Used By |
|------|--------|---------|
| CountComparison | LESS_THAN, EQUAL_TO, GREATER_THAN, LESS_OR_EQUAL, GREATER_OR_EQUAL | GroupCountGoal, PointsGoal |
| InputAction | MOVE, AIM, ACTION_PRESSED, ACTION_RELEASED | CDInputRouter |
| PatrolMode | LOOP, RETRACE, ONCE | Patrol AI brains |
| EntityCompare | VELOCITY, Y_POSITION, CUSTOM | OnJoust arms |
| EntityCompareTiebreaker | DONT_FIRE, FIRE | Entity comparison tiebreakers |
| EntityCompareInvalidAction | DONT_FIRE, FIRE | Invalid comparison handling |

### Audio / Sound

| Enum | Values | Used By |
|------|--------|---------|
| WaveShape | SINE, SQUARE, SAWTOOTH, TRIANGLE, NOISE | CDSoundDef |
| Effect | NONE, WARBLE, TREMOLO, SWEEP_DOWN, DECAY | CDSoundDef |
| Semitone | C3–B5 (MIDI 48–83) | Sound generation |

### Must-Includes

- Import `CDEnums` (it's a class_name, just use it directly)
- Use `ComponentCategory` for all component `_process_priority` values — never hardcode priority numbers
- When adding new enums, add them here (not in individual scripts)

---

## CDUtilities — Pure Static Utilities

Stateless utility functions organized into three categories: entity spawning, expression evaluation, and audio waveform generation.

### Spawn & Entity Functions

| Function | Purpose |
|----------|---------|
| `apply_spawn_context(entity, context)` | Apply a `CDSpawnContext` to an entity before it enters the tree |

### Expression Evaluation

| Function | Purpose |
|----------|---------|
| `evaluate_int(equation, var_names, var_values, context_name)` | Evaluate a string expression with named variables, returns int |

### Audio / Waveform Functions

| Function | Purpose |
|----------|---------|
| `freq_from_note(note)` | Convert MIDI note number to frequency in Hz |
| `apply_freq_effect(freq, t, effect)` | Apply frequency effects (warble, sweep_down) |
| `wave_sample(phase, wave_shape)` | Generate raw waveform sample from phase position |
| `apply_amp_effect(sample, t, note_progress, effect)` | Apply amplitude effects (tremolo, decay) |

### Must-Includes

- All functions are `static` — call directly via `CDUtilities.func_name()`
- `MIX_RATE` constant (11025 Hz) used by sound generation
- When adding new utilities, keep them pure (no state, no side effects)
