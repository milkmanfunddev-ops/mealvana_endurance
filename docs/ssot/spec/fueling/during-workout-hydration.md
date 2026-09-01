# SSOT — During-Workout Hydration (single-sport)

**Status: RATIFIED (Xuan, 2026-07-26), Algorithm v2.1.**
**Source:** Notion "💧 During-Workout Hydration · Transparency Copy V1" (Algorithm v2.1, 2026-04-08)
— [page](https://app.notion.com/p/33ce3fdb754c81b9be8bf88932468bfb).
**Code:** `OfflineMacroCalculator.calculateDuringWorkoutHydration` + `calculateActualSweatRate`
(`app/lib/features/nutrition_plan/data/offline_macro_calculator.dart:922, :879`), mirrors
`generate-macros-v4`. **Code matches v2.1 constants** (verified: sweat tiers, temp baseline, replacement %).
**Scope of this slice:** single-sport during-hydration. Multi-segment tri (T1/T2 transitions +
redistribution, `calculateBrickHydration`) is a SEPARATE follow-up slice.

## Effective sweat rate (5-step chain)
```
base         = knownSweatRateMlPerHour/1000  OR  sweatTier[category]     # L/hr
tempMult     = clamp(1 + (tempC − 22)·0.04, 0.50, 1.80)
humidityMult = clamp(1 + max(0, humid% − 50)·0.002, 1.00, 1.10)
indoorMult   = 1.30 if indoor else 1.00
effective    = round3dp( clamp(base·tempMult·humidityMult·indoorMult, 0.30, 3.00) )   # L/hr
```

## Target, floor, ceiling
```
replacementPct = 30% (<60min) · 50% (60–90] · 60% (90–150] · 70% (150–240) · 80% (240+)
gate           = duration < 60 AND tempC < 30  → rate = round(effMlHr · pct), floor = 0
standard:
  ceiling = round( min(GI_limit, effMlHr) )          # GI: 800 run / 1200 bike ; + 100%-sweat cap
  floor   = max(0, (totalLoss − 0.02·BW·1000) / durH)   # keep deficit ≤ 2% BW
  rate    = min( max( round(effMlHr·pct), floor ), ceiling )
  flags:  ceiling<floor → "exceed 2% BW even at max"; realized deficit >3% → dehydration flag
swimming → all hydration outputs 0 (no drinking)
```

## Constants — research vs design choice (confidence per the SSOT)
| Constant | Value | Confidence / source |
|---|---|---|
| sweat tiers | light 0.90 · medium 1.28 · heavy 1.66 L/hr | **High** — Barnes & Baker 2019, n=1,303 (25/50/75th pct) |
| temp coefficient | +0.04 L/hr per °C over 22 °C, clamp 0.50–1.80× | Medium — Jenkins 2023 |
| humidity mult | +0.002 per %RH over 50, cap 1.10× | **Design choice** — Jenkins 2023 found humidity NOT significant; Mealvana conservative estimate |
| indoor mult | 1.30× | **Low / design choice** — not quantified in research |
| replacement % | 30/50/60/70/80 by duration | Med (60–240) · **High** (240+) · **Low design-choice** (30% <60min soft target) |
| 2% BW floor | 0.02·BW | **High** — Sawka 2007 ACSM |
| GI ceiling | 800 run · 1200 bike ml/hr | Peters 1999 / Coyle 1992 |
| 100%-sweat ceiling | effMlHr | **High** — hyponatremia guard (Hew-Butler 2015) |

## Worked examples (from the SSOT) — NOTE a rounding nuance
The doc's examples hand-round the sweat rate to **2 dp** (e.g. 1.29), but the code uses the
spec's own **round3dp** (1.293). So precise-algorithm outputs differ from the doc's printed
numbers by ~2–3 ml. **Vectors use the precise algorithm** (3dp), not the doc's 2dp hand-calc.
- Ex1 (90-min run, 65 kg, medium, 22 °C, 55%): doc prints rate 645 / floor 423 / ceiling 800;
  **precise: rate 647 / floor 426 / ceiling 800** (eff 1.293).
- Ex2 (45-min gate, 70 kg, medium, 22 °C): rate 384 / floor 0 / ceiling 800 (matches; no fractional carry).

## Ratification (resolved — Xuan, 2026-07-26)
1. **`round3dp` on the sweat rate is canonical** (the code + vectors). The doc's 2dp worked
   examples are illustrative only.
2. **Accepted as ratified design choices:** humidity 1.10×, indoor 1.30×, 30% <60-min soft target.

## Conformance
Vectors: `qa/vectors/fueling/during-workout-hydration.json`. Runner asserts
`calculateDuringWorkoutHydration` output (rate/floor/ceiling/replacementPct/effectiveSweatRate).
