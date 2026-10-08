# 44: Onboarding Your daily plan applies the session protein bump

**Status:** ready (round develop-2026-10, fix wave 4)
**Labels:** fix, round:develop-2026-10, area:onboarding, area:nutrition
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** 40 (runs first, alone). Nothing else.
**Next:** `/testing-wave develop-2026-10` (fix wave 4)
**Model:** opus

**What to build:** The onboarding preview's Workout day gives protein at the baseline 1.4 g/kg. The ratified rule adds a session bump: 0.2 × weight for an endurance session over 1.0 hr, 0.3 × weight for strength, max across sessions, never a sum (`docs/ssot/spec/daily-macros/session-demand.md:142-154`, "Protein bump from today's sessions (Iteration 1, assembly step 3d)"). The deployed engine applies it, and the Dart twin the preview runs on does not have it. Line numbers are from code at `d7650d15`.

1. **Where production applies it.** `calculate-daily-macros-v6/pipeline.ts:296-327` (STEP 4). One session: `prot_bump = strength ? 0.3 × weight_kg : duration_hr > 1.0 ? 0.2 × weight_kg : 0` (`:307-319`). Two or more: `multiSessionCarbCompound` (`formulas/safety.ts:~140-192`), whose loop takes `max_prot_bump` the same way (`:176-181`) and returns it unrounded. Then `prot += prot_bump` (`:327`), before recovery debt, weekly load, phase modifiers and the step-9 clamp (`:366-371`).
2. **Where the preview leaves it out.** `PlanPreviewService.buildPreview` (`lib/features/onboarding/application/plan_preview_service.dart:45-219`) builds one representative workout session: sport `sessionSport` (`:143-147`), length `sessionMinutes` (`:148-154`), which is `defaultLongRunMinutes = 150` / `defaultLongRideMinutes = 180` (`:34-35`) or the athlete's reliable longest session. It adds the session's carbs (`:167-172`, `:176`) but passes `protG: baseline.protG` for the workout day (`:177`), the same as rest (`:187`) and carb-load (`:200`). The calculator it uses, `DailyBaselineCalculator` (`lib/features/nutrition_plan/application/daily_baseline_calculator.dart`), mirrors F1, F2, the clamps, F3, F4, F5, F15 and step 10b, but has no protein bump (`grep -n bump` finds nothing).
3. **Add the twin to the calculator.** In `DailyBaselineCalculator`, next to `carbDemand` (`:291-306`), add `static double proteinBump({required List<({String sport, double durationHr})> sessions, required double weightKg})`. Follow the spec's pseudo-code exactly: strength → `0.3 × weightKg` at any duration; any other sport with `durationHr > 1.0` (strict) → `0.2 × weightKg`; max across sessions; unrounded. Rounding happens once, at display (`plan_preview_service.dart` `_dayPreview`, `proteinG = clamped.protG.round()`), as R1 asks. Doc comment cites `session-demand.md` §Protein bump and `pipeline.ts:307-319`.
4. **The preview uses it for the workout day only.** At `plan_preview_service.dart:177`, pass `protG: baseline.protG + DailyBaselineCalculator.proteinBump(sessions: [(sport: sessionSport, durationHr: sessionHr)], weightKg: weightKg)`. Rest and carb-load days have no session, so no bump, which matches the server. The existing clamp in `_dayPreview` (`:262-266`, max 2.5 g/kg) then runs after the bump, as STEP 9 does on the server. A reliable import whose longest session is 60 minutes or less gets no bump, which is right under the strict `> 1.0 hr` rule. The carbs move a little via the step-10b fat cap (Finding 30-004: B's workout carbs about 563 g instead of 576 g). Nothing else changes.

**Findings:** 30-004 (ssot-conflict).

**Decisions:**
- Lee, 2026-10-08 (TRIAGE): fix ticket 44.
- The decision the Finding cites: `session-demand.md` §Protein bump, quote "Strength qualifies on sport alone, at any duration. The endurance trigger is strictly `> 1.0 hr`." The spec README (`docs/ssot/spec/daily-macros/README.md:20-22`) adds Xuan's ruling of 2026-08-17: the preview and the deployed engine must ship the same formula generation, or a new athlete sees a preview that disagrees with the plan after onboarding.
- The parity fixture is not regenerated. `test/features/onboarding/fixtures/plan_preview_parity.json` is generated from exported TS formulas ("regenerate, never hand-patch"). The single-session bump is inline in `pipeline.ts`, with no exported formula to generate from. The vector file already pins it (below), so the Dart twin is held to the vector, not to a new fixture section.
- Spec wording owed, not by this ticket: the README's list of what the Dart mirror covers (`README.md:13-16`) does not name the protein bump. `docs/ssot/` syncs from the QA repo, which is hands-off, so the lead raises it through `/ssot` (review queue), not by editing here.
- Not in this ticket: the hydration conditions the preview uses (30-016, review queue PREVIEW-HYDRATION-001).

**Touches:** lib/features/nutrition_plan/application/daily_baseline_calculator.dart, lib/features/onboarding/application/plan_preview_service.dart, test/features/onboarding/daily_baseline_calculator_test.dart, test/features/onboarding/plan_preview_service_test.dart. 4 files. No generated files: both classes are static, with no annotations.

**Overlaps:** none in wave 4. 42 edits `onboarding_draft.dart` and `onboarding_controller.dart`; this ticket only reads the draft through `PlanPreviewService`. 43 edits onboarding widgets, not `application/`. No other wave-4 ticket touches `nutrition_plan/application/`.

No edge-function or schema change. Nothing to deploy. The server already applies the bump.

- [ ] Vector-backed test (`daily_baseline_calculator_test.dart`): a new group that loads `docs/ssot/vectors/daily-macros/session-demand.json` (as the existing "session-demand kcal vectors" group does at `:359-397`) and runs every row whose `expected` has `protBumpG` through `proteinBump`. Today that is `protbump-max-not-sum`: 75 kg, strength 1.0 h plus running 1.5 h → 22.5 g. Read the file's tolerance as the existing group does. This is the same row `calculate-daily-macros-v6/vectors.conformance.test.ts:231-241` runs on the TS side, so the twins are held to one vector.
- [ ] Spec boundary units (hand values from the spec's pseudo-code, not from the calculator): running 1.0 h exactly → 0 (strict `>`); running 1.01 h at 62 kg → 12.4; strength 0.5 h at 62 kg → 18.6; no sessions → 0.
- [ ] Preview test (`plan_preview_service_test.dart`), producer-shaped. The draft is account B's onboarding answers as the app stores them (Running + Cycling, Female, born 1994, 173 cm, 62 kg entered metric, gut High, sweat Heavy; read `onboarding_draft.dart` for how metric input is stored), and no training insights. Expected numbers are by hand from the spec, not from the calculator: workout protein `round(62 × 1.4 + 0.2 × 62) = 99` g (1.6 g/kg), and rest and carb-load protein stay 87 g. Calories stay 4/4/9-consistent (the existing assertion at `:131`). A reliable import whose longest run is 45 minutes gives workout protein equal to rest.
- [ ] `flutter analyze` clean on touched files; run `test/features/onboarding/`.
- [ ] Retest on device: wave 5 retest ticket 50 (it lists 44 in its Blocked-by). Account B's answers through to Your daily plan → Workout day shows 99 g / 1.6 g/kg protein and rest shows 87 g.

Next: /testing-wave develop-2026-10 (fix wave 4)
