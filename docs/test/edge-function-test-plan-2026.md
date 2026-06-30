# Edge-Function Unit Test Plan — Nutrition Engine (2026-06-23)

Grounded in a full code map of `generate-macros-v4` (current) + `generate-nutrition-plan-v3`
(current). Goal: lock down the nutrition plan, which "is not working super well." Leverages
the existing deterministic harness — **no live DB** for unit tests (in-memory food catalog via
`supabase/functions/_shared/nutrition/test-utils.ts`); live E2E stays in `run-algorithm-tests.sh §2`.

## Current vs legacy
- **App uses:** `generate-macros-v4` → `generate-nutrition-plan-v3`.
- **Legacy:** `generate-macros-v3` + `generate-nutrition-plan-v2` (only the Python integration test hits these). Don't invest there.

## What already exists (leverage, don't rebuild)
- `run-algorithm-tests.sh` §1 = deterministic unit tests (rule solver, algorithm-audit, LP, before-phase filtering, pre-workout invariants, template solver, **parity**). §2 = live E2E.
- `tests/parity/parity.test.ts` — 16 fixtures × invariants, but **only exercises the rule solver + personal-formula path** (not template solver, not LP, not after-phase). 2 `knownFailure` fixtures (fluid floor <480ml; sodium gap in constrained catalog).
- `test-utils.ts` helpers: `makeFood`, `makeDuringFoods(Extended)`, `makeAfterFoods`, `assertWithinPercent`, `assertInRange`, `LogCapture`.

## Convention for bug-exposing tests
Many target areas are *currently broken*. Write assertions for **correct** behavior; where the bug exists today, mark the case `knownFailure` (mirroring the parity harness) so the suite stays green while the bug is tracked. Each new `.test.ts` is deterministic, `--allow-write --node-modules-dir=none`, and gets a line in `run-algorithm-tests.sh §1`.

## Priority test matrix (ranked by the mapped failure modes)

### P1 — Empty during/after phase (the core "errors out / missing phase" symptom)
- `getTemplateFoodsForPhase` → `[]` ⇒ `generateDuringPhase` returns `{foods:[]}` silently, **no shortfall**. Assert: returns without throwing AND emits a meaningful warning/shortfall (this is the fix target — today it's silent).
- Both default + expanded during pools empty ⇒ empty phase. Assert behavior + that `response.warnings` is populated.
- File: `generate-nutrition-plan-v3/during-phase-empty-pool.test.ts`.

### P2 — Diet/allergy filtering silently passes disallowed foods  ⚠ known bug
- **Vegan/vegetarian not recognized** in before-phase Algorithm C nor in `template-food-queries.ts` STEP 4 (only gluten-free/dairy-free/peanut-free/all-free handled). Assert: vegan/vegetarian athlete + template with empty `excluded_diets` containing meat ⇒ those foods excluded. Will fail today ⇒ `knownFailure` + ticket.
- Allergy overlap exclusion across before/during/after.
- Pin override correctly bypasses filters (assert the documented behavior).
- File: `generate-nutrition-plan-v3/diet-allergy-filtering.test.ts` (extends `before-phase-filtering.test.ts`).

### P3 — Macro adherence + shortfall asymmetry
- Shortfalls only emitted when `dislikedFoods.size > 0`. Assert: athlete w/ 1 dislike + restrictive diet that misses sodium ⇒ `shortfalls` emitted; same athlete w/ 0 dislikes ⇒ currently silent (mark the gap).
- `validatePhaseResultAgainstTargets` tolerance: during carbs/sodium/water [0.9,1.1]; before/after [0.85,1.1]. Assert in/out-of-range classification.
- File: `generate-nutrition-plan-v3/macro-adherence.test.ts`.

### P4 — After-phase ignores macro targets (silent non-adherence)
- After uses canonical template portions, not `post_run` targets. Assert: high `post_run.carbs_g` ⇒ validation surfaces a non-fatal warning in `response.warnings` (and that it IS surfaced, so the client can show it).
- File: `generate-nutrition-plan-v3/after-phase-adherence.test.ts`.

### P5 — LP infeasibility / greedy fallback
- `solveLPModel` infeasible + `greedyFallback` empty pool ⇒ never returns `{foods: undefined}`; returns `{foods:[]}` cleanly.
- File: extend `lp-solver.test.ts`.

### P6 — Missing template component food
- Template with a component absent from `foodsByName` ⇒ template excluded (not thrown); if all excluded ⇒ falls to rule solver. Assert both.
- File: extend `during-template-solver.test.ts`.

### P7 — pre_workout_templates DB failure kills the macro call
- `loadPreWorkoutTemplates` throws on query failure ⇒ `generate-macros-v4` handler returns 500 (not 200-with-empty). Assert the throw + handler mapping (mock a failing client).
- File: `generate-macros-v4/pre-workout-db-failure.test.ts`.

### Coverage breadth — extend the parity harness (athletes × distances × activity types)
Add fixtures to `tests/parity/fixtures/` covering the combinations the user cares about, each asserting macro parity within tolerance + invariants:
- Activity types: running, cycling, swimming (during=0 expected), brick/triathlon.
- Distances/durations: <60m, 90m, 150m, 240m, >240m (hits every carb band + sport ceiling).
- Intensities: low/moderate/high gut-training × zone distributions.
- Diets: omnivore, vegetarian, vegan, gluten-free, dairy-free, multi-allergy.
- Pins: system template pin, personal formula (before/during/after), out-of-scope formula.
Extend the harness to also drive the **template solver** and **LP** paths (currently rule-solver only) so coverage matches production.

## Macro-engine (v4) unit gaps to add
- Sport ceilings (run 70 / bike 120 / swim 0 g/h) and duration bands ([0,30]…[80,100]) — property-style across the full input range (consider `glados` on the Flutter mirror; Deno-side use a loop).
- Gut multipliers (0.7/1.0/1.2); fasted/post multipliers; weather→sweat (`classifyEnvironment`, default 20°C/60%).
- Override band expansion (`adjustTargetsForOverrides`) at the orchestrator level.

## Run
`bash supabase/functions/run-algorithm-tests.sh` (unit, deterministic) / `... --e2e` (live). Per-PR: §1 only. Nightly: §1 + §2 + Python integration + parity breadth.

## Known real bugs to file (found via this mapping / parity)
1. Vegan/vegetarian before-phase + SQL diet filter gap (non-vegan foods pass).
2. Fluid floor overshoot (<480ml targets, min serving 240ml) — parity fixture 01.
3. Sodium fill skipped when score doesn't improve in constrained catalogs — parity fixture 05.
4. Empty during/after pool produces silent empty phase (no shortfall/warning).
5. After-phase ignores `post_run` targets (warning may not reach the client).
6. Shortfall emission only when user has dislikes (asymmetric adherence reporting).
