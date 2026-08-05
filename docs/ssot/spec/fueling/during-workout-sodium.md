# SSOT — During-Workout Sodium

**Status: RATIFIED (Xuan, 2026-07-26).** No open ratification questions — no arbitrary design
constants; the tiers are research-backed and the formula is a direct multiply.
**Source:** Notion "🧂 During-Workout Sodium · Transparency Copy V1"
— [page](https://app.notion.com/p/33de3fdb754c819abb03cf8997c28c97).
**Code:** computed inside `OfflineMacroCalculator.calculateDuringWorkoutHydration`
(`offline_macro_calculator.dart:1033`, gate path :984). **Code matches the SSOT** (conc tiers verified).

## The rule
Replace 100% of the sodium in the fluid you drink — sodium just sets the *concentration* of the
already-determined fluid rate. Two steps, no independent gate/floor/ceiling/redistribution — all
of that is inherited from the fluid (hydration) algorithm.

## The math (RATIFIED)
```
conc_mg_per_l   = knownSodiumConcMgPerL   OR   sodiumTier[category]
sodiumRateMgph  = round( (recommendedFluidRateMlHr / 1000) · conc_mg_per_l )
sodiumTotalMg   = round( sodiumRateMgph · durationHr )
# recommendedFluidRateMlHr is the RATIFIED fluid output (post floor/ceiling) from the hydration slice.
# swimming -> 0 (no drinking). Range (floor/ceiling) is display-only = fluid floor/ceiling × conc.
```

## Concentration tiers (Baker 2016, n=506; 826 ± 239 mg/L)
| Type | mg/L | Percentile |
|---|---|---|
| Low | 650 | 25th |
| Average (a.k.a. medium alias) | 825 | 50th |
| High | 1,000 | 75th |
Known sweat-sodium test value overrides the tier.

## Note — inherits the ratified precise fluid rate
Sodium multiplies the fluid rate, so it inherits the round3dp precision decision. The doc's
example prints `532 mg/hr` (from fluid 645); at the ratified precise fluid rate (647) it is
**534 mg/hr**. Vectors use the precise value.

## Confidence (per SSOT)
Tiers **High** (Baker 2016). The "100% replacement of sodium in consumed fluid" principle is
**Medium** (Tiller 2019, Mosler 2020) — evidence stronger for direction than exact %. Not a
tunable design constant; recorded as the ratified rule.

## Conformance
Vectors: `qa/vectors/fueling/during-workout-sodium.json` — same function, asserting
`sodiumConcMgPerL`, `sodiumRateMgph`, `sodiumTotalMg`.
