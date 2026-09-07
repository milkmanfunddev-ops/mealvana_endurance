# Handoff — pre-workout-macros@v2 → the coding agent

**Checkout `pre-workout-macros@v2`** (commit `8ab0e6d`) in the qa repo (resolve via `$QA_ROOT` from
`mealvana_endurance/workspace.env`). The manifest `bundles/pre-workout-macros.yaml` is the index:
3 math slices + 5 design slices, 8 named exclusions, `done_when`. Companions: the deferred ledger
`bundles/pre-workout-macros.deferred.md` (**P1–P12 — each carries the interim default you
implement; do not re-ask**), the feature test plan `docs/feature-test-plans/pre-workout-before-card.md`,
the two design manifests `conformance/design/pre-workout-before-card.{goldens,gestures}.yaml`, the
reconciliation `docs/design-reconciliation/pre-workout-v2-vs-pre-workout.md`, and the charter
`.claude/skills/sim-explore/references/charter-pre-workout-before-card.md`.

## 1. Where the truth lives

| What | Where |
|---|---|
| Math contract | `spec/fueling/pre-workout-carbs.md` v2 · `pre-workout-hydration.md` v6 (**read the PW-021 paragraph in *The urine check* — the `offerCheck` predicate is retired**) · `pre-workout-sodium.md` v3 · `pre-workout.notes.md` §6–§7 (where §6 conflicts with M-5 / R-01 / PW-021, the newer ruling wins — deferred P5) |
| Vectors (the executable contract) | `vectors/fueling/pre-workout-{hydration 21, carbs 19, sodium 8}.json` — `scripts/count-vectors.mjs fueling` = 164 for the family |
| Design contract | `spec/design/surfaces/pre-workout-before-card.md` v1 (composition + B-1…B-5 + S-G1…S-G4) · `components/fuel-stat.md` v1 · `components/feeding-card.md` v1 · `components/hydration-check.md` v1 · `tokens.md` (Q-D8 electrolyte on the per-workout fuel side; Q-D9 dragonfruit for out-of-range) |
| **The reference rendering (visual spec)** | `spec/design/renderings/pre-workout@v2.html` (frozen at qa `394754b`) = `$PROTOTYPES_ROOT/pre-workout/v4.html` @ prototypes `d6b2de4` ("v4 candidate — no basis captions (M-4), delivered-only headers (FC-2)"). Five `plannedAhead` scenarios × three `targetState` values; walk all fifteen |
| Design conformance | `conformance/design/pre-workout-before-card.goldens.yaml` (18 goldens, `before_fine_print` deferred) · `.gestures.yaml` (17 tests) |
| Deferred with interim defaults | `bundles/pre-workout-macros.deferred.md` P1–P12 |

## 2. The port prompt (verbatim, Xuan's — static fidelity)

---
This is a port, not a redesign. The HTML design (path + commit above) is the visual spec —
use its exact values (colors, fonts, spacing, corner radii), not approximations.

Rules:
1. Preserve visual hierarchy exactly: which button is filled vs. outlined, primary CTA color,
   text alignment, and element order.
2. Do not substitute, remove, or "improve" any content (e.g., testimonial cards, dividers,
   footnote text stay as designed).
3. If real app data conflicts with static content in the design, ask me before changing anything.

Verification loop — do this for every screen:
1. Implement the screen.
2. Capture a screenshot of it running in the simulator.
3. Compare side-by-side against the HTML design and list every discrepancy (color, alignment,
   hierarchy, spacing, missing elements).
4. Fix the discrepancies and re-capture until the audit list is empty.
5. Show me the final side-by-side before moving to the next screen.

If any decision isn't clearly answered by the design, ask me instead of guessing.
---

**Scope note on rule 3 / "ask me":** the twelve questions already asked are answered in the deferred
ledger with interim defaults — use those, do not re-open them. Anything *new* still goes through
`intake/` (red means raise), never into a spec edit.

