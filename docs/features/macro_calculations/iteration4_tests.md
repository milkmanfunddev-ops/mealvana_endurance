> Mirrored from Notion: https://www.notion.so/daily_macro_calc_iteration4_tests-326e3fdb754c805a8956ede41fca6ffc
> Last edited (Notion): 2026-03-17T20:59:00.000Z
> **Authoritative source is Notion.** Edit there and re-mirror.

# Macro Calculator — Iteration 4 Test Cases

Run these against the implementation. All Iteration 1–3 tests must also still pass with carb_cycle_opt_in=false (regression).

Reference athlete: Male, 34yr, 75kg, 178cm, BF 14.7% → LBM 64kg, FFM 64kg, RMR 1908. Serious tier, DESK lifestyle.
Tolerances: carb/prot ±5%, fat ±15%, TDEE ±5%, EA ±1.0.

---

## EA Calculation

EA boundaries use ≥ (not >). EA = 45.0 is OK. EA = 30.0 is SOFT_WARNING. EA = 20.0 is HARD_WARNING.

| Intake (kcal) | Session (kcal) | FFM (kg) | Expected EA | Expected Status |
| --- | --- | --- | --- | --- |
| 4368 | 1479 | 64 | 45.1 | OK |
| 3500 | 1000 | 64 | 39.1 | SOFT_WARNING |
| 2500 | 800 | 64 | 26.6 | HARD_WARNING |
| 1800 | 900 | 64 | 14.1 | BLOCK |
| 1500 | 0 | 64 | 23.4 | HARD_WARNING |
| 3780 | 900 | 64 | 45.0 | OK (boundary) |
| 2720 | 800 | 64 | 30.0 | SOFT_WARNING (boundary) |
| 2180 | 900 | 64 | 20.0 | HARD_WARNING (boundary) |

## EA Override

| Carb / Prot / Fat | Session kcal | EA Before | Expected After |
| --- | --- | --- | --- |
| 250 / 115 / 60 | 208 | 28.0 | carb=269, fat=66. Deficit=128 kcal split 60/40. New EA=30.0 |
| 200 / 100 / 55 | 543 | 18.0 | BLOCK. Plan not generated. |
| 500 / 140 / 120 | 300 | 46.3 | No change (EA ≥ 45) |
| 400 / 130 / 90 | 200 | 40.3 | No change (EA ≥ 30, only soft warning) |

## Multi-Session Carb Compounding (75 kg)

Compounding: endurance sessions only. 1st = ×1.0, 2nd = ×1.1, 3rd = ×1.21. Strength always ×1.0.

| Sessions (time order) | Compounding Applied | Expected Session Carb | Prot Bump |
| --- | --- | --- | --- |
| bike 2hr IF 0.80, run 0.75hr IF 0.78 | bike ×1.0 + run ×1.1 | bike=126g + run=43g = 169g | 15g (bike dur>1hr) |
| swim 0.5hr IF 0.70, bike 2hr IF 0.80, run 1hr IF 0.78 | ×1.0 + ×1.1 + ×1.21 | swim=20g + bike=139g + run=63g = 222g | 15g (bike dur>1hr) |
| strength 1hr IF 0.70, run 1.5hr IF 0.74 | strength ×1.0 (no compound), run ×1.0 (1st endurance) | strength=27g + run=69g = 96g | 22.5g (strength) |
| Single: run 1.5hr IF 0.74 | n/a (single session) | 69g (same as Iter 1) | 15g |

## Carb Cycling

ALL four conditions must be true. Reference baseline carb = 300g (4.0 × 75). Carb cycle reduces baseline to 225g (3.0 × 75).

| IF | Duration | opt_in | Phase | Expected Carb Baseline |
| --- | --- | --- | --- | --- |
| 0.65 | 0.75hr | true | BASE | 225g (train-low) |
| 0.85 | 0.75hr | true | BASE | 300g (IF > 0.80) |
| 0.70 | 1.5hr | true | BASE | 300g (dur > 1.25hr) |
| 0.70 | 1.25hr | true | BASE | 225g (at boundary, ≤ 1.25) |
| 0.70 | 1.267hr | true | BASE | 300g (just over 75min) |
| 0.80 | 0.75hr | true | BASE | 225g (at boundary, ≤ 0.80) |
| 0.81 | 0.75hr | true | BASE | 300g (just over IF boundary) |
| 0.65 | 0.75hr | true | PEAK | 300g (disabled in PEAK) |
| 0.65 | 0.75hr | true | RACE_WEEK | 300g (disabled in RACE_WEEK) |
| 0.65 | 0.75hr | false | BASE | 300g (not opted in) |
| both easy | both short | true | BASE | 300g (multi-session never qualifies) |
| 0.65 | 0.75hr | true | OFF_SEASON | 225g (allowed) |
| 0.65 | 0.75hr | true | BUILD | 225g (allowed) |
| 0.65 | 0.75hr | true | TAPER | 225g (allowed) |

## Masters Protein (Regression)

Masters adjustment (age ≥ 45, ×1.15) was in Iteration 1's baselineMacros. Verify in full v4 pipeline.

| Age | LBM | Base Prot | After 1.15× |
| --- | --- | --- | --- |
| 34 | 64 kg | 115g (1.8×64) | 115g (no change) |
| 45 | 64 kg | 115g (1.8×64) | 132g |
| 34 | null | 105g (1.4×75) | 105g (no change) |
| 45 | null | 105g (1.4×75) | 121g |
| 60 | 64 kg | 115g | 132g |
| 44 (boundary) | 64 kg | 115g | 115g (no change) |

## Full Pipeline Integration

| Scenario | Expected |
| --- | --- |
| Normal day (Scenario 2: 90-min run) | Macros same as Iter 3. EA ≈ 39+. ea_status = SOFT_WARNING. |
| Carb cycling easy day (45min Z1, opt_in=true, BASE) | Carb baseline reduced to 225g. Session carb added on top. |
| Brick with compounding (bike 2hr + run 45min) | Carb higher than naive sum by ~4g from run ×1.1. |
| EA override fires (extreme restriction) | EA forced to 30. carb and fat adjusted upward. ea_status = HARD_WARNING. |
| EA block (very low intake, high exercise) | Plan not generated. Error returned. ea_status = BLOCK. |

## Edge Cases

| Test | Expected |
| --- | --- |
| No sessions + carb_cycle_opt_in=true | No session to evaluate → cycling does not fire. Baseline = 300g. |
| FFM from estimate: male 75kg, no BF% | FFM = 75 × 0.85 = 63.75 kg |
| FFM from estimate: female 62kg, no BF% | FFM = 62 × 0.78 = 48.36 kg |
| 5 endurance sessions | Factors: 1.0, 1.1, 1.21, 1.331, 1.464. Total capped at 12 × weight. |
| EA override with carb at ceiling (900g) | Cannot add more carb. Override adds to fat only. |
| Carb cycle + recovery debt same day | Cycle reduces baseline, then debt adds on top. Both apply. |
| All Iter 1–3 outputs unchanged | With carb_cycle_opt_in=false and single sessions, output identical to Iter 3. |
