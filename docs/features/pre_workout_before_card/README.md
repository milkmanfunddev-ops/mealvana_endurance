# Pre-workout BEFORE card — implementation record (pre-workout-macros@v2)

**Bundle:** `pre-workout-macros@v2` (qa `8ab0e6d`, handoff `b2d64e7`) · **Branch:**
`feature/pre-workout-before-card` · **Date:** 2026-08-26.
Contract: `docs/ssot/spec/design/surfaces/pre-workout-before-card.md` v1 + components
`fuel-stat` / `feeding-card` / `hydration-check` v1 + `tokens.md` (Q-D8/Q-D9); math
`docs/ssot/spec/fueling/pre-workout-{carbs v2, hydration v6 (+PW-021), sodium v3}.md`.
Interim defaults P1–P12: `docs/ssot/bundles/pre-workout-macros.deferred.md`.

## Where things live

| Layer | File | Role |
|---|---|---|
| library (design-bearing) | `lib/shared/widgets/kyle_design/fueling/fuel_stat.dart` | fuel-stat v1 (F-1/F-2, M-1…M-5) |
| library | `lib/shared/widgets/kyle_design/fueling/feeding_card.dart` | feeding-card v1 (FC-1…FC-7, FC-G1…G3) |
| library | `lib/shared/widgets/kyle_design/fueling/hydration_check_control.dart` | hydration-check v1 (H-1…H-5, copy register) |
| library | `lib/shared/widgets/kyle_design/fueling/fueling_glyphs.dart` | the rendering's SVG glyphs, token alphas, the Compadre substitution |
| surface (feature) | `lib/features/nutrition_plan/presentation/widgets/activity_detail/pre_workout_before_card.dart` | composition; S-G1…S-G4 |
| application | `lib/features/nutrition_plan/application/pre_workout_before_card_assembler.dart` | B-1 sums, B-2 membership, B-5 units (R-01 / M-5) |
| application | `lib/features/nutrition_plan/application/pre_workout_hydration_check_service.dart` | H-2 write / H-3 revert through the engine seam |
| domain | `lib/features/nutrition_plan/domain/pre_workout_before_card_model.dart` | view data + copy register |
| domain | `lib/features/nutrition_plan/domain/pre_workout_hydration_check.dart` | answer enum, persisted record, row tag |
| domain | `lib/features/nutrition_plan/domain/pre_workout_display_units.dart` | R-01 oz, M-5 g (supersedes `pre_workout_display_rounding.dart`, retired) |
| domain | `lib/features/nutrition_plan/domain/pre_workout_feeding_labels.dart` | FC-1 titles (sport variant retired, P4), window labels |
| data | `lib/features/nutrition_plan/data/macro_repository.dart` | `hydrationCheck` threaded to `calculatePreWorkoutHydration` (`preWorkoutHydrationFor` seam); `fluidsMl` null on the gate |
| controller | `ActivityDetailController.answerHydrationCheck` / `clearHydrationCheckAnswer` | one atomic write |

Retired from the BEFORE surface: `before_phase_widget.dart` (deleted), `pre_workout_display_rounding.dart`
(deleted; 25-ml helpers kept *privately* inside the explanation service and `macro_summary_row.dart`
for the untouched DURING/AFTER surfaces), `before_phase_collapsed_chips_test.dart` (deleted, replaced
by the gesture suite). `macro_summary_row.dart` and `time_slot_row.dart` stay because DURING / AFTER /
by-hour still compose them (S-G1: those surfaces are untouched).

## Decisions written before coding (handoff §5.4 I10, deferred ledger)

- **Recompute is client-only** through `MacroRepositoryImpl.preWorkoutHydrationFor` →
  `OfflineMacroCalculator.calculatePreWorkoutHydration` (the engine is the authority per its header).
  No `generate-macros-v4` request field this iteration (P2).
- **`timeBeforeWorkoutMin` is the activity's frozen `time_before_minutes`** (clamped 0–240, D-016),
  never the clock (PW-021).
- **Only `fluidMl` and the tier split move** on an answer; the band is asserted identical (inv. 8b).
- **Water row** = 1 cup / 8 oz / 236.588 ml, tagged `origin: hydration_check`, added only when
  delivered < new target; its id is recorded so Change answer removes it even after an edit (P3).
- **Stepper to 0 removes the row** (P3); no swipe-to-delete on this surface.
- **Check suppressed when `regime == gated`** (P1) and below `T_REF`.
- **The `?` fine print is absent** (S-G4 / P9).
- **Absent weight ⇒ absent numbers**: `_computeOfflineMacros` throws `MissingBodyWeightException`
  (no 70-kg stand-in); the card's FC-1 threshold cannot be evaluated without a weight and falls back
  to "Pre-Workout Snack".

## Persistence (P2) — JSON keys in `activities.nutrition_plan_data`

```
preWorkoutHydrationCheck: {
  answer: "pale" | "dark" | "not_yet" | "not_sure",
  baselineFluidMl: <ml before the answer>,
  baselineFluidTiers: [ {tier, fluidMl}, … ],
  baselineHydrationCheckUsed: "pale" | "dark" | "unknown",
  addedWaterFoodId: "<food id>" | null
}
sections[before].subPhases[snack].foodItems[].origin = "hydration_check"   // the tagged row
detailedMacroTargets.preRun.{fluidsMl, fluidTiers, hydrationCheckUsed}      // the moved target
```

Stepper edits persist as they always did (the sub-phase's `foodItems[].quantity` +
`nutritionalInfo`). One write: `ActivityDetailController._saveNutritionPlanToActivity` (plan JSON +
`detailedMacroTargets`); the activity-scoped SharedPreferences targets cache is refreshed too
because the load path reads it first. Seam test:
`test/features/nutrition_plan/pre_workout_hydration_check_persistence_test.dart`.

## Port-loop assumptions raised to qa intake (red means raise)

- `2026-08-26-compadre-demo-cut-cannot-render-design-lowercase.md` — the Compadre slots render in
  Sansita 700 (demo cut has no lowercase / parentheses).
- `2026-08-26-before-card-goldens-manifest-meal-expanded-note.md` — the `feeding_meal_expanded`
  note says "hydration-check row first"; FC-6 says SNACK; spec wins.
- `2026-08-26-before-card-port-assumptions.md` — snack fluid figure after DARK (9 oz), 24 oz vs
  the illustrative 25 oz, the TOP_OFF "NOW" threshold.

## Conformance

- Goldens (18): `test/features/nutrition_plan/pre_workout_before_card_goldens_test.dart` →
  `goldens/*.png` (17 manifest ids + `oz_conversion`; `before_fine_print` deferred).
- Gestures (21): `test/features/nutrition_plan/pre_workout_before_card_gestures_test.dart`.
- Units / service / boundary: `domain/pre_workout_display_units_test.dart`,
  `domain/pre_workout_feeding_labels_test.dart`,
  `application/pre_workout_hydration_check_service_test.dart`,
  `data/pre_workout_boundary_collapses_test.dart`.
- Math: `test/qa_conformance/` (74/74, unchanged).