## 3. Design-SSOT addendum (behaviour + meaning — what screenshots can't hold)

- Where the HTML and `spec/design/` disagree, **spec/design wins**. Known scaffold in the HTML that is
  NOT contract: the scenario switcher resetting the answer (hydration-check "Do not encode as truth").
- Implement **every state and gesture row, including suppressions as negative tests**: the check
  absent below 2 h (`h_suppressed_below_2h`) and on a gated plan (P1, `h_suppressed_when_gated`); no
  live clock (`h_no_live_clock`); no basis signifier (`fs_no_basis_signifier`); no DONE/AIM pair
  (`fc_header_delivered_only`); sodium never banded; the `?` ABSENT (P9, `s_fine_print_absent`).
- **Tokens by meaning, not value**: `electrolyte` = per-workout fuel headline/delivered/check accent;
  `orange` = daily intake (never on this card's figures); `dragonfruit` = overshoot marker only.
- **Numbers come from the engine per the traceability rows** (surface B-5, fuel-stat table): figure =
  Σ rows; band ends = engine fields; oz = `round(ml/29.5735)` target, `[floor, ceil]` band (R-01);
  carbs whole grams (M-5). The 63-kg mock values in the HTML are illustrative — never hard-code them.
- **Three no-number states are three trees** (F-1): gate → "No fluid target for this session";
  fasted → "No carbs this session"; start line → real `0g` with no band.
- The hydration check's four labels map onto three engine values (PALE/NOT_SURE → no top-up,
  DARK/NOT_YET → `+4·BW`); the **band never moves** (inv. 8b); the water row is the *means*, added
  only when delivered < new target; Change answer reverts both. The check is the **first row of the
  SNACK card**, labelled as a fluid instrument, present for the life of every ≥ 2 h plan.
- Goldens regenerate only after a spec change; bless 17 from the first correct rendering.
- Run the component specs' conformance checklists alongside the side-by-side loop.

## 4. Engine rules

- **The math is already green — keep it that way.** `flutter test test/qa_conformance` = 74/74
  (2026-08-26). The only engine-adjacent change: thread `hydrationCheck` through
  `macro_repository.dart:173-178` (and the persisted answer) so the recompute is real; assert all
  three values reach `calculatePreWorkoutHydration`. Vectors are the contract — never edited to pass.
- **Expected-red inventory (design side):** everything in both design manifests; the two boundary
  collapses (`macro_repository.dart:210`, `macro_generation_service.dart:652`); D-016 stepper cap.
- **Superseded tests that will go red by design** and must be replaced citing the design spec:
  `before_phase_collapsed_chips_test.dart`, `pre_workout_feeding_labels_test.dart` (sport-varying
  titles — P4), `seeded_tests/nutrition_plan_content_test.dart`. Legacy-map tests
  (`offline_macro_calculator_pre_workout_legacy_map_test.dart`, `pre_workout_hydration_tier_test.dart`,
  `pre_workout_windows_test.dart`) pin the superseded map — they stay until that map is retired, and
  their green is not the card's contract.
- **Schema tasks:** none for engine outputs; **P2** — the answer, edits and the tagged water row
  persist in `activities.nutrition_plan_data` (keys named in the implementation, mirrored back to the
  test plan §3 "plan serialization" vector row).
- **Handback (I4):** replace `qa/conformance/pre_workout_*_conformance_test.dart` verbatim with the
  app's `test/qa_conformance/*` (or point `run_dart.sh` at them); re-pin `docs/ssot/SSOT_SOURCE.txt`
  to `pre-workout-macros@v2` / `8ab0e6d`; re-sync the mirror (hydration spec + OPEN-QUESTIONS differ
  today; the design family and both manifests are absent); flip test-plan rows.

## 5. Known terrain & conflict watchlist (verified against `$APP_ROOT` 2026-08-26 — carried verbatim from the feature test plan §6)


