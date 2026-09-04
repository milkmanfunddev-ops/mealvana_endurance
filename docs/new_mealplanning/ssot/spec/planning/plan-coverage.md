# SSOT — Plan Coverage

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.**
**Engine:** `coverageOf(meals, scope)` — edge `_shared/vana/plan-math.ts` (authoritative, pure); prototype
`server/vana/plan.ts` `coverageOf(meals)` (**no scope — D-11**); Dart `PlanCoverageService.compute(meals,
lunchDinnerSlots)` (`domain/plan_coverage.dart`, the local-first recompute).
**Consumers:** `MealPlan.coverage` on every `batch` part; the plan bar / staples card "N / 14"; the persona's
"when every type in scope is covered".

## Inputs

`meals[]` — `PlanMeal`s with `mealType`, `servings`, `kcal`, `carbsG`, `proteinG` (per serving, nullable).
`scope` — the athlete's `coverage_scope` setting: `dinners` · `dinners_lunches` · `all` · null (never chosen).

## Constants

```
SLOTS_LUNCH_DINNER = 14      # 7 lunches + 7 dinners
SLOTS_DINNERS      = 7       # scope == "dinners"
DAYS               = 7
```

## The algorithm

```
dinnersOnly = (scope == "dinners")          # ONLY the literal string narrows; anything else = 14
slots       = dinnersOnly ? 7 : 14
counted     = meals where mealType == dinner or (!dinnersOnly and mealType == lunch)
covered     = min(slots, Σ counted.servings)
perDay      = { kcal: round(Σ all kcal×servings / 7), carbsG: round(Σ carbsG×servings / 7), proteinG: round(Σ proteinG×servings / 7) }
             # null macros contribute 0; round = JS Math.round
```

**Breakfast and snacks are never slots.** `all` widens what the persona offers, not the denominator (PC-3).

## Invariants

1. `0 ≤ covered ≤ lunchDinnerSlots`; `lunchDinnerSlots ∈ {7, 14}`.
2. `covered` counts **servings**, not meals: one dinner ×14 covers the week.
3. `perDay` sums **every** meal type, including breakfast and snacks, whatever the scope.
4. Null macros are 0, never an error and never excluded from the serving count.
5. The Dart twin must reproduce the server's `covered` for the same `lunchDinnerSlots` — it reads the
   denominator back from the wire (7 ⇔ dinners) rather than the setting, so a local edit never changes the
   scope the server chose.
6. Rounding halves toward +∞ (`half-rounds-up`).

## Worked examples

`vectors/planning/plan-coverage.json` — `cap-at-14` is the canonical one: 5 + 4 + 4 + 1 dinner servings = 14 →
covered 14; 9130 kcal ÷ 7 → 1304; 1215 g C ÷ 7 → 174; 571 g P ÷ 7 → 82.

## Deviations

- **D-11 — the prototype's `coverageOf` has no `scope` argument**; its plan bar always shows /14. Two vectors
  are EXPECTED-RED on `run_prototype.sh` until the prototype adopts `plan-math.ts`'s signature.

## Conformance

Vectors: `vectors/planning/plan-coverage.json` (10). Edge 10/10; prototype 8/10 (D-11); Dart — the runner maps
`scope` to the denominator. Required coverage: both denominators, the cap, breakfast/snack exclusion, null
macros, the .5 rounding, an unknown scope string.
