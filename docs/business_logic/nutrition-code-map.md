# Nutrition System Code Map

## Call Chain

```
Flutter App
├── macro_generation_service.dart ──invoke──> generate-macros-v4 (macro targets)
├── brick_macro_service.dart ──invoke──> generate-macros-v4 (brick macro targets)
├── nutrition_plan_service.dart ──invoke──> generate-nutrition-plan-v3 (food selection)
└── llm_nutrition_plan_service.dart ──invoke──> generate-nutrition-plan (V1, legacy LLM only)
```

## Production File Tree

### generate-nutrition-plan-v3/ (Main Plan Generation)
```
generate-nutrition-plan-v3/
├── index.ts                     (225 lines)  HTTP handler, validation, response
├── types.ts                     (104 lines)  PlanInputV2, LPPhaseResult, ByHourData
├── before-phase.ts              (260 lines)  Algorithm C orchestrator
├── before-phase-db.ts           (84 lines)   DB queries: pre_workout_templates, template_foods
├── before-phase-substitution.ts (221 lines)  User food matching by product_type + carb profile
├── before-phase-explosion.ts    (323 lines)  Component explosion + macro normalization
├── during-phase.ts              (725 lines)  Personal-formula pin -> template solver -> rule solver -> gap-fill/shortfall closing pass
├── lp-phase.ts                  (~190 lines) LP solver orchestration (after phase only — no during-phase LP tier as of 2026-07-21)
├── plan-generation-log.ts       (113 lines)  Per-plan ledger row (targets vs delivered, during-cascade path, shortfalls, pin decisions)
├── validation.ts                (144 lines)  Phase result validation
└── brick-handler.ts             (485 lines)  Brick workout multi-segment handler
```
`by-hour-apportionment.ts` was deleted 2026-07-21 (its only caller, the during-phase LP tier, was
deleted with it). The shared `during-gap-fill.ts` (closing-pass carb top-up) lives under
`_shared/nutrition/`, see below.

### generate-macros-v4/ (Macro Target Calculation)
```
generate-macros-v4/
├── index.ts        (1,252 lines)  HTTP handler + single-sport + brick calculations
├── types.ts        (170 lines)    PreWorkoutTemplate, PreWorkoutTargets, etc.
├── pre-workout.ts  (1,121 lines)  Algorithm C: scoring, stacking, selection
└── pre-workout.test.ts (577 lines)
```

### _shared/nutrition/ (Shared Solver Modules)
```
_shared/nutrition/
├── index.ts                 (26 lines)   Re-exports
├── types.ts                 (178 lines)  Food, Phase, MacroTargets, FoodResult, etc.
├── constants.ts             (183 lines)  MACRO_CONSTRAINT_RANGES, weights, thresholds
├── lp-solver.ts             (449 lines)  buildLPModel() + solveLPModel()
├── during-rule-solver.ts    (671 lines)  Deterministic rule-based during solver
├── during-gap-fill.ts       (210 lines)  During-phase closing carb gap-fill (append-only, gut-cap clamped)
├── greedy-fallback.ts       (378 lines)  Greedy fallback when LP fails
├── food-queries.ts          (376 lines)  Legacy food table queries
├── food-utils.ts            (115 lines)  Food utility functions
├── template-food-queries.ts (838 lines)  Template food table queries (V2+)
├── sport-configs/
│   ├── index.ts             (136 lines)  getSportConfig(), getOptimizationWeights()
│   ├── types.ts             (79 lines)   PhaseConfig, SportConfig interfaces
│   ├── running.ts           (47 lines)   Running-specific config
│   ├── cycling.ts           (48 lines)   Cycling-specific config
│   ├── swimming.ts          (48 lines)   Swimming-specific config
│   └── brick.ts             (65 lines)   Brick workout config
└── templates/
    ├── types.ts             (153 lines)  BeforePhaseResult, SubPhaseResult
    ├── pre-workout-targets.ts (136 lines) Pre-workout target calculation
    ├── diet-filter.ts       (127 lines)  Allergen/diet filtering
    ├── drink-selection.ts   (215 lines)  Drink template selection
    ├── meal-chain.ts        (217 lines)  Meal chain template selection
    └── scaling.ts           (305 lines)  Template scaling logic
```

## Database Tables Used