**Headline: this is an UPDATE of a build whose ENGINE already implements the ratified math, and a
GREENFIELD build of the design family.** `flutter test test/qa_conformance` → **74/74 passed**
(2026-08-26) against a vector mirror byte-identical to `qa/vectors/fueling/pre-workout-*.json`.
Verify, don't rebuild, the engine; build the UI.

### 5.1 Update-vs-greenfield

| Piece | State | Where |
|---|---|---|
| Carbs v2 engine | **implemented** | `lib/features/nutrition_plan/data/offline_macro_calculator.dart:185-279` (`calculatePreWorkoutCarbs`, `_carbTier`; constants `:117-165` match the spec) |
| Hydration v6 + sodium v3 engine | **implemented** | `offline_macro_calculator.dart:1417-1545` (`calculatePreWorkoutHydration`); gate `:1431-1445` returns `null`/`[]`/`gated`/`none`; sodium permanently `null` `:1948-1953`; `k = 3.2/60` computed |
| Cross-spec pin | **implemented three ways** | `:1368-1393`, `:2025-2030` (const ctor), TS `pre-workout.ts:168-172` |
| `hydrationCheck` plumbing | **engine, wire, domain, server echo exist; NO producer** | param `:1422` (default `unknown`); `macro_repository.dart:173-178` does not pass it; echo `macro_generation_service.dart:790-791`; `HydrationCheck.fromWire` `:1876`. **No widget sets it — the hydration-check component is the new input.** |
| PW-021 (no live clock) | engine already frozen-lead (`offline_macro_calculator.dart:1413-1416` "MUST reuse the original value") | nothing to undo — the old `offerCheck` predicate was never built |
| BEFORE card UI | **OLD UI** — `before_phase_widget.dart` (523 L) with ctor `carbs/sodium/fluids + Low/High + *Overridden` | `lib/features/nutrition_plan/presentation/widgets/activity_detail/before_phase_widget.dart`, `macro_summary_row.dart` (`round5`/`round25` `:125-126`), `time_slot_row.dart`, `section_subtitle_widget.dart:50-51`; embedded by `nutrition_sections_builder.dart:206-212` → `activity_detail_screen.dart:601` and `brick_nutrition_sections.dart:229-231` |
| Feeding labels | partly built: `pre_workout_feeding_labels.dart` (`preWorkoutFeedingTitle` — **Pre-Run / Pre-Ride / Pre-Workout by sport**; `preWorkoutWindowLabel`) | **Conflict with FC-1:** the ratified MEAL title is "Pre-Run Meal" *always*; the code varies it by sport. Either the design spec is silently run-specific (raise via intake) or the sport variant is retired. Flag, don't decide. |
| Display rounding | built for ml/g: `pre_workout_display_rounding.dart` (`round25/floor25/ceil25/round5/roundFluidBand/roundCarbBand`) | **R-01 (fl oz) and M-5 (whole grams) are NOT implemented** — the existing helpers encode notes §6's 25 ml / 5 g rules. This is the I11 conflict in code form |
| Goldens / design manifests | **none for pre-workout** (13 PNGs, all macro-dashboard/daily-macros/meal-logging); `docs/ssot/conformance/design/` holds only the macro-dashboard manifests; `docs/ssot/spec/design/components/` has only `workout-card.md`, `energy-card.md` | mirror re-sync must bring `pre-workout-before-card.{goldens,gestures}.yaml` + the three component specs + surface + `renderings/pre-workout@v2.html` |
| Design-system components already exist | `FuelItem`, `FuelStep`, `PhaseCard`, `MacroStat`, `HeroNumber`, `StackedBar` in `ds-bundle/` (`_ds_sync.json` renderHashes) | port onto these; `/design-sync` (source-authority §3.5–3.7) is the fidelity loop |

### 5.2 Tests pinning superseded behaviour / harness state

