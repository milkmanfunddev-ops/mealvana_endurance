# SSOT — During-Workout Carbohydrates (single-sport core)

**Status: recorded 2026-07-26 — awaiting ratification of one boundary question (below).**
**Source:** Claude artifact "Mealvana — During Carb · Three Variants"
([artifact](https://claude.ai/public/artifacts/5ff22213-f427-44ea-9f79-8d0531fff098)).
**Code:** `OfflineMacroCalculator.calculateDuringWorkoutCarbRate` (`offline_macro_calculator.dart:60`).
**Code matches the SSOT band table + constants.**
**Scope:** the single-sport pure core (band → gut → midpoint → sport ceiling). The
**personal-target override (≥90 min)** and **brick penalty (×0.8, multi-segment)** shown in the
doc's brick/swim variants are applied DOWNSTREAM (orchestrator / brick path) — a SEPARATE
follow-up slice, not in this pure function.

## The math (RATIFIED)
```
[low, high] = durationBand(durationMin)          # raw g/hr band, strict < boundaries
scaled      = [low·gutMult, high·gutMult]
midpoint    = (scaledLow + scaledHigh) / 2
finalRate   = min(midpoint, sportCeiling)        # g/hr, rounded to 1 dp
```

## Duration bands (raw g/hr) — strict `<` boundaries
| duration | band |
|---|---|
| <60 | 0–30 |
| 60–<90 | 30–60 |
| 90–<150 | 45–60 |
| 150–<240 | 60–90 |
| ≥240 | 80–100 |
*Jeukendrup 2014; Kerksick 2017. **Transparency note (SSOT):** the 5 bands are Mealvana's
interpolation (design choice) — direction well-supported, exact cutoffs are Mealvana's. Accept as ratified.*

## Gut multiplier · sport ceiling
- gut: Low 0.7× · Moderate/unknown 1.0× · High 1.2× (Jeukendrup 2017)
- ceiling: Running 70 · Cycling 120 · Swimming 0 · default 70 (Pfeiffer 2012). Swim → 0 zeroes the rate.
- Body weight does NOT affect during-carbs (Jeukendrup 2014 — gut absorption isn't weight-scaled).

## ⚠️ Ratification question (one)
The doc's single-sport **worked example** shows `60 min run → band 0–30 → 15 g/hr`, but the
doc's **own band table** ("60–90 · 30–60") and the code (strict `<60`) put **60 min in the
30–60 band → 45 g/hr**. The table + code agree; the worked example is the outlier.
**Vectors follow the table + code (60 min → 30–60 → 45 g/hr).** Confirm the example is just an
illustration error, or that the intended boundary is `≤60 → 0–30`.

## Deferred to a follow-up slice (multi-segment / race)
- **Personal-target override:** for efforts ≥90 min, a set personal g/hr replaces the midpoint.
- **Brick penalty:** run-after-bike ×0.8; band uses **cumulative event time**, not segment time.
- Swim segment still counts toward cumulative time though it consumes 0 g.

## Conformance
Vectors: `qa/vectors/fueling/during-workout-carbs.json` — asserts rate_gph · band_low/high ·
sport_ceiling · gut_multiplier.