| Table | Used By | Purpose |
|-------|---------|---------|
| `template_foods` | template-food-queries.ts, before-phase-db.ts | Food catalog for all phases |
| `pre_workout_templates` | before-phase-db.ts, generate-macros-v4/index.ts | Before-phase meal/drink/electrolyte templates |
| `user_foods` | before-phase-substitution.ts, template-food-queries.ts | User's custom foods for substitution |
| `users` | before-phase-substitution.ts | Device ID → user ID lookup |
| `plan_generation_log` | plan-generation-log.ts | Per-plan ledger (targets vs delivered, during-cascade path, shortfalls, pin decisions); service-role only, best-effort write |

## Test Inventory

### Local Tests (no Supabase needed)
| # | File | Description | Run Command |
|---|------|-------------|-------------|
| 1 | `_shared/nutrition/during-rule-solver.test.ts` | During-phase rule solver unit tests | `deno test --allow-write <file>` |
| 2 | `_shared/nutrition/algorithm-audit.test.ts` | Comprehensive solver audit | `deno test --allow-write <file>` |
| 3 | `_shared/nutrition/lp-solver.test.ts` | LP solver unit tests | `deno test --allow-write <file>` |
| 4 | `generate-nutrition-plan-v3/before-phase-filtering.test.ts` | Before-phase template filtering | `deno test --allow-write <file>` |
| 5 | `generate-macros-v4/pre-workout.test.ts` | Algorithm C unit tests | `deno test --allow-write <file>` |
| 6 | `generate-nutrition-plan-v3/during-invariant-matrix.test.ts` | During cascade invariant matrix (activity × duration × gut level, incl. null/'medium'): carbs >= 90% of target OR a carbs shortfall reported (bug 3a3e3fdb) | `deno test --allow-write <file>` |

(Note: this table predates several other test files added since — see `run-algorithm-tests.sh` for the full, current §1 list.)

### E2E Tests (need SUPABASE_URL + SUPABASE_ANON_KEY)
| # | File | Description | Run Command |
|---|------|-------------|-------------|
| 1 | `generate-nutrition-plan-v3/index.test.ts` | Full V3 pipeline E2E | `deno test --allow-net --allow-env <file>` |
| 2 | `generate-nutrition-plan-v3/strict-macro-e2e.test.ts` | Strict macro range validation | `deno test --allow-net --allow-env <file>` |
| 3 | `generate-macros-v4/index.test.ts` | Macro generation E2E | `deno test --allow-net --allow-env <file>` |

### Run All Tests
```bash
# Local tests only
./supabase/functions/run-algorithm-tests.sh

# Local + E2E tests
export SUPABASE_URL=https://wvmvsodrvbkxfydabqed.supabase.co
export SUPABASE_ANON_KEY=<your-anon-key>
./supabase/functions/run-algorithm-tests.sh --e2e
```

### Archived Tests
Legacy test files moved to `supabase/functions/_archived_tests/`:
- `generate-nutrition-plan-v1-index.test.ts` (V1)
- `generate-nutrition-plan-v2-index.test.ts` (V2)
- `generate-macros-v3-index.test.ts` (macros V3)
- `generate-macros-v3-template-validation.test.ts` (macros V3)

## Deployment Flow

**Manual only.** The CI deploy workflows (`deploy-dev.yml` / `deploy-prod.yml`) were deleted in
`b2f86b4f` (2026-05-22); no workflow runs `supabase functions deploy`. Merging a change to
`develop` or `main` does NOT ship it — someone must deploy by hand. See
`/docs/deployment/README.md` for the runbook.

```bash
# Dev
./scripts/deploy_dev.sh generate-nutrition-plan-v3 generate-macros-v4

# Prod (asks for interactive 'yes')
./scripts/deploy_prod.sh generate-nutrition-plan-v3 generate-macros-v4
```

Or use the `/deploy-edge` Claude skill (same command plus pre/post checks). Note:
`generate-nutrition-plan-v3` imports from `generate-macros-v4/` — any Algorithm C change
requires deploying BOTH functions.

**Important:** If `_shared/` code changes, redeploy ALL importing functions.

## Flutter Integration Points

| Flutter File | Edge Function | Purpose |
|--------------|---------------|---------|
| `nutrition_plan_service.dart:798` | `generate-nutrition-plan-v3` | Main food selection |
| `llm_nutrition_plan_service.dart:198` | `generate-nutrition-plan` | Legacy LLM pathway |
| `macro_generation_service.dart:395` | `generate-macros-v4` | Single-sport macro targets |
| `brick_macro_service.dart:80` | `generate-macros-v4` | Brick workout macro targets |
