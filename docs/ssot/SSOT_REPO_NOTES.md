# Mealvana QA

The quality department. Two jobs:
1. **Home of the calculation SSOT** — the authoritative, versioned spec of what the app's
   nutrition math *should* compute (fueling, macros, recommendation). One file per section.
2. **Testing agents** that mechanically tie that SSOT to the app's real code, so neither
   the engine nor the in-app explanation can silently drift from the spec.

Shared with Lee: he develops **against** this department's SSOT; green conformance is the contract.
Plan: `ops/docs/qa-department-plan.md`. Created 2026-07-26.

## Layout
- `spec/<engine>/<section>.md` — the SSOT: rule · formula · band · citations · which
  constants are research-derived vs Mealvana design choices. `.html` = the source drawer.
- `vectors/<engine>/<section>.json` — golden `input → expected` cases (the *executable* SSOT).
- `conformance/` — runners that feed vectors to the app's real code and diff actual vs expected.
- `.claude/skills/` — qa-conformance (run vectors), qa-smoke (simulator), qa-edge-finder (grow vectors).

## Cross-department contract
- QA depends on app's **published interface**, not its internals: for now the pure
  `OfflineMacroCalculator` static API; later the `generate-macros-v4` edge function.
- Paths resolve through the workspace registry (`$APP_ROOT`, `$QA_ROOT` from
  `mealvana_endurance/workspace.env` via `find_workspace`) — never hardcoded.
- QA runs app's tests/simulator over `$APP_ROOT` via the filesystem (the `verify-fixes` pattern).

## Two-layer conformance (the point)
The spec drawer is the app's **explanation** layer, so two numbers must agree:
1. **engine ⇄ spec** — `OfflineMacroCalculator` output == vector expected (fast, deterministic).
2. **explanation ⇄ engine** — the in-app drawer shows the same number the engine computed
   (caught by qa-smoke on the simulator). The engine-says-47g-drawer-says-48g drift is a bug.

## Governance — implementation is not authorization
Discovering that code does X is a reason to log X in `DEVIATIONS.md`, **NOT** to rewrite the
SSOT to say X. The SSOT is the team's ratified intent; evolving it is a deliberate, separate
act. Vectors that merely pin observed-but-unratified behavior are marked
`status: characterization` (a tripwire), never treated as truth.

## The loop
Bug found → write it as a **failing vector here first** → Lee fixes app to green → the vector
is a permanent regression guard.

## Pilot status
Pre-workout **carbs** (Engine A, pure Dart). Chosen for simplicity: SSOT exists and already
agrees with code. Conformance runs **locally from qa/** (no Lee dependency yet); CI merge
gate + server parity come after the loop is proven.
