# resources/infrastructure

Foundational, dependency-light support code shared across the V2 codebase. The scripts in this folder are not game logic themselves — they provide the shared enums, pure-utility functions, and data resource shapes that the rest of the system is built on.

There are three files, each with a distinct role:

| File | `class_name` | Kind | State |
| --- | --- | --- | --- |
| `cd_enums.gd` | `CDEnums` | Enum container | None |
| `cd_utilities.gd` | `CDUtilities` | Static utility bag | None |
| `cd_collision_group.gd` | `CDCollisionGroup` | `Resource` | Exported fields |

---

## `cd_enums.gd` — `CDEnums`

A plain `class_name CDEnums` (no `extends`) used purely as a namespace for enumerations. It holds no state and no instance methods — code references the enums as `CDEnums.SomeEnum.SOME_VALUE`.

It also exposes two static helpers:

```gdscript
static func category_to_priority(category: ComponentCategory) -> int
```

This converts a `ComponentCategory` into its numeric processing-priority value (the values documented inline on each enum member). Any unrecognized value returns `95`.

```gdscript
static func compare(observed: float, target: float, op: CountComparison) -> bool
```

Evaluates an `observed` value against a `target` using a `CountComparison` operator (`LESS_THAN`,
`EQUAL_TO`, `GREATER_THAN`, `LESS_OR_EQUAL`, `GREATER_OR_EQUAL`). It exists so the operator
vocabulary is defined once — goals (e.g. `GroupCountGoal`, `ScoreThresholdGoal`) and other
threshold-comparing components delegate here instead of re-implementing the `match` block.

### Enums defined here

**Component processing priority**

- `ComponentCategory` — the named priority buckets used by `CDComponent2D` / `CDStageComponent2D`, plus the numeric priority each maps to (REGISTRATION=5, INPUT=8, INTENT=10, STEERING=20, ENTITY=30, COLLISION=35, INTERACTION=40, STATE=50, VISUAL=60, AUDIO=65, RULES=70, MANAGER=75, UPDATE=90).

**Entity & game lifecycle**

- `EntityState` — `CDEntity` lifecycle states: `ACTIVE`, `DEACTIVATING`, `INACTIVE`.
- `GameState` — `CDGame` state machine values: `ATTRACT`, `PLAYING`, `PAUSED`, `GAME_OVER`.
- `GameResult` — argument passed on the game bus's `game_over` signal: `VICTORY`, `DEFEAT`, `DRAW`.

**Physics & collision**

- `CollisionResponse` — `CDEntity` physics processing type: `STOP`, `BOUNCE`, `SLIDE`.
- `Edge` — screen edges used by spawners: `TOP`, `BOTTOM`, `LEFT`, `RIGHT`.

**Logic & comparison**

- `CountComparison` — comparison operators used by goals (e.g. `GroupCountGoal`, `ScoreThresholdGoal`): `LESS_THAN`, `EQUAL_TO`, `GREATER_THAN`, `LESS_OR_EQUAL`, `GREATER_OR_EQUAL`. Evaluated via the `compare(observed, target, op)` static helper above.
- `InputAction` — `CDInputRouter` action types: `MOVE`, `AIM`, `ACTION_PRESSED`, `ACTION_RELEASED`.
- `PatrolMode` — patrol patterns for "patrol" AI brains: `LOOP`, `RETRACE`, `ONCE`.
- `EntityCompare` — comparison modes for entity comparisons (e.g. `OnJoust` arms): `VELOCITY`, `Y_POSITION`, `CUSTOM` (define any attribute located on a component).
- `EntityCompareTiebreaker` — tiebreaker behavior: `DONT_FIRE`, `FIRE`.
- `EntityCompareInvalidAction` — behavior when a comparison is invalid: `DONT_FIRE`, `FIRE`.

**Audio / sound**

- `WaveShape` — `CDSoundDef` wave shapes: `SINE`, `SQUARE`, `SAWTOOTH`, `TRIANGLE`, `NOISE`, `PULSE_25`, `PULSE_12`, `PURE_NOISE`.
- `Effect` — `CDSoundDef` frequency/amplitude effects: `NONE`, `WARBLE`, `TREMOLO`, `SWEEP_DOWN`, `DECAY`, `SWEEP_UP`, `FAST_DECAY`, `WARBLE_WIDE`, `RIPPLE`, `REVERB`.
- `Semitone` — MIDI note numbers for procedural sound generation, spanning octaves 2–6 (e.g. `C2 = 36` through `B6 = 95`). Sharps use an `S` suffix (`CS2`, `DS2`, …).

---

## `cd_utilities.gd` — `CDUtilities`

A plain `class_name CDUtilities` (no `extends`) containing **pure static functions with no state and no side effects**. Call them directly, e.g. `CDUtilities.freq_from_note(69)`.

### Constant

- `MIX_RATE: int = 11025` — sample rate used by the procedural sound generation functions.

### Functions