1. **QA-repo harnesses are the broken half** (intake `2026-08-25-hydration-slice-stale-v1.md` confirmed):
   `qa/conformance/pre_workout_hydration_conformance_test.dart` and `..._sodium_...` reference the
   retired `out.tier` and use `int` helpers against `double?`/`int?` fields → **do not compile**;
   `qa/conformance/pre_workout_carbs_conformance_test.dart` compiles but calls the **legacy**
   `calculatePreWorkoutTargets(weightKg:, hoursBefore:)`. `run_dart.sh` (which reads
   `$QA_ROOT/vectors/...`) therefore fails for all three slices. **The trustworthy copies are
   `$APP_ROOT/test/qa_conformance/*` — the land-bundle gate must run those, or the QA copies must be
   replaced by them (verbatim) before ship.** `docs/ssot/conformance/*` mirrors the broken QA copies.
2. **Legacy-map tests pin v1 numbers deliberately:** `test/features/nutrition_plan/data/offline_macro_calculator_pre_workout_legacy_map_test.dart`,
   `pre_workout_hydration_tier_test.dart`, `pre_workout_windows_test.dart`. They pin
   `calculatePreWorkoutTargets` (§6.3) — they stay green *correctly* until that map is retired; do not
   read their green as the card's contract.
3. **Widget tests that will go red by design when the old UI is replaced:**
   `test/features/nutrition_plan/presentation/widgets/before_phase_collapsed_chips_test.dart`,
   `pre_workout_feeding_labels_test.dart` (sport-varying titles — see FC-1 conflict),
   `test/seeded_tests/nutrition_plan_content_test.dart`. Replace deliberately, citing the design spec.
4. **Layering-plan row disagrees with the tiers:** `docs/test-layering-plan.md:36` asserts H5
   occasion bands at "≤ 30 / 30–90 / ≥ 90" min; ratified tiers are 30 / 120. Patrol
   `integration_test/flows/recommendation_stacking_flow_test.dart` (branch `qa/patrol-recommendation-h5-stacking`)
   should be checked for the 90-min boundary.
5. **`docs/test/README.md` does not list `test/qa_conformance/` or `test/contracts/`** — stale;
   both run in CI (`codemagic.yaml:57` runs all of `test/` minus `integration || e2e` tags).

### 5.3 Twin implementations & the second engine in the same file

- **Dart ⇄ TS twin:** `supabase/functions/generate-macros-v4/pre-workout.ts` (constants `:137-163`
  identical; pinned by `pre-workout-vectors.test.ts` loading `docs/ssot/vectors/fueling/`, tol 1e-3;
  `run-algorithm-tests.sh` `QUARANTINE=()` empty). Parity is enforced today — keep it: any vector
  regeneration must land in the mirror for **both** harnesses.
