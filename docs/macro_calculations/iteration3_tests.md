> Mirrored from Notion: https://www.notion.so/daily_macro_calc_iteration3_tests-326e3fdb754c80298207c0fbe7eebcaa
> Last edited (Notion): 2026-03-17T17:25:00.000Z
> **Authoritative source is Notion.** Edit there and re-mirror.

# Macro Calculator — Iteration 3 Test Cases

Run these against the implementation. All Iteration 1–2 tests must also still pass (regression).

Reference athlete: Male, 34yr, 75kg, 178cm, BF 14.7% → LBM 64kg, RMR 1908. Serious tier (10 hrs/week), DESK lifestyle.
Tolerances: carb/prot ±5%, fat ±15%, TDEE ±5%, NEAT ±5%.

---

## Volume Tier Inference

| Weekly Hours | Expected Tier | Expected base_neat |
| --- | --- | --- |
| 3 | RECREATIONAL | 0.30 |
| 6 | MODERATE | 0.25 |
| 10 | SERIOUS | 0.20 |
| 15 | HIGH_VOLUME | 0.17 |
| 20 | PROFESSIONAL | 0.13 |
| null | MODERATE (default) | 0.25 |
| 4.9 (just below 5) | RECREATIONAL | 0.30 |
| 5.0 (boundary) | MODERATE | 0.25 |
| 8.0 (boundary) | SERIOUS | 0.20 |
| 12.0 (boundary) | HIGH_VOLUME | 0.17 |
| 18.0 (boundary) | PROFESSIONAL | 0.13 |

## Day Type Classification

Evaluation order: DOUBLE → TRAINING → REST_AFTER_HARD → REST.

| Today's Sessions | Yesterday TSS | Expected Day Type | Modifier |
| --- | --- | --- | --- |
| None | 50 | REST | 1.00 |
| None | 180 | REST_AFTER_HARD | 0.90 |
| 1 session, 1.5hr | any | TRAINING | 1.10 |
| 2 sessions | any | DOUBLE | 1.15 |
| 1 session, 0.5hr (below 0.75hr) | 50 | REST | 1.00 |
| 1 session, exactly 0.75hr | 50 | TRAINING | 1.10 |
| None | null | REST | 1.00 |

## NEAT Calculation (RMR = 1908)

| Tier / Day Type / Lifestyle | Expected neat_factor | Expected NEAT |
| --- | --- | --- |
| 0.20 × 1.00 × 0.90 (Serious, rest, desk) | 0.180 | 343 kcal |
| 0.20 × 1.10 × 0.90 (Serious, training, desk) | 0.198 | 378 kcal |
| 0.20 × 0.90 × 0.90 (Serious, rest after hard, desk) | 0.162 | 309 kcal |
| 0.30 × 1.00 × 1.15 (Recreational, rest, active) | 0.345 | 658 kcal |
| 0.13 × 1.15 × 1.00 (Pro, double, mixed) | 0.149 | 285 kcal |
| 0.20 × 1.00 × 1.00 (Serious, rest, mixed default) | 0.200 | 382 kcal |

## TEF Iteration & TDEE (Reference Athlete, Serious, Desk)

Carb and protein are inputs from Steps 1–7 (unchanged from Iter 2).

For each scenario, verify: (a) the loop converges (exits before max_passes), (b) final delta < 10 kcal, (c) TDEE and fat match expected values.

| Scenario | Carb/Prot/Session kcal | NEAT | Expected Passes | Final TEF | Final TDEE | Final Fat |
| --- | --- | --- | --- | --- | --- | --- |
| Rest day | 300 / 115 / 0 | 343 | 3 | 250 | 2501 | 93g |
| 90-min run | 369 / 130 / 1205 | 378 | 3 | 388 | 3879 | 209g |
| Rest after long ride | 394 / 123 / 0 | 309 | 2 | 261 | 2478 | 60g (floor) |
| Pre-race all layers | 798 / 159 / 1050 | 378 | 2 | 437 | 3773 | 60g (floor) |

Convergence detail for "Rest day" (non-floor case):
- Pass 1: tef=0→new_tef=225, delta=225 (>10, continue)
- Pass 2: tef=225→new_tef=248, delta=23 (>10, continue)
- Pass 3: tef=248→new_tef=250, delta=2 (<10, STOP)

Convergence detail for "Rest after long ride" (fat at floor):
- Pass 1: tef=0→new_tef=261, delta=261 (>10, continue)
- Pass 2: tef=261→new_tef=261, delta=0 (<10, STOP)
- Fat is at floor, so intake is fixed → TEF stabilizes immediately on pass 2.

Key test: the loop must NOT be hardcoded to exactly 2 passes. It must actually check delta < 10 and break.

## v2 vs. v3 Regression

Carb and protein MUST be identical. Only TDEE and fat change.

| Scenario | v2 TDEE | v3 TDEE | Δ TDEE | v2 Fat | v3 Fat | Carb/Prot Changed? |
| --- | --- | --- | --- | --- | --- | --- |
| Rest day, desk | 2385 | 2501 | +116 | 81g | 93g | No |
| 90-min run, desk | 3590 | 3879 | +289 | 177g | 209g | No |
| Rest after hard, desk | 2385 | 2478 | +93 | 60g (floor) | 60g (floor) | No |
| Active-job rest day | 2385 | 2608 | +223 | 81g | 105g | No |

## Lifestyle Variation — Same Day, Different Lifestyle

Rest day, no sessions, Serious tier, RMR 1908. Only lifestyle differs.

| Lifestyle | NEAT | TDEE | Fat |
| --- | --- | --- | --- |
| DESK (0.90) | 343 | 2501 | 93g |
| MIXED (1.00) | 382 | 2544 | 98g |
| ACTIVE (1.15) | 439 | 2608 | 105g |
| VERY_ACTIVE (1.25) | 477 | 2650 | 110g |

## Mode Parameter

| Test | Expected |
| --- | --- |
| PROSPECTIVE with planned session | Normal calculation |
| RETROSPECTIVE with same inputs | Identical output to PROSPECTIVE |
| RETROSPECTIVE with adjusted duration (2hr instead of 1.5hr) | Recalculated: session_kcal, carb_demand, TDEE, fat all change |
| Output includes mode field | mode: PROSPECTIVE or RETROSPECTIVE in return object |

## Edge Cases

| Test | Expected |
| --- | --- |
| All new inputs null/default (lifestyle=null→MIXED, hours=null→MODERATE) | NEAT uses 0.25 × day_mod × 1.00. Still works. |
| typical_weekly_hours = 0 | RECREATIONAL tier (< 5). base_neat = 0.30. |
| Very high NEAT (recreational, double session, very active job) | 0.30 × 1.15 × 1.25 = 0.431. NEAT = 822 kcal. Valid, within range. |
| Very low NEAT (pro, rest after hard, desk) | 0.13 × 0.90 × 0.90 = 0.105. NEAT = 201 kcal. Valid, within range. |
| Carb/prot from Iter 1 rest-day test | Must still produce carb=300, prot=115 (TDEE/fat differ, macros don't) |
| Carb/prot from Iter 2 pre-race test | Must still produce carb≈798, prot≈159 (TDEE/fat differ, macros don't) |
| Output includes neat_kcal and tef_kcal fields | Verify fields exist and are numeric |
