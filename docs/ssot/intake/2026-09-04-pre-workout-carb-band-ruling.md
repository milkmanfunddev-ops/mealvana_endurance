> **RESOLVED 2026-09-04 → spec/fueling/pre-workout-carbs.md plan-band amendment (Xuan, 2026-09-04) · vectors/fueling/pre-workout-carbs.json regenerated (12 vectors, band fields only) · `targetBasis` label DEFERRED as PW-022 · app engines already implement it at 3cf3ee42**

type: ruling-request
bundle: pre-workout-macros@v2.1 (spec/fueling/pre-workout-carbs.md v2 — plan band clause)

## Why this matters
The ratified plan band publishes Thomas's full 1.0–4.0 g/kg evidence RANGE as the athlete's
per-plan band whenever the fueling window is in [60, WINDOW_MAX] and duration ≥ 60. On device
that renders a ~50 kg athlete a "50g–200g" slider around a 50 g target — a 150 g-wide band that
dwarfs any actual plan and reads as a bug (Xuan, on-device 2026-09-04, IMG_8893). The evidence
window is a statement about the literature, not a usable per-plan tolerance.

## The ruling (Xuan, 2026-09-04) — IMPLEMENTED PENDING RATIFICATION, app commit today
Target stays as ratified: `target = window-hours × 1 g/kg × BW, capped at 4 g/kg`.
**The plan band is `target ± 12.5 %` in ALL cases** (the same TIER_TOL both engines already use
for the solver tolerance and the out-of-window band) — the in-window 1.0–4.0 g/kg band clause
is superseded. `target_basis` still reports evidenced_band/design_choice (it describes the
TARGET's derivation, not the band); whether that label should be renamed is left to the
ratifier.

## What shipped (both engines, same commit — twin rule)
- `supabase/functions/generate-macros-v4/pre-workout.ts` `calculatePreWorkoutCarbs`
- `lib/features/nutrition_plan/data/offline_macro_calculator.dart` (Dart twin)
- Deployed to dev: generate-macros-v4 + generate-nutrition-plan-v3 (imports the shared code).

## Failing tests left RED on purpose (the ratification debt — regenerate, don't revert)
Both engines fail identically against the v2 vectors — the twins agree with each other.
Full inventory (re-measured after the P3 gate run's coding agent flagged a wider set,
`ops/data/bug-reports/2026-09-04-trunk-red-band-change-blocks-release-cut.md`):
- TS: `pre-workout-vectors.test.ts` — 12 vector steps (the cited-* rows) + the cross-slice pin
  "the two carb bands are deliberately different objects" (they now deliberately coincide).
- Dart vectors: the same 12 `pre-workout-carbs.json` rows + 13 frozen carbs-v2 rows in
  `test/qa_conformance/`.
- Dart unit pins: 3 re-stating the 1–4 g/kg band (the 4 g/kg-cap-on-ceiling pair and the
  duration-flip band assertion).
- Band-derived GOLDENS: before-card/hydration goldens + feeding-membership scenarios (~6)
  render the band values and need regeneration alongside the vectors — a golden update is a
  ratification act, so it waits for this ruling to land.
NOTE for the release process: this red set blocks the §8 P1–P3 gates on trunk; the
food-recommendation@v1.1 prod cut should go from 18189b7b (parent of the band commit) or wait
for this ratification — see the ops report above.

## Gates
QA: fold the ruling into `pre-workout-carbs.md` (v2 → v3 or post-ratification amendment),
regenerate the `pre-workout-carbs.json` band expecteds (targets unchanged — only
carbs_low_g/carbs_high_g move to ±12.5 %), rule on the `target_basis` label. App: update/retire
the 4 band-shape unit pins to the ratified text once it lands; suites go green with no further
engine change.