**Spawn & entity**

```gdscript
static func apply_spawn_context(entity: CDEntity, context: CDSpawnContext) -> void
```

Applies a `CDSpawnContext` to an entity before it enters the tree. No-ops if `context` is null. It:

1. Sets `entity.velocity` from `context.velocity`.
2. If `context.use_random_angle`, keeps the speed but randomizes the direction within `[random_angle_min, random_angle_max]`.
3. If `context.random_flip_h` / `random_flip_v`, randomly negates the x / y component of the velocity.
4. Sets `entity.rotation` from `context.rotation`.
5. Adds every entry in `context.additional_groups` to the entity via `add_to_group`.

**Expression evaluation**

```gdscript
static func evaluate_int(equation: String, var_names: PackedStringArray, var_values: Array, context_name: String) -> int
```

Parses and executes a string `Expression` with named variables, returning the result coerced to `int`. On parse failure or execution failure it `push_error`s a message prefixed with `context_name` (the caller, for debugging) and returns `0`.

**Audio / waveform**

```gdscript
static func freq_from_note(note: int) -> float
```

Converts a MIDI note number to frequency in Hz (`440.0 * pow(2.0, (note - 69) / 12.0)`).

```gdscript
static func apply_freq_effect(freq: float, t: float, effect: int) -> float
```

Returns a modified frequency for a given `CDEnums.Effect`. Handles `WARBLE`, `SWEEP_DOWN`, `SWEEP_UP`, and `WARBLE_WIDE`; any other effect returns `freq` unchanged.

```gdscript
static func wave_sample(phase: float, wave_shape: int) -> float
```

Returns a raw waveform sample in the range roughly `[-1, 1]` for a phase position and a `CDEnums.WaveShape`. Implements all shapes listed under `WaveShape` above; unknown shapes return `0.0`.

```gdscript
static func apply_amp_effect(sample: float, t: float, note_progress: float, effect: int) -> float
```

Returns a sample modified by an amplitude `CDEnums.Effect`. Handles `TREMOLO`, `DECAY`, `FAST_DECAY`, and `RIPPLE`; any other effect returns `sample` unchanged.

---

## `cd_collision_group.gd` — `CDCollisionGroup`

A small data resource (`class_name CDCollisionGroup extends Resource`) describing a single row of a collision matrix. It is meant to be authored as a `.tres` and collected by `CDCollisionMatrix` (defined elsewhere) to configure which collision layers physically interact.

### Exported fields

- `group_name: StringName` — name of the entity group (maps to a collision layer).
- `collides_with: Array[StringName]` — the list of groups this one should physically interact with.

---

## Conventions used in this folder

These three files establish the conventions you should follow when adding new infrastructure support code here:

1. **Naming.** Each file uses the `cd_` snake_case filename plus a `class_name` in `CDCamelCase`. The filename and the class name differ only in casing and prefix (`cd_enums.gd` → `CDEnums`).
2. **Header docstring.** Every file begins with a `## ClassName` line followed by one or more `##` lines explaining what the class is and (where relevant) that it is stateless/side-effect-free.
3. **Per-member docs.** Enums, constants, exported fields, and functions each carry their own `##` doc comment immediately above the declaration; enum members carry inline `#` comments where a numeric value needs explanation.
4. **Static-only utility classes** (`CDEnums`, `CDUtilities`) use `class_name` with no `extends`. They never hold state and are invoked statically — `CDUtilities.func_name()`, `CDEnums.EnumName.VALUE`.
5. **Data resources** (`CDCollisionGroup`) `extends Resource`, expose only `@export` fields, and exist primarily to be authored in the inspector and saved as `.tres`.
6. **Dependency direction.** Infrastructure code here may reference types defined elsewhere (e.g. `CDEntity`, `CDSpawnContext`, `CDEnums`), but it must not depend on a specific scene tree, autoload, or runtime singleton — it stays safe to call from anywhere.

### Adding a new shared enum

- Add the enum inside `CDEnums` in `cd_enums.gd`.
- Document it with a `##` comment above the declaration, and use inline `#` comments for each member if the meaning isn't obvious from the name.
- If the enum has an associated numeric mapping (like `ComponentCategory`), add a branch to `category_to_priority` or a sibling static helper (like `compare` for `CountComparison`) rather than scattering `match` statements across the codebase.

### Adding a new pure utility function

- Add it as a `static func` inside `CDUtilities` in `cd_utilities.gd`.
- Keep it free of state and side effects; pass everything in as arguments and return a result.
- Document inputs, return type, and any failure modes (e.g. `push_error` + fallback return) in the `##` comment.

### Adding a new data resource shape

- Create a new `cd_*.gd` file in this folder with `class_name CD... extends Resource`.
- Expose its data only through `@export` fields, typed as tightly as possible (`StringName`, typed arrays, etc., as `CDCollisionGroup` does).
- Document the role of the resource and each field; it will be authored as a `.tres` in the inspector.