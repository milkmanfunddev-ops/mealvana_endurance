# 30-003 · Stored during-run carb target sits below its own band and off the ratified during-carbs math (91 g vs 97-126 g)

- kind: bug
- status: triaged
- ticket: 30
- run: w10-20260924T1615Z
- screen: Activity detail (12 mi Run, fuelling plan)
- decision: 

**Steps.**
1. Timeline, Monday 21 September, tap the "12 mi Run" card (108 min, 12 mi, stored plan in `activities.nutrition_plan_data`).
2. Scroll to DURING and read carbs; compare with `detailedMacroTargets.duringRun` in the stored plan.

**Expected.**
By the ratified math: 108 min is in the 90-<150 band (45-60 g/hr), gut multiplier 1.2 gives 54-72, midpoint 63 g/hr, under the 70 g/hr running ceiling, so about 63 g/hr x 1.8 h = 113 g, inside the band shown.

**Actual.**
The screen shows DURING carbs 92 g in pink with an info icon, marker left of a 97-126 g band. The stored plan has `carbTotalG: 91`, `carbRateGPerH: 50.4`, `massNormRateGPerH: 0.6`, `absClampRangeGPerH: [54, 70]`, `carbsLowG: 97.2`, `carbsHighG: 126`. The target rate is mass-normalized (0.6 g/kg/h), which the spec says body weight must not affect, and it sits below the plan's own clamp range. Today's "Patrol H5" (120 min) has the same shape: 101 g target, 102 g of foods, band 108-140. The digest already records an unratified sport-ceiling clamp on the band (PRE-WORKOUT-BUNDLE-DIGEST.md, 2026-08-05 audit); the mass-normalized rate is a further change from the ratified rule. Numbers recorded, not recomputed beyond the formula above.

**Evidence.**
- runs/30/09-12mi-run-topoff-during.png
- runs/30/db-fuel-plan-12mi-run-0921.json (nutrition_plan_data.detailedMacroTargets.duringRun)
- runs/30/db-fuel-plans-summary.txt
- runs/30/screen-12mi-run-labels.txt
- runs/30/screen-patrol-h5-labels.txt

**Decision quote.** (no decision id exists for this rule, so it is filed as a bug; the quote is from the ratified spec `docs/ssot/spec/fueling/during-workout-carbs.md`, "The math (RATIFIED)" and "Gut multiplier · sport ceiling")
> ```
> [low, high] = durationBand(durationMin)          # raw g/hr band, strict < boundaries
> scaled      = [low·gutMult, high·gutMult]
> midpoint    = (scaledLow + scaledHigh) / 2
> finalRate   = min(midpoint, sportCeiling)        # g/hr, rounded to 1 dp
> ```
> - Body weight does NOT affect during-carbs (Jeukendrup 2014 — gut absorption isn't weight-scaled).

**Triage.**

Fix ticket 63 (Lee, 2026-09-25). Closed by the retest after it merges.
