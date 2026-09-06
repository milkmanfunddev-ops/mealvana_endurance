# APP-SIDE HANDBACK — pre-workout plan band = target ± 12.5 %

Source ruling: `intake/2026-09-04-pre-workout-carb-band-ruling.md` (RESOLVED).
QA commit: **`d264895`** — "apply-ruling: pre-workout plan band is target ±12.5% in all cases".
Engines need **NO change**: the app already implements this (`3cf3ee42`, both twins,
dev-deployed). Everything below is test/artifact catch-up.

## 0 · Re-sync the mirror FIRST — nothing below passes without it

- [ ] Re-sync `docs/ssot` as a **verbatim mirror** of qa `d264895` (at minimum
      `spec/fueling/pre-workout-carbs.md` + `vectors/fueling/pre-workout-carbs.json`), and
      update `docs/ssot/SSOT_SOURCE.txt`'s commit pin.
      **QA deliberately did NOT hand-copy these two files**: a partial mirror with a stale
      `SSOT_SOURCE.txt` pin is worse than an unsynced one. Do the whole sync, move the pin.

## 1 · The ratified wording to cite in every commit message below

> **The plan band is `target ± 12.5 %` (TIER_TOL) in all cases.** The v2 clause publishing
> Thomas's `[1·BW, 4·BW]` as the in-window band is SUPERSEDED. The **target** is unchanged
> (`min(t/60, 4.0) × BW`), and so is `targetBasis` — it describes the TARGET's derivation,
> never the band.
> — `spec/fueling/pre-workout-carbs.md`, "The plan band — RULED (Xuan, 2026-09-04,
> post-ratification amendment)"; invariants 11 (amended) and 12 (new).

## 2 · Measured state with the new vectors in place (QA ran these)

| suite | result |
|---|---|
| `deno test supabase/functions/generate-macros-v4/pre-workout-vectors.test.ts` | **all 12 vector steps PASS** (3 passed / 50 steps); 1 failure left = the cross-slice pin below |
| `flutter test test/qa_conformance/pre_workout_carbs_conformance_test.dart` | **29/30**; all 12 vector rows PASS; 1 failure left = the property branch below |

So the vectors are already green against the unchanged engines — exactly as the ruling predicted.

## 3 · The superseded assertions — exact locations and replacements

**(a) TS cross-slice pin** — `supabase/functions/generate-macros-v4/pre-workout-vectors.test.ts:422`,
test *"the two carb bands are deliberately different objects"*. They now **deliberately coincide**.
Retire or invert it. Invariant 12 says so explicitly, cite it.

**(b) Dart property branch** — `test/qa_conformance/pre_workout_carbs_conformance_test.dart:552–563`.
Delete the `else` (cited-regime) branch asserting `carbsLowG == 1.0*bw` / `carbsHighG == 4.0*bw`
and let the `design_choice` sum-check body run for **every** row — the sum identity is now
unconditional. Rename the test: it is no longer "in design_choice they sum to the plan band".

**(c) Dart unit pins** — `test/features/nutrition_plan/data/offline_macro_calculator_pre_workout_carbs_test.dart`

| line | test | change |
|---|---|---|
| 601–607 | *"dur = 60 at t = 180 flips to evidenced_band [1, 4] g/kg"* | `carbsLowG` 65 → **170.625**; `carbsHighG` 260 → **219.375**. Drop "[1, 4] g/kg" from the name — the flip now moves only `targetBasis`, not the band. |
| 637–642 | *"binds at t = 240 for 65 kg — 260 g, sitting ON the band ceiling"* | `carbsHighG` 260 → **292.50**. The name is now WRONG: 260 sits at the band's **centre**, not its ceiling. Rename. |
| 644–649 | *"is per-kg, not an absolute gram ceiling (100 kg -> 400 g)"* | `carbsHighG` 400 → **450.0**. `carbsG` 400 is unchanged and still the point of the test. |

The neighbouring `dur = 59` case (line 597, `170.625/219.375`) is **already correct** — it was the
design_choice row all along. Leave it.

**(d) Strengthening now unlocked** — `..._pre_workout_carbs_test.dart:~845`, test
*"11: tier windows are +/-12.5 % and sum to the design_choice plan band"* pins `dur = 30` to stay
inside design_choice, because the sum only held there. That restriction is obsolete: drop `dur = 30`
and the regime word from the name, and it covers the whole grid.

## 4 · Band-derived goldens (~6)

- [ ] Regenerate the before-card / hydration goldens and feeding-membership scenarios that render
      band values. **The commit message must cite the spec amendment** (goldens-regeneration rule) —
      a golden update is a ratification act, and this ruling is its authority.

## 5 · Close-out

- [ ] Flip the matching rows in `docs/feature-test-plans/pre-workout-before-card.md` (⬜ → ✅ with
      the test file).
- [ ] Report the new green counts for both suites.
- [ ] Cross-update `ops/data/bug-reports/2026-09-04-trunk-red-band-change-blocks-release-cut.md` —
      once these land, the red set no longer blocks the §8 P1–P3 gates, and the
      food-recommendation@v1.1 prod cut no longer needs to go from `18189b7b`.

## 6 · Deferred, do NOT act on

**PW-022** — `targetBasis`'s NAME. The value `evidenced_band` no longer predicts the band's shape.
Renaming it is a published wire field on two engines = impact class (c), needs its own bundle.
QA recommends keeping the name. Registered in `spec/fueling/pre-workout.OPEN-QUESTIONS.md`.
