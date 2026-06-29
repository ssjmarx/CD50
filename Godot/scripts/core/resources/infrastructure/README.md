# Infrastructure Resources

Foundational, dependency-light support code shared across the V2 codebase. Not game logic — these provide the shared enums, pure utility functions, and data resource shapes the rest of the system is built on.

## Files

| File | Class | Kind | State |
|------|-------|------|-------|
| `cd_enums.gd` | `CDEnums` | Enum container (no `extends`) | None |
| `cd_utilities.gd` | `CDUtilities` | Static utility bag (no `extends`) | None |
| `cd_collision_group.gd` | `CDCollisionGroup` | `Resource` | Exported fields |

---

## Patterns

### 1. Three file roles
- **`CDEnums`** — a plain `class_name CDEnums` (no `extends`) used purely as a namespace for enumerations plus two static helpers: `category_to_priority(category)` and `compare(observed, target, op)`. Referenced as `CDEnums.SomeEnum.SOME_VALUE`.
- **`CDUtilities`** — a plain `class_name CDUtilities` (no `extends`) of pure static functions, no state, no side effects. Call as `CDUtilities.func_name(...)`. Includes `MIX_RATE = 11025`.
- **`CDCollisionGroup`** — a small `extends Resource` data shape authored as `.tres` and collected by `CDCollisionMatrix` (elsewhere) to configure which groups physically interact.

### 2. Naming
`cd_` snake_case filename + `class_name` in `CDCamelCase`. Filename and class differ only in casing/prefix (`cd_enums.gd` → `CDEnums`).

### 3. Header docstring
Every file starts with a `## ClassName` line followed by `##` lines explaining what it is and (where relevant) that it is stateless/side-effect-free.

### 4. Per-member docs
Enums, constants, exports, and functions each carry a `##` comment immediately above. Enum members get inline `#` comments when a numeric value needs explanation.

### 5. Static-only classes hold no state
`CDEnums` and `CDUtilities` use `class_name` with no `extends`, hold no state, and are invoked statically.

### 6. Data resources are pure data
`CDCollisionGroup` and any new data resource here `extends Resource`, expose only tightly-typed `@export` fields (`StringName`, typed arrays), and exist to be authored as `.tres`.

### 7. Dependency direction
Infrastructure code here may reference types defined elsewhere (`CDEntity`, `CDSpawnContext`, `CDEnums`), but must **not** depend on a scene tree, autoload, or runtime singleton — it stays safe to call from anywhere.

---

## How to add new infrastructure support code

**A new shared enum:**
- Add it inside `CDEnums` in `cd_enums.gd`; document with `##` + inline `#` comments.
- If it has an associated numeric mapping (like `ComponentCategory`), add a branch to `category_to_priority` or a sibling static helper (like `compare` for `CountComparison`) instead of scattering `match` statements across the codebase.

**A new pure utility function:**
- Add as `static func` inside `CDUtilities`.
- Keep it stateless/side-effect-free; pass everything in as arguments, return a result.
- Document inputs, return type, and failure modes (`push_error` + fallback) in the `##` comment.

**A new data resource shape:**
- New `cd_*.gd` file: `class_name CD... extends Resource`.
- Expose data only through tightly-typed `@export` fields.
- Document the role of the resource and each field; authored as `.tres` in the inspector.

### Checklist

- [ ] Filename `cd_<snake_case>.gd`; `class_name CD<PascalCase>` (or `class_name CD<Name>` with no `extends` for a static-only class).
- [ ] `## ClassName` header + `##` explanation lines.
- [ ] Per-member `##` docs; inline `#` on numeric enum members.
- [ ] Pick the right shape: enum/static-only (no `extends`, no state) vs data resource (`extends Resource`, `@export` fields only).
- [ ] No scene-tree/autoload/singleton dependencies — safe to call from anywhere.