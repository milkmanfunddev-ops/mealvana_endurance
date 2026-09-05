type: handback
bundle: pre-workout-macros@v2
from: app coding agent (feature/pre-workout-before-card), 2026-08-26 — for Xuan's charter run + test-plan audit

## What landed (app repo, branch `feature/pre-workout-before-card`, branched from `develop`)

- The BEFORE card as the ratified design family: `lib/shared/widgets/kyle_design/fueling/{fuel_stat,
  feeding_card, hydration_check_control}.dart` (library, spec-cited headers) + the surface
  `pre_workout_before_card.dart`; assembler + hydration-check write service in the application layer.
- Engine: `test/qa_conformance` **74/74 unchanged**; `hydrationCheck` threaded through
  `macro_repository.dart` (`preWorkoutHydrationFor` seam, also exposed on `generateMacroTargets`) so
  all three values reach `calculatePreWorkoutHydration`; the offline-fallback plan path now overlays
  hydration v6 / sodium v3 over the legacy map (PW-012) instead of shipping `water_ml`.
- Boundary collapses fixed with tests: `PreRunMacros.fluidsMl` is nullable (gate → "No fluid target
  for this session", never 0 oz); `_computeOfflineMacros` throws `MissingBodyWeightException` instead
  of the 70-kg stand-in.
- D-016: the 240 cap + clamp-on-load was already in code (`fueling_window_limits.dart`,
  `fueling_window_clamp_test.dart` covers 480 → 240 on all four controllers); verified, not re-done.
- Retired: `before_phase_widget.dart`, `pre_workout_display_rounding.dart`,
  `before_phase_collapsed_chips_test.dart`; `pre_workout_feeding_labels_test.dart` rewritten to FC-1.
  `macro_summary_row.dart` / `time_slot_row.dart` stay — DURING / AFTER / by-hour compose them (S-G1).
- Persistence keys (P2): `nutrition_plan_data.preWorkoutHydrationCheck{answer, baselineFluidMl,
  baselineFluidTiers, baselineHydrationCheckUsed, addedWaterFoodId}`; the tagged row's
  `foodItems[].origin = "hydration_check"`; `detailedMacroTargets.preRun.{fluidsMl, fluidTiers,
  hydrationCheckUsed}`.

## Conformance artifacts

- Goldens (`test/features/nutrition_plan/goldens/`): the 17 manifest ids + `oz_conversion`
  (`before_fine_print` deferred). Blessed from the side-by-side against `pre-workout@v2.html`; the
  Compadre slots render in Sansita 700 — see the intake ruling-request.
- Gesture tests (`pre_workout_before_card_gestures_test.dart`): the 17 manifest ids +
  `h_suppressed_when_gated`, `s_fine_print_absent`, `fc_stepper_clamp`; oz pairs in
  `pre_workout_display_units_test.dart`.
- QA-side gate: `qa/conformance/pre_workout_{carbs,hydration,sodium}_conformance_test.dart` replaced
  verbatim from `app/test/qa_conformance/` (this commit).

## Raised (red means raise), all non-blocking

- `2026-08-26-compadre-demo-cut-cannot-render-design-lowercase.md` (ruling-request)
- `2026-08-26-before-card-goldens-manifest-meal-expanded-note.md` (spec-erratum)
- `2026-08-26-before-card-port-assumptions.md` (ruling-request: snack fluid figure after DARK;
  24 oz vs the illustrative 25; the TOP_OFF "NOW" threshold)

## Feature test plan rows believed to flip ⬜ → ✅ (`docs/feature-test-plans/pre-workout-before-card.md`)

| Row | Test |
|---|---|
| I2 only `fluidMl` moves | `pre_workout_before_card_gestures_test.dart` (h2_answer_writes_target, s_answer_propagates); `application/pre_workout_hydration_check_service_test.dart` |
| I3 `null ≠ 0` everywhere | gestures (fs_three_no_number_states); goldens `fuelstat_gated`, `fuelstat_fasted`, `before_start_line`; `data/pre_workout_boundary_collapses_test.dart` |
| I4 traceability + oz | gestures (s_delivered_is_surface_sum); `domain/pre_workout_display_units_test.dart`; golden `oz_conversion` |
| I5 check × gated (interim P1) | gestures (h_suppressed_when_gated); service test "gated plan (P1)" |
| I6 no clock | gestures (h_no_live_clock) |
| I7 one-way / two-way; M-3 | gestures (fs_fluid_one_way_carbs_two_way, fs_two_markers); golden `fuelstat_fluid_overshoot` |
| I8 no basis signifier | gestures (fs_no_basis_signifier) |
| I9 undo symmetry | gestures (h3_change_answer_reverts); service test revert group |
| I10 persistence (interim P2) | `pre_workout_hydration_check_persistence_test.dart` |
| I11 rounding (interim P5: M-5 / R-01) | `domain/pre_workout_display_units_test.dart`; golden `oz_conversion` |
| I12 no visible rounding jump | `domain/pre_workout_display_units_test.dart` (floor/ceil widen-only) — partial; the 17-point grid sweep of displayed figures is not written |
| §2 inputs → engine (weight fallback, 480 lead) | `data/pre_workout_boundary_collapses_test.dart`; `presentation/providers/fueling_window_clamp_test.dart` (pre-existing) |
| §2 sodium fields — the *card* reads Σ rows | gestures (fs_sodium_never_banded); service test "assembler — B-1" |
| §2 engine → persisted plan (no `tier` int) | `pre_workout_hydration_check_persistence_test.dart` (asserts `hydrationRegime`, tiers, `hydrationCheckUsed` round-trip) — partial: a dedicated serialization-vector suite is not written |
| §2 fasted path (golden) | golden `fuelstat_fasted`; gestures (fs_three_no_number_states) |
| §2 t → which feedings exist | goldens `before_*` ×5; gestures (h_no_live_clock); service test "B-2 membership" |
| §2 tier grams → card title | gestures (fc_naming_threshold); golden `feeding_snack_light_meal`; `domain/pre_workout_feeding_labels_test.dart` |
| §2 t → window label | golden `before_2h15_meal_15min_window`; `domain/pre_workout_feeding_labels_test.dart` (NOW UNTIL / NOW variants) |
| §2 rows → header delivered | gestures (fc_header_delivered_only) |
| §2 rows → summary delivered | gestures (s_delivered_is_surface_sum) |
| §2 engine band → rail + markers | gestures (fs_two_markers, fs_sodium_never_banded); goldens `fuelstat_*` |
| §2 targetBasis → nothing | gestures (fs_no_basis_signifier) |
| §2 ml → oz | `domain/pre_workout_display_units_test.dart`; golden `oz_conversion` |
| §2 colour meaning | goldens (token-resolved) |
| §2 plan t ≥ 120 → row exists | gestures (h_suppressed_below_2h); golden `before_90min` |
| §2 chip → expanded | gestures (h1_expand); golden `check_expanded` |
| §2 four labels → three engine values | service test "answer → hydrationCheck map" |
| §2 answer → recompute → target | gestures (h2_answer_writes_target); service test |
| §2 new target vs delivered → row or no row | gestures (h2_already_covered); service test "already covered" |
| §2 emission → whole-card update | gestures (s_answer_propagates) |
| §2 result copy | gestures (s_copy_registers) — 24 oz interpolated, see intake Q2 |
| §2 Change answer → revert (incl. edited row, P3) | gestures (h3_change_answer_reverts); service test "P3" |
| §2 answer → persisted `hydrationCheck` | persistence test |
| §2 check on a gated plan | gestures (h_suppressed_when_gated) |
| §2 stepper → row quantity (`fc_stepper_clamp`) | gestures (fc_stepper_clamp) |
| §2 row change → delivered only, aim fixed | gestures (s_delivered_is_surface_sum, fc_header_delivered_only) |
| §2 row removal (P3) | gestures (fc_stepper_clamp: 0 removes) |
| §2 sodium per row → delivered mg | gestures (fs_sodium_never_banded) |
| §2 edit → persisted plan → re-render | persistence test |
| §2 `?` suppressed (`s_fine_print_absent`) | gestures (s_fine_print_absent) |
| §3 Goldens + gestures (app test tree) | both suites |
| §3 Display rounding vectors | `domain/pre_workout_display_units_test.dart` |
| §3 Four answers → three values → fluidMl | gestures (h2_answer_writes_target); service test |

Not flipped: I1/carbs/hydration/sodium/cross-spec (already ✅); "+ Add Food → what may be added"
(food-composition sibling bundle, no engine); "Plan serialization" vectors as a QA vector file (only
the app-side round-trip test exists); `before_fine_print` (deferred S-G4).
