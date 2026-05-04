> Mirrored from Notion: https://www.notion.so/daily_macro_calc_iteration1_tests-326e3fdb754c809e938bdf688be8c400
> Last edited (Notion): 2026-03-17T16:52:00.000Z
> **Authoritative source is Notion.** Edit there and re-mirror.

# Macro Calculator — Iteration 1 Test Cases

Run these against the implementation. Do not modify the implementation to match expected values — if a test fails, debug the formula logic.

Reference athlete: Male, 34yr, 75kg, 178cm, body_fat 14.7% → LBM 64kg.
Tolerances: carb/prot ±5%, fat ±15%, TDEE ±5%, IF ±0.005.

---

## RMR

| Input | Expected |
| --- | --- |
| Male, 75kg, 178cm, 34yr, BF 14.7% (LBM=64) | 1908 |
| Male, 75kg, 178cm, 34yr, no BF | 1698 |
| Female, 62kg, 165cm, 29yr, no BF | 1345 |
| Male, 75kg, 178cm, 34yr, BF 14.7% | 1908 (Cunningham must take priority) |

## Zone Distribution → IF

| Conv / Tempo / AllOut | Expected IF |
| --- | --- |
| 100 / 0 / 0 | 0.680 |
| 0 / 100 / 0 | 0.880 |
| 0 / 0 / 100 | 1.080 |
| 70 / 20 / 10 | 0.771 |
| 30 / 40 / 30 | 0.894 |
| 50 / 0 / 50 | 0.902 |
| 70 / 20 / 20 (sum=1.1) | REJECT — input validation must fail |

## Session Cost (75 kg)

| Sport, Duration, IF | Expected kcal |
| --- | --- |
| running, 1.5hr, 0.74 | 1205 |
| cycling, 1.25hr, 0.93 | 1297 |
| cycling, 4.0hr, 0.72 | 2488 |
| strength, 1.0hr, 0.70 | 350 |
| running, 0.75hr, 0.65 | 465 |

## Session Cost — Weight Scaling

Output must scale linearly with weight. Ratio column must hold exactly.

| Sport, Duration, IF, Weight | Expected kcal | Ratio to 75kg |
| --- | --- | --- |
| running, 1.5hr, 0.74, 60kg | 964 | 0.800 |
| running, 1.5hr, 0.74, 75kg | 1205 | 1.000 |
| running, 1.5hr, 0.74, 90kg | 1446 | 1.200 |

## Carb Demand (75 kg)

| IF, Duration | Raw (g) | After 1.15× | Multiplier applied? |
| --- | --- | --- | --- |
| 0.65, 0.75hr | 26 | 26 | No (IF<0.85 AND dur≤1.5) |
| 0.74, 1.5hr | 69 | 69 | No (IF<0.85 AND dur=1.5, not >1.5) |
| 0.88, 2.0hr | 142 | 163 | Yes (IF>0.85) |
| 0.93, 1.25hr | 101 | 116 | Yes (IF>0.85) |
| 0.72, 4.0hr | 172 | 198 | Yes (dur>1.5) |

## Carb Demand — Weight Scaling

| IF, Duration, Weight | Expected (g) |
| --- | --- |
| 0.74, 1.5hr, 60kg | 55 |
| 0.74, 1.5hr, 75kg | 69 |
| 0.74, 1.5hr, 90kg | 83 |
| 0.88, 2.0hr, 60kg (with 1.15×) | 131 |
| 0.88, 2.0hr, 90kg (with 1.15×) | 196 |

## Full Day — Integration Tests (Reference Athlete: 75kg, LBM 64, RMR 1908)

| Session | Carb | Prot | Fat | TDEE |
| --- | --- | --- | --- | --- |
| None (rest day) | 300 | 115 | 80 | 2385 |
| run 1.5hr IF 0.74 | 369 | 130 | 177 | 3590 |
| bike 4.0hr IF 0.72 | 498 | 130 | 262 | 4873 |
| strength 1.0hr IF 0.70 | 340 | 138 | 92 | 2735 |
| bike 1.25hr IF 0.93 | 416 | 130 | 166 | 3682 |

## Edge Cases

| Test | Expected Behavior |
| --- | --- |
| No sessions (empty array) | Returns baseline macros + rest-day TDEE |
| Two sessions: strength 1hr + run 1.5hr | Protein bump = max(22.5, 15) = 22.5g (override, not sum) |
| Session with IF that would push carb above 12g/kg | Carb clamped to 900g (12×75) |
| Age = 45, no BF% | Protein = 1.4 × 75 × 1.15 = 121g (masters multiplier applies) |
| Age = 44 | Protein = 1.4 × 75 = 105g (no masters multiplier) |
| Body fat = 0% (edge) | LBM = weight. Cunningham = 500 + 22×75 = 2150. Should work. |
| Zone distribution = 0/0/0 | REJECT — does not sum to 1.0 |