- **The LEGACY int map `calculatePreWorkoutTargets` (`offline_macro_calculator.dart:316-470`) is
  a live second pre-workout engine**: protein/fat/**water 6.5 / 5.5 ml/kg / 250 ml flat** and
  **sodium 300/450/600 (+100 hot) split meal/snack/top-up** with bands [200,2000]/[100,1000]/[0,400]
  — PW-012's number. `_computeOfflineMacros` (`macro_generation_service.dart:648-…`) reaches it on
  every edge-call failure, with **no UI marker that the offline engine produced the plan**. A
  BEFORE card that reads `sodium_mg` from the plan reads *this*. Rule for the coding agent: the
  card's sodium is Σ food rows (FC-5, sodium v3 inv. 4) — never the plan's `sodium_mg`; and the
  legacy map's `water_ml` must not feed the FLUIDS stat.
- **A second, silent derivation to EXTRACT, not copy:** `macro_explanation_service.explanations.dart:14-23`
  back-derives `hoursBeforeEst` from carbs/weight and branches at **2.5 h / 1.0 h** (v1
  thresholds); `fluid.dart:147,172-173` hard-codes 7.5 ml/kg and [5,12] narrative;
  `fluid.dart:82` infers the gate as `isTier3 && durationMin < 60 && tempC < 30` instead of reading
  `gateTriggered` (PW-013 note). The explanation layer must consume `tiers[]`/`regime`/`gateTriggered`
  from the engine result, not re-derive.

### 5.4 Deploy-coupled API surfaces & runtime coexistence with installed versions

- **Dual wire shapes are intentionally live (PW-013):** `macro_generation_service.dart:772-775`
  accepts `pre_run_hydration_regime` (string) **and** the retired `pre_run_hydration_tier` (int),
  parsed in `lib/features/nutrition_plan/domain/pre_run_macros_wire.dart`; the edge function still
  emits the retired tier (`ca28f04a` "keep emitting the retired hydration tier"). Do not collapse
  until every installed client reads `regime` — there is **no feature flag and no min-version bump
  tied to this** (the only gates are `app_config.min_app_version` / `current_schema_version`,
  `app_database.dart:281` `schemaVersion => 18`).
- **Edge functions the pre-workout path calls:** `generate-macros-v4` (`macro_generation_service.dart:541`,
  `brick_macro_service.dart:88`), `generate-nutrition-plan-v3` (food explosion for the BEFORE
  phase — `nutrition_plan_service.dart:395`). Wire keys read `:769-791`: `pre_run_water_{low,high}_ml`,
  `pre_run_hydration_regime`, `pre_run_{fluid,carb}_target_basis`, `pre_run_{fluid,carb}_tiers`,
  `pre_run_hydration_check_used`, `pre_run_selections`.
- **The `hydrationCheck` recompute has no wire path.** The answer must reach the engine twice
  (I2/I10): offline via `macro_repository.dart:173-178` (add the param) and server-side via
  `generate-macros-v4` (a request field does not exist yet). Either the recompute is client-only
  (offline engine — fine, the engine is the authority per the file header `:5-26`) or the request
  gains a field and both deploy together. **Decide and write it down before coding (I10).**
- **Schema:** no migration is needed for the engine outputs (they live in `activities.nutrition_plan_data`
  JSON), but **the hydration answer, added water row and stepper edits have no column or JSON key
  today** — the durability hole (I10) is also a schema task.

### 5.5 Adjacent call sites the rulings touch

- **Brick:** `brick_nutrition_sections.dart:229-231` embeds the same BEFORE widget; H10 says a brick
  has one shared Before. D-004a (brick fluids ml labelled oz) lives on the brick macro-summary. The
  new fuel-stat's oz conversion (R-01) must be applied once, at the component, so the brick path
  cannot re-label ml. Brick eligibility itself is the open `intake/2026-08-26-brick-eligibility-logic-ssot.md`.
- **Formula kit's "before card"** (`formula_kit/presentation/widgets/before_formula_card.dart`,
  `formula_library_screen.dart:527`) is a *different* surface — untouched; do not port the design
  family onto it by name-match.
- **Fueling-window stepper (D-016 / PW-011):** `fueling_window_clamp_test.dart` exists — verify the
  cap is 240 on all tabs and persisted 300–480 values clamp on load.
- **Explanation drawers** (`macro_explanation_service.*`) — §6.3; and `docs/ssot/PRE-WORKOUT-BUNDLE-DIGEST.md`
  §5 owns the display-rounding rules the Dart cites → superseded by R-01/M-5 once I11 is ruled.

### 5.6 Fate of existing UI / goldens

Replace `before_phase_widget.dart` + `macro_summary_row.dart` + `time_slot_row.dart` with the three
components + surface; the old widgets have **no goldens to retire**. `pre_workout_display_rounding.dart`
is superseded (oz + whole-gram rules) — retire, don't extend, once I11 is ruled. Bless 18 new goldens
from the manifest (`before_fine_print` deferred, S-G4).

### 5.7 Mirror & ledger

`docs/ssot/SSOT_SOURCE.txt` pins pre-workout at `pre-workout-food-composition@v1 @ fe31443b`,
branch `qa/pre-workout-drawers`. Verified 2026-08-26: vectors ×4 IDENTICAL; `pre-workout-carbs.md`,
`-sodium.md`, `-food-composition.md`, `.notes.md` IDENTICAL; **`pre-workout-hydration.md` and
`pre-workout.OPEN-QUESTIONS.md` DIFFER** (PW-021 fold not yet synced); design family absent. The
mirrored spec headers still say "code implements v1" — that is the *QA* text being stale (the
engine is v2/v6/v3): **fix in qa, then re-sync; never app-side** (VERBATIM policy). Re-pin
`SSOT_SOURCE.txt` to the new bundle tag at handback.

### 5.8 Producer / consumer inventory — every domain field the BEFORE card reads

| Field | Producers (shape actually written) | Consumers today & how each resolves it | This surface's rule | Finding |
|---|---|---|---|---|
| `bodyWeightKg` | profile lb→kg (`daily_macro_service.dart:164-172`, factor `0.453592`; `macro_repository.dart:169` inline `0.45359237`); persisted `weight_kg` **deliberately null when unknown** (`daily_macro_targets_repository.dart:219`) | engine (required); `dashboard_assembler.dart:60-71` **absent ⇒ absent number** (the 2026-08-20 ruling); **`macro_generation_service.dart:652` `?? 70.0` (offline plan path)**; `athlete_detail_controller.dart:281` hardcoded 70; `nutrition_targets_help_bottom_sheet.dart:260` 70 | absent weight ⇒ no plan numbers, loudly (macro-dashboard I7 precedent) | **DEFECT-CLASS: `?? 70.0` at `:652` is the same bug fixed on the dashboard, unfixed on the plan path** — every offline plan for a weight-less athlete is a 70-kg plan. Two lb→kg factors coexist |
| `timeBeforeWorkoutMin` | `activities.time_before_minutes` (`activity_mapper.dart:119/459/534`); stepper 0–**480** (D-016) | engine (frozen at generation `:1413-1416`); wire as `hours_before` (`:284`) and `time_before_min` (`:365/444`); **`?? 2.0` h fallback `:653-654`**; explanation layer back-derives it (§6.3) | the ONE field both specs read; grid 0–240 | 480 cap (PW-011); a silent 2 h default; one field, three wire spellings |
| `workoutDurationMin` | imports (`final_surge_transformer.dart:362-394` `PlannedTime` then `ActualTime`, clamp 1–1440), `vdot_transformer.dart:77-81`, manual entry | engine gate (`< 60`) and cited-window (`>= 60`) legs | as spec | `< 60 AND tempC < 30` gates 29 % of prod plans — PW-003 ruling request pending |
| `tempC` | weather (`get-weather-forecast`) or null → engine default 22; `activities.swimming_water_temp_c` recorded and **unused** | engine gate only | as spec | which temperature for swims (intake adjacent item) |
| `isFasted` | fasted toggle (`fasted_toggle.dart`; swimming forces off) | engine short-circuit (D-001, characterization) | FC-4 fasted card | unratified (D-001) |
| `gutTolerance` | profile | carbs input (composition only) | n/a on this card | — |
| `hydrationCheck` | **NOBODY** | engine default `unknown`; echo `pre_run_hydration_check_used` | hydration-check component writes it | **greenfield producer; no column (I10)** |
| plan output (`tiers[]`, bands, `regime`, `gateTriggered`, `targetBasis`) | engine → `nutrition_plan_data` JSON via wire keys (§6.4) | `pre_run_macros_wire.dart`; **`macro_repository.dart:210` `fluidsMl: preHydration.fluidMl ?? 0`** — the gate's `null` collapses to `0` at the domain boundary; only `hydrationRegime`/`isHydrationGated` distinguish | fuel-stat F-1: gate ≠ 0 | **DEFECT-CLASS: any fuel-stat reading `fluidsMl` alone renders "0 oz" for a gated plan (the coach-complaint class)** |
| sport | activity type | `pre_workout_feeding_labels.dart:25-42` (title by sport) | FC-1: "Pre-Run Meal" always | conflict, see §6.1 |
| food rows (name, carbs, sodium, step/cap) | `generate-nutrition-plan-v3` explosion + `pre-workout-scoring.ts`; catalog has **no fibre field** (food-composition bundle note) | old BEFORE widget | FC-5 observation; Σ = delivered | composition gates unenforceable without fibre (sibling bundle) |
| sweat rate / sodium concentration / IF / timezone | various (`settings_controller.dart`, `user_preferences.dart`) | during-workout only; legacy map reads `sweatSodiumCat` for its sodium | **not inputs** to this card | confirm the card never reads them |
| user edits (stepper, add row), added water row, answer | **NOBODY** | — | FC-G2 / FC-7 / H-2 | **no column, no key — I10** |

### 5.9 Conflict watchlist (mandatory handoff section — carry verbatim into `ship-bundle`)

1. **Engine: verify, don't rebuild.** 74/74 in `test/qa_conformance/` on 2026-08-26. Add `hydrationCheck` to `macro_repository.dart:173-178`; nothing else in the engine changes.
2. **Fix the two boundary collapses before any UI reads them:** `macro_repository.dart:210` (`fluidMl ?? 0`) and `macro_generation_service.dart:652` (`?? 70.0`). Both are the class the dashboard already fixed.
3. **Never read `sodium_mg` / `water_ml` from the legacy map into the card.** Sodium = Σ rows; fluid = v6 `fluidMl`.
4. **FC-1 title vs sport-varying titles** — raise via intake if the run-only title is not intended.
5. **Rounding:** implement R-01 (oz) + M-5 (whole g); retire `pre_workout_display_rounding.dart`; **I11 (notes §6 5 g vs M-5 1 g) must be ruled first.**
6. **Check × gated plan (I5) and persistence (I10) must be ruled/written before the hydration-check write path is coded.**
7. **Do not collapse the dual wire shapes** (PW-013) without a coordinated deploy.
8. **Replace the QA-repo conformance harnesses with the app's `test/qa_conformance/*` (verbatim) or point `run_dart.sh` at them** — otherwise land-bundle's gate cannot run.
9. **Old widget tests go red by design** (§6.2 item 3) — replace citing the design spec; regenerate nothing (no goldens exist); bless 17 (18 − deferred).
10. **Mirror:** re-sync hydration spec + OPEN-QUESTIONS (PW-021), the design family, both manifests; fix the "code implements v1" headers in qa first.


## 6. Done

Verbatim from the manifest's `done_when`: the three math slices stay green (74 tests, plus
hydrationCheck threaded through macro_repository so all three check values reach the engine); every
artifact in both design manifests exists and passes in CI — 17 goldens blessed from the first correct
rendering (before_fine_print deferred), 17 gesture tests plus h_suppressed_when_gated,
s_fine_print_absent, fc_stepper_clamp and the oz-conversion golden (487.5 ml → 16 oz, 756 ml →
26 oz); the BEFORE card reads fluid from v6 fluidMl (null renders "No fluid target", never 0 oz) and
sodium as the sum of food rows (never the legacy map); the two boundary collapses
(macro_repository.dart:210 fluidMl ?? 0, macro_generation_service.dart:652 weight ?? 70.0) are fixed
with tests; the fueling-window cap is 240 with clamp-on-load (D-016); the old before_phase_widget and
its rounding helpers are retired; the docs/ssot mirror is re-synced to this tag; feature test plan
rows flip.
